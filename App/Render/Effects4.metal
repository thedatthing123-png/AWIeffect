#include <metal_stdlib>
using namespace metal;

// Batch 4: alpha-edge light effects (outline glow, aura, rim light, inner/outer glow, stroke).
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s4Zero(address::clamp_to_zero, filter::linear, coord::pixel);

static float h4(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static float n4(float3 x) {
    float3 i = floor(x), f = fract(x); float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(h4(i), h4(i + float3(1, 0, 0)), u.x), mix(h4(i + float3(0, 1, 0)), h4(i + float3(1, 1, 0)), u.x), u.y),
               mix(mix(h4(i + float3(0, 0, 1)), h4(i + float3(1, 0, 1)), u.x), mix(h4(i + float3(0, 1, 1)), h4(i + float3(1, 1, 1)), u.x), u.y), u.z);
}

// Modes:
//  0 edge line: aux = alpha blurred by the core width. a = (intensity, sharpness, noiseScale, rise), b = color,
//    c = (noise px, time, flicker, noise speed), i.y = 0 both sides / 1 outside only / 2 inside only.
//  1 add: dst = src + aux * a.x (additive light).
//  2 color by alpha: dst = b.rgb * src.a * a.x (i.y = 1 uses 1 - alpha).
//  3 rim: src alpha minus alpha shifted by a.xy, times a.z, colored b.
//  4 mask: dst = src * aux.a (i.y = 0) or src * (1 - aux.a) (i.y = 1).
//  5 border: a.x = width px, b = color, a.y = opacity; i.y = 0 outside (dilate, under the layer),
//    1 inside (erode, over the layer), 2 centered.
kernel void fxGlow4(texture2d<half, access::sample> src [[texture(0)]],
                    texture2d<half, access::write> dst [[texture(1)]],
                    texture2d<half, access::sample> aux [[texture(2)]],
                    constant EffectParams& p [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s4Zero, c));
    float4 o = s;
    switch (p.i.x) {
        case 0: {
            float t = p.c.y;
            float sc = max(p.a.z, 1.0);
            // Flowing noise warp (energy / flame look), rising over time.
            float3 q = float3(c.x / sc, c.y / sc + t * p.a.w, t * p.c.w);
            float2 warp = float2(n4(q) - 0.5, n4(q + 17.3) - 0.5) * 2.0 * p.c.x;
            float b = float(aux.sample(s4Zero, c + warp).a);
            float line = clamp(b * (1.0 - b) * 4.0, 0.0, 1.0);
            line = pow(line, max(p.a.y, 0.05));
            float a0 = float(src.sample(s4Zero, c + warp).a);
            if (p.i.y == 1) line *= 1.0 - a0;
            if (p.i.y == 2) line *= a0;
            float fl = 1.0 - p.c.z * (0.5 + 0.5 * sin(t * 23.0 + n4(float3(c * 0.01, t * 4.0)) * 6.28));
            float v = clamp(line * p.a.x * fl, 0.0, 4.0);
            o = float4(p.b.rgb * v, min(v, 1.0));
            break;
        }
        case 1: {
            float4 l = float4(aux.sample(s4Zero, c)) * p.a.x;
            o = float4(s.rgb + l.rgb, clamp(s.a + l.a * (1.0 - s.a), 0.0, 1.0));
            break;
        }
        case 2: {
            float a = p.i.y == 1 ? 1.0 - s.a : s.a;
            o = float4(p.b.rgb * a * p.a.x, a * p.a.x);
            break;
        }
        case 3: {
            float a1 = float(src.sample(s4Zero, c - p.a.xy).a);
            float r = clamp(s.a * (1.0 - a1) * p.a.z, 0.0, 1.0);
            o = float4(p.b.rgb * r, r);
            break;
        }
        case 4: {
            float m = float(aux.sample(s4Zero, c).a);
            o = s * (p.i.y == 0 ? m : 1.0 - m);
            break;
        }
        case 6: {
            // Track matte: aux is the matte layer render. i.y: 0 alpha, 1 alpha inv, 2 luma, 3 luma inv.
            float4 m = float4(aux.sample(s4Zero, c));
            float lum = m.a > 1e-5 ? dot(m.rgb / m.a, float3(0.2126, 0.7152, 0.0722)) * m.a : 0.0;
            float k = p.i.y == 0 ? m.a : (p.i.y == 1 ? 1.0 - m.a : (p.i.y == 2 ? lum : 1.0 - lum));
            o = s * clamp(k, 0.0, 1.0);
            break;
        }
        case 5: {
            float r = max(p.a.x, 0.5);
            float mx = s.a, mn = s.a;
            for (int ring = 1; ring <= 3; ring++) {
                float rr = r * float(ring) / 3.0;
                for (int k = 0; k < 16; k++) {
                    float ang = float(k) * 0.3926991 + float(ring) * 0.2;
                    float a = float(src.sample(s4Zero, c + float2(cos(ang), sin(ang)) * rr).a);
                    mx = max(mx, a); mn = min(mn, a);
                }
            }
            float band = p.i.y == 0 ? mx * (1.0 - s.a) : (p.i.y == 1 ? s.a * (1.0 - mn) : clamp(mx - mn, 0.0, 1.0));
            band *= p.a.y;
            float4 b = float4(p.b.rgb * band, band);
            o = p.i.y == 0 ? s + b * (1.0 - s.a) : b + s * (1.0 - b.a);
            break;
        }
    }
    dst.write(half4(o), gid);
}
