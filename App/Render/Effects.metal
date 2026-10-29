#include <metal_stdlib>
using namespace metal;

// All effect textures are rgba16Float, PREMULTIPLIED alpha, sRGB-encoded (AE default working space).
// Must match EffectParams in EffectRegistry.swift.
struct EffectParams {
    float4 a;
    float4 b;
    float4 c;
    float4 d;
    uint4  i;
};

constexpr sampler sZero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler sEdge(address::clamp_to_edge, filter::linear, coord::pixel);

static inline float4 samp(texture2d<half, access::sample> t, float2 px, bool edge) {
    return edge ? float4(t.sample(sEdge, px)) : float4(t.sample(sZero, px));
}

static inline float3 unpremul(float4 c) { return c.a > 1e-6 ? c.rgb / c.a : float3(0.0); }

static float luma(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

static float3 rgb2hsl(float3 c) {
    float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
    float l = (mx + mn) * 0.5, h = 0.0, s = 0.0;
    float d = mx - mn;
    if (d > 1e-6) {
        s = l > 0.5 ? d / (2.0 - mx - mn) : d / (mx + mn);
        if (mx == c.r) h = (c.g - c.b) / d + (c.g < c.b ? 6.0 : 0.0);
        else if (mx == c.g) h = (c.b - c.r) / d + 2.0;
        else h = (c.r - c.g) / d + 4.0;
        h /= 6.0;
    }
    return float3(h, s, l);
}

static float hue2rgb(float p, float q, float t) {
    t = fract(t);
    if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
    if (t < 0.5) return q;
    if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
    return p;
}

static float3 hsl2rgb(float3 hsl) {
    if (hsl.y <= 1e-6) return float3(hsl.z);
    float q = hsl.z < 0.5 ? hsl.z * (1.0 + hsl.y) : hsl.z + hsl.y - hsl.z * hsl.y;
    float p = 2.0 * hsl.z - q;
    return float3(hue2rgb(p, q, hsl.x + 1.0 / 3.0), hue2rgb(p, q, hsl.x), hue2rgb(p, q, hsl.x - 1.0 / 3.0));
}

// ---------- Utility ----------

kernel void fxCopy(texture2d<half, access::sample> src [[texture(0)]],
                   texture2d<half, access::write> dst [[texture(1)]],
                   uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    dst.write(src.sample(sZero, float2(gid) + 0.5), gid);
}

kernel void fxClear(texture2d<half, access::write> dst [[texture(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    dst.write(half4(0.0h), gid);
}

// ---------- Blurs ----------

// Separable Gaussian. a.xy = direction, a.z = sigma (px), a.w = radius (px); i.x = repeat edges.
kernel void fxGaussian(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float sigma = max(p.a.z, 0.01);
    int radius = int(min(p.a.w, 400.0));
    bool edge = p.i.x != 0;
    float4 acc = samp(src, c, edge);
    float wsum = 1.0;
    float inv2s2 = 1.0 / (2.0 * sigma * sigma);
    // Pair taps and use bilinear filtering to halve sample count.
    for (int k = 1; k <= radius; k += 2) {
        float w1 = exp(-float(k * k) * inv2s2);
        float w2 = exp(-float((k + 1) * (k + 1)) * inv2s2);
        float w = w1 + w2;
        float off = float(k) + w2 / max(w, 1e-8);
        float2 o = p.a.xy * off;
        acc += w * (samp(src, c + o, edge) + samp(src, c - o, edge));
        wsum += 2.0 * w;
    }
    dst.write(half4(acc / wsum), gid);
}

// Directional (motion) blur. a.xy = half-length vector (px); i.x = sample count.
kernel void fxDirectional(texture2d<half, access::sample> src [[texture(0)]],
                          texture2d<half, access::write> dst [[texture(1)]],
                          constant EffectParams& p [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    int n = int(clamp(p.i.x, 1u, 256u));
    float4 acc = float4(0.0);
    for (int k = 0; k < n; k++) {
        float t = n == 1 ? 0.0 : (float(k) / float(n - 1)) * 2.0 - 1.0;
        acc += samp(src, c + p.a.xy * t, false);
    }
    dst.write(half4(acc / float(n)), gid);
}

// Radial blur. a.xy = center (px), a.z = amount, i.x = type (0 spin, 1 zoom), i.y = samples.
kernel void fxRadial(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     constant EffectParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float2 d = c - p.a.xy;
    int n = int(clamp(p.i.y, 2u, 128u));
    float amount = p.a.z;
    float4 acc = float4(0.0);
    for (int k = 0; k < n; k++) {
        float t = (float(k) / float(n - 1)) - 0.5;
        float2 q;
        if (p.i.x == 0) {
            float ang = t * amount * (M_PI_F / 180.0);
            float cs = cos(ang), sn = sin(ang);
            q = p.a.xy + float2(d.x * cs - d.y * sn, d.x * sn + d.y * cs);
        } else {
            q = p.a.xy + d * (1.0 + t * amount * 0.01);
        }
        acc += samp(src, q, false);
    }
    dst.write(half4(acc / float(n)), gid);
}

// ---------- Color ----------
// i.x = op: 0 exposure, 1 brightness/contrast, 2 hue/sat, 3 tint, 4 levels, 5 invert, 6 fill, 7 vignette
kernel void fxColor(texture2d<half, access::sample> src [[texture(0)]],
                    texture2d<half, access::write> dst [[texture(1)]],
                    constant EffectParams& p [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 s = float4(src.sample(sZero, float2(gid) + 0.5));
    float a = s.a;
    if (a <= 0.0 && p.i.x != 7) { dst.write(half4(0.0h), gid); return; }
    float3 c = unpremul(s);
    switch (p.i.x) {
        case 0: { // Exposure: a.x stops, a.y offset, a.z gamma
            c = c * exp2(p.a.x) + p.a.y;
            c = pow(max(c, 0.0), float3(1.0 / max(p.a.z, 0.01)));
            break;
        }
        case 1: { // Brightness (-150..150), Contrast (-100..100)
            c = c + p.a.x / 255.0;
            float k = p.a.y >= 0 ? 1.0 + p.a.y / 100.0 * 2.0 : 1.0 + p.a.y / 100.0;
            c = (c - 0.5) * k + 0.5;
            c = clamp(c, 0.0, 1.0);
            break;
        }
        case 2: { // Hue (deg), Saturation (-100..100), Lightness (-100..100), colorize i.y
            float3 hsl = rgb2hsl(clamp(c, 0.0, 1.0));
            if (p.i.y != 0) {
                hsl.x = fract(p.a.x / 360.0);
                hsl.y = clamp(p.b.x / 100.0, 0.0, 1.0);
            } else {
                hsl.x = fract(hsl.x + p.a.x / 360.0);
                hsl.y = clamp(hsl.y * (1.0 + p.a.y / 100.0), 0.0, 1.0);
            }
            float L = p.a.z / 100.0;
            hsl.z = L >= 0 ? hsl.z + (1.0 - hsl.z) * L : hsl.z * (1.0 + L);
            c = hsl2rgb(hsl);
            break;
        }
        case 3: { // Tint: map black -> b.rgb, map white -> c.rgb, amount a.x (0..1)
            float l = luma(c);
            float3 t = mix(p.b.rgb, p.c.rgb, l);
            c = mix(c, t, p.a.x);
            break;
        }
        case 4: { // Levels: a = inBlack, inWhite, gamma, outBlack ; b.x = outWhite (0..1)
            float3 x = clamp((c - p.a.x) / max(p.a.y - p.a.x, 1e-4), 0.0, 1.0);
            x = pow(x, float3(1.0 / max(p.a.z, 0.01)));
            c = mix(float3(p.a.w), float3(p.b.x), x);
            break;
        }
        case 5: { // Invert, blend a.x
            c = mix(c, 1.0 - c, p.a.x);
            break;
        }
        case 6: { // Fill: b.rgb color, a.x opacity
            c = mix(c, p.b.rgb, p.a.x);
            break;
        }
        case 7: { // Vignette: a.x amount (-1..1), a.y size (0..1), a.z softness; a.zw.. b.xy = texture size
            float2 uv = (float2(gid) + 0.5) / p.b.xy;
            float2 d = (uv - 0.5) * float2(p.b.x / max(p.b.y, 1.0), 1.0);
            float r = length(d) / (0.5 * length(float2(p.b.x / max(p.b.y, 1.0), 1.0)));
            float v = smoothstep(p.a.y, p.a.y + max(p.a.z, 0.01), r);
            if (a <= 0.0) { dst.write(half4(0.0h), gid); return; }
            c = p.a.x >= 0 ? c * (1.0 - v * p.a.x) : mix(c, float3(1.0), v * -p.a.x);
            break;
        }
        default: break;
    }
    dst.write(half4(half3(c * a), half(a)), gid);
}

// ---------- Glow ----------

// Extract brights. a.x threshold (0..1), a.y softness. i.x = based on (0 luma, 1 alpha)
kernel void fxGlowThreshold(texture2d<half, access::sample> src [[texture(0)]],
                            texture2d<half, access::write> dst [[texture(1)]],
                            constant EffectParams& p [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 s = float4(src.sample(sZero, float2(gid) + 0.5));
    float v = p.i.x == 1 ? s.a : luma(unpremul(s)) * s.a;
    float k = smoothstep(p.a.x - p.a.y, p.a.x + p.a.y, v);
    dst.write(half4(s * k), gid);
}

// Combine. a.x intensity, i.x op (0 add, 1 screen), i.y = composite original (0 on top,1 behind,2 none)
// i.z = use colors (A/B tint); b.rgb color A, c.rgb color B
kernel void fxGlowCombine(texture2d<half, access::sample> src [[texture(0)]],
                          texture2d<half, access::sample> glow [[texture(1)]],
                          texture2d<half, access::write> dst [[texture(2)]],
                          constant EffectParams& p [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(sZero, c));
    float4 g = float4(glow.sample(sZero, c)) * p.a.x;
    if (p.i.z != 0) {
        float l = luma(unpremul(g));
        g.rgb = mix(p.c.rgb, p.b.rgb, clamp(l, 0.0, 1.0)) * g.a;
    }
    float4 o;
    if (p.i.y == 2) {
        o = g;
    } else if (p.i.x == 1) {
        o = s + g - s * g;
    } else {
        o = s + g;
        o.a = min(o.a, 1.0);
    }
    dst.write(half4(o), gid);
}

// ---------- Generate ----------

static float hash21(float2 p, float seed) {
    p = fract(p * float2(123.34, 456.21) + seed * 0.1234);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float hash31(float3 p) {
    p = fract(p * float3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

// Value noise in 3D (xy + evolution as z), smooth (Hermite) interpolation.
static float vnoise(float3 x) {
    float3 i = floor(x), f = fract(x);
    float3 u = f * f * (3.0 - 2.0 * f);
    float n000 = hash31(i), n100 = hash31(i + float3(1, 0, 0));
    float n010 = hash31(i + float3(0, 1, 0)), n110 = hash31(i + float3(1, 1, 0));
    float n001 = hash31(i + float3(0, 0, 1)), n101 = hash31(i + float3(1, 0, 1));
    float n011 = hash31(i + float3(0, 1, 1)), n111 = hash31(i + float3(1, 1, 1));
    return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
               mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

// Fractal Noise. a = contrast(%), brightness(%), scale(px), complexity
// b = subInfluence(%), subScaling(%), evolution(revolutions), offset.x ; c.x offset.y ; c.y rotation (deg)
// i.x fractal type (0 basic, 1 turbulent), i.y invert, i.z composite over source (0 replace, 1 multiply src alpha)
kernel void fxFractalNoise(texture2d<half, access::sample> src [[texture(0)]],
                           texture2d<half, access::write> dst [[texture(1)]],
                           constant EffectParams& p [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5 + float2(p.b.w, p.c.x);
    float rot = p.c.y * M_PI_F / 180.0;
    c = float2(c.x * cos(rot) - c.y * sin(rot), c.x * sin(rot) + c.y * cos(rot));
    float scale = max(p.a.z, 1.0);
    int oct = int(clamp(p.a.w, 1.0, 10.0));
    float amp = 1.0, sum = 0.0, norm = 0.0;
    float2 q = c / scale;
    float evo = p.b.z;
    for (int k = 0; k < oct; k++) {
        float n = vnoise(float3(q, evo + float(k) * 7.31));
        if (p.i.x == 1) n = abs(n * 2.0 - 1.0);
        sum += n * amp;
        norm += amp;
        amp *= p.b.x / 100.0;
        q *= 100.0 / max(p.b.y, 1.0);
    }
    float v = sum / max(norm, 1e-5);
    v = (v - 0.5) * (p.a.x / 100.0) + 0.5 + p.a.y / 100.0;
    if (p.i.y != 0) v = 1.0 - v;
    v = clamp(v, 0.0, 1.0);
    float alpha = 1.0;
    if (p.i.z == 1) alpha = float(src.sample(sZero, float2(gid) + 0.5).a);
    dst.write(half4(half3(v * alpha), half(alpha)), gid);
}

// ---------- Keying / stylize ----------

// Chroma key, Keylight-style screen-balance matte.
// b.rgb key color; a.x tolerance (0..1), a.y softness (0..1), a.z spill (0..1), a.w screen balance (0..1); i.x view matte
// Saturation of the screen channel = dominant - mix(max(others), min(others), balance). Pixels whose saturation
// reaches (1 - tolerance) of the key's become transparent; below that they fade over `softness`.
static float screenSat(float3 c, int dom, float balance) {
    float d = dom == 1 ? c.g : (dom == 2 ? c.b : c.r);
    float o1 = dom == 0 ? c.g : c.r;
    float o2 = dom == 2 ? c.g : c.b;
    return d - mix(max(o1, o2), min(o1, o2), balance);
}

kernel void fxChromaKey(texture2d<half, access::sample> src [[texture(0)]],
                        texture2d<half, access::write> dst [[texture(1)]],
                        constant EffectParams& p [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 s = float4(src.sample(sZero, float2(gid) + 0.5));
    if (s.a <= 0.0) { dst.write(half4(0.0h), gid); return; }
    float3 c = unpremul(s);
    float3 k = p.b.rgb;
    int dom = (k.g >= k.r && k.g >= k.b) ? 1 : ((k.b >= k.r) ? 2 : 0);
    float balance = p.a.w;
    float ks = max(screenSat(k, dom, balance), 1e-3);
    float ratio = screenSat(c, dom, balance) / ks;
    float hi = 1.0 - p.a.x;
    float lo = hi - max(p.a.y, 1e-3);
    float matte = 1.0 - smoothstep(lo, hi, ratio);
    // Despill: pull the screen channel down to the balanced mix of the others.
    float3 o = c;
    float sat = max(screenSat(c, dom, balance), 0.0) * p.a.z;
    if (dom == 1) o.g -= sat; else if (dom == 2) o.b -= sat; else o.r -= sat;
    float a = s.a * matte;
    if (p.i.x != 0) { dst.write(half4(half3(a), 1.0h), gid); return; }
    dst.write(half4(half3(max(o, 0.0) * a), half(a)), gid);
}

// RGB split / chromatic aberration. a.xy = offset vector (px) for red; blue gets the opposite.
kernel void fxRGBSplit(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 r = float4(src.sample(sZero, c + p.a.xy));
    float4 g = float4(src.sample(sZero, c));
    float4 b = float4(src.sample(sZero, c - p.a.xy));
    // Premultiplied channels combine additively; alpha is the union.
    float a = max(r.a, max(g.a, b.a));
    dst.write(half4(r.r, g.g, b.b, a), gid);
}

// ---------- Adjustment layer mix ----------
// Mixes processed comp back into comp inside the adjustment layer's transformed rect.
// a/b = inverse affine rows (comp px -> local), c.xy = half size, c.z = opacity, c.w = aa
kernel void fxAdjustMix(texture2d<half, access::read_write> comp [[texture(0)]],
                        texture2d<half, access::sample> processed [[texture(1)]],
                        constant EffectParams& p [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= comp.get_width() || gid.y >= comp.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float2 q = float2(dot(p.a.xy, c) + p.a.z, dot(p.b.xy, c) + p.b.z);
    float2 dq = abs(q) - p.c.xy;
    float d = length(max(dq, 0.0)) + min(max(dq.x, dq.y), 0.0);
    float cov = clamp(0.5 - d / max(p.c.w, 1e-4), 0.0, 1.0) * p.c.z;
    if (cov <= 0.0) return;
    float4 base = float4(comp.read(gid));
    float4 fx = float4(processed.sample(sZero, c));
    comp.write(half4(mix(base, fx, cov)), gid);
}
