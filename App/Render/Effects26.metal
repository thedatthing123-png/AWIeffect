#include <metal_stdlib>
using namespace metal;

// Batch 26: shake & blur remake — camera shake blur on a noise path with roll, adaptive spin / vortex (spiral) blur,
// wet-paint smear, direction-aware edge blur, isolated luma-mask blur, frosted glass refraction, progressive
// tilt-shift and a real bokeh lens blur (linear-light highlights, polygon iris, rim).
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s26Zero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler s26Edge(address::clamp_to_edge, filter::linear, coord::pixel);

static inline float3 u26(float4 c) { return c.a > 1e-5 ? c.rgb / c.a : float3(0.0); }
static inline float l26(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static inline float2 rot26(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(cs * v.x - sn * v.y, sn * v.x + cs * v.y); }
static inline float h26(float x, float seed) { return fract(sin(x * 127.1 + seed * 311.7) * 43758.5453); }
static inline float h26v(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
// Smooth 1D value noise in [-1, 1] (quintic fade, like the Swift Wiggle).
static float vn26(float x, float seed) {
    float i = floor(x), f = x - i;
    float u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(h26(i, seed), h26(i + 1.0, seed), u) * 2.0 - 1.0;
}
static float fbm26(float x, float seed) {
    return (vn26(x, seed) + 0.5 * vn26(x * 2.03 + 3.1, seed + 17.0)) / 1.5;
}
// Smooth 2D value noise in [-1, 1].
static float vn26x2(float2 p, float seed) {
    float2 i = floor(p), f = p - i;
    float2 u = f * f * (3.0 - 2.0 * f);
    float2 o = float2(seed * 17.13, seed * 7.31);
    float a = h26v(i + o), b = h26v(i + float2(1.0, 0.0) + o);
    float c = h26v(i + float2(0.0, 1.0) + o), d = h26v(i + float2(1.0, 1.0) + o);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}
static float edgeLum26(texture2d<half, access::sample> t, float2 c) {
    float4 v = float4(t.sample(s26Edge, c));
    return l26(v.rgb) * 0.8 + v.a * 0.2;
}
// Sobel gradient vector (not magnitude).
static float2 sobel26(texture2d<half, access::sample> t, float2 c, float w) {
    float tl = edgeLum26(t, c + float2(-w, -w)), tr = edgeLum26(t, c + float2(w, -w));
    float bl = edgeLum26(t, c + float2(-w, w)), br = edgeLum26(t, c + float2(w, w));
    float l = edgeLum26(t, c + float2(-w, 0.0)), r = edgeLum26(t, c + float2(w, 0.0));
    float u = edgeLum26(t, c + float2(0.0, -w)), d = edgeLum26(t, c + float2(0.0, w));
    float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
    float gy = (bl + 2.0 * d + br) - (tl + 2.0 * u + tr);
    return float2(gx, gy);
}
// Radius scale of a regular n-blade iris at angle th (1 = inscribed circle touches the blade).
static float iris26(float th, float n) {
    if (n < 2.5) return 1.0;
    float seg = 6.2831853 / n;
    float m = th - seg * floor(th / seg);
    return cos(3.14159265 / n) / max(cos(m - 3.14159265 / n), 1e-3);
}

kernel void fxBlur26(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     texture2d<half, access::sample> aux [[texture(2)]],
                     texture2d<half, access::sample> msk [[texture(3)]],
                     texture2d<half, access::sample> ext [[texture(4)]],
                     constant EffectParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s26Zero, c));
    float4 o = s;
    float t = p.d.x;
    float3 col = u26(s);
    switch (p.i.x) {
        case 0: { // camera shake blur: a = (amplitude px, shutter 0-1, speed Hz, roll rad), b.x = seed
            // The camera wanders on smooth noise; the blur kernel is the path travelled while the shutter is open,
            // measured from its middle so the image never drifts (or crops) — only smears.
            float seed = p.b.x;
            float u0 = t * p.a.z;
            float win = max(p.a.y, 0.0) * 0.6;
            float2 p0 = float2(fbm26(u0, seed + 1.0), fbm26(u0, seed + 2.0));
            float r0 = fbm26(u0 * 0.8, seed + 3.0);
            float2 ctr = size * 0.5;
            float4 acc = float4(0.0); float ws = 0.0;
            const int N = 32;
            for (int k = 0; k < N; k++) {
                float f = (float(k) + 0.5) / float(N) - 0.5;
                float u = u0 + f * win;
                float2 off = (float2(fbm26(u, seed + 1.0), fbm26(u, seed + 2.0)) - p0) * p.a.x;
                float ang = (fbm26(u * 0.8, seed + 3.0) - r0) * p.a.w;
                float w = 1.0 - abs(f) * 1.2; // tent shutter: soft streak ends
                float2 q = ctr + rot26(c - ctr, -ang) - off;
                acc += float4(src.sample(s26Zero, q)) * w; ws += w;
            }
            o = acc / max(ws, 1e-4);
            break;
        }
        case 1: { // spin blur: a = (center px, angle rad, sharp center radius px)
            float2 d = c - p.a.xy;
            float r = length(d);
            float ang = p.a.z * (p.a.w > 0.5 ? smoothstep(0.0, p.a.w, r) : 1.0);
            int n = int(clamp(abs(ang) * r / 1.2, 8.0, 96.0));
            float dither = h26v(c) - 0.5;
            float4 acc = float4(0.0); float ws = 0.0;
            for (int k = 0; k < n; k++) {
                float f = (float(k) + 0.5 + dither) / float(n) - 0.5;
                float w = 1.0 - abs(f);
                acc += float4(src.sample(s26Zero, p.a.xy + rot26(d, f * ang))) * w; ws += w;
            }
            o = acc / max(ws, 1e-4);
            break;
        }
        case 2: { // vortex blur: a = (center px, max angle rad, falloff px), b.x = inward pull 0-1
            // Samples follow a log spiral: twist and pull are strongest at the eye and fade out like a whirlpool.
            float2 d = c - p.a.xy;
            float r = length(d);
            float k0 = exp(-r / max(p.a.w, 1.0));
            float ang = p.a.z * k0;
            float pull = p.b.x * 1.5 * k0;
            int n = int(clamp(abs(ang) * r / 1.2 + pull * r / 1.5, 8.0, 96.0));
            float dither = h26v(c) - 0.5;
            float4 acc = float4(0.0); float ws = 0.0;
            for (int k = 0; k < n; k++) {
                float f = (float(k) + 0.5 + dither) / float(n);
                float w = 1.0 - f * 0.6;
                float2 q = p.a.xy + rot26(d, f * ang) * exp(-f * pull);
                acc += float4(src.sample(s26Zero, q)) * w; ws += w;
            }
            o = acc / max(ws, 1e-4);
            break;
        }
        case 3: { // smear: a.xy = direction * length px, a.z = decay 0-1, a.w = luminance threshold
            // Bright paint is dragged one way; the trail is a weighted average (no stair-steps) laid over with lighten.
            float4 acc = s; float ws = 1.0;
            const int N = 40;
            for (int k = 1; k <= N; k++) {
                float f = float(k) / float(N);
                float4 v = float4(src.sample(s26Zero, c - p.a.xy * f));
                float m = smoothstep(p.a.w, p.a.w + 0.15, l26(u26(v)));
                float w = exp(-f * p.a.z * 5.0) * m * 1.5;
                acc += v * w; ws += w;
            }
            float4 sm = acc / ws;
            o = float4(max(s.rgb, sm.rgb), max(s.a, sm.a));
            break;
        }
        case 4: { // edge field: a = (detect width px, threshold). rg = doubled-angle gradient direction * mask, a = mask
            float2 g = sobel26(src, c, max(p.a.x, 0.5));
            float e = length(g);
            float m = smoothstep(p.a.y, p.a.y + 0.15, e);
            float2 n = g / max(e, 1e-4);
            o = float4((n.x * n.x - n.y * n.y) * m, 2.0 * n.x * n.y * m, 0.0, m);
            break;
        }
        case 5: { // edge blur: aux = blurred edge field, a = (radius px, amount). 1D blur across the edge only
            float4 f = float4(aux.sample(s26Zero, c));
            float m = f.a;
            float th = 0.5 * atan2(f.g, f.r + 1e-6);
            float2 dir = float2(cos(th), sin(th));
            float rad = max(p.a.x, 0.0);
            float4 acc = float4(0.0); float ws = 0.0;
            for (int k = -8; k <= 8; k++) {
                float fk = float(k) / 8.0;
                float w = exp(-fk * fk * 2.0);
                acc += float4(src.sample(s26Zero, c + dir * fk * rad)) * w; ws += w;
            }
            float wt = clamp(m * 1.6 * p.a.y, 0.0, 1.0);
            o = mix(s, acc / ws, wt);
            break;
        }
        case 6: { // luma mask premultiply: a = (threshold, softness), i.y = invert
            float w = smoothstep(p.a.x - p.a.y, p.a.x + p.a.y + 1e-3, l26(col));
            if (p.i.y == 1) w = 1.0 - w;
            o = s * w;
            break;
        }
        case 7: { // luma mask combine: aux = blur of the masked image, a = (threshold, softness, amount), i.y = invert
            // Only masked pixels feed the blur, so darks never smudge into the soft brights (and vice versa).
            float w = smoothstep(p.a.x - p.a.y, p.a.x + p.a.y + 1e-3, l26(col));
            if (p.i.y == 1) w = 1.0 - w;
            float4 b = float4(aux.sample(s26Zero, c));
            float3 bc = b.a > 1e-4 ? clamp(b.rgb / b.a, 0.0, 1.0) : col;
            float wt = clamp(max(w, b.a * 0.85), 0.0, 1.0) * clamp(p.a.z, 0.0, 1.0);
            o = mix(s, float4(bc * s.a, s.a), wt);
            break;
        }
        case 8: { // frosted glass: aux = softened input, a = (amount px, grain px, haze 0-1)
            float g = max(p.a.y, 0.5);
            float2 n = float2(vn26x2(c / (g * 4.0), 1.0), vn26x2(c / (g * 4.0), 2.0));
            float2 grit = float2(h26v(floor(c / g)), h26v(floor(c / g) + 19.7)) * 2.0 - 1.0;
            float2 d = (n * 0.65 + grit * 0.35) * p.a.x;
            float4 v = float4(aux.sample(s26Zero, c + d));
            float3 vc = u26(v);
            float frost = p.a.z * (0.75 + 0.25 * grit.x);
            vc = mix(vc, float3(0.92, 0.95, 1.0), frost * 0.35);
            vc = mix(float3(l26(vc)), vc, 1.0 - frost * 0.3);
            o = float4(clamp(vc, 0.0, 1.0) * v.a, v.a);
            break;
        }
        case 9: { // tilt-shift: aux / msk / ext = small / mid / full blur, a = (center px, half width px, falloff px), b = (angle, saturation)
            float2 nrm = float2(-sin(p.b.x), cos(p.b.x));
            float dist = abs(dot(c - p.a.xy, nrm));
            float m = clamp((dist - p.a.z) / max(p.a.w, 1.0), 0.0, 1.0) * 3.0;
            float4 b1 = float4(aux.sample(s26Zero, c)), b2 = float4(msk.sample(s26Zero, c)), b3 = float4(ext.sample(s26Zero, c));
            float4 r = m < 1.0 ? mix(s, b1, m) : (m < 2.0 ? mix(b1, b2, m - 1.0) : mix(b2, b3, m - 2.0));
            float3 rc = u26(r);
            rc = mix(float3(l26(rc)), rc, 1.0 + p.b.y);
            rc = mix(rc, smoothstep(0.0, 1.0, rc), p.b.y * 0.35); // a touch of contrast sells the miniature
            o = float4(clamp(rc, 0.0, 1.0) * r.a, r.a);
            break;
        }
        case 10: { // bokeh prep: a = (highlight boost, threshold). sRGB -> linear light; hot highlights carry extra energy
            float3 lc = pow(clamp(col, 0.0, 1.0), float3(2.2));
            float hot = smoothstep(p.a.y, max(p.a.y + 0.2, 1.0), l26(clamp(col, 0.0, 1.0)));
            lc *= 1.0 + p.a.x * hot * 6.0;
            o = float4(lc * s.a, s.a);
            break;
        }
        case 11: { // bokeh gather (linear src): a = (radius px, iris rotation, blades, rim 0-1). Output back in sRGB
            float rad = max(p.a.x, 0.0);
            int rings = int(clamp(ceil(rad / 5.0), 2.0, 9.0));
            float4 acc = s; float ws = 1.0;
            for (int i = 1; i <= rings; i++) {
                float rf = float(i) / float(rings);
                int n = 6 * i;
                float w = 1.0 + p.a.w * 2.5 * smoothstep(0.55, 1.0, rf);
                for (int k = 0; k < n; k++) {
                    float th = (float(k) + 0.5 * float(i & 1)) * 6.2831853 / float(n);
                    float rr = rf * rad * iris26(th, p.a.z);
                    float2 off = float2(cos(th + p.a.y), sin(th + p.a.y)) * rr;
                    acc += float4(src.sample(s26Zero, c + off)) * w; ws += w;
                }
            }
            float4 b = acc / ws;
            float3 bc = pow(max(u26(b), float3(0.0)), float3(1.0 / 2.2));
            o = float4(clamp(bc, 0.0, 1.0) * b.a, b.a);
            break;
        }
        default: break;
    }
    o.a = clamp(o.a, 0.0, 1.0);
    o.rgb = clamp(o.rgb, float3(0.0), float3(max(o.a, 0.0)));
    dst.write(half4(o), gid);
}
