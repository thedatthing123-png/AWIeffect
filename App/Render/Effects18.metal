#include <metal_stdlib>
using namespace metal;

// Batch 18: edit essentials — Twitch-style glitch bursts and a manga negative / mono flash.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler sm18(address::clamp_to_zero, filter::linear, coord::pixel);

static inline float h18(float x) { return fract(sin(x * 127.1 + 311.7) * 43758.5453); }
static inline float h182(float2 p) { return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
static inline float lum18(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

kernel void fx18(texture2d<half, access::sample> src [[texture(0)]],
                 texture2d<half, access::write> dst [[texture(1)]],
                 texture2d<half, access::sample> aux [[texture(2)]],
                 constant EffectParams& p [[buffer(0)]],
                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float t = p.d.x;
    float4 o;
    if (p.i.x == 0) {
        // Twitch: a = (intensity 0-1, bursts per second, burst length 0-1, seed)
        //         b = (rgb split px, slice px, flash 0-1, blur px)
        float slot = floor(t * max(p.a.y, 0.01));
        float phase = fract(t * max(p.a.y, 0.01));
        // Every other burst always fires (plus random extras), so the rhythm stays readable.
        bool fire = slot < 0.5 || fmod(slot, 2.0) >= 1.0 || h18(slot + p.a.w * 13.0) < 0.5;
        float on = (fire && phase < max(p.a.z, 0.02)) ? 1.0 : 0.0;
        float k = on * p.a.x * (0.5 + 0.5 * h18(slot * 3.1 + p.a.w));
        float fr = floor(t * 30.0);
        // Horizontal slice offsets.
        float band = floor(c.y / max(size.y / 18.0, 2.0));
        float sl = (h182(float2(band, fr + p.a.w)) - 0.5) * 2.0 * p.b.y * k * step(0.55, h182(float2(band * 1.7, fr)));
        float2 q = c + float2(sl, 0.0);
        // Directional jitter blur.
        float bl = p.b.w * k;
        float4 acc = float4(0.0);
        for (int s = -2; s <= 2; s++) acc += float4(src.sample(sm18, q + float2(float(s) * bl * 0.5, 0.0)));
        float4 base = acc / 5.0;
        float split = p.b.x * k;
        float r = float(src.sample(sm18, q + float2(split, 0.0)).r);
        float b = float(src.sample(sm18, q - float2(split, 0.0)).b);
        o = float4(r, base.g, b, base.a);
        o.a = max(o.a, max(float(src.sample(sm18, q + float2(split, 0.0)).a), float(src.sample(sm18, q - float2(split, 0.0)).a)));
        o.rgb = min(o.rgb + p.b.z * k * o.a, float3(o.a));
    } else {
        // Negative / mono flash: a = (flashes per second, mix 0-1, mode 0 negative 1 mono threshold 2 both, threshold)
        float4 s = float4(src.sample(sm18, c));
        float fr = floor(t * max(p.a.x, 0.01));
        float on = fmod(fr, 2.0) >= 1.0 ? 1.0 : 0.0;
        float3 col = s.a > 0.0 ? s.rgb / s.a : float3(0.0);
        float3 neg = 1.0 - col;
        float3 mono = float3(step(p.a.w, lum18(col)));
        float3 fx = p.a.z < 0.5 ? neg : (p.a.z < 1.5 ? mono : (fmod(fr, 4.0) < 2.0 ? neg : 1.0 - mono));
        col = mix(col, fx, on * p.a.y);
        o = float4(col * s.a, s.a);
    }
    dst.write(half4(o), gid);
}
