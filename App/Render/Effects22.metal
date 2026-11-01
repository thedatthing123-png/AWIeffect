#include <metal_stdlib>
using namespace metal;

struct EffectParams22 { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler s22(coord::pixel, address::clamp_to_edge, filter::linear);
constexpr sampler s22z(coord::pixel, address::clamp_to_zero, filter::linear);

// i.x: 0 tiny planet, 1 triangle pixelate, 2 brick pixelate, 3 diamond pixelate, 4 ink bleed, 5 wind streaks.
// tiny planet: a = (zoom, rotation rad, -, -), b = layer rect (x, y, w, h)
// triangle / brick / diamond: a.x cell px, a.y brick offset 0..1
// ink bleed: a = (spread px, darkness threshold 0..1, -, -)
// wind streaks: a = (length px, angle rad, threshold 0..1, intensity)
kernel void fx22(texture2d<half, access::sample> src [[texture(0)]],
                 texture2d<half, access::write> dst [[texture(1)]],
                 constant EffectParams22& p [[buffer(0)]],
                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 o;
    switch (p.i.x) {
        case 0: {
            // The bottom edge of the layer becomes the planet center, the top wraps into the sky.
            float4 r = p.b;
            float2 ctr = r.xy + r.zw * 0.5;
            float2 d = c - ctr;
            float rad = length(d) / (0.5 * min(r.z, r.w));
            float ang = atan2(d.y, d.x) + p.a.y;
            float u = fract(ang / 6.2831853 + 0.25);
            float v = 1.0 - saturate(atan(rad * p.a.x) / 1.5707963);
            o = float4(src.sample(s22, r.xy + float2(u, v) * r.zw));
            break;
        }
        case 1: {
            float s = max(p.a.x, 2.0);
            float h = s * 0.866;
            float row = floor(c.y / h);
            float sh = fmod(row, 2.0) == 0.0 ? 0.0 : 0.5;
            float gx = c.x / s + sh;
            float cx = floor(gx), fx = fract(gx), fy = fract(c.y / h);
            bool up = fmod(cx + row, 2.0) == 0.0;
            float edge = abs(fx * 2.0 - 1.0);
            bool lower = up ? (fy > 1.0 - edge) : (fy < edge);
            float2 cc = float2(cx + (fx < 0.5 ? 0.25 : 0.75) * (lower ? 1.0 : 0.0) + (lower ? 0.0 : 0.5) - sh, row + (lower ? 0.66 : 0.33));
            o = float4(src.sample(s22, cc * float2(s, h)));
            break;
        }
        case 2: {
            float s = max(p.a.x, 2.0);
            float2 sz = float2(s * 2.0, s);
            float row = floor(c.y / sz.y);
            float off = fmod(row, 2.0) * p.a.y * sz.x;
            float col = floor((c.x + off) / sz.x);
            float2 cc = float2((col + 0.5) * sz.x - off, (row + 0.5) * sz.y);
            float2 lc = float2(fract((c.x + off) / sz.x), fract(c.y / sz.y));
            float mortar = (lc.x < 0.04 || lc.y < 0.08) ? 0.75 : 1.0;
            o = float4(src.sample(s22, cc));
            o.rgb *= mortar;
            break;
        }
        case 3: {
            float s = max(p.a.x, 2.0) * 1.41421;
            float2 q = float2(c.x + c.y, c.y - c.x) / s;
            float2 cell = floor(q) + 0.5;
            float2 cc = float2(cell.x - cell.y, cell.x + cell.y) * s * 0.5;
            o = float4(src.sample(s22, cc));
            break;
        }
        case 4: {
            // Dark ink spreads outward into the paper.
            float4 base = float4(src.sample(s22z, c));
            float4 best = base;
            float bl = dot(base.rgb, float3(0.299, 0.587, 0.114));
            float sp = max(p.a.x, 1.0);
            for (int k = 0; k < 16; k++) {
                float a = float(k) * 0.3926991;
                for (int j = 1; j <= 3; j++) {
                    float2 q = c + float2(cos(a), sin(a)) * sp * float(j) / 3.0;
                    float4 s2 = float4(src.sample(s22z, q));
                    float l = dot(s2.rgb, float3(0.299, 0.587, 0.114));
                    if (s2.a > 0.5 && l < p.a.y && l < bl) {
                        float w = (1.0 - float(j - 1) / 3.0) * 0.6;
                        best = mix(best, s2, w); bl = mix(bl, l, w);
                    }
                }
            }
            o = best;
            break;
        }
        default: {
            // Bright pixels blow downwind in streaks.
            float4 base = float4(src.sample(s22z, c));
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            float3 acc = float3(0);
            float len = max(p.a.x, 1.0);
            for (int k = 1; k <= 24; k++) {
                float t = float(k) / 24.0;
                float4 s2 = float4(src.sample(s22z, c - dir * len * t));
                float l = dot(s2.rgb, float3(0.299, 0.587, 0.114));
                acc += s2.rgb * smoothstep(p.a.z, p.a.z + 0.1, l) * (1.0 - t);
            }
            acc *= p.a.w / 12.0;
            o = float4(base.rgb + acc, max(base.a, saturate(dot(acc, float3(0.333)))));
            break;
        }
    }
    dst.write(half4(o), gid);
}
