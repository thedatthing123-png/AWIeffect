#include <metal_stdlib>
using namespace metal;

struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

kernel void fxEdgeCurrent(texture2d<half, access::sample> input [[texture(0)]],
                          texture2d<half, access::write> output [[texture(1)]],
                          constant EffectParams& p [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    constexpr sampler sampleEdge(coord::normalized, address::clamp_to_zero, filter::linear);
    const float2 size = float2(input.get_width(), input.get_height());
    const float2 pixel = float2(gid) + 0.5;
    const float4 src = float4(input.sample(sampleEdge, pixel / size));
    const float2 relative = pixel - p.a.xy;
    const float bearing = atan2(relative.y, relative.x) / 6.28318530718;
    const float distance = abs(fract(bearing - p.a.z + 0.5) - 0.5);
    if (distance >= p.a.w) {
        output.write(half4(src), gid);
        return;
    }

    const float2 radius = max(0.5, p.b.x) / size;
    const float2 uv = pixel / size;
    const float2 directions[] = {
        float2(1, 0), float2(0, 1), float2(-1, 0), float2(0, -1),
        float2(0.7071, 0.7071), float2(-0.7071, 0.7071),
        float2(-0.7071, -0.7071), float2(0.7071, -0.7071)
    };
    float low = src.a;
    float high = src.a;
    for (uint index = 0; index < 8; ++index) {
        const float alpha = float(input.sample(sampleEdge, uv + radius * directions[index]).a);
        low = min(low, alpha);
        high = max(high, alpha);
    }
    const float arc = 1 - smoothstep(0.08 * p.a.w, p.a.w, distance);
    const float intensity = p.b.y * arc * p.c.a;
    const float outer = saturate((high - src.a) * intensity * 0.65) * (1 - src.a);
    const float inner = saturate((src.a - low) * intensity);
    const float3 lit = src.rgb + (src.a - min(src.rgb, src.a)) * saturate(p.c.rgb * inner);
    output.write(half4(float4(lit + p.c.rgb * outer, src.a + outer)), gid);
}

kernel void fxSyncRoll(texture2d<half, access::sample> input [[texture(0)]],
                       texture2d<half, access::write> output [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    constexpr sampler sampleFrame(coord::normalized, address::clamp_to_zero, filter::linear);
    const float2 size = float2(input.get_width(), input.get_height());
    const float2 pixel = float2(gid) + 0.5;
    const float4 src = float4(input.sample(sampleFrame, pixel / size));
    const float2 frameSize = max(p.a.zw, float2(1));
    const float2 local = (pixel - p.a.xy) / frameSize;
    if (any(local < 0) || any(local >= 1)) {
        output.write(half4(src), gid);
        return;
    }

    const float y = fract(local.y - p.b.x);
    const float seam = p.b.y > 0 ? 1 - smoothstep(0.0, p.b.y, min(y, 1 - y)) : 0;
    const float2 samplePixel = p.a.xy + float2(local.x * frameSize.x + p.c.x * seam, y * frameSize.y);
    const float2 sampleLocal = (samplePixel - p.a.xy) / frameSize;
    float4 rolled = 0;
    if (sampleLocal.x >= 0 && sampleLocal.x < 1) {
        const float2 safePixel = clamp(samplePixel, p.a.xy + 0.5, p.a.xy + frameSize - 0.5);
        rolled = float4(input.sample(sampleFrame, safePixel / size));
        rolled.rgb *= 1 - seam * p.b.z;
    }
    output.write(half4(mix(src, rolled, p.b.w)), gid);
}
