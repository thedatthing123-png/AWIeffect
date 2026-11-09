#include <metal_stdlib>
using namespace metal;

// Swift BoneMeshGPU.Vertex has the same 16-byte alignment and 48-byte stride.
struct BoneSkinVertex { float2 rest; uint4 bones; float4 weights; };
struct BoneSkinAffine { float4 x; float4 y; };
struct BoneSkinOut { float4 position [[position]]; float2 uv; float weight; };

vertex BoneSkinOut boneSkinVertex(uint vid [[vertex_id]],
                                  const device BoneSkinVertex* vertices [[buffer(0)]],
                                  constant float4& view [[buffer(1)]],
                                  constant BoneSkinAffine* palette [[buffer(2)]],
                                  constant uint4& preview [[buffer(3)]]) {
    BoneSkinVertex v = vertices[vid];
    float2 point = 0.0; float total = 0.0; float selected = 0.0;
    for (uint i = 0; i < 4; ++i) {
        float w = v.weights[i]; uint bone = v.bones[i];
        if (w <= 0.0 || bone >= uint(view.w)) continue;
        float3 p = float3(v.rest, 1.0);
        point += float2(dot(palette[bone].x.xyz, p), dot(palette[bone].y.xyz, p)) * w;
        total += w;
        if (bone == preview.x) selected += w;
    }
    point = total > 0.0 ? point / total : v.rest;
    float2 pixel = view.xy * 0.5 + point * view.z;
    float2 ndc = pixel / view.xy * 2.0 - 1.0;
    BoneSkinOut out;
    out.position = float4(ndc.x, -ndc.y, 0.0, 1.0);
    out.weight = total > 0.0 ? selected/total : 0.0;
    out.uv = (view.xy * 0.5 + v.rest * view.z) / view.xy;
    return out;
}

fragment half4 boneSkinFragment(BoneSkinOut in [[stage_in]], texture2d<half> image [[texture(0)]],
                                constant uint4& preview [[buffer(0)]]) {
    constexpr sampler s(address::clamp_to_zero, filter::linear);
    half4 c = image.sample(s, in.uv);
    if (preview.y != 0u) {
        float hue = (1.0-clamp(in.weight,0.0,1.0))*2.0/3.0;
        float3 p = abs(fract(hue+float3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0);
        float3 heat = clamp(p-1.0,0.0,1.0);
        c.rgb = half3(mix(float3(c.rgb),heat*float(c.a),0.65));
    }
    return c;
}
