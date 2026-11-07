#include <metal_stdlib>
using namespace metal;

// Batch 28: Distort & Transitions remakes.
// rgba16Float, premultiplied alpha, sRGB-encoded (same as every other batch).
// Edge modes (AE "Edge Behavior"): 0 transparent, 1 repeat edge pixels, 2 tile (wrap), 3 mirror.
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s28Zero(address::clamp_to_zero, filter::linear, coord::pixel);

// ---------- shared helpers ----------

// Maps an integer texel index into range for an edge mode; returns -1 when the texel is outside (transparent).
static inline int addr28(int i, int n, uint mode) {
    if (mode == 1u) return clamp(i, 0, n - 1);
    if (mode == 2u) { int m = i % n; return m < 0 ? m + n : m; }
    if (mode == 3u) {
        int p2 = 2 * n;
        int m = i % p2; if (m < 0) m += p2;
        return m < n ? m : p2 - 1 - m;
    }
    return (i < 0 || i >= n) ? -1 : i;
}

static inline float4 tap28(texture2d<half, access::sample> t, int x, int y, int2 n, uint2 mode) {
    int xx = addr28(x, n.x, mode.x), yy = addr28(y, n.y, mode.y);
    if (xx < 0 || yy < 0) return float4(0.0);
    return float4(t.sample(s28Zero, float2(float(xx), float(yy)) + 0.5));
}

// Bilinear sample at a pixel-space coordinate with a per-axis edge mode (no seams when tiling / mirroring).
static float4 samp28(texture2d<half, access::sample> t, float2 q, uint2 mode) {
    if (mode.x == 0u && mode.y == 0u) return float4(t.sample(s28Zero, q));
    int2 n = int2(int(t.get_width()), int(t.get_height()));
    float2 g = q - 0.5;
    float2 f0 = floor(g);
    float2 fr = g - f0;
    int x0 = int(f0.x), y0 = int(f0.y);
    float4 a = tap28(t, x0, y0, n, mode), b = tap28(t, x0 + 1, y0, n, mode);
    float4 c = tap28(t, x0, y0 + 1, n, mode), d = tap28(t, x0 + 1, y0 + 1, n, mode);
    return mix(mix(a, b, fr.x), mix(c, d, fr.x), fr.y);
}

// Sub-pixel offset k of an n x n grid (n = 1, 2 or 3).
static inline float2 ss28(int k, int n) {
    int x = k % n, y = k / n;
    return (float2(float(x), float(y)) + 0.5) / float(n) - 0.5;
}

static inline float2 rot28(float2 v, float a) { float c = cos(a), s = sin(a); return float2(v.x * c - v.y * s, v.x * s + v.y * c); }
static inline float fmod28(float x, float y) { return x - y * floor(x / y); }

// AE-style pinning: 0 none, 1 all, 2 top, 3 bottom, 4 left, 5 right, 6 top+bottom, 7 left+right.
static float pin28(float2 c, float4 rect, uint mode, float soft) {
    if (mode == 0u) return 1.0;
    float2 uv = clamp((c - rect.xy) / max(rect.zw, float2(1.0)), 0.0, 1.0);
    float s = max(soft, 0.01);
    float top = smoothstep(0.0, s, uv.y), bottom = smoothstep(0.0, s, 1.0 - uv.y);
    float left = smoothstep(0.0, s, uv.x), right = smoothstep(0.0, s, 1.0 - uv.x);
    switch (mode) {
        case 1u: return top * bottom * left * right;
        case 2u: return top;
        case 3u: return bottom;
        case 4u: return left;
        case 5u: return right;
        case 6u: return top * bottom;
        case 7u: return left * right;
        default: return 1.0;
    }
}

// 3D gradient (Perlin-style) noise in roughly -1..1, quintic fade: smooth, no value-noise blockiness.
static float3 hg28(float3 p) {
    p = float3(dot(p, float3(127.1, 311.7, 74.7)), dot(p, float3(269.5, 183.3, 246.1)), dot(p, float3(113.5, 271.9, 124.6)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}
static float gn28(float3 x) {
    float3 i = floor(x), f = fract(x);
    float3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float n000 = dot(hg28(i), f);
    float n100 = dot(hg28(i + float3(1, 0, 0)), f - float3(1, 0, 0));
    float n010 = dot(hg28(i + float3(0, 1, 0)), f - float3(0, 1, 0));
    float n110 = dot(hg28(i + float3(1, 1, 0)), f - float3(1, 1, 0));
    float n001 = dot(hg28(i + float3(0, 0, 1)), f - float3(0, 0, 1));
    float n101 = dot(hg28(i + float3(1, 0, 1)), f - float3(1, 0, 1));
    float n011 = dot(hg28(i + float3(0, 1, 1)), f - float3(0, 1, 1));
    float n111 = dot(hg28(i + float3(1, 1, 1)), f - float3(1, 1, 1));
    return 1.6 * mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
                     mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}
// Fractal sum; `oct` may be fractional (last octave fades in), `gain` is the per-octave amplitude.
static float fbm28(float3 p, float oct, float gain) {
    float s = 0.0, a = 1.0, nrm = 0.0;
    int n = int(clamp(ceil(oct), 1.0, 8.0));
    for (int k = 0; k < n; k++) {
        float w = (float(k + 1) > oct) ? max(oct - float(k), 0.0) : 1.0;
        s += gn28(p) * a * w; nrm += a * w;
        p = float3(p.x * 1.6 - p.y * 1.2, p.x * 1.2 + p.y * 1.6, p.z * 1.7) + float3(5.2, 1.3, 2.9);
        a *= gain;
    }
    return s / max(nrm, 1e-4);
}

// ---------- Turbulent Displace ----------
// a = (amount px, size px, complexity, evolution turns); b = (stretch x, stretch y, offset x px, offset y px)
// c = (cycle length turns (0 = no cycle), pin softness, ...); d = layer rect
// i = (type, axis 0 XY / 1 X / 2 Y, packed: edge mode | aa grid << 4, pinning)
// type: 0 turbulent, 1 turbulent smoother, 2 bulge, 3 twist, 4 cross
static float2 turbField28(float2 pp, float z, constant EffectParams& p) {
    uint type = p.i.x;
    float oct = clamp(p.a.z, 1.0, 8.0);
    float gain = type == 1u ? 0.35 : 0.5;
    if (type == 1u) oct = max(1.0, oct * 0.75);
    float3 np = float3(pp, z);
    if (type == 0u || type == 1u) {
        return float2(fbm28(np, oct, gain), fbm28(np + float3(19.1, 7.3, 3.7), oct, gain)) * 0.7;
    }
    if (type == 4u) {
        float v = fbm28(np, oct, gain) * 0.7;
        return float2(v, v);
    }
    // Bulge / twist: gradient (or its perpendicular, a curl field) of one scalar noise.
    float e = 0.08;
    float n0 = fbm28(np, oct, gain);
    float nx = fbm28(np + float3(e, 0, 0), oct, gain);
    float ny = fbm28(np + float3(0, e, 0), oct, gain);
    float2 g = float2(nx - n0, ny - n0) / e * 0.12;
    return type == 3u ? float2(g.y, -g.x) : g;
}

static float2 turbAt28(float2 c, constant EffectParams& p) {
    float2 pp = (c + p.b.zw) / (max(p.a.y, 1.0) * max(p.b.xy, float2(0.01)));
    float evo = p.a.w;
    float L = p.c.x;
    float2 d;
    if (L > 0.0) {
        // Cycle Evolution: blend two noise slices so evolution loops seamlessly every L turns.
        float z = fmod28(evo, L);
        float u = z / L;
        d = mix(turbField28(pp, z, p), turbField28(pp, z - L, p), u);
    } else {
        d = turbField28(pp, evo, p);
    }
    if (p.i.y == 1u) d.y = 0.0;
    if (p.i.y == 2u) d.x = 0.0;
    float k = pin28(c, p.d, p.i.w, p.c.y);
    return c + d * 2.0 * p.a.x * k;
}

kernel void fxTurbulent28(texture2d<half, access::sample> src [[texture(0)]],
                          texture2d<half, access::write> dst [[texture(1)]],
                          constant EffectParams& p [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    uint em = p.i.z & 15u;
    int n = clamp(int((p.i.z >> 4) & 15u), 1, 3);
    uint2 mode = uint2(em, em);
    float4 acc = float4(0.0);
    for (int k = 0; k < n * n; k++) {
        float2 cs = c + ss28(k, n);
        acc += samp28(src, turbAt28(cs, p), mode);
    }
    dst.write(half4(acc / float(n * n)), gid);
}

// ---------- Wave Warp (AE) with antialiasing ----------
// a = (height px, width px, direction deg, phase rad); b = layer rect; c.x = pin falloff
// i = (type, pinning, aa grid 1..3, edge mode)
static float2 waveAt28(float2 c, constant EffectParams& p) {
    float ang = p.a.z * M_PI_F / 180.0;
    float2 dir = float2(sin(ang), -cos(ang));
    float2 perp = float2(dir.y, -dir.x);
    float t = dot(c - p.b.xy, perp) / max(p.a.y, 1.0) * 2.0 * M_PI_F + p.a.w;
    float ph = fract(t / (2.0 * M_PI_F));
    float w;
    switch (p.i.x) {
        case 1u: w = sin(t) >= 0.0 ? 1.0 : -1.0; break;
        case 2u: w = 2.0 * abs(2.0 * ph - 1.0) - 1.0; break;
        case 3u: w = 2.0 * ph - 1.0; break;
        case 4u: { float q2 = fract(ph * 2.0) * 2.0 - 1.0; w = (ph < 0.5 ? 1.0 : -1.0) * sqrt(max(0.0, 1.0 - q2 * q2)); break; }
        case 5u: { float q2 = ph * 2.0 - 1.0; w = sqrt(max(0.0, 1.0 - q2 * q2)) * 2.0 - 1.0; break; }
        case 6u: {
            float a0 = floor(t / M_PI_F), f0 = fract(t / M_PI_F);
            float h0 = fract(sin(a0 * 127.1) * 43758.5) * 2.0 - 1.0, h1 = fract(sin((a0 + 1.0) * 127.1) * 43758.5) * 2.0 - 1.0;
            w = mix(h0, h1, f0 * f0 * (3.0 - 2.0 * f0)); break;
        }
        default: w = sin(t);
    }
    return c + dir * w * p.a.x * pin28(c, p.b, p.i.y, p.c.x);
}

kernel void fxWaveWarp28(texture2d<half, access::sample> src [[texture(0)]],
                         texture2d<half, access::write> dst [[texture(1)]],
                         constant EffectParams& p [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    int n = clamp(int(p.i.z), 1, 3);
    uint2 mode = uint2(p.i.w, p.i.w);
    float4 acc = float4(0.0);
    for (int k = 0; k < n * n; k++) acc += samp28(src, waveAt28(c + ss28(k, n), p), mode);
    dst.write(half4(acc / float(n * n)), gid);
}

// ---------- Polar Coordinates (seamless, supersampled) ----------
// a.x interpolation 0..1; i = (0 rect->polar / 1 polar->rect, aa grid 1..3)
kernel void fxPolar28(texture2d<half, access::sample> src [[texture(0)]],
                      texture2d<half, access::write> dst [[texture(1)]],
                      constant EffectParams& p [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c0 = float2(gid) + 0.5;
    int n = clamp(int(p.i.y), 1, 3);
    float interp = clamp(p.a.x, 0.0, 1.0);
    // The angle axis wraps around in rect->polar, so tile in x there (no dark seam at 12 o'clock).
    uint2 mode = (p.i.x == 0u && interp > 0.999) ? uint2(2u, 0u) : uint2(0u, 0u);
    float4 acc = float4(0.0);
    for (int k = 0; k < n * n; k++) {
        float2 c = c0 + ss28(k, n);
        float2 uv = c / size;
        float2 pq;
        if (p.i.x == 0u) {
            float2 d = uv - 0.5;
            float ang = atan2(d.x, -d.y) / (2.0 * M_PI_F) + 0.5;
            pq = float2(ang, length(d) * 2.0) * size;
        } else {
            float ang = (uv.x - 0.5) * 2.0 * M_PI_F;
            pq = (float2(sin(ang), -cos(ang)) * uv.y * 0.5 + 0.5) * size;
        }
        acc += samp28(src, mix(c, pq, interp), mode);
    }
    dst.write(half4(acc / float(n * n)), gid);
}

// ---------- Ripple (AE) ----------
// a = (center xy px, radius px, wave width px); b = (height px, phase rad, conversion 0 asym / 1 sym, aa grid)
// i.x = edge mode
static float2 rippleAt28(float2 c, constant EffectParams& p) {
    float2 d = c - p.a.xy;
    float r = length(d);
    float R = max(p.a.z, 1.0);
    if (r >= R || r < 1e-3) return c;
    float fall = 1.0 - r / R;
    fall = fall * fall * (3.0 - 2.0 * fall);         // smooth fade into the undisturbed area (no crease at the rim)
    float core = smoothstep(0.0, max(p.a.w * 0.5, 1.0), r); // calm center instead of a pinched singularity
    float ph = r / max(p.a.w, 1.0) * 2.0 * M_PI_F - p.b.y;
    float w = sin(ph) * p.b.x * fall * core;
    float2 rd = d / r;
    if (p.b.z > 0.5) return c + rd * w;
    // Asymmetric (AE default look): add a tangential swirl component out of phase with the radial one.
    float2 tg = float2(-rd.y, rd.x);
    return c + rd * w + tg * cos(ph) * p.b.x * fall * core * 0.5;
}

kernel void fxRipple28(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    int n = int(clamp(p.b.w, 1.0, 3.0));
    uint2 mode = uint2(p.i.x, p.i.x);
    float4 acc = float4(0.0);
    for (int k = 0; k < n * n; k++) acc += samp28(src, rippleAt28(c + ss28(k, n), p), mode);
    dst.write(half4(acc / float(n * n)), gid);
}

// ---------- Magnify (AE) ----------
// a = (center xy px, magnification, size px); b = (feather px, opacity 0..1, shape 0 circle / 1 square, blend 0 normal / 1 add / 2 screen)
kernel void fxMagnify28(texture2d<half, access::sample> src [[texture(0)]],
                        texture2d<half, access::write> dst [[texture(1)]],
                        constant EffectParams& p [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s28Zero, c));
    float2 d = c - p.a.xy;
    float R = max(p.a.w, 1.0);
    float dist = p.b.z > 0.5 ? max(abs(d.x), abs(d.y)) : length(d);
    float fe = max(p.b.x, 1.0); // at least a one-pixel antialiased rim
    float m = (1.0 - smoothstep(R - fe, R, dist)) * clamp(p.b.y, 0.0, 1.0);
    if (m <= 0.0) { dst.write(half4(s), gid); return; }
    float mag = max(p.a.z, 0.01);
    // Large magnifications: 2x2 taps over the source footprint keep it smooth; minification (<1) averages too.
    float4 z = float4(0.0);
    for (int k = 0; k < 4; k++) z += float4(src.sample(s28Zero, p.a.xy + (d + ss28(k, 2)) / mag));
    z *= 0.25;
    float4 o;
    if (p.b.w > 1.5) o = float4(s.rgb + z.rgb - s.rgb * z.rgb, s.a + z.a - s.a * z.a);
    else if (p.b.w > 0.5) o = s + z;
    else o = z;
    o = mix(s, o, m);
    o.a = clamp(o.a, 0.0, 1.0);
    o.rgb = min(o.rgb, float3(o.a));
    dst.write(half4(o), gid);
}

// ---------- Transitions: antialiased pattern wipes ----------
// Same parameter layout as fxTrans9 for the modes below; a.x completion (already eased).
// 0 clock wipe, 7 pixel dissolve (b.x softness 0..1), 15 stripes, 16 checker, 17 radial blinds.
static inline float prog28(float x, float comp, float fe) {
    fe = max(fe, 1e-4);
    float thr = mix(-fe, 1.0 + fe, comp);
    return smoothstep(thr - fe, thr + fe, x);
}

static float transMask28(float2 c, float2 size, constant EffectParams& p, float comp) {
    float2 ctr = p.c.zw;
    switch (p.i.x) {
        case 0u: {
            float2 q = c - ctr;
            float r = max(length(q), 1.0);
            float fr = fract((atan2(q.x, -q.y) - p.a.z) * p.a.w / 6.2831853);
            return prog28(fr, comp, max(p.a.y, 0.5) / (r * 6.2831853));
        }
        case 15u: {
            float2 dir = float2(cos(p.b.x), sin(p.b.x));
            float2 perp = float2(-dir.y, dir.x);
            float2 q = c - size * 0.5;
            float extD = max(0.5 * (abs(dir.x) * size.x + abs(dir.y) * size.y), 1.0);
            float extP = max(0.5 * (abs(perp.x) * size.x + abs(perp.y) * size.y), 1.0);
            float u = (dot(q, dir) + extD) / (2.0 * extD);
            float v = saturate((dot(q, perp) + extP) / (2.0 * extP));
            float cnt = floor(max(p.a.y, 1.0));
            float local = fract(u * cnt);
            float stg = max(p.a.w, 0.0);
            float cc = clamp(comp * (1.0 + stg) - stg * v, 0.0, 1.0);
            float pxw = cnt / (2.0 * extD); // one pixel in stripe units
            return prog28(local, cc, max(p.a.z, pxw));
        }
        case 16u: {
            float cs = max(p.a.y, 2.0);
            float2 cell = floor(c / cs);
            float par = fmod28(cell.x + cell.y, 2.0);
            float cc = clamp(par < 0.5 ? comp * 1.6 : comp * 1.6 - 0.6, 0.0, 1.0);
            return prog28(fract(c.x / cs), cc, max(p.a.z, 1.0 / cs));
        }
        case 17u: {
            float2 q = c - ctr;
            float cnt = floor(max(p.a.y, 1.0));
            float a01 = fract((atan2(q.y, q.x) - p.a.w) / 6.2831853);
            float r = max(length(q), 1.0);
            float pxw = cnt / (r * 6.2831853);
            return prog28(fract(a01 * cnt), comp, max(p.a.z, min(pxw, 0.5)));
        }
        default: return 1.0;
    }
}

kernel void fxTrans28(texture2d<half, access::sample> src [[texture(0)]],
                      texture2d<half, access::write> dst [[texture(1)]],
                      constant EffectParams& p [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s28Zero, c));
    float comp = clamp(p.a.x, 0.0, 1.0);
    if (comp >= 1.0) { dst.write(half4(0.0h), gid); return; }
    if (comp <= 0.0) { dst.write(half4(s), gid); return; }
    float m;
    if (p.i.x == 7u) {
        // Pixel dissolve: each block fades over a softness window instead of blinking (coherent, no per-pixel noise).
        float bs = max(p.a.y, 1.0);
        float2 cell = floor(c / bs);
        float2 hp = cell + float2(p.a.z * 17.13, p.a.z * 3.71);
        float3 q3 = fract(float3(hp.xyx) * 0.1031); q3 += dot(q3, q3.yzx + 33.33);
        float h = fract((q3.x + q3.y) * q3.z);
        float w = clamp(p.b.x, 0.0, 1.0);
        if (w < 1e-3) m = h >= comp ? 1.0 : 0.0;
        else m = saturate((h - mix(-w, 1.0, comp)) / w);
    } else {
        // 3x3 supersampled mask: smooth stripe / checker seams and the clock-hand start line.
        m = 0.0;
        for (int k = 0; k < 9; k++) m += transMask28(c + ss28(k, 3), size, p, comp);
        m /= 9.0;
    }
    dst.write(half4(s * m), gid);
}


// ---------- Batch 14 & batch 6 warps, supersampled with an edge-behavior override ----------
// The fxWarp14 / fxDistort6 warps evaluated as functions of the pixel position so they can be supersampled
// (Antialiasing) and given AE-style Edge Behavior. em: 0 = the effect's own default edges, 1 transparent,
// 2 repeat edge pixels, 3 tile, 4 mirror. defMode = the original sampler (0 zero, 1 clamp).
static inline float4 tapE28(texture2d<half, access::sample> t, uint em, uint defMode, float2 q) {
    uint m = em == 0u ? defMode : (em == 1u ? 0u : (em == 2u ? 1u : (em == 3u ? 2u : 3u)));
    return samp28(t, q, uint2(m, m));
}
static inline float lum14x28(float4 c) { return dot(c.rgb, float3(0.2126, 0.7152, 0.0722)); }
static float hash14x28(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static inline float2 hash2x28(float2 cell, float s) { return float2(hash14x28(cell + s * 3.7), hash14x28(cell.yx + s * 5.3 + 17.0)); }
static float vn14x28(float2 x) {
    float2 i = floor(x), f = fract(x); float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash14x28(i), hash14x28(i + float2(1, 0)), u.x), mix(hash14x28(i + float2(0, 1)), hash14x28(i + float2(1, 1)), u.x), u.y);
}
static inline float2 rot14x28(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(v.x * cs - v.y * sn, v.x * sn + v.y * cs); }
static inline float mir14x28(float x) { return 1.0 - abs(1.0 - 2.0 * fract(x * 0.5)); }
static inline float wav14x28(float2 q, float t) {
    return sin(dot(q, float2(1.0, 0.3)) + t * 1.3) + sin(dot(q, float2(-0.4, 1.1)) * 1.3 - t * 1.7)
         + 0.6 * sin(dot(q, float2(0.7, -0.8)) * 2.1 + t * 2.3) + 0.4 * sin(dot(q, float2(-1.2, -0.5)) * 2.9 - t * 1.1);
}

static float4 warp14at28(texture2d<half, access::sample> src, float2 c, float2 size, constant EffectParams& p, uint em) {
    float4 o = tapE28(src, em, 1u, c);
    float t = p.d.x;
    float hmin14 = max(min(size.x, size.y) * 0.5, 1.0);
    float twoPi = 6.2831853;
    switch (p.i.x) {
        case 0: { // black hole: a = (radius frac, lensing, glow 0-1, spin), b.xy = center
            float2 ctr = p.b.xy;
            float R = max(p.a.x * hmin14, 1.0);
            float2 d = c - ctr;
            float r = max(length(d), 1e-3);
            float2 dir = d / r;
            float rs = r - p.a.y * R * R / r;
            float ang = p.a.w * (R / r) * (R / r) + p.a.w * t * 0.5;
            float4 s = tapE28(src, em, 1u, ctr + rot14x28(dir, ang) * rs);
            float hz = smoothstep(R * 0.92, R * 1.02, r);
            o = s * hz + float4(0, 0, 0, 1) * (1.0 - hz);
            float rr = (r - 1.5 * R) / (0.4 * R);
            float g = exp(-rr * rr) * p.a.z * (0.75 + 0.25 * sin(atan2(d.y, d.x) * 3.0 + t * 4.0 * p.a.w));
            o.rgb += g * float3(1.0, 0.62, 0.25);
            o.a = max(o.a, min(g, 1.0));
            break;
        }
        case 1: { // droste spiral: a = (scale ratio, twist, zoom speed, rotation rad), b.xy = center
            float2 d = c - p.b.xy;
            float r = max(length(d), 1e-3);
            float th = atan2(d.y, d.x) + p.a.w;
            float L = log(max(p.a.x, 1.05));
            float Rref = hmin14 * 0.3;
            float u = log(r / Rref) + th / twoPi * L * p.a.y - t * p.a.z * L;
            u = u - L * floor(u / L);
            float rr = Rref * exp(u);
            o = tapE28(src, em, 1u, p.b.xy + float2(cos(th - p.a.w), sin(th - p.a.w)) * rr);
            break;
        }
        case 2: { // fractal zoom: a = (scale, speed, rotation rad/level, mix 0-1), b.xy = center
            float2 d = c - p.b.xy;
            float s = max(p.a.x, 1.1);
            float f = fract(t * p.a.y);
            float4 acc = float4(0.0); float ws = 0.0;
            for (int k = 0; k < 4; k++) {
                float e = float(k) + f;
                float zf = pow(s, e - 1.0);
                float w = sin(3.1415926 * e / 4.0);
                acc += tapE28(src, em, 0u, p.b.xy + rot14x28(d, p.a.z * e) / max(zf, 1e-3)) * w;
                ws += w;
            }
            acc /= max(ws, 1e-3);
            o = mix(o, acc, p.a.w);
            break;
        }
        case 3: { // page curl: a = (progress 0-1, angle rad, curl radius frac, shadow 0-1)
            if (p.a.x <= 0.0) break;
            if (p.a.x >= 1.0) { o = float4(0.0); break; }
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            float d0 = min(min(0.0, dot(float2(size.x, 0), dir)), min(dot(float2(0, size.y), dir), dot(size, dir)));
            float d1 = max(max(0.0, dot(float2(size.x, 0), dir)), max(dot(float2(0, size.y), dir), dot(size, dir)));
            float ext = max(d1 - d0, 1.0);
            float x = dot(c, dir) - d0;
            float R = max(p.a.z * hmin14, 1.0);
            float F = ext * (1.0 - clamp(p.a.x, 0.0, 1.0)) - R * 0.5 * clamp(p.a.x * 4.0, 0.0, 1.0);
            float dd = x - F;
            float4 res;
            if (dd > R) {
                // Removed paper cannot generate a rectangular shadow where no paper exists.
                res = float4(0.0);
            } else if (dd > 0.0) {
                float th = asin(clamp(dd / R, 0.0, 1.0));
                float xb = F + R * (3.1415926 - th);
                float xf = F + R * th;
                float4 b = tapE28(src, em, 0u, c + dir * (xb - x));
                if (xb < ext && b.a > 0.01) {
                    res = float4(mix(b.rgb, float3(0.92) * b.a, 0.55) * (0.75 + 0.25 * cos(th)), b.a);
                } else {
                    res = tapE28(src, em, 0u, c + dir * (xf - x));
                    res.rgb *= 1.0 - p.a.w * 0.4 * (dd / R);
                }
            } else {
                float xb = F + 3.1415926 * R + (F - x);
                float4 b = xb < ext ? tapE28(src, em, 0u, c + dir * (xb - x)) : float4(0.0);
                float4 fr = o;
                fr.rgb *= 1.0 - p.a.w * 0.5 * exp(dd / R) * b.a;
                float4 bk = float4(mix(b.rgb, float3(0.92) * b.a, 0.55) * 0.75, b.a);
                res = bk + fr * (1.0 - bk.a);
            }
            o = res;
            break;
        }
        case 4: { // accordion fold: a = (folds, depth 0-1, angle rad, shading 0-1)
            float2 dir = float2(cos(p.a.z), sin(p.a.z));
            float2 per = float2(-dir.y, dir.x);
            float2 d = c - size * 0.5;
            float x = dot(d, dir), y = dot(d, per);
            float ext = abs(size.x * dir.x) + abs(size.y * dir.y);
            float P = max(ext / max(p.a.x, 1.0), 2.0);
            float sc = 1.0 - 0.6 * p.a.y;
            float xs = x / sc;
            float u = fract(xs / P);
            float idx = floor(xs / P);
            float even = fmod(abs(idx), 2.0);
            float tri = even < 0.5 ? u : 1.0 - u;
            float ys = y * (1.0 + p.a.y * 0.18 * (tri - 0.5));
            o = tapE28(src, em, 0u, size * 0.5 + dir * xs + per * ys);
            o.rgb *= 1.0 - p.a.w * 0.6 * tri;
            break;
        }
        case 5: { // skew / shear: a = (tan x, tan y, 0, 0), b.xy = anchor
            float2 d = c - p.b.xy;
            float x = d.x - p.a.x * d.y;
            float y = d.y - p.a.y * x;
            o = tapE28(src, em, 0u, p.b.xy + float2(x, y));
            break;
        }
        case 6: { // perspective tilt (keystone): a = (tilt x, tilt y, zoom, 0)
            float2 h = size * 0.5;
            float2 uv = (c - h) / h;
            float fy = max(1.0 + p.a.y * uv.y * 0.6, 0.1);
            float fx = max(1.0 + p.a.x * uv.x * 0.6, 0.1);
            float2 s = float2(uv.x / fy, uv.y / fx) / max(p.a.z, 0.05);
            o = tapE28(src, em, 0u, h + s * h);
            break;
        }
        case 7: { // stretch segment: a = (position 0-1, half width frac, stretch, angle rad)
            float2 dir = float2(cos(p.a.w), sin(p.a.w));
            float ext = abs(size.x * dir.x) + abs(size.y * dir.y);
            float2 P = size * 0.5 + dir * (p.a.x - 0.5) * ext;
            float s = dot(c - P, dir);
            float st = max(p.a.z, 0.1);
            float Hs = max(p.a.y * ext, 0.5);
            float Ho = Hs * st;
            float ssrc = abs(s) < Ho ? s / st : s - sign(s) * (Ho - Hs);
            o = tapE28(src, em, 0u, c + dir * (ssrc - s));
            break;
        }
        case 8: { // traveling wave line: a = (amplitude frac, wavelength frac, speed, angle rad), b.x = packet width frac
            float2 dir = float2(cos(p.a.w), sin(p.a.w));
            float2 per = float2(-dir.y, dir.x);
            float ext = abs(size.x * dir.x) + abs(size.y * dir.y);
            float s = dot(c - size * 0.5, dir) + ext * 0.5;
            float front = (fract(t * p.a.z) * 1.4 - 0.2) * ext;
            float w = max(p.b.x * ext, 1.0);
            float q = (s - front) / w;
            float env = exp(-q * q);
            float lam = max(p.a.y * hmin14, 1.0);
            float wv = sin((s - front) / lam * twoPi);
            o = tapE28(src, em, 1u, c + per * wv * env * p.a.x * hmin14);
            o.rgb *= 1.0 + 0.15 * wv * env;
            break;
        }
        case 9: { // twist columns: a = (columns, twist rad, speed, shading 0-1)
            float cw = max(size.x / max(p.a.x, 1.0), 2.0);
            float col = floor(c.x / cw);
            float cx = (col + 0.5) * cw;
            float u = clamp((c.x - cx) / (cw * 0.5), -1.0, 1.0);
            float ph = p.a.y * (c.y / size.y - 0.5) + t * p.a.z + col * 0.37;
            float a0 = asin(u) + ph;
            float us = sin(a0);
            float sh = cos(a0);
            o = tapE28(src, em, 1u, float2(cx + us * cw * 0.5, c.y));
            float lit = sh >= 0.0 ? (0.7 + 0.3 * sqrt(max(1.0 - u * u, 0.0))) : 0.45;
            o.rgb *= mix(1.0, lit, p.a.w);
            break;
        }
        case 10: { // smear drag: a = (length frac, angle rad, falloff, brightness bias 0-1)
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            float L = p.a.x * hmin14 * 2.0;
            float4 m = o;
            for (int k = 1; k <= 24; k++) {
                float f = float(k) / 24.0;
                float w = pow(1.0 - f, max(p.a.z, 0.05));
                float4 s = tapE28(src, em, 1u, c - dir * L * f);
                float gate = mix(1.0, smoothstep(0.1, 0.6, lum14x28(s)), p.a.w);
                m = max(m, s * w * gate);
            }
            o = m;
            break;
        }
        case 11: { // mesh jitter: a = (cell frac, amount 0-1, rate /s, seed)
            float cs = max(p.a.x * hmin14, 2.0);
            float fr = floor(t * p.a.z);
            float2 g = c / cs;
            float2 i = floor(g), f = fract(g);
            float2 u = f * f * (3.0 - 2.0 * f);
            float sd = p.a.w * 1.73 + fr * 7.31;
            float2 o00 = hash2x28(i, sd) - 0.5, o10 = hash2x28(i + float2(1, 0), sd) - 0.5;
            float2 o01 = hash2x28(i + float2(0, 1), sd) - 0.5, o11 = hash2x28(i + float2(1, 1), sd) - 0.5;
            float2 off = mix(mix(o00, o10, u.x), mix(o01, o11, u.x), u.y);
            o = tapE28(src, em, 1u, c + off * 2.0 * p.a.y * cs);
            break;
        }
        case 12: { // elastic bounce: a = (amount, frequency, damping, radius frac), b.xy = center
            float2 d = c - p.b.xy;
            float R = max(p.a.w * hmin14, 1.0);
            float fall = 1.0 - smoothstep(0.0, 1.0, length(d) / R);
            float env = exp(-p.a.z * t) * sin(twoPi * p.a.y * t + 0.6);
            float A = p.a.x * env * fall;
            float2 sc = float2(1.0 + A, 1.0 - A * 0.8);
            o = tapE28(src, em, 1u, p.b.xy + d / max(sc, float2(0.05)));
            break;
        }
        case 13: { // moving magnifier: a = (radius frac, magnification, rim frac, speed), b = (cx, cy, orbit frac, 0)
            float R = max(p.a.x * hmin14, 2.0);
            float orb = p.b.z * hmin14;
            float ang = t * p.a.w * twoPi;
            float2 lc = p.b.xy + float2(cos(ang), sin(ang) * 0.6) * orb;
            float2 d = c - lc;
            float r = length(d) / R;
            if (r < 1.0) {
                float bar = 1.0 - 0.25 * (1.0 - r * r);
                float4 s = tapE28(src, em, 1u, lc + d * bar / max(p.a.y, 0.1));
                float spec = pow(max(1.0 - length(d / R - float2(-0.35, -0.4)) * 1.6, 0.0), 3.0) * 0.35;
                o = s;
                o.rgb += spec * o.a;
            }
            float rim = max(p.a.z, 0.005);
            float e = abs(r - 1.0) / rim;
            if (e < 1.0) {
                float sh = 0.55 + 0.45 * dot(normalize(d + 1e-4), float2(-0.6, -0.8));
                float k = smoothstep(1.0, 0.6, e);
                o = mix(o, float4(float3(0.35 + 0.5 * sh), 1.0), k);
            }
            break;
        }
        case 14: { // tunnel warp (log-polar): a = (speed, twist, repeats, depth fade), b.xy = center
            float2 d = c - p.b.xy;
            float r = max(length(d), 1e-3);
            float th = atan2(d.y, d.x) / twoPi + 0.5;
            float lr = log(r / hmin14);
            float sx = mir14x28(th * 2.0 * max(p.a.z, 0.5) + p.a.y * lr);
            float sy = mir14x28(lr * max(p.a.z, 0.5) * 0.5 - t * p.a.x);
            o = tapE28(src, em, 1u, float2(sx, sy) * size);
            o *= pow(clamp(r / hmin14, 0.0, 1.0), p.a.w);
            break;
        }
        case 15: { // puff / inflate: a = (amount, radius frac, highlight 0-1, 0)
            float R = max(p.a.y * hmin14, 1.0);
            float2 g = float2(0.0);
            for (int k = 0; k < 12; k++) {
                float an = float(k) * (twoPi / 12.0);
                float2 dv = float2(cos(an), sin(an));
                float4 s = tapE28(src, em, 1u, c + dv * R);
                g += dv * (lum14x28(s) * 0.7 + s.a * 0.3);
            }
            g /= 6.0;
            o = tapE28(src, em, 1u, c + g * p.a.x * R);
            float hl = clamp(dot(g, float2(0.6, 0.8)), 0.0, 1.0);
            o.rgb += hl * p.a.z * 0.5 * o.a;
            break;
        }
        case 16: { // pinch waves (angular lobes): a = (amount, lobes, speed, radius frac), b.xy = center
            float2 d = c - p.b.xy;
            float r = length(d);
            float R = max(p.a.w * hmin14, 1.0);
            float fall = 1.0 - smoothstep(0.0, 1.0, r / R);
            float th = atan2(d.y, d.x);
            float wv = sin(th * floor(max(p.a.y, 1.0)) + t * p.a.z * twoPi);
            float s = 1.0 + p.a.x * wv * fall * 0.6;
            o = tapE28(src, em, 1u, p.b.xy + d * max(s, 0.05));
            break;
        }
        case 17: { // polar ripple (rotational waves): a = (angle rad, wavelength frac, speed, decay), b.xy = center
            float2 d = c - p.b.xy;
            float r = length(d);
            float lam = max(p.a.y * hmin14, 1.0);
            float ph = (r / lam - t * p.a.z) * twoPi;
            float ang = p.a.x * sin(ph) * exp(-p.a.w * 3.0 * r / hmin14);
            o = tapE28(src, em, 1u, p.b.xy + rot14x28(d, ang));
            break;
        }
        case 18: { // vortex spin: a = (strength turns, radius frac, speed turns/s, power), b.xy = center
            float2 d = c - p.b.xy;
            float r = length(d);
            float R = max(p.a.y * hmin14, 1.0);
            float fall = pow(max(1.0 - r / R, 0.0), max(p.a.w, 0.1));
            float ang = (p.a.x + t * p.a.z) * twoPi * fall;
            o = tapE28(src, em, 1u, p.b.xy + rot14x28(d, ang));
            break;
        }
        case 19: { // glass blocks: a = (block frac, refraction, bevel 0-0.5, highlight 0-1)
            float cs = max(p.a.x * hmin14, 3.0);
            float2 cell = floor(c / cs);
            float2 q = fract(c / cs) - 0.5;
            float2 cc = (cell + 0.5) * cs;
            float k = 1.0 - p.a.y * 1.5;
            float e = max(abs(q.x), abs(q.y));
            float bv = max(p.a.z, 0.001);
            float edge = smoothstep(0.5 - bv, 0.5, e);
            float2 nrm = abs(q.x) > abs(q.y) ? float2(sign(q.x), 0.0) : float2(0.0, sign(q.y));
            o = tapE28(src, em, 1u, cc + q * cs * k - nrm * edge * cs * 0.25);
            float hl = edge * clamp(dot(nrm, float2(-0.7, -0.7)) + 0.3, 0.0, 1.0);
            o.rgb = o.rgb * (1.0 - edge * 0.25) + hl * p.a.w * 0.6 * max(o.a, 0.3);
            o.a = max(o.a, hl * p.a.w * 0.6);
            break;
        }
        case 20: { // frosted window: a = (roughness frac, grain frac, frost 0-1, seed), b = (cx, cy, clear radius frac, 0)
            float rough = p.a.x * hmin14;
            float gs = max(p.a.y * hmin14, 1.0);
            float2 cl = c - p.b.xy;
            float clear = smoothstep(p.b.z * hmin14 * 0.8, p.b.z * hmin14 * 1.1 + 1.0, length(cl));
            float n1 = vn14x28(c / gs + p.a.w * 3.1), n2 = vn14x28(c / gs + float2(7.3, 2.9) + p.a.w * 1.7);
            float4 acc = float4(0.0);
            for (int k = 0; k < 4; k++) {
                float2 j = hash2x28(c + float2(float(k) * 13.0, float(k) * 7.0), p.a.w) - 0.5;
                acc += tapE28(src, em, 1u, c + (float2(n1, n2) - 0.5 + j * 0.8) * 2.0 * rough * clear);
            }
            acc *= 0.25;
            float fr = p.a.z * clear;
            acc.rgb = mix(acc.rgb, float3(0.85, 0.9, 0.95) * max(acc.a, 0.6) * 0.55 + acc.rgb * 0.45, fr);
            acc.a = max(acc.a, fr * 0.6);
            o = acc;
            break;
        }
        case 21: { // water surface: a = (strength frac, scale frac, speed, highlight 0-1)
            float sc = max(p.a.y * hmin14, 1.0);
            float2 q = c / sc;
            float tt = t * p.a.z * 2.0;
            const float e = 0.05;
            float h = wav14x28(q, tt);
            float2 g = float2(wav14x28(q + float2(e, 0), tt) - wav14x28(q - float2(e, 0), tt),
                              wav14x28(q + float2(0, e), tt) - wav14x28(q - float2(0, e), tt)) / (2.0 * e);
            o = tapE28(src, em, 1u, c + g * p.a.x * hmin14 * 0.1);
            float ca = pow(clamp(h / 3.0 * 0.5 + 0.5, 0.0, 1.0), 6.0) * 3.0;
            o.rgb += ca * p.a.w * float3(0.75, 0.92, 1.0) * max(o.a, 0.2) * 0.5;
            o.a = max(o.a, min(ca * p.a.w * 0.3, 1.0));
            break;
        }
        case 22: { // mirage: a = (amount frac, band frac, speed, horizon 0-1), b.x = reflection 0-1
            float bh = max(p.a.y * hmin14, 1.0);
            float yb = c.y / bh;
            float nz = vn14x28(float2(yb * 1.7, t * p.a.z * 2.0)) - 0.5;
            float dx = (sin(yb * twoPi + t * p.a.z * 5.0) * 0.6 + nz * 1.6) * p.a.x * hmin14;
            float hy = p.a.w * size.y;
            float below = smoothstep(hy - 2.0, hy + 2.0, c.y);
            float4 a0 = tapE28(src, em, 1u, float2(c.x + dx * (0.4 + below), c.y));
            float ry = hy - (c.y - hy) * 1.2;
            float4 rf = tapE28(src, em, 1u, float2(c.x + dx * 1.6, ry + nz * bh));
            float fade = exp(-max(c.y - hy, 0.0) / max(size.y * 0.3, 1.0));
            o = mix(a0, max(a0, rf * float4(0.85, 0.9, 1.0, 1.0)), below * p.b.x * fade);
            break;
        }
        case 23: { // earthquake chunks: a = (intensity frac, block frac, frequency /s, seed), b.x = cracks 0-1
            float bs = max(p.a.y * hmin14, 3.0);
            float fr = floor(t * p.a.z);
            float2 shift = (hash2x28(float2(fr, 3.0), p.a.w) - 0.5) * 0.4;
            float2 g = c / bs + shift;
            float row = floor(g.y);
            g.x += hash14x28(float2(row, p.a.w + 11.0)) * 0.9;
            float2 cell = floor(g);
            float2 lq = fract(g);
            float2 v = (hash2x28(cell, p.a.w + fr * 3.17) - 0.5) * 2.0 * p.a.x * hmin14;
            float2 glob = (hash2x28(float2(fr, 1.0), p.a.w * 2.0) - 0.5) * p.a.x * hmin14 * 0.5;
            o = tapE28(src, em, 1u, c + v + glob);
            float ed = min(min(lq.x, 1.0 - lq.x), min(lq.y, 1.0 - lq.y)) * bs;
            float crack = (1.0 - smoothstep(0.0, 1.5, ed)) * p.b.x;
            o.rgb *= 1.0 - crack * 0.8;
            o.a = max(o.a, crack * 0.8);
            break;
        }
        case 24: { // zoom rings: a = (ring width frac, zoom, speed, twist rad), b.xy = center
            float2 d = c - p.b.xy;
            float r = length(d);
            float w = max(p.a.x * hmin14, 2.0);
            float idx = floor(r / w - t * p.a.z);
            float alt = fmod(abs(idx), 2.0) < 0.5 ? 1.0 : -1.0;
            float s = max(1.0 + p.a.y * alt * 0.5, 0.1);
            o = tapE28(src, em, 1u, p.b.xy + rot14x28(d, p.a.w * alt) / s);
            break;
        }
    }
    return o;
}

kernel void fxWarp14AA28(texture2d<half, access::sample> src [[texture(0)]],
                         texture2d<half, access::write> dst [[texture(1)]],
                         texture2d<half, access::sample> aux [[texture(2)]],
                         constant EffectParams& p [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    int n = clamp(int(p.i.y), 1, 3);
    float4 acc = float4(0.0);
    for (int k = 0; k < n * n; k++) acc += warp14at28(src, c + ss28(k, n), size, p, p.i.z);
    dst.write(half4(acc / float(n * n)), gid);
}

static inline float lum6x28(float4 c) { float3 u = c.a > 1e-6 ? c.rgb / c.a : float3(0.0); return dot(u, float3(0.2126, 0.7152, 0.0722)); }
static float hash6x28(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float hash63x28(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static float noise63x28(float3 x) {
    float3 i = floor(x), f = fract(x); float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash63x28(i), hash63x28(i + float3(1, 0, 0)), u.x), mix(hash63x28(i + float3(0, 1, 0)), hash63x28(i + float3(1, 1, 0)), u.x), u.y),
               mix(mix(hash63x28(i + float3(0, 0, 1)), hash63x28(i + float3(1, 0, 1)), u.x), mix(hash63x28(i + float3(0, 1, 1)), hash63x28(i + float3(1, 1, 1)), u.x), u.y), u.z);
}
static float fbm63x28(float3 x) {
    float v = 0.0, amp = 0.5;
    for (int k = 0; k < 4; k++) { v += noise63x28(x) * amp; x = x * 2.03 + float3(1.7, 9.2, 0.0); amp *= 0.5; }
    return v / 0.9375;
}
static inline float2 rot6x28(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(v.x * cs - v.y * sn, v.x * sn + v.y * cs); }
static inline float2 seed6x28(float2 cell, float s) { return float2(hash6x28(cell + s * 3.7), hash6x28(cell.yx + s * 5.3 + 17.0)); }

static float4 distort6at28(texture2d<half, access::sample> src, float2 c, float2 size, constant EffectParams& p, uint em) {
    float4 o = tapE28(src, em, 1u, c);
    float t = p.d.x;
    float hmin6 = max(min(size.x, size.y) * 0.5, 1.0);
    switch (p.i.x) {
        case 0: { // fisheye / anti-fisheye: a = (amount -1..1, radius 0-1.5 of half-min, cx, cy)
            float R = max(p.a.y * hmin6, 1.0);
            float2 d = (c - p.a.zw) / R;
            float r = length(d);
            if (r < 1.0 && r > 1e-4) {
                float e = max(1.0 + p.a.x * 1.5, 0.2);
                float rs = pow(r, e);
                o = tapE28(src, em, 1u, p.a.zw + d / r * rs * R);
            }
            break;
        }
        case 1: { // lens distortion: a = (k1, k2, chroma 0-1, zoom), b.xy = center
            float R = max(length(size) * 0.5, 1.0);
            float2 d = (c - p.b.xy) / R;
            float r2 = dot(d, d);
            float f = (1.0 + p.a.x * r2 + p.a.y * r2 * r2) / max(p.a.w, 0.05);
            float ch = p.a.z * 0.08 * sqrt(r2);
            float4 g = tapE28(src, em, 1u, p.b.xy + d * f * R);
            float4 rr = tapE28(src, em, 1u, p.b.xy + d * f * (1.0 + ch) * R);
            float4 bb = tapE28(src, em, 1u, p.b.xy + d * f * (1.0 - ch) * R);
            o = float4(rr.r, g.g, bb.b, max(g.a, max(rr.a, bb.a)));
            break;
        }
        case 2: { // glass refraction: a = (strength px, scale px, speed, seed)
            float sc = max(p.a.y, 1.0);
            float3 q = float3(c / sc, t * p.a.z + p.a.w * 1.37);
            const float e = 0.15;
            float2 g = float2(fbm63x28(q + float3(e, 0, 0)) - fbm63x28(q - float3(e, 0, 0)),
                              fbm63x28(q + float3(0, e, 0)) - fbm63x28(q - float3(0, e, 0))) / (2.0 * e);
            o = tapE28(src, em, 1u, c + g * p.a.x);
            float spec = pow(clamp(0.5 + 0.5 * dot(normalize(float3(-g, 1.0)), normalize(float3(0.4, -0.6, 1.0))), 0.0, 1.0), 24.0);
            o.rgb += spec * 0.25 * o.a;
            break;
        }
        case 3: { // liquid warp (domain warping): a = (amount px, scale px, speed, seed)
            float sc = max(p.a.y, 1.0);
            float z = t * p.a.z * 0.5 + p.a.w * 2.13;
            float2 u = c / sc;
            float2 q = float2(fbm63x28(float3(u, z)), fbm63x28(float3(u + float2(5.2, 1.3), z)));
            float2 w = float2(fbm63x28(float3(u + q * 3.0 + float2(1.7, 9.2), z * 1.3)), fbm63x28(float3(u + q * 3.0 + float2(8.3, 2.8), z * 1.3)));
            o = tapE28(src, em, 1u, c + (w - 0.5) * 2.0 * p.a.x);
            break;
        }
        case 4: { // water ripples: a = (amplitude px, wavelength px, speed, decay), b.xy = center
            float2 d = c - p.b.xy;
            float r = length(d);
            float2 dir = d / max(r, 1e-3);
            float ph = r / max(p.a.y, 1.0) * 6.2831853 - t * p.a.z * 6.2831853;
            float env = exp(-p.a.w * 3.0 * r / hmin6);
            o = tapE28(src, em, 1u, c + dir * sin(ph) * p.a.x * env);
            o.rgb *= 1.0 + 0.12 * cos(ph) * env * min(p.a.x, 10.0) / 10.0;
            break;
        }
        case 5: { // rain on glass: a = (cell px, drop size 0-1, refraction, speed), c.x = seed
            float cs = max(p.a.x, 2.0);
            float4 acc = o;
            for (int layer = 0; layer < 2; layer++) {
                float lsz = cs * (layer == 0 ? 1.0 : 1.7);
                float col = floor(c.x / lsz);
                float fall = t * p.a.w * (0.4 + hash6x28(float2(col, p.c.x + float(layer) * 11.0))) * 1.5;
                float2 uv = float2(c.x / lsz, c.y / lsz - fall);
                float2 id = floor(uv);
                float2 f = fract(uv) - 0.5;
                float2 r = seed6x28(id + float(layer) * 31.0, p.c.x);
                float2 off = (r - 0.5) * 0.45;
                float rad = p.a.y * 0.4 * (0.5 + 0.5 * hash6x28(id * 1.3 + p.c.x));
                float2 dd = f - off;
                float l = length(dd);
                if (r.x > 0.25 && l < rad && rad > 1e-3) {
                    float k = l / rad;
                    float2 lens = -dd / rad * (1.0 - k * k) * p.a.z * lsz * 0.5;
                    float4 q = tapE28(src, em, 1u, c + lens * 2.0 - dd * lsz * p.a.z * 0.6);
                    float hl = smoothstep(0.35, 0.0, length(dd / rad - float2(-0.35, -0.35)));
                    q.rgb = q.rgb * (0.85 + 0.15 * k) + hl * 0.35 * q.a;
                    acc = mix(acc, q, smoothstep(1.0, 0.85, k));
                }
            }
            o = acc;
            break;
        }
        case 6: { // heat haze: a = (amount px, scale px, speed, seed)
            float sc = max(p.a.y, 1.0);
            float3 q = float3(c.x / sc, c.y / sc + t * p.a.z, p.a.w * 1.91);
            float nx = noise63x28(q) - 0.5;
            float ny = noise63x28(q * 1.7 + float3(3.1, 7.7, 1.0)) - 0.5;
            o = tapE28(src, em, 1u, c + float2(nx * 2.0, ny) * p.a.x);
            break;
        }
        case 7: { // bulge / pinch: a = (amount -1..1, radius 0-1.5 of half-min, cx, cy)
            float R = max(p.a.y * hmin6, 1.0);
            float2 d = (c - p.a.zw) / R;
            float r = length(d);
            if (r < 1.0) {
                float k = clamp(p.a.x, -1.0, 1.0) * 0.9;
                float tt = 1.0 - r;
                o = tapE28(src, em, 1u, p.a.zw + d * (1.0 - k * tt * tt) * R);
            }
            break;
        }
        case 8: { // squeeze: a = (amount -1..1, curve, 0, 0), i.y = 0 horizontal / 1 vertical
            float2 ctr = size * 0.5;
            bool vert = p.i.y == 1;
            float across = vert ? (c.x / size.x * 2.0 - 1.0) : (c.y / size.y * 2.0 - 1.0);
            float prof = pow(clamp(1.0 - across * across, 0.0, 1.0), max(p.a.y, 0.05));
            float s = max(1.0 + clamp(p.a.x, -1.0, 1.0) * 0.8 * prof, 0.05);
            float2 d = c - ctr;
            if (vert) d.y *= s; else d.x *= s;
            o = tapE28(src, em, 1u, ctr + d);
            break;
        }
        case 9: { // bend: a = (amount px, axis angle rad, 0, 0)
            float2 ctr = size * 0.5;
            float2 d = rot6x28(c - ctr, -p.a.y);
            float u = d.x / hmin6;
            d.y -= p.a.x * u * u;
            d.x *= 1.0 + 0.002 * p.a.x * u * d.y / hmin6;
            o = tapE28(src, em, 1u, ctr + rot6x28(d, p.a.y));
            break;
        }
        case 10: { // swirl+: a = (twist rad, radius 0-1.5 of half-min, falloff, spin rad/s), b.xy = center
            float R = max(p.a.y * hmin6, 1.0);
            float2 d = c - p.b.xy;
            float r = length(d) / R;
            if (r < 1.0) {
                float a = (p.a.x + p.a.w * t) * pow(1.0 - r, max(p.a.z, 0.05));
                o = tapE28(src, em, 1u, p.b.xy + rot6x28(d, a));
            }
            break;
        }
        case 11: { // hex tiles: a = (size px, max rotation rad, max offset px, seed), b.x = gap px
            float sz = max(p.a.x, 2.0);
            const float2 r6 = float2(1.0, 1.7320508);
            float2 g = c / sz;
            float2 h = r6 * 0.5;
            float2 a1 = g - r6 * floor(g / r6) - h;
            float2 gg = g - h;
            float2 a2 = gg - r6 * floor(gg / r6) - h;
            float2 l = dot(a1, a1) < dot(a2, a2) ? a1 : a2;
            float2 hc = (g - l) * sz;
            float2 id = floor(hc + 0.5);
            float2 rn = seed6x28(id, p.a.w);
            float ang = (rn.x - 0.5) * 2.0 * p.a.y;
            float2 off = (float2(hash6x28(id + 7.1 + p.a.w), rn.y) - 0.5) * 2.0 * p.a.z;
            o = tapE28(src, em, 1u, hc + rot6x28(c - hc, ang) + off);
            float hd = max(dot(abs(l), float2(0.5, 0.8660254)), abs(l.x));
            float edge = smoothstep(0.5 - p.b.x / sz, 0.5 - p.b.x / sz * 0.3, hd) * step(1e-3, p.b.x);
            o.rgb *= 1.0 - edge * 0.85;
            break;
        }
        case 12: { // shatter: a = (progress 0-1, cell px, spread, seed), b.xy = center
            float cs = max(p.a.y, 4.0);
            float2 base = floor(c / cs);
            float4 res = float4(0.0);
            bool hit = false;
            for (int j = -2; j <= 2 && !hit; j++) {
                for (int i = -2; i <= 2 && !hit; i++) {
                    float2 k = base + float2(i, j);
                    float2 kp = (k + 0.15 + 0.7 * seed6x28(k, p.a.w)) * cs;
                    float2 away = kp - p.b.xy;
                    float dl = length(away);
                    float2 dir = dl > 1e-3 ? away / dl : float2(0.0, 1.0);
                    float pr = p.a.x * (0.6 + 0.8 * hash6x28(k + 3.3 + p.a.w));
                    float2 disp = dir * pr * p.a.z * (cs * 0.6 + dl * 0.35);
                    float ang = (hash6x28(k + 9.1 + p.a.w) - 0.5) * 2.0 * pr * 1.2;
                    float2 q = kp + rot6x28(c - disp - kp, -ang);
                    // is q nearest to seed k?
                    float2 qb = floor(q / cs);
                    float best = 1e9; float2 bk = qb;
                    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
                        float2 m = qb + float2(x, y);
                        float2 mp = (m + 0.15 + 0.7 * seed6x28(m, p.a.w)) * cs;
                        float dd = dot(q - mp, q - mp);
                        if (dd < best) { best = dd; bk = m; }
                    }
                    if (all(bk == k)) {
                        res = tapE28(src, em, 1u, q);
                        res.rgb *= 1.0 - 0.35 * pr * hash6x28(k + 1.7);
                        hit = true;
                    }
                }
            }
            o = res;
            break;
        }
        case 13: { // perfect slice: a = (offset px, angle rad, cx, cy)
            float2 n = float2(-sin(p.a.y), cos(p.a.y));
            float2 tg = float2(cos(p.a.y), sin(p.a.y));
            float sd = dot(c - p.a.zw, n);
            float side = smoothstep(-0.75, 0.75, sd);
            float4 aSide = tapE28(src, em, 1u, c - tg * p.a.x * 0.5);
            float4 bSide = tapE28(src, em, 1u, c + tg * p.a.x * 0.5);
            o = mix(aSide, bSide, side);
            break;
        }
        case 14: { // glitch blocks: a = (amount px, block px, probability 0-1, rate fps), c.x = seed, c.y = rgb split px
            float frame = floor(t * p.a.w) + p.c.x * 7.0;
            float bs = max(p.a.y, 2.0);
            float2 cellSz = float2(bs * (1.0 + 3.0 * hash6x28(float2(floor(c.y / bs), frame))), bs);
            float2 cell = floor(c / cellSz);
            float r = hash6x28(cell + frame * 1.31);
            float2 shift = float2(0.0);
            float split = 0.0;
            if (r < p.a.z) {
                shift = float2((hash6x28(cell * 2.1 + frame) - 0.5) * 2.0 * p.a.x, (hash6x28(cell * 3.7 - frame) - 0.5) * p.a.x * 0.25);
                split = p.c.y * (0.5 + hash6x28(cell + 5.5));
            }
            float4 g = tapE28(src, em, 1u, c + shift);
            float4 rr = tapE28(src, em, 1u, c + shift + float2(split, 0));
            float4 bb = tapE28(src, em, 1u, c + shift - float2(split, 0));
            o = float4(rr.r, g.g, bb.b, max(g.a, max(rr.a, bb.a)));
            break;
        }
        case 15: { // glitch lines: a = (amount px, line height px, density 0-1, rate fps), c.x = seed, c.y = chroma px
            float frame = floor(t * p.a.w) + p.c.x * 11.0;
            float lh = max(p.a.y, 1.0);
            float row = floor(c.y / lh);
            float band = floor(c.y / (lh * 6.0));
            float on = step(1.0 - p.a.z, hash6x28(float2(band, frame))) * step(0.3, hash6x28(float2(row, frame + 2.0)));
            float dx = (hash6x28(float2(row * 1.7, frame)) - 0.5) * 2.0 * p.a.x * on;
            float4 g = tapE28(src, em, 1u, c + float2(dx, 0));
            float4 rr = tapE28(src, em, 1u, c + float2(dx + p.c.y * on, 0));
            float4 bb = tapE28(src, em, 1u, c + float2(dx - p.c.y * on, 0));
            o = float4(rr.r, g.g, bb.b, max(g.a, max(rr.a, bb.a)));
            break;
        }
        case 16: { // digital noise glitch: a = (intensity 0-1, block px, rate fps, seed)
            float frame = floor(t * p.a.z) + p.a.w * 13.0;
            float bs = max(p.a.y, 1.0);
            float2 big = floor(c / (bs * 6.0));
            float2 cell = floor(c / bs);
            float zone = step(1.0 - p.a.x * 0.6, hash6x28(big + frame * 0.77));
            float4 q = tapE28(src, em, 1u, c + float2((hash6x28(big + frame) - 0.5) * bs * 4.0 * zone, 0));
            float3 nz = float3(hash6x28(cell + frame), hash6x28(cell + frame + 1.3), hash6x28(cell + frame + 2.6));
            float sel = step(0.5, hash6x28(cell * 0.71 + frame));
            float3 col = q.a > 1e-6 ? q.rgb / q.a : float3(0.0);
            float3 post = floor(col * 4.0 + nz * 0.9) / 4.0;
            float3 g = mix(post, nz, sel * 0.7);
            float spark = step(1.0 - p.a.x * 0.08, hash6x28(c + frame * 3.1));
            float a = max(q.a, spark);
            float3 outc = mix(col, g, zone);
            outc = mix(outc, nz, spark);
            o = float4(clamp(outc, 0.0, 1.0) * a, a);
            break;
        }
        case 17: { // datamosh smear: a = (length px, angle rad, block px, chaos 0-1), c.x = seed
            float bs = max(p.a.z, 2.0);
            float2 blk = floor(c / bs);
            float fr = floor(t * 8.0) + p.c.x * 5.0;
            float bn = hash6x28(blk + fr);
            float ang = p.a.y + (bn - 0.5) * p.a.w * 3.1415926;
            float len = p.a.x * (0.3 + 0.7 * hash6x28(blk * 1.9 + fr + 4.0)) * (0.25 + 0.75 * step(0.35 * p.a.w, bn));
            float2 dir = float2(cos(ang), sin(ang));
            float4 best = o; float bl = lum6x28(o) * o.a;
            const int N = 20;
            for (int k = 1; k <= N; k++) {
                float f = float(k) / float(N);
                float4 q = tapE28(src, em, 1u, c - dir * len * f);
                float l = (lum6x28(q) * q.a) * (1.0 - 0.5 * f);
                if (l > bl) { bl = l; best = q; }
            }
            o = best;
            break;
        }
        case 18: { // pixel stretch: a = (position 0-1, jitter px, 0, 0), i.y = direction (0 right, 1 left, 2 down, 3 up), c.x = seed
            uint dirm = p.i.y;
            bool horiz = dirm < 2;
            float along = horiz ? c.x : c.y;
            float lineP = p.a.x * (horiz ? size.x : size.y);
            float crossC = horiz ? c.y : c.x;
            float j = (noise63x28(float3(crossC / 6.0, t * 3.0, p.c.x)) - 0.5) * 2.0 * p.a.y;
            float lp = lineP + j;
            bool past = (dirm == 0 || dirm == 2) ? (along > lp) : (along < lp);
            if (past) {
                float2 q = horiz ? float2(lp, c.y) : float2(c.x, lp);
                o = tapE28(src, em, 1u, q);
            }
            break;
        }
        case 19: { // displace by luminance: a = (amount px, angle rad, 0, 0), i.y = 0 along angle / 1 radial
            float l = lum6x28(o) * o.a;
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            if (p.i.y == 1) { float2 d = c - size * 0.5; dir = d / max(length(d), 1e-3); }
            float4 q = tapE28(src, em, 1u, c + dir * (l - 0.35) * p.a.x);
            o = tapE28(src, em, 1u, c + dir * ((lum6x28(q) * q.a) * 0.5 + l * 0.5 - 0.35) * p.a.x);
            break;
        }
        case 20: { // kaleidoscope+: a = (segments, rotation rad, spin rad/s, zoom), b.xy = center, i.y = mirror
            float n = max(round(p.a.x), 2.0);
            float seg = 6.2831853 / n;
            float2 d = c - p.b.xy;
            float r = length(d) / max(p.a.w, 0.05);
            float rotA = p.a.y + p.a.z * t;
            float th = atan2(d.y, d.x) - rotA;
            th = th - seg * floor(th / seg);
            if (p.i.y == 1) th = abs(th - seg * 0.5);
            th += rotA;
            o = tapE28(src, em, 1u, p.b.xy + float2(cos(th), sin(th)) * r);
            break;
        }
        case 21: { // wobble: a = (amplitude px, wavelength px, speed, 0)
            float wl = max(p.a.y, 1.0);
            float ph = t * p.a.z * 6.2831853;
            float2 off = float2(sin(c.y / wl * 6.2831853 + ph), cos(c.x / wl * 8.17 + ph * 0.8 + 1.3)) * p.a.x;
            o = tapE28(src, em, 1u, c + off);
            break;
        }
        case 22: { // signal interference: a = (strength px, bands, speed, chroma px), b.x = noise 0-1, c.x = seed
            float y = c.y / size.y;
            float ph = y * p.a.y * 6.2831853 - t * p.a.z * 6.2831853;
            float band = sin(ph);
            float sharp = pow(abs(band), 6.0) * sign(band);
            float fr = floor(t * 120.0) + p.c.x * 9.0;
            float rn = (hash6x28(float2(floor(c.y), fr)) - 0.5) * p.b.x * 2.0;
            float dx = (sharp + rn) * p.a.x;
            float4 g = tapE28(src, em, 1u, c + float2(dx, 0));
            float4 rr = tapE28(src, em, 1u, c + float2(dx + p.a.w, 0));
            float4 bb = tapE28(src, em, 1u, c + float2(dx - p.a.w, 0));
            o = float4(rr.r, g.g, bb.b, max(g.a, max(rr.a, bb.a)));
            o.rgb *= 1.0 + 0.18 * band * min(p.a.x / 10.0, 1.0);
            break;
        }
        case 23: { // CRT scan distort: a = (roll speed, bar strength px, scanlines 0-1, curvature 0-1)
            float2 uv = c / size * 2.0 - 1.0;
            float k = p.a.w * 0.35;
            uv *= 1.0 + k * dot(uv, uv);
            float2 q = (uv * 0.5 + 0.5) * size;
            float y = q.y + t * p.a.x * size.y;
            y = y - size.y * floor(y / size.y);
            float barY = fract(t * 0.6 + 0.2) * size.y;
            float dyb = (y - barY) / max(size.y * 0.08, 1.0);
            float bar = exp(-dyb * dyb);
            float wav = sin(y * 0.35 + t * 20.0);
            q.x += (bar * 1.0 + 0.15) * wav * p.a.y;
            float inside = step(0.0, q.x) * step(q.x, size.x) * step(abs(uv.y), 1.0) * step(abs(uv.x), 1.0);
            float4 s = float4(src.sample(s28Zero, float2(q.x, y))) * inside;
            float scan = 1.0 - p.a.z * 0.6 * (0.5 + 0.5 * sin(c.y * 3.1415926));
            s.rgb *= scan * (1.0 + 0.25 * bar);
            o = s;
            break;
        }
    }
    return o;
}

kernel void fxDistort6AA28(texture2d<half, access::sample> src [[texture(0)]],
                           texture2d<half, access::write> dst [[texture(1)]],
                           texture2d<half, access::sample> aux [[texture(2)]],
                           constant EffectParams& p [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    int n = clamp(int(p.i.z), 1, 3);
    float4 acc = float4(0.0);
    for (int k = 0; k < n * n; k++) acc += distort6at28(src, c + ss28(k, n), size, p, p.i.w);
    dst.write(half4(acc / float(n * n)), gid);
}
