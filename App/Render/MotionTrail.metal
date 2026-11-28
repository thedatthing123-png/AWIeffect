#include <metal_stdlib>
using namespace metal;

struct TrailVarying {
    float4 position [[position]];
    float side;
    float age;
};

struct TrailStyle {
    float4 head;
    float4 middle;
    float4 tail;
    float4 profile; // middle position, fade curve, edge softness, middle enabled
    float4 opacity; // head, tail, overall mix
};

vertex TrailVarying motionTrailVertex(constant float4 *vertices [[buffer(0)]], uint index [[vertex_id]]) {
    float4 v = vertices[index];
    return {float4(v.xy, 0, 1), v.z, v.w};
}

fragment half4 motionTrailFragment(TrailVarying v [[stage_in]], constant TrailStyle &style [[buffer(0)]]) {
    float age = saturate(v.age);
    float middle = style.profile.x;
    float4 color;
    if (style.profile.w == 0.0f) {
        color = mix(style.head, style.tail, age);
    } else if (age < middle) {
        color = mix(style.head, style.middle, age / middle);
    } else {
        color = mix(style.middle, style.tail, (age - middle) / (1.0f - middle));
    }
    float side = abs(v.side);
    float feather = clamp(max(fwidth(v.side), style.profile.z), 0.001f, 1.0f);
    float opacity = mix(style.opacity.x, style.opacity.y, pow(age, style.profile.y));
    float alpha = saturate(color.a * style.opacity.z * opacity) * (1.0f - smoothstep(1.0f - feather, 1.0f, side));
    return half4(half3(color.rgb * alpha), half(alpha));
}
