#include <metal_stdlib>
using namespace metal;

struct TrailVertex {
    float4 positionAndSide;
    float4 color;
};

struct TrailVarying {
    float4 position [[position]];
    float4 color;
    float side;
};

vertex TrailVarying motionTrailVertex(constant TrailVertex *vertices [[buffer(0)]], uint index [[vertex_id]]) {
    TrailVertex v = vertices[index];
    return {float4(v.positionAndSide.xy, 0, 1), v.color, v.positionAndSide.z};
}

fragment half4 motionTrailFragment(TrailVarying v [[stage_in]]) {
    float side = abs(v.side);
    float feather = clamp(fwidth(v.side), 0.001f, 1.0f);
    float alpha = saturate(v.color.a) * (1.0f - smoothstep(1.0f - feather, 1.0f, side));
    return half4(half3(v.color.rgb * alpha), half(alpha));
}
