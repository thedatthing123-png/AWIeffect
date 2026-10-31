#include <metal_stdlib>
using namespace metal;

constexpr sampler rsLinear(address::clamp_to_edge, filter::linear, coord::normalized);

// Bilinear resample src into dst (any size). Halving steps average 2x2 blocks, which is what the blur pyramid needs.
kernel void fxResample(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    dst.write(src.sample(rsLinear, uv), gid);
}

// Frame blending: dst = mix(a, b, w) for slowed-down footage. w in params.a.x.
struct FrameMixParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
kernel void frameMix(texture2d<half, access::sample> a [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     texture2d<half, access::sample> b [[texture(2)]],
                     constant FrameMixParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    dst.write(half4(mix(float4(a.sample(rsLinear, uv)), float4(b.sample(rsLinear, uv)), p.a.x)), gid);
}

// Effect masks: dst = mix(before effects, after effects, mask coverage).
kernel void maskMix(texture2d<half, access::sample> before [[texture(0)]],
                    texture2d<half, access::write> dst [[texture(1)]],
                    texture2d<half, access::sample> after [[texture(2)]],
                    texture2d<half, access::sample> cov [[texture(3)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    float m = clamp(float(cov.sample(rsLinear, uv).r), 0.0, 1.0);
    dst.write(half4(mix(float4(before.sample(rsLinear, uv)), float4(after.sample(rsLinear, uv)), m)), gid);
}
