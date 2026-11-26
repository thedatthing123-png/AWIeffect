#include <metal_stdlib>
using namespace metal;

struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

kernel void fxGhostOverlay(texture2d<half, access::sample> input [[texture(0)]],
                           texture2d<half, access::write> output [[texture(1)]],
                           constant EffectParams& params [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    constexpr sampler transparentEdges(address::clamp_to_zero, filter::linear, coord::pixel);
    const float2 center = float2(input.get_width(), input.get_height()) * 0.5;
    const float2 pixel = float2(gid) + 0.5;
    const float2 offset = (pixel - center - params.b.zw) * params.a.z;
    const float2 source = center + float2(params.b.x * offset.x + params.b.y * offset.y,
                                         params.b.x * offset.y - params.b.y * offset.x);

    const float4 original = float4(input.sample(transparentEdges, pixel));
    float4 ghost = float4(input.sample(transparentEdges, source));
    // Invert premultiplied RGB without turning transparent pixels into white.
    const float3 negative = clamp(float3(ghost.a) - ghost.rgb, float3(0), float3(ghost.a));
    ghost.rgb = mix(ghost.rgb, negative, params.a.y);
    ghost *= params.a.x;
    float4 result = ghost + original * (1 - ghost.a);
    if (params.i.x != 0 && ghost.a > 0.00001 && original.a > 0.00001) {
        const float3 base = original.rgb / original.a;
        const float3 top = ghost.rgb / ghost.a;
        const float3 blended = params.i.x == 1 ? 1 - (1 - base) * (1 - top) : abs(base - top);
        result.rgb += (blended - top) * (original.a * ghost.a);
    }
    output.write(half4(result), gid);
}
