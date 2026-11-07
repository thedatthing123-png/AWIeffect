#include <metal_stdlib>
using namespace metal;

// Batch R4: CC Studio Grade with the renewed controls.
//  fxGradeR4 — fxGrade plus offset wheel, wheel luminance, hue curves (Hue vs Hue / Sat / Lum, Luma vs Sat) and the
//  qualifier (hue softness, saturation / luma ranges, show mask). Grades that use none of these keep fxGrade.
// rgba16Float, PREMULTIPLIED alpha, sRGB-encoded.
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

static float3 hsvR4(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
static float3 rgbR4(float3 c) {
    float3 p = abs(fract(c.xxx + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(float3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
/// 1 inside [lo, hi]; soft falloff outside. A range reaching an end has no edge there.
static float windowR4(float v, float lo, float hi, float soft) {
    float s = max(soft * 0.25, 1e-4);
    float a = lo <= 1e-4 ? 1.0 : smoothstep(lo - s, lo, v);
    float b = hi >= 0.9999 ? 1.0 : 1.0 - smoothstep(hi, hi + s, v);
    return a * b;
}

// wheels: 0 lift, 1 gamma, 2 gain, 3 offset rgb, 4 luminance (lift, gamma, gain, offset),
//         5 qualifier (satLo, satHi, lumLo, lumHi), 6 (hue softness, show mask, hue curves on, -)
kernel void fxGradeR4(texture2d<half, access::sample> src [[texture(0)]],
                      texture2d<half, access::write> dst [[texture(1)]],
                      texture2d<half, access::sample> curve [[texture(2)]],
                      texture3d<half, access::sample> lut [[texture(3)]],
                      texture2d<half, access::sample> hueCurve [[texture(4)]],
                      constant EffectParams& p [[buffer(0)]],
                      constant float4* wheels [[buffer(1)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 s = float4(src.read(gid));
    if (p.c.w > 0.0 && float(gid.x) < p.c.w * float(dst.get_width())) { dst.write(half4(s), gid); return; }
    if (s.a <= 0.0) { dst.write(half4(s), gid); return; }
    float3 c = s.rgb / s.a;
    c = pow(max(c, 0.0), 2.2) * exp2(p.a.x); c = pow(max(c, 0.0), 1.0 / 2.2);
    c += float3(p.b.x * 0.12, p.b.y * 0.12, -p.b.x * 0.12);
    c = (c - 0.5) * (1.0 + p.a.y) + 0.5;
    float l = dot(clamp(c, 0.0, 1.0), float3(0.2126, 0.7152, 0.0722));
    c += p.a.z * 0.3 * smoothstep(0.45, 1.0, l) + p.a.w * 0.3 * (1.0 - smoothstep(0.0, 0.55, l));
    // Lift / gamma / gain (+ each wheel's luminance), then offset moves everything.
    float4 Y = wheels[4];
    float3 lift = (wheels[0].rgb + Y.x) * 0.25, gam = wheels[1].rgb + Y.y, gain = 1.0 + (wheels[2].rgb + Y.z) * 0.5;
    c = clamp(c * gain + lift * (1.0 - c), 0.0, 1.0);
    c = pow(c, exp2(-gam));
    c = clamp(c + (wheels[3].rgb + Y.w) * 0.25, 0.0, 1.0);
    constexpr sampler cs(address::clamp_to_edge, filter::linear, coord::normalized);
    c = float3(float(curve.sample(cs, float2(c.r, 0.5)).r), float(curve.sample(cs, float2(c.g, 0.5)).g), float(curve.sample(cs, float2(c.b, 0.5)).b));
    l = dot(c, float3(0.2126, 0.7152, 0.0722));
    float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    c = l + (c - l) * (1.0 + p.b.w + p.b.z * (1.0 - sat));
    // Hue curves: per-hue shift / saturation / lightness (the 8 vectors) and saturation by luma.
    if (wheels[6].z > 0.5) {
        float3 h = hsvR4(clamp(c, 0.0, 1.0));
        float lv = dot(clamp(c, 0.0, 1.0), float3(0.2126, 0.7152, 0.0722));
        float4 hc = float4(hueCurve.sample(cs, float2(h.x, 0.5)));
        float ls = float(hueCurve.sample(cs, float2(lv, 0.5)).a);
        float3 o = rgbR4(float3(fract(h.x + hc.r), clamp(h.y * (1.0 + hc.g) * (1.0 + ls), 0.0, 1.0), h.z));
        // Lightness follows how colorful the pixel is, so greys stay put.
        c = clamp(o + hc.b * 0.5 * h.y, 0.0, 1.0);
    }
    // Qualifier: hue window (with softness) x saturation range x luma range.
    float3 h = hsvR4(clamp(c, 0.0, 1.0));
    float dh = abs(fract(h.x - p.c.x + 0.5) - 0.5);
    float soft = clamp(wheels[6].x, 0.0, 1.0);
    float w = 1.0 - smoothstep(min(p.c.y * (1.0 - soft), p.c.y - 1e-4), p.c.y, dh);
    float lq = dot(clamp(c, 0.0, 1.0), float3(0.2126, 0.7152, 0.0722));
    w *= windowR4(h.y, wheels[5].x, wheels[5].y, soft) * windowR4(lq, wheels[5].z, wheels[5].w, soft);
    if (wheels[6].y > 0.5) { dst.write(half4(half3(w * s.a), half(s.a)), gid); return; }
    if (w > 0.0) {
        h.x = fract(h.x + p.c.z * w);
        h.y = clamp(h.y * (1.0 + p.d.x * w), 0.0, 1.0);
        h.z = clamp(h.z + p.d.y * 0.5 * w, 0.0, 1.0);
        c = rgbR4(h);
    }
    if (p.i.x == 1) {
        float n = float(lut.get_width());
        float3 uvw = clamp(c, 0.0, 1.0) * ((n - 1.0) / n) + 0.5 / n;
        constexpr sampler ls3(address::clamp_to_edge, filter::linear, coord::normalized);
        c = mix(c, float3(lut.sample(ls3, uvw).rgb), p.d.z);
    }
    c = clamp(c, 0.0, 1.0);
    dst.write(half4(half3(c * s.a), half(s.a)), gid);
}

// Per-effect Mix: a.x = amount of the effect (0 = its input, 1 = its output).
kernel void fxMixR4(texture2d<half, access::read> before [[texture(0)]],
                    texture2d<half, access::read> after [[texture(1)]],
                    texture2d<half, access::write> dst [[texture(2)]],
                    constant EffectParams& p [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    dst.write(half4(mix(float4(before.read(gid)), float4(after.read(gid)), clamp(p.a.x, 0.0, 1.0))), gid);
}

// Gradient fill / overlay inside the layer's alpha.
// a = (center u, center v, cos angle, sin angle), b = color 1, c = color 2, d = (scale, opacity, layer w px, layer h px)
// i.x 0 linear / 1 radial, i.y blend 0 normal, 1 multiply, 2 screen, 3 overlay, 4 soft light, 5 color
static float3 blendR4(float3 s, float3 g, uint m) {
    if (m == 1u) return s * g;
    if (m == 2u) return 1.0 - (1.0 - s) * (1.0 - g);
    if (m == 3u) return select(1.0 - 2.0 * (1.0 - s) * (1.0 - g), 2.0 * s * g, s < 0.5);
    if (m == 4u) return select(s + (2.0 * g - 1.0) * (sqrt(s) - s), s - (1.0 - 2.0 * g) * s * (1.0 - s), g < 0.5);
    if (m == 5u) {
        float ls = dot(s, float3(0.2126, 0.7152, 0.0722)), lg = dot(g, float3(0.2126, 0.7152, 0.0722));
        return clamp(g + (ls - lg), 0.0, 1.0);
    }
    return g;
}
kernel void fxGradientR4(texture2d<half, access::read> src [[texture(0)]],
                         texture2d<half, access::write> dst [[texture(1)]],
                         constant EffectParams& p [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 s = float4(src.read(gid));
    if (s.a <= 0.0) { dst.write(half4(s), gid); return; }
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 lp = max(p.d.zw, float2(1.0));
    float2 off = (size - lp) * 0.5;
    float2 px = float2(gid) + 0.5 - off;
    float m = max(lp.x, lp.y);
    float2 d = (px - p.a.xy * lp) / m;          // from the center, in units of the longer side
    float sc = max(p.d.x, 0.01);
    float t;
    if (p.i.x == 1u) t = length(d) / (0.5 * sc);
    else {
        // Linear: the gradient spans the layer along the angle.
        float2 dir = float2(p.a.z, p.a.w);
        float span = (abs(dir.x) * lp.x + abs(dir.y) * lp.y) / m;
        t = dot(d, dir) / max(span * sc, 1e-4) + 0.5;
    }
    t = clamp(t, 0.0, 1.0);
    float4 g = mix(p.b, p.c, t);
    float3 sc3 = s.rgb / s.a;
    float3 o = mix(sc3, blendR4(sc3, g.rgb, p.i.y), clamp(p.d.y * g.a, 0.0, 1.0));
    dst.write(half4(half3(o * s.a), half(s.a)), gid);
}
