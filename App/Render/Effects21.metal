#include <metal_stdlib>
using namespace metal;

struct EffectParams21 { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler s21(coord::pixel, address::clamp_to_edge, filter::linear);
constexpr sampler s21z(coord::pixel, address::clamp_to_zero, filter::linear);

static float h21(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
static float2 h22(float2 p) { return float2(h21(p), h21(p + float2(17.3, 9.1))); }
static float n21(float2 p) {
    float2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + float2(1, 0)), u.x), mix(h21(i + float2(0, 1)), h21(i + float2(1, 1)), u.x), u.y);
}

// i.x: 0 liquid glass, 1 water droplets, 2 puddle reflection, 3 water waves.
// liquid glass: a = (refraction px, blob scale px, speed, edge highlight), b.x time
// droplets: a = (drop size px, density 0..1, refraction px, highlight), b.x seed
// puddle: a = (horizon y px, ripple px, ripple scale px, darkness 0..1), b = (time, speed, -, -)
// water waves: a = (amplitude px, wavelength px, speed, choppiness), b.x time, b.y angle rad
kernel void fx21(texture2d<half, access::sample> src [[texture(0)]],
                 texture2d<half, access::write> dst [[texture(1)]],
                 constant EffectParams21& p [[buffer(0)]],
                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 o;
    switch (p.i.x) {
        case 0: {
            // Height field of soft moving blobs -> its slope bends the image like thick glass, edges catch light.
            float sc = max(p.a.y, 4.0), t = p.b.x * p.a.z;
            float2 q = c / sc;
            float hC = n21(q + t) + 0.5 * n21(q * 2.1 - t * 0.7);
            float hx = n21(q + float2(0.02, 0) + t) + 0.5 * n21((q + float2(0.02, 0)) * 2.1 - t * 0.7);
            float hy = n21(q + float2(0, 0.02) + t) + 0.5 * n21((q + float2(0, 0.02)) * 2.1 - t * 0.7);
            float2 g = float2(hx - hC, hy - hC) / 0.02;
            o = float4(src.sample(s21z, c + g * p.a.x));
            float rim = saturate(length(g) * 0.25) * p.a.w;
            o.rgb += rim * o.a;
            break;
        }
        case 1: {
            // Drops on a cell grid: inside a drop the image is seen magnified and flipped (lens), with a rim and glint.
            float cell = max(p.a.x * 2.2, 6.0);
            float2 id = floor(c / cell);
            float2 best = float2(0); float bestD = 1e9, bestR = 0;
            for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
                float2 k = id + float2(x, y);
                float2 r = h22(k + p.b.x);
                if (r.x > p.a.y) continue;
                float rad = p.a.x * (0.45 + 0.55 * r.y);
                float2 ctr = (k + 0.2 + 0.6 * h22(k * 1.7 + p.b.x)) * cell;
                float d = length(c - ctr) / rad;
                if (d < bestD) { bestD = d; best = ctr; bestR = rad; }
            }
            if (bestD < 1.0) {
                float2 dv = (c - best) / bestR;
                float z = sqrt(max(0.0, 1.0 - dot(dv, dv)));
                float2 q = best - dv * bestR * 0.6 + dv * (1.0 - z) * p.a.z;
                o = float4(src.sample(s21z, q));
                float glint = pow(saturate(dot(normalize(float3(dv, z)), normalize(float3(-0.4, -0.5, 0.8)))), 24.0) * p.a.w;
                float rim = smoothstep(0.75, 1.0, bestD) * 0.35;
                o.rgb = o.rgb * (1.0 - rim) + glint * max(o.a, 0.5);
                o.a = max(o.a, glint);
            } else {
                o = float4(src.sample(s21z, c));
            }
            break;
        }
        case 2: {
            // Below the horizon: a mirrored copy, rippled and darkened (wet street / lake reflection).
            float hz = p.a.x;
            if (c.y <= hz) { o = float4(src.sample(s21z, c)); break; }
            float dy = c.y - hz;
            float t = p.b.x * p.b.y;
            float wob = (n21(float2(c.x / max(p.a.z, 2.0), dy / max(p.a.z, 2.0) * 3.0 + t)) - 0.5) * 2.0 * p.a.y * saturate(dy / 40.0);
            float2 q = float2(c.x + wob, hz - dy);
            float4 r = float4(src.sample(s21z, q));
            float fade = 1.0 - saturate(dy / max(size.y - hz, 1.0)) * 0.6;
            r.rgb *= (1.0 - p.a.w) * fade;
            r.a *= fade;
            float4 base = float4(src.sample(s21z, c));
            o = base + r * (1.0 - base.a);
            break;
        }
        default: {
            // Gerstner-style water: points move in circles, crests sharpen with choppiness.
            float2 dir = float2(cos(p.b.y), sin(p.b.y));
            float k = 6.2831853 / max(p.a.y, 2.0);
            float ph = dot(c, dir) * k - p.b.x * p.a.z * 6.2831853;
            float ph2 = dot(c, float2(-dir.y, dir.x)) * k * 0.63 + p.b.x * p.a.z * 4.1;
            float2 disp = dir * (sin(ph) * p.a.w) * p.a.x + float2(0, cos(ph) * p.a.x + sin(ph2) * p.a.x * 0.35);
            o = float4(src.sample(s21, c + disp));
            break;
        }
    }
    dst.write(half4(o), gid);
}
