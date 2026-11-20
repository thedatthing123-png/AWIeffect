#include <metal_stdlib>
using namespace metal;
vertex float4 referenceVertexAM35(uint index [[vertex_id]]) {
    const float2 positions[3] = {float2(-1., -1.), float2(3., -1.), float2(-1., 3.)};
    return float4(positions[index], 0., 1.);
}
