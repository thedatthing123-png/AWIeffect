#include <metal_stdlib>
using namespace metal;

// Batch 5: editor-community looks — chromatic aberration, god rays, light leaks, old film, halation, gradient map,
// cinematic bars, bokeh lens blur, chromatic zoom blur, flicker, hue cycle, ink sketch, retro dither.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s5Zero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler s5Edge(address::clamp_to_edge, filter::linear, coord::pixel);

static inline float3 u5(float4 c) { return c.a > 1e-6 ? c.rgb / c.a : float3(0.0); }
static inline float l5(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float h5(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float h53(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static float n5(float3 x) {
    float3 i = floor(x), f = fract(x); float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(h53(i), h53(i + float3(1, 0, 0)), u.x), mix(h53(i + float3(0, 1, 0)), h53(i + float3(1, 1, 0)), u.x), u.y),
               mix(mix(h53(i + float3(0, 0, 1)), h53(i + float3(1, 0, 1)), u.x), mix(h53(i + float3(0, 1, 1)), h53(i + float3(1, 1, 1)), u.x), u.y), u.z);
}
static float3 hueRot(float3 c, float a) {
    float3 k = float3(0.57735);
    float ca = cos(a);
    return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

kernel void fxLook5(texture2d<half, access::sample> src [[texture(0)]],
                    texture2d<half, access::write> dst [[texture(1)]],
                    texture2d<half, access::sample> aux [[texture(2)]],
                    constant EffectParams& p [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s5Zero, c));
    float4 o = s;
    float t = p.d.x;
    switch (p.i.x) {
        case 0: { // chromatic aberration: a = (amount px, cx, cy, falloff)
            float2 d = c - p.a.yz;
            float r = length(d) / max(length(size) * 0.5, 1.0);
            float2 dir = d / max(length(d), 1e-3);
            float k = p.a.x * pow(r, max(p.a.w, 0.01));
            float4 cr = float4(src.sample(s5Zero, c + dir * k));
            float4 cb = float4(src.sample(s5Zero, c - dir * k));
            o = float4(cr.r, s.g, cb.b, max(max(cr.a, cb.a), s.a));
            break;
        }
        case 1: { // god rays: a = (cx, cy, length 0-1, intensity), b = color, c.x = threshold
            float2 toC = p.a.xy - c;
            float3 acc = float3(0.0);
            const int N = 40;
            for (int k = 0; k < N; k++) {
                float f = float(k) / float(N) * p.a.z;
                float4 q = float4(src.sample(s5Zero, c + toC * f));
                float3 col = u5(q);
                float b = max(l5(col) - p.c.x, 0.0) / max(1.0 - p.c.x, 1e-3);
                acc += col * b * q.a * (1.0 - float(k) / float(N));
            }
            float3 rays = acc / float(N) * p.a.w * p.b.rgb * 2.0;
            o = float4(s.rgb + rays, max(s.a, clamp(l5(rays), 0.0, 1.0)));
            break;
        }
        case 2: { // light leak: a = (intensity, speed, scale px, hue rad), c.x = seed
            float3 q = float3(c / max(p.a.z, 1.0), t * p.a.y * 0.3 + p.c.x * 7.1);
            float m = smoothstep(0.35, 0.95, n5(q) * 0.65 + n5(q * 2.1 + 3.0) * 0.35);
            float side = smoothstep(0.2, 1.0, 1.0 - c.x / size.x + 0.3 * sin(t * p.a.y + p.c.x));
            float3 warm = hueRot(float3(1.0, 0.45, 0.12), p.a.w);
            float3 leak = warm * m * side * p.a.x;
            float3 base = s.rgb;
            o = float4(1.0 - (1.0 - base) * (1.0 - clamp(leak, 0.0, 1.0)), max(s.a, clamp(l5(leak), 0.0, 1.0)));
            break;
        }
        case 3: { // old film: a = (grain, scratches, dust, flicker), b.x = sepia, c.x = seed
            float3 col = u5(s);
            float frame = floor(t * 24.0) + p.c.x * 13.0;
            col *= 1.0 - p.a.w * 0.5 * h5(float2(frame, 3.1));
            float g = (h5(c + frame * 17.0) - 0.5) * p.a.x;
            col += g;
            for (int k = 0; k < 4; k++) {
                float on = step(1.0 - p.a.y, h5(float2(frame, float(k) * 7.3)));
                float x = h5(float2(frame * 1.7, float(k))) * size.x;
                col = mix(col, float3(0.92), on * (1.0 - smoothstep(0.0, 1.6, abs(c.x - x))) * 0.8);
            }
            float cs = max(size.x, size.y) / 16.0;
            float2 cell = floor(c / cs);
            float dust = step(1.0 - p.a.z * 0.15, h5(cell + frame * 3.3));
            float2 dc = (cell + 0.5) * cs + (float2(h5(cell + frame), h5(cell - frame)) - 0.5) * cs * 0.6;
            float dr = max(cs * 0.12, 1.0);
            col = mix(col, float3(0.05), dust * (1.0 - smoothstep(dr * 0.5, dr, length(c - dc))));
            float lum = l5(col);
            col = mix(col, float3(lum * 1.07, lum * 0.92, lum * 0.72), p.b.x);
            o = float4(clamp(col, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 4: { // halation highlight pass: a.x = threshold, b = tint
            float3 col = u5(s);
            float b = max(l5(col) - p.a.x, 0.0) / max(1.0 - p.a.x, 1e-3);
            o = float4(p.b.rgb * b * s.a, b * s.a);
            break;
        }
        case 5: { // add aux * a.x
            float4 l = float4(aux.sample(s5Zero, c)) * p.a.x;
            o = float4(s.rgb + l.rgb, clamp(s.a + l.a * (1.0 - s.a), 0.0, 1.0));
            break;
        }
        case 6: { // gradient map: b = shadows color, c = highlights color, a.x = mix, a.y = contrast
            float lum = clamp((l5(u5(s)) - 0.5) * p.a.y + 0.5, 0.0, 1.0);
            float3 g = mix(p.b.rgb, p.c.rgb, lum);
            o = float4(mix(u5(s), g, p.a.x) * s.a, s.a);
            break;
        }
        case 7: { // cinematic bars: a = (aspect, softness px, offset px, opacity), b = color
            float h = size.x / max(p.a.x, 0.1);
            float bar = max((size.y - h) * 0.5, 0.0);
            float y = c.y - p.a.z;
            float m = max(1.0 - smoothstep(bar - p.a.y, bar + 0.5, y), smoothstep(size.y - bar - 0.5, size.y - bar + p.a.y, y)) * p.a.w;
            o = mix(s, float4(p.b.rgb, 1.0), m);
            break;
        }
        case 8: { // lens blur (bokeh): a = (radius px, highlight boost, blade rotation, 0)
            float4 acc = float4(0.0); float wsum = 0.0;
            const int N = 64;
            for (int k = 0; k < N; k++) {
                float fk = float(k) + 0.5;
                float rr = sqrt(fk / float(N)) * p.a.x;
                float ang = fk * 2.39996 + p.a.z;
                float4 q = float4(src.sample(s5Edge, c + float2(cos(ang), sin(ang)) * rr));
                float w = 1.0 + p.a.y * pow(l5(u5(q)), 4.0) * 8.0;
                acc += q * w; wsum += w;
            }
            o = acc / wsum;
            break;
        }
        case 9: { // chromatic zoom blur: a = (cx, cy, amount 0-1, spread)
            float2 d = c - p.a.xy;
            float3 acc = float3(0.0); float aa = 0.0;
            const int N = 24;
            for (int k = 0; k < N; k++) {
                float f = float(k) / float(N - 1) * p.a.z;
                float4 qr = float4(src.sample(s5Zero, p.a.xy + d * (1.0 - f * (1.0 + p.a.w))));
                float4 qg = float4(src.sample(s5Zero, p.a.xy + d * (1.0 - f)));
                float4 qb = float4(src.sample(s5Zero, p.a.xy + d * (1.0 - f * (1.0 - p.a.w))));
                acc += float3(qr.r, qg.g, qb.b); aa += max(qr.a, max(qg.a, qb.a));
            }
            o = float4(acc / float(N), aa / float(N));
            break;
        }
        case 10: { // flicker: a = (amount, frequency, smoothness, seed)
            float x = t * p.a.y + p.a.w * 11.0;
            float r = mix(h5(float2(floor(x), p.a.w)), n5(float3(x, p.a.w, 0.0)), p.a.z);
            float k = 1.0 - p.a.x * r + p.a.x * 0.3 * (1.0 - p.a.z);
            o = float4(clamp(s.rgb * k, 0.0, 4.0), s.a);
            break;
        }
        case 11: { // hue cycle: a = (speed deg/s, offset deg, spread deg/px*1000, 0)
            float ang = (t * p.a.x + p.a.y + (c.x + c.y) * p.a.z * 0.001) * 3.14159265 / 180.0;
            o = float4(clamp(hueRot(u5(s), ang), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 12: { // ink sketch: a = (strength, threshold, paper mix, line width px)
            float w = max(p.a.w, 0.5);
            float tl = l5(u5(float4(src.sample(s5Edge, c + float2(-w, -w))))), tr = l5(u5(float4(src.sample(s5Edge, c + float2(w, -w)))));
            float bl = l5(u5(float4(src.sample(s5Edge, c + float2(-w, w))))), br = l5(u5(float4(src.sample(s5Edge, c + float2(w, w)))));
            float l = l5(u5(float4(src.sample(s5Edge, c + float2(-w, 0))))), r = l5(u5(float4(src.sample(s5Edge, c + float2(w, 0)))));
            float u = l5(u5(float4(src.sample(s5Edge, c + float2(0, -w))))), d = l5(u5(float4(src.sample(s5Edge, c + float2(0, w)))));
            float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl), gy = (bl + 2.0 * d + br) - (tl + 2.0 * u + tr);
            float e = smoothstep(p.a.y, p.a.y + 0.25, length(float2(gx, gy))) * p.a.x;
            float3 base = mix(u5(s), float3(0.97, 0.95, 0.9), p.a.z);
            o = float4(base * (1.0 - e) * s.a, s.a);
            break;
        }
        case 13: { // retro dither: a = (pixel size, levels, palette mix, 0)
            float ps = max(p.a.x, 1.0);
            float2 cc = (floor(c / ps) + 0.5) * ps;
            float4 q = float4(src.sample(s5Edge, cc));
            const float bayer[16] = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };
            int2 bi = int2(floor(c / ps)) & 3;
            float th = (bayer[bi.y * 4 + bi.x] + 0.5) / 16.0 - 0.5;
            float lv = max(p.a.y - 1.0, 1.0);
            float3 col = floor(u5(q) * lv + th + 0.5) / lv;
            float g = floor(l5(u5(q)) * lv + th + 0.5) / lv;
            float3 gb = mix(float3(0.06, 0.22, 0.06), float3(0.61, 0.74, 0.06), g);
            o = float4(clamp(mix(col, gb, p.a.z), 0.0, 1.0) * q.a, q.a);
            break;
        }
    }
    dst.write(half4(o), gid);
}
