#include <metal_stdlib>
using namespace metal;

// Soft body mesh: the layer's pixels drawn on a deformed triangle grid (rest UV -> simulated position).
struct SoftVert { float2 pos; float2 uv; };
struct SoftVOut { float4 pos [[position]]; float2 uv; float shade; };

vertex SoftVOut softMeshVertex(uint vid [[vertex_id]],
                               constant SoftVert* v [[buffer(0)]],
                               constant float4& view [[buffer(1)]],      // xy = target size px, z = shading strength
                               constant float* shade [[buffer(2)]]) {
    SoftVOut o;
    float2 p = v[vid].pos / view.xy * 2.0 - 1.0;
    o.pos = float4(p.x, -p.y, 0, 1);
    o.uv = v[vid].uv;
    o.shade = shade[vid];
    return o;
}

fragment float4 softMeshFragment(SoftVOut in [[stage_in]], texture2d<float, access::sample> src [[texture(0)]],
                                 constant float4& view [[buffer(0)]]) {
    constexpr sampler s(address::clamp_to_zero, filter::linear);
    float4 c = src.sample(s, in.uv);
    // Squash darkens a little, stretch brightens: reads as volume (glossy jelly) without a 3D model.
    c.rgb *= clamp(1.0 + in.shade * view.z, 0.6, 1.4);
    return c;
}
