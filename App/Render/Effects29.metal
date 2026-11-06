#include <metal_stdlib>
using namespace metal;

// Batch 29: Backgrounds / Particles / Color / Key remakes.
//  fxFractalNoise29  — AE-style Fractal Noise (fractal type, noise type, overflow, transform, sub settings, cycle, blend).
//  fxGen29           — domain-warped clouds / smoke / fire, crystal shards, depth-layered snow / rain / confetti / bubbles.
//  fxKey29           — Luma Key (4 key types, edge decontamination, view matte) and Color Range Key (softness, spill).
//  fxColor29         — linear-light Exposure, non-clipping Brightness & Contrast, gamut-safe Vibrance.
// rgba16Float, PREMULTIPLIED alpha, sRGB-encoded. Color math is done on straight color and re-premultiplied.
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s29Zero(address::clamp_to_zero, filter::linear, coord::pixel);

static inline float lum29(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static inline float3 unp29(float4 c) { return c.a > 1e-5 ? max(c.rgb / c.a, float3(0.0)) : float3(0.0); }
static inline float3 toLin29(float3 c) {
    c = max(c, float3(0.0));
    return select(pow((c + 0.055) / 1.055, float3(2.4)), c / 12.92, c <= float3(0.04045));
}
static inline float3 toSrgb29(float3 c) {
    c = max(c, float3(0.0));
    return select(1.055 * pow(c, float3(1.0 / 2.4)) - 0.055, c * 12.92, c <= float3(0.0031308));
}
static inline float3 unpackRGB29(uint v) {
    return float3(float((v >> 16) & 255u), float((v >> 8) & 255u), float(v & 255u)) / 255.0;
}
static inline float2 rot29(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(v.x * cs - v.y * sn, v.x * sn + v.y * cs); }
static inline float3 hsv29(float h, float s, float v) {
    float3 k = clamp(abs(fract(h + float3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    return v * mix(float3(1.0), k, s);
}
static inline float3 rgb2hsv29(float3 c) {
    float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
    float d = mx - mn, h = 0.0;
    if (d > 1e-6) {
        if (mx == c.r) h = (c.g - c.b) / d + (c.g < c.b ? 6.0 : 0.0);
        else if (mx == c.g) h = (c.b - c.r) / d + 2.0;
        else h = (c.r - c.g) / d + 4.0;
        h /= 6.0;
    }
    return float3(h, mx > 1e-6 ? d / mx : 0.0, mx);
}

// ---------- hashing & noise ----------
static inline float h29(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static inline float h29v2(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static inline float3 grad29(float3 p) {
    return float3(h29(p), h29(p + float3(19.19, 7.7, 3.1)), h29(p + float3(47.3, 31.1, 13.7))) * 2.0 - 1.0;
}

// Lattice value noise. mode 0 block (steps in space, smooth in evolution), 1 linear, 2 soft linear (smoothstep).
static float vn29(float3 x, int mode) {
    float3 i = floor(x), f = fract(x);
    float3 u;
    if (mode == 0) u = float3(0.0, 0.0, f.z * f.z * (3.0 - 2.0 * f.z));
    else if (mode == 1) u = f;
    else u = f * f * (3.0 - 2.0 * f);
    float n000 = h29(i), n100 = h29(i + float3(1, 0, 0));
    float n010 = h29(i + float3(0, 1, 0)), n110 = h29(i + float3(1, 1, 0));
    float n001 = h29(i + float3(0, 0, 1)), n101 = h29(i + float3(1, 0, 1));
    float n011 = h29(i + float3(0, 1, 1)), n111 = h29(i + float3(1, 1, 1));
    return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
               mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

// Gradient (Perlin) noise with quintic fade, remapped to ~0..1 ("Spline" noise type: round, smooth blobs).
static float gn29(float3 x) {
    float3 i = floor(x), f = fract(x);
    float3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float n000 = dot(grad29(i), f);
    float n100 = dot(grad29(i + float3(1, 0, 0)), f - float3(1, 0, 0));
    float n010 = dot(grad29(i + float3(0, 1, 0)), f - float3(0, 1, 0));
    float n110 = dot(grad29(i + float3(1, 1, 0)), f - float3(1, 1, 0));
    float n001 = dot(grad29(i + float3(0, 0, 1)), f - float3(0, 0, 1));
    float n101 = dot(grad29(i + float3(1, 0, 1)), f - float3(1, 0, 1));
    float n011 = dot(grad29(i + float3(0, 1, 1)), f - float3(0, 1, 1));
    float n111 = dot(grad29(i + float3(1, 1, 1)), f - float3(1, 1, 1));
    float n = mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
                  mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
    return clamp(0.5 + n * 0.85, 0.0, 1.0);
}

static inline float noise29(float3 x, int mode) { return mode >= 3 ? gn29(x) : vn29(x, mode); }

// Smooth fbm with octave rotation (hides the lattice); fine detail evolves faster than coarse shapes.
static float fbmw29(float3 x, int oct) {
    float v = 0.0, a = 0.5, n = 0.0;
    for (int k = 0; k < 8; k++) {
        if (k >= oct) break;
        v += a * vn29(x, 2);
        n += a;
        x = float3(float2(x.x * 0.8 - x.y * 0.6, x.x * 0.6 + x.y * 0.8) * 2.03 + float2(5.2, 1.3), x.z * 1.35 + 3.1);
        a *= 0.5;
    }
    return v / max(n, 1e-4);
}

// ---------- Fractal Noise ----------
// One evaluation of the fractal at evolution z.
// ftype: 0 Basic, 1 Turbulent, 2 Turbulent Smooth, 3 Turbulent Sharp, 4 Dynamic, 5 Dynamic Twist, 6 Max, 7 Rocky, 8 Strings, 9 Smeary
static float fractal29(float2 q, float z, float complexity, float subInf, float subScale, float subRot, float2 subOff,
                       int ftype, int ntype) {
    int oct = int(ceil(clamp(complexity, 1.0, 20.0)));
    float last = clamp(complexity - float(oct - 1), 0.0, 1.0);
    float amp = 1.0, sum = 0.0, norm = 0.0, sq = 0.0, mx = 0.0, prev = 0.5, rw = 1.0;
    float2 pp = q;
    float freqMul = 1.0 / clamp(subScale, 0.1, 1.0);
    for (int k = 0; k < 20; k++) {
        if (k >= oct) break;
        float w = (k == oct - 1) ? (oct == 1 ? 1.0 : last) : 1.0;
        float2 qq = pp;
        if (ftype == 4) qq += (prev - 0.5) * 1.3;
        else if (ftype == 5) qq = rot29(qq, (prev - 0.5) * 3.5);
        else if (ftype == 9) qq.x += (prev - 0.5) * 3.0;
        float n = noise29(float3(qq, z + float(k) * 7.31), ntype);
        float cv = n;
        switch (ftype) {
            case 1: cv = abs(n * 2.0 - 1.0); break;
            case 2: { float tt = abs(n * 2.0 - 1.0); cv = tt * tt * (3.0 - 2.0 * tt); break; }
            case 3: { float tt = 1.0 - abs(n * 2.0 - 1.0); cv = tt * tt * tt; break; }
            case 7: { float tt = 1.0 - abs(n * 2.0 - 1.0); tt *= tt; cv = tt * rw; rw = clamp(tt * 2.0, 0.0, 1.0); break; }
            case 8: { float tt = abs(n * 2.0 - 1.0); cv = 1.0 - smoothstep(0.0, 0.09, tt); break; }
            default: cv = n; break;
        }
        if (ftype == 6) mx = max(mx, mix(0.5, n, w) * mix(1.0, amp, 0.35));
        sum += cv * amp * w;
        norm += amp * w;
        sq += amp * amp * w;
        prev = n;
        amp *= subInf;
        pp = rot29(pp, subRot) * freqMul + subOff;
    }
    norm = max(norm, 1e-4);
    if (ftype == 6) return mx;
    if (ftype == 0 || ftype == 4 || ftype == 5 || ftype == 9) {
        float centered = (sum - 0.5 * norm) / max(0.5 * (norm + sqrt(sq)), 1e-4);
        float gain = ntype >= 3 ? 1.15 : 1.55;
        return 0.5 + centered * gain;
    }
    if (ftype == 8) return sum / max(sqrt(sq), 1e-4) * 0.7;
    return sum / norm * (ftype == 3 || ftype == 7 ? 1.8 : 1.25);
}

// a = (contrast %, brightness %, scale width px, complexity)
// b = (sub influence 0-1, sub scaling 0-1, evolution revolutions, rotation rad)
// c = (offset x px, offset y px, sub rotation rad, opacity 0-1)
// d = (sub offset x px, sub offset y px, cycle revolutions (0 = off), height/width scale ratio)
// i = (fractal type, noise type, overflow, flags: bit0 invert, bit1 use layer alpha, bits 8.. blend mode)
kernel void fxFractalNoise29(texture2d<half, access::sample> src [[texture(0)]],
                             texture2d<half, access::write> dst [[texture(1)]],
                             constant EffectParams& p [[buffer(0)]],
                             uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 px = float2(gid) + 0.5;
    float4 s = float4(src.sample(s29Zero, px));
    // Transform: rotate around the frame center, then scale and offset (AE "Offset Turbulence").
    float2 c = rot29(px - size * 0.5, -p.b.w) + size * 0.5 - p.c.xy;
    float sw = max(p.a.z, 1.0);
    float sh = max(p.a.z * max(p.d.w, 0.01), 1.0);
    float2 q = c / float2(sw, sh);
    float2 subOff = p.d.xy / sw;
    int ftype = int(p.i.x), ntype = int(p.i.y);
    float cx = p.a.w, si = p.b.x, ss = p.b.y, sr = p.c.z;
    float evo = p.b.z;
    float v;
    float period = p.d.z;
    if (period > 0.01) {
        float e = fmod(evo, period);
        if (e < 0.0) e += period;
        float v0 = fractal29(q, e, cx, si, ss, sr, subOff, ftype, ntype);
        float v1 = fractal29(q, e - period, cx, si, ss, sr, subOff, ftype, ntype);
        float k = e / period;
        k = k * k * (3.0 - 2.0 * k);
        v = mix(v0, v1, k);
    } else {
        v = fractal29(q, evo, cx, si, ss, sr, subOff, ftype, ntype);
    }
    v = (v - 0.5) * (p.a.x / 100.0) + 0.5 + p.a.y / 100.0;
    if ((p.i.w & 1u) != 0u) v = 1.0 - v;
    switch (p.i.z) {
        case 1: v = 0.5 + 0.5 * tanh((v - 0.5) * 2.2); break;                 // soft clamp
        case 2: v = 1.0 - abs(fract(v * 0.5) * 2.0 - 1.0); break;             // wrap back
        case 3: v = clamp(v, 0.0, 16.0); break;                                // allow HDR
        default: v = clamp(v, 0.0, 1.0); break;                                // clip
    }
    uint blend = (p.i.w >> 8) & 255u;
    float3 nv = float3(v);
    float4 o;
    if (blend == 0u) {
        float al = (p.i.w & 2u) != 0u ? s.a : 1.0;
        o = float4(nv * al, al);
    } else {
        float3 b = clamp(unp29(s), 0.0, 1.0);
        float3 n1 = clamp(nv, 0.0, 1.0);
        float3 r;
        switch (blend) {
            case 1: r = b + nv; break;
            case 2: r = b * nv; break;
            case 3: r = 1.0 - (1.0 - b) * (1.0 - n1); break;
            case 4: r = select(1.0 - 2.0 * (1.0 - b) * (1.0 - n1), 2.0 * b * n1, b < float3(0.5)); break;
            default: r = (1.0 - 2.0 * n1) * b * b + 2.0 * n1 * b; break;     // soft light
        }
        r = p.i.z == 3u ? max(r, float3(0.0)) : clamp(r, 0.0, 1.0);
        o = float4(r * s.a, s.a);
    }
    o = mix(s, o, clamp(p.c.w, 0.0, 1.0));
    o = select(o, float4(0.0), isnan(o));
    dst.write(half4(o), gid);
}

// ---------- Generators ----------
// Particle helper: soft antialiased disc, blur widens the edge and lowers the peak (energy roughly kept).
static inline float disc29(float d, float r, float blur) {
    float e = max(blur, 0.6);
    float m = 1.0 - smoothstep(r - e, r + e, d);
    return m * clamp(r * r / ((r + blur * 0.5) * (r + blur * 0.5)), 0.25, 1.0);
}

// Common: d.x = time, d.y = blend 0-1, d.z = only, i.x = mode, i.y = 0 additive / 1 over.
kernel void fxGen29(texture2d<half, access::sample> src [[texture(0)]],
                    texture2d<half, access::write> dst [[texture(1)]],
                    texture2d<half, access::sample> aux [[texture(2)]],
                    constant EffectParams& p [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s29Zero, c));
    float t = p.d.x;
    float mn = max(min(size.x, size.y), 1.0);
    float3 g = float3(0.0);
    float ga = 0.0;
    switch (p.i.x) {
        case 0: { // clouds: a = (scale, coverage, softness, drift px/s), b = color, c = (evolve, seed, warp, shading), i.z = shadow rgb, i.w = detail
            float sc = max(p.a.x, 2.0);
            float seed = p.c.y;
            float2 q = (c + float2(t * p.a.w, 0.0)) / sc + float2(seed * 7.13, seed * 3.71);
            float z = t * p.c.x * 0.3 + seed * 1.3;
            int oct = clamp(int(p.i.w), 2, 8);
            float2 wq = float2(fbmw29(float3(q, z), 4), fbmw29(float3(q + float2(5.2, 1.3), z), 4)) - 0.5;
            float2 wr = float2(fbmw29(float3(q + 4.0 * wq + float2(1.7, 9.2), z * 1.3), 4),
                               fbmw29(float3(q + 4.0 * wq + float2(8.3, 2.8), z * 1.3), 4)) - 0.5;
            float2 qw = q + p.c.z * 3.0 * wr;
            float n = fbmw29(float3(qw, z), oct);
            float nL = fbmw29(float3(qw + float2(-0.045, -0.06), z), oct);
            float n2 = clamp((n - 0.5) * 2.3 + 0.5, 0.0, 1.0);
            float th = 1.0 - clamp(p.a.y, 0.0, 1.0);
            float sf = max(p.a.z, 0.02);
            float dens = smoothstep(th - sf * 0.5, th + sf * 0.5, n2);
            float shade = clamp(0.55 + (n - nL) * 9.0, 0.0, 1.0);
            float thick = smoothstep(th, th + 0.45, n2);
            float lit = mix(1.0, shade * (1.0 - 0.35 * thick) + 0.2, clamp(p.c.w, 0.0, 1.0));
            float3 shadow = unpackRGB29(p.i.z);
            float3 col = mix(shadow, p.b.rgb, clamp(lit, 0.0, 1.0));
            col += p.b.rgb * dens * (1.0 - dens) * 0.5 * shade;   // silver lining on thin edges
            g = col;
            ga = dens;
            break;
        }
        case 1: { // smoke: a = (scale, rise px/s, turbulence, height 0-1), b = color, c = (seed, density, shading, 0), i.w = detail
            float sc = max(p.a.x, 2.0);
            float seed = p.c.x;
            float yb = 1.0 - c.y / size.y;
            float2 q = float2(c.x, c.y + t * p.a.y) / sc + float2(seed * 5.3, seed * 2.9);
            float z = t * 0.18 + seed;
            int oct = clamp(int(p.i.w), 2, 8);
            float tb = p.a.z * (0.45 + yb * 1.4);
            float2 w1 = float2(fbmw29(float3(q * 0.7, z), 4), fbmw29(float3(q * 0.7 + 3.7, z), 4)) - 0.5;
            float2 qw = q + tb * 2.2 * w1;
            float2 w2 = float2(fbmw29(float3(qw * 1.3 + 1.1, z * 1.4), 3), fbmw29(float3(qw * 1.3 + 8.4, z * 1.4), 3)) - 0.5;
            qw += tb * 0.9 * w2;
            float n = fbmw29(float3(qw, z * 0.7), oct);
            float nL = fbmw29(float3(qw + float2(0.0, -0.07), z * 0.7), oct);
            float n2 = clamp((n - 0.5) * 2.4 + 0.5, 0.0, 1.0);
            float hh = max(p.a.w, 0.02);
            float fade = 1.0 - smoothstep(hh * 0.25, hh, yb);
            float dens = smoothstep(0.32, 0.85, n2) * mix(1.0, smoothstep(0.25, 0.75, n2), clamp(yb / hh, 0.0, 1.0));
            dens *= fade * p.c.y;
            float shade = clamp(0.5 + (n - nL) * 8.0, 0.0, 1.0);
            float lit = mix(0.8, shade + 0.15, clamp(p.c.z, 0.0, 1.0));
            g = mix(p.b.rgb * 0.42, p.b.rgb * 1.08, clamp(lit, 0.0, 1.0));
            ga = clamp(dens, 0.0, 1.0);
            break;
        }
        case 2: { // fire (additive): a = (height 0-1, scale, speed, turbulence), b = tint, c = (seed, intensity, 0, 0), i.w = detail
            float sc = max(p.a.y, 2.0);
            float seed = p.c.x;
            float H = max(p.a.x * size.y, 1.0);
            float yb = (size.y - c.y) / H;
            float2 q = float2(c.x / sc, c.y / sc + t * p.a.z) + float2(seed * 5.1, seed * 1.7);
            float z = t * p.a.z * 0.35 + seed;
            int oct = clamp(int(p.i.w), 2, 8);
            float2 w = float2(fbmw29(float3(q * 0.9, z), 3), fbmw29(float3(q * 0.9 + 4.3, z), 3)) - 0.5;
            float2 qw = q + w * p.a.w * 1.8 * float2(1.0, 0.7);
            float n = fbmw29(float3(qw * float2(1.0, 0.55), z), oct);
            float shape = 1.0 - yb;
            float heat = shape * 1.15 + (n - 0.55) * 1.9 * mix(0.55, 1.1, clamp(yb, 0.0, 1.0)) - 0.12;
            heat = clamp(heat, 0.0, 1.4);
            float3 tint = p.b.rgb;
            float3 col = mix(float3(0.35, 0.02, 0.005), tint, smoothstep(0.08, 0.45, heat));
            col = mix(col, float3(1.0, 0.82, 0.38), smoothstep(0.45, 0.85, heat));
            col = mix(col, float3(1.0, 0.97, 0.88), smoothstep(0.9, 1.3, heat));
            float em = smoothstep(0.02, 0.4, heat);
            g = col * em * max(p.c.y, 0.0);
            ga = clamp(em * max(p.c.y, 0.0), 0.0, 1.0);
            break;
        }
        case 3: { // crystal shards (over): a = (size, light speed, edge glow, contrast), b = tint, c = (seed, refraction)
            float cl = max(p.a.x, 6.0);
            float seed = p.c.x;
            float2 uv = c / cl + float2(seed * 2.3, seed * 1.7);
            float2 id = floor(uv);
            float md = 9.0;
            float2 mr = float2(0.0), best = id;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cid = id + float2(float(i), float(j));
                    float2 o = float2(h29v2(cid + seed * 3.1), h29v2(cid * 1.7 + 3.1 + seed));
                    float2 rv = cid + 0.15 + 0.7 * o - uv;
                    float dd = dot(rv, rv);
                    if (dd < md) { md = dd; mr = rv; best = cid; }
                }
            }
            float ed = 9.0;
            for (int j = -2; j <= 2; j++) {
                for (int i = -2; i <= 2; i++) {
                    float2 cid = best + float2(float(i), float(j));
                    float2 o = float2(h29v2(cid + seed * 3.1), h29v2(cid * 1.7 + 3.1 + seed));
                    float2 rv = cid + 0.15 + 0.7 * o - uv;
                    float2 dr = rv - mr;
                    if (dot(dr, dr) > 1e-5) ed = min(ed, dot(0.5 * (mr + rv), normalize(dr)));
                }
            }
            float edPx = ed * cl;
            float2 rel = -mr * cl;                                   // pixel offset from the shard's seed point
            float ha = h29v2(best * 0.61 + 9.9 + seed), hb = h29v2(best * 1.31 + 4.7), hc = h29v2(best * 2.17 + 1.3 + seed);
            float ra = ha * 6.2831853;
            float2 ridge = float2(cos(ra), sin(ra));
            float2 across = float2(-ridge.y, ridge.x);
            float sd = dot(rel, across);
            float tiltB = 0.2 + 0.45 * hb;
            float ta = hc * 6.2831853;
            float2 baseTilt = float2(cos(ta), sin(ta)) * tiltB * 0.6;
            float3 nA = normalize(float3(baseTilt + across * tiltB, 1.0));
            float3 nB = normalize(float3(baseTilt - across * tiltB, 1.0));
            float3 nrm = normalize(mix(nB, nA, smoothstep(-0.8, 0.8, sd)));
            float lt = t * p.a.y * 0.8 + seed;
            float3 L = normalize(float3(cos(lt) * 0.8, sin(lt) * 0.6 - 0.3, 0.9));
            float3 V = normalize(float3((c - size * 0.5) / mn * 0.7, 1.0));
            float3 R = reflect(-V, nrm);
            float dif = max(dot(nrm, L), 0.0);
            float spc = pow(max(dot(R, L), 0.0), 36.0);
            float con = clamp(p.a.w, 0.0, 1.0);
            float refr = clamp(p.c.y, 0.0, 1.0);
            float shade = mix(0.8, 0.3 + 0.95 * dif, con);
            float2 sp2 = clamp(c + nrm.xy * cl * 0.55 * refr, float2(0.5), size - 0.5);
            float4 rs = float4(src.sample(s29Zero, sp2));
            float3 rf = unp29(rs) * rs.a;
            float3 tint = p.b.rgb;
            float3 col = mix(tint * shade, rf * mix(float3(1.0), tint * 1.25, 0.5) * (0.65 + 0.5 * dif), refr * 0.8);
            col += mix(tint, float3(1.0), 0.6) * spc * (0.35 + 0.6 * con);
            col *= 0.8 + 0.2 * smoothstep(0.0, cl * 0.12, edPx);        // bevel darkening toward the rim
            float eg = max(p.a.z, 0.0);
            float edgeLine = 1.0 - smoothstep(0.25, 1.25, edPx);
            float ridgeLine = (1.0 - smoothstep(0.2, 1.0, abs(sd))) * smoothstep(0.0, 2.0, edPx);
            float3 ec = mix(tint, float3(1.0), 0.7);
            col = mix(col, ec, clamp(edgeLine * 0.85 * min(eg, 1.0), 0.0, 1.0));
            col += ec * (exp(-edPx / 3.0) * 0.3 * eg + ridgeLine * 0.25 * eg * (0.3 + dif));
            g = col;
            ga = 1.0;
            break;
        }
        case 4: { // snow (over): a = (spacing, size, fall px/s, wind px/s), b = color, c = (seed, sway, depth blur 0-1, layers)
            float3 P = float3(0.0);
            float A = 0.0;
            int layers = clamp(int(p.c.w + 0.5), 1, 5);
            float wob = clamp(p.c.y, 0.0, 2.0);
            float seed = p.c.x;
            for (int L = 0; L < 5; L++) {
                if (L >= layers) break;
                float z = layers > 1 ? float(L) / float(layers - 1) : 1.0;     // 0 far .. 1 near
                float ls = mix(0.45, 1.6, z);
                float cl = max(p.a.x, 2.0) * mix(0.55, 1.9, z);
                float rr = max(p.a.y * ls, 0.35);
                float spd = p.a.z * mix(0.45, 1.3, z);
                float2 base = c - float2(p.a.w * mix(0.5, 1.25, z) * t, 0.0) + float2(float(L) * 37.7 + seed * 17.0, float(L) * 91.3);
                float colx = floor(base.x / cl);
                float blur = clamp(p.c.z, 0.0, 1.0) * abs(z - 0.3) * rr * 2.2;
                float op = mix(0.5, 1.0, z);
                float3 lc = mix(p.b.rgb * float3(0.8, 0.88, 1.0), p.b.rgb, z);
                for (int i = -1; i <= 1; i++) {
                    float cx = colx + float(i);
                    float cf = 0.8 + 0.4 * h29v2(float2(cx, float(L) * 7.0 + seed));
                    float qy = base.y - spd * cf * t;
                    float cy0 = floor(qy / cl);
                    for (int j = -1; j <= 1; j++) {
                        float2 cid = float2(cx, cy0 + float(j));
                        float ha = h29v2(cid + float(L) * 13.7 + seed * 3.1), hb = h29v2(cid * 1.37 + 5.3 + seed), hc = h29v2(cid * 0.71 + 11.9 - seed);
                        if (hc > 0.82) continue;
                        float2 ctr = (cid + 0.5 + (float2(ha, hb) - 0.5) * 0.6) * cl;
                        ctr.x += wob * cl * 0.22 * sin(t * (0.6 + hc * 1.3) + ha * 6.283);
                        ctr.y += wob * cl * 0.05 * cos(t * (0.9 + hb) + hc * 6.283);
                        float r = rr * (0.55 + 0.6 * hc);
                        float d = length(float2(base.x, qy) - ctr);
                        float m = disc29(d, r, blur) * op;
                        m += exp(-d / (r + blur + 0.5)) * 0.12 * op * (1.0 - m);
                        m = clamp(m, 0.0, 1.0);
                        P = P * (1.0 - m) + lc * m;
                        A = A * (1.0 - m) + m;
                    }
                }
            }
            g = P / max(A, 1e-3);
            ga = A;
            break;
        }
        case 5: { // rain (over): a = (angle rad, speed, length, spacing), b = color, c = (width, seed, amount, layers)
            float2 dir = float2(sin(p.a.x), cos(p.a.x));
            float2 pv = float2(dir.y, -dir.x);
            float along = dot(c, dir), across = dot(c, pv);
            float3 P = float3(0.0);
            float A = 0.0;
            int layers = clamp(int(p.c.w + 0.5), 1, 5);
            float seed = p.c.y;
            for (int L = 0; L < 5; L++) {
                if (L >= layers) break;
                float fl = float(L);
                float z = layers > 1 ? fl / float(layers - 1) : 1.0;
                float sp = max(p.a.w, 2.0) * mix(0.6, 1.7, z);
                float len = max(p.a.z, 1.0) * mix(0.5, 1.6, z);
                float w = max(p.c.x, 0.2) * mix(0.6, 1.7, z);
                float blur = z * z * 1.2;
                float u = across / sp + fl * 0.37 + seed * 0.13;
                float colI = floor(u), fu = fract(u);
                float hcol = h29v2(float2(colI, fl * 5.0 + seed * 3.7));
                float dx = abs(fu - (0.2 + 0.6 * hcol)) * sp;
                float seg = len * mix(2.2, 4.0, h29v2(float2(colI * 0.7, fl + 2.0)));
                float v = along - t * p.a.y * mix(0.6, 1.25, z) * (0.85 + 0.3 * hcol) + hcol * 1000.0;
                float cy = floor(v / seg);
                float fy = (v / seg - cy) * seg;
                float on = step(h29v2(float2(colI * 1.31 + seed, cy + fl * 17.0)), p.c.z);
                float sAl = clamp(fy / len, 0.0, 1.0);
                float body = smoothstep(0.0, 1.0, sAl) * (1.0 - smoothstep(len - 1.0, len, fy));
                float wd = w * (0.45 + 0.55 * sAl) * 0.5;
                float m = body * (1.0 - smoothstep(wd - 0.5, wd + 0.5 + blur, dx)) * on * mix(0.35, 0.85, z);
                m = clamp(m, 0.0, 1.0);
                float3 lc = p.b.rgb * mix(0.85, 1.1, z);
                P = P * (1.0 - m) + lc * m;
                A = A * (1.0 - m) + m;
            }
            g = P / max(A, 1e-3);
            ga = A;
            break;
        }
        case 6: { // confetti (over): a = (spacing, size, fall, spin), c = (seed, saturation, sway, depth blur)
            float3 P = float3(0.0);
            float A = 0.0;
            float seed = p.c.x;
            for (int L = 0; L < 3; L++) {
                float z = float(L) * 0.5;
                float cl = max(p.a.x, 4.0) * mix(0.7, 1.6, z);
                float sz = max(p.a.y, 0.5) * mix(0.6, 1.45, z);
                float spd = p.a.z * mix(0.6, 1.2, z);
                float blur = clamp(p.c.w, 0.0, 1.0) * z * z * sz * 0.5;
                float2 base = c + float2(float(L) * 41.0 + seed * 17.0, float(L) * 23.0);
                float colx = floor(base.x / cl);
                for (int i = -1; i <= 1; i++) {
                    float cx = colx + float(i);
                    float cf = 0.8 + 0.4 * h29v2(float2(cx * 1.3, float(L) + seed));
                    float qy = base.y - spd * cf * t;
                    float cy0 = floor(qy / cl);
                    for (int j = -1; j <= 1; j++) {
                        float2 cid = float2(cx, cy0 + float(j));
                        float ha = h29v2(cid + float(L) * 9.1 + seed), hb = h29v2(cid * 1.31 + 2.7), hc = h29v2(cid * 0.77 + 6.1 + seed), hd = h29v2(cid * 1.9 + 12.3 + float(L));
                        if (hb > 0.9) continue;
                        float2 ctr = (cid + 0.5 + (float2(ha, hb) - 0.5) * 0.5) * cl;
                        ctr.x += sin(t * (1.6 + hc) + hc * 6.283) * p.c.z * cl * 0.22;
                        float ang = hd * 6.283 + t * p.a.w * (0.3 + ha * 0.7) * (ha > 0.5 ? 1.0 : -1.0);
                        float flipPh = t * p.a.w * 1.4 * (0.5 + hb) + hc * 6.283;
                        float fc = cos(flipPh);
                        float2 lc = rot29(float2(base.x, qy) - ctr, -ang);
                        float sq = max(abs(fc), 0.06);
                        float sdist;
                        float pr = sz * (0.7 + 0.5 * hc);
                        if (hd < 0.3) {
                            sdist = length(float2(lc.x, lc.y / sq)) * min(1.0, sq * 1.5 + 0.3) - pr * 0.6;
                        } else {
                            float2 hs = float2(pr, pr * 0.5 * sq);
                            float2 dd = abs(lc) - hs;
                            sdist = length(max(dd, 0.0)) + min(max(dd.x, dd.y), 0.0);
                        }
                        float e = 0.6 + blur;
                        float m = 1.0 - smoothstep(-e, e, sdist);
                        if (m <= 0.001) continue;
                        float3 base3 = hsv29(fract(hd * 7.13 + ha), clamp(p.c.y, 0.0, 1.0), 1.0);
                        float face = fc > 0.0 ? 1.0 : 0.72;                             // back side of the paper is darker
                        float lit = 0.5 + 0.5 * abs(fc);
                        float3 col = base3 * lit * face + float3(1.0) * pow(abs(fc), 24.0) * 0.35;
                        col *= mix(0.8, 1.0, z);
                        P = P * (1.0 - m) + col * m;
                        A = A * (1.0 - m) + m;
                    }
                }
            }
            g = P / max(A, 1e-3);
            ga = A;
            break;
        }
        case 7: { // bubbles (additive): a = (spacing, size, rise, sway), b = color, c = (seed, iridescence, depth blur, 0)
            float3 acc = float3(0.0);
            float seed = p.c.x;
            float irid = clamp(p.c.y, 0.0, 1.0);
            for (int L = 0; L < 3; L++) {
                float z = float(L) * 0.5;
                float cl = max(p.a.x, 6.0) * mix(0.6, 1.7, z);
                float spd = p.a.z * mix(0.55, 1.2, z);
                float blur = clamp(p.c.z, 0.0, 1.0) * (z > 0.75 ? 2.0 : (z < 0.25 ? 0.8 : 0.0));
                float2 base = c + float2(float(L) * 53.0 + seed * 19.0, float(L) * 31.0);
                float colx = floor(base.x / cl);
                for (int i = -1; i <= 1; i++) {
                    float cx = colx + float(i);
                    float cf = 0.75 + 0.5 * h29v2(float2(cx * 1.7, float(L) * 3.0 + seed));
                    float qy = base.y + spd * cf * t;
                    float cy0 = floor(qy / cl);
                    for (int j = -1; j <= 1; j++) {
                        float2 cid = float2(cx, cy0 + float(j));
                        float ha = h29v2(cid + float(L) * 7.0 + seed), hb = h29v2(cid * 1.5 + 2.9), hc = h29v2(cid * 0.6 + 7.3 + seed);
                        if (hb > 0.85) continue;
                        float2 ctr = (cid + 0.5 + (float2(ha, hb) - 0.5) * 0.4) * cl;
                        ctr.x += sin(t * 2.0 * (0.6 + hc) + ha * 6.283) * clamp(p.a.w, 0.0, 2.0) * cl * 0.14;
                        float rr = clamp(p.a.y * (0.6 + 0.7 * hc) * mix(0.6, 1.5, z), 1.0, cl * 0.45);
                        float2 dv = float2(base.x, qy) - ctr;
                        float ang = atan2(dv.y, dv.x);
                        float rw = rr * (1.0 + 0.035 * sin(3.0 * ang + t * 3.0 * (0.5 + ha)) + 0.02 * sin(5.0 * ang - t * 2.0));
                        float d = length(dv);
                        float e = 0.7 + blur;
                        float inside = 1.0 - smoothstep(rw - e, rw + e, d);
                        if (inside <= 0.0) continue;
                        float rn = clamp(d / rw, 0.0, 1.0);
                        float fres = pow(rn, 5.0) * 0.9 + 0.04;
                        float film = fract(rn * 1.3 + ha + t * 0.08 + 0.15 * sin(ang * 2.0 + t));
                        float3 fc = mix(p.b.rgb, hsv29(film, 0.55, 1.0) * mix(float3(1.0), p.b.rgb, 0.3), irid);
                        float2 h1 = dv / rw + float2(0.38, 0.42);
                        float2 h2 = dv / rw - float2(0.42, 0.36);
                        float spec = exp(-dot(h1, h1) * 38.0) * 1.1 + exp(-dot(h2 * float2(1.0, 2.0), h2 * float2(1.0, 2.0)) * 60.0) * 0.35;
                        float bri = mix(0.55, 1.0, z);
                        acc += (fc * fres + float3(1.0) * spec) * inside * bri;
                    }
                }
            }
            g = acc;
            ga = clamp(max(acc.r, max(acc.g, acc.b)), 0.0, 1.0);
            break;
        }
        default: break;
    }
    float4 base = p.d.z > 0.5 ? float4(0.0) : s;
    float bl = clamp(p.d.y, 0.0, 1.0);
    float4 o;
    if (p.i.y == 0u) {
        float3 Lg = max(g, float3(0.0)) * bl;
        o = float4(base.rgb + Lg, max(base.a, clamp(max(ga * bl, lum29(Lg)), 0.0, 1.0)));
    } else {
        float a = clamp(ga, 0.0, 1.0) * bl;
        o = float4(clamp(g, 0.0, 4.0) * a + base.rgb * (1.0 - a), a + base.a * (1.0 - a));
    }
    o = select(o, float4(0.0), isnan(o));
    dst.write(half4(o), gid);
}

// ---------- Keys ----------
// i.x = 0 luma key: a = (threshold, tolerance, feather, edge clean 0-1), i.y = type (0 darker, 1 brighter, 2 similar, 3 dissimilar),
//        i.z flags: bit0 invert, bit1 view matte
// i.x = 1 color range key: a = (hue deg, width deg, sat min, val min), b = (softness deg, spill 0-1, 0, 0), i.z flags as above
kernel void fxKey29(texture2d<half, access::sample> src [[texture(0)]],
                    texture2d<half, access::write> dst [[texture(1)]],
                    constant EffectParams& p [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 s = float4(src.sample(s29Zero, float2(gid) + 0.5));
    bool viewMatte = (p.i.z & 2u) != 0u;
    if (s.a <= 1e-5) { dst.write(viewMatte ? half4(0.0h, 0.0h, 0.0h, 1.0h) : half4(0.0h), gid); return; }
    float3 col = clamp(unp29(s), 0.0, 1.0);
    float keep = 1.0;
    if (p.i.x == 0u) {
        float l = lum29(col);
        float thr = p.a.x, tol = p.a.y, fe = max(p.a.z, 0.004);
        float bgLevel = 0.0;
        switch (p.i.y) {
            case 1: keep = 1.0 - smoothstep(thr - fe * 0.5, thr + fe * 0.5, l); bgLevel = 1.0; break;
            case 2: keep = smoothstep(tol - fe * 0.5, tol + fe * 0.5, abs(l - thr)); bgLevel = thr; break;
            case 3: keep = 1.0 - smoothstep(tol - fe * 0.5, tol + fe * 0.5, abs(l - thr)); bgLevel = thr; break;
            default: keep = smoothstep(thr - fe * 0.5, thr + fe * 0.5, l); bgLevel = 0.0; break;
        }
        if ((p.i.z & 1u) != 0u) keep = 1.0 - keep;
        // Edge decontamination: a soft edge pixel is fg*k + bg*(1-k); recover fg so no dark/bright fringe remains.
        float k = max(keep, 0.04);
        float3 fg = clamp((col - float3(bgLevel) * (1.0 - k)) / k, 0.0, 1.0);
        col = mix(col, fg, clamp(p.a.w, 0.0, 1.0) * step(keep, 0.999));
    } else {
        float3 hsv = rgb2hsv29(col);
        float dh = abs(fmod(hsv.x * 360.0 - p.a.x + 720.0, 360.0) - 180.0);
        dh = 180.0 - dh;                                                  // 0 = exactly the key hue
        float hw = p.a.y * 0.5, soft = max(p.b.x, 0.5);
        float hueK = 1.0 - smoothstep(hw, hw + soft, dh);
        float satK = smoothstep(max(p.a.z - 0.08, 0.0), p.a.z + 0.08, hsv.y);
        float valK = smoothstep(max(p.a.w - 0.08, 0.0), p.a.w + 0.08, hsv.z);
        float k = hueK * satK * valK;
        keep = 1.0 - k;
        if ((p.i.z & 1u) != 0u) keep = 1.0 - keep;
        // Spill suppression: pixels whose hue leans toward the key lose that cast (neutralised toward their luma).
        float spillW = (1.0 - smoothstep(hw, hw + soft + 45.0, dh)) * smoothstep(0.02, 0.2, hsv.y);
        float sp = clamp(p.b.y, 0.0, 1.0) * spillW * ((p.i.z & 1u) != 0u ? 0.0 : 1.0);
        col = mix(col, float3(lum29(col)), sp * 0.9);
    }
    float na = s.a * clamp(keep, 0.0, 1.0);
    if (viewMatte) { dst.write(half4(half3(na), 1.0h), gid); return; }
    dst.write(half4(half3(col * na), half(na)), gid);
}

// ---------- Color ----------
// i.x = 0 exposure: a = (stops, offset, gamma, highlight rolloff 0-1), i.y = bypass linear
// i.x = 1 brightness & contrast: a = (brightness -150..150, contrast -100..100), i.y = legacy (clipping) formula
// i.x = 2 vibrance: a = (vibrance -1..1, saturation -1..1)
static inline float sCurve29(float x, float gm) {
    x = clamp(x, 0.0, 1.0);
    float a = pow(x, gm), b = pow(1.0 - x, gm);
    return a / max(a + b, 1e-6);
}

kernel void fxColor29(texture2d<half, access::sample> src [[texture(0)]],
                      texture2d<half, access::write> dst [[texture(1)]],
                      constant EffectParams& p [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 s = float4(src.sample(s29Zero, float2(gid) + 0.5));
    float a = s.a;
    if (a <= 1e-5) { dst.write(half4(0.0h), gid); return; }
    float3 c = unp29(s);
    switch (p.i.x) {
        case 0: {
            bool bypass = p.i.y != 0u;
            float3 x = bypass ? c : toLin29(c);
            float gain = exp2(p.a.x);
            x = x * gain + p.a.y;
            float r = clamp(p.a.w, 0.0, 1.0) * clamp(p.a.x * 0.5, 0.0, 1.0) * 4.0;
            if (r > 0.0) x = max(x, float3(0.0)) * (1.0 + r) / (1.0 + max(x, float3(0.0)) * r);  // filmic shoulder: 1 stays 1, no hard clip
            x = pow(max(x, float3(0.0)), float3(1.0 / max(p.a.z, 0.01)));
            c = bypass ? x : toSrgb29(x);
            c = clamp(c, 0.0, 1.0);
            break;
        }
        case 1: {
            if (p.i.y != 0u) {
                c = c + p.a.x / 255.0;
                float k = p.a.y >= 0 ? 1.0 + p.a.y / 100.0 * 2.0 : 1.0 + p.a.y / 100.0;
                c = clamp((c - 0.5) * k + 0.5, 0.0, 1.0);
            } else {
                c = clamp(c, 0.0, 1.0);
                float kb = clamp(p.a.x / 150.0, -1.0, 1.0);
                c = c + kb * c * (1.0 - c);                                       // midtone lift, endpoints fixed
                float kc = clamp(p.a.y / 100.0, -1.0, 1.0);
                float gm = kc >= 0.0 ? 1.0 + kc * 2.0 : 1.0 + kc * 0.7;
                c = float3(sCurve29(c.r, gm), sCurve29(c.g, gm), sCurve29(c.b, gm));
            }
            break;
        }
        case 2: {
            c = clamp(c, 0.0, 1.0);
            float l = lum29(c);
            float mx = max(c.r, max(c.g, c.b)), mnv = min(c.r, min(c.g, c.b));
            float sat = mx > 1e-5 ? (mx - mnv) / mx : 0.0;
            float3 hsv = rgb2hsv29(c);
            float hueSkin = 1.0 - smoothstep(0.02, 0.09, abs(hsv.x - 0.07));      // protect skin tones (orange hues)
            float vib = p.a.x;
            float vAmt = vib >= 0.0 ? vib * (1.0 - sat) * (1.0 - sat) * (1.0 - 0.6 * hueSkin) * 1.6 : vib * (1.0 - sat * 0.5);
            float f = max(1.0 + vAmt + p.a.y, 0.0);
            if (f > 1.0) {
                // Largest factor that keeps every channel inside 0..1 — saturate up to the gamut edge, never past it.
                float fm = 1e4;
                for (int k = 0; k < 3; k++) {
                    float dv = c[k] - l;
                    if (dv > 1e-5) fm = min(fm, (1.0 - l) / dv);
                    else if (dv < -1e-5) fm = min(fm, l / -dv);
                }
                float want = f - 1.0, room = max(fm - 1.0, 0.0);
                f = 1.0 + room * (1.0 - exp(-want / max(room, 1e-4)));          // soft approach to the gamut edge
            }
            c = clamp(float3(l) + (c - float3(l)) * f, 0.0, 1.0);
            break;
        }
        default: break;
    }
    dst.write(half4(half3(c * a), half(a)), gid);
}
