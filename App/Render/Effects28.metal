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
    return float4(t.read(uint2(uint(xx), uint(yy))));
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
    int n = int(clamp((p.i.z >> 4) & 15u, 1u, 3u));
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
    int n = int(clamp(p.i.z, 1u, 3u));
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
    int n = int(clamp(p.i.y, 1u, 3u));
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
