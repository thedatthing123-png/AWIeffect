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
