// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/circularripple2.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea0f52d685790
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 centerPoint;
    char _m6_pad[8];
    float frequency;
    char _m7_pad[12];
    float strength;
    char _m8_pad[12];
    float phase;
    char _m9_pad[12];
    float radius;
    char _m10_pad[12];
    float feather;
};

struct refAM35_ea0f52d685790_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsea0f52d685790& _33, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 st = gl_FragCoord.xy / _33.refScreen.xy;
    float2 center = (_33.centerPoint / float2(1000.0)) * float2(-1.0, 1.0);
    float featherSize = (_33.radius * 0.5) * _33.feather;
    float innerRadius = fast::max(0.0, _33.radius - featherSize);
    float outerRadius = fast::max(innerRadius + 9.9999997473787516355514526367188e-06, _33.radius + featherSize);
    st -= ((float2(_33.refLayer.x + (_33.refLayer.z * 0.5), (_33.refScreen.y - _33.refLayer.y) - (_33.refLayer.w * 0.5)) / _33.refScreen.xy) - center);
    st.y *= (_33.refScreen.y / _33.refScreen.x);
    float dist = length(st);
    float damping = smoothstep(outerRadius, innerRadius, dist);
    float2 offset = (fast::normalize(st) * ((sin((((dist * _33.frequency) * 3.141590118408203125) * 2.0) + ((_33.phase * 3.141590118408203125) * 2.0)) * _33.strength) / 2.0)) * damping;
    st += offset;
    st.y /= (_33.refScreen.y / _33.refScreen.x);
    st += ((float2(_33.refLayer.x + (_33.refLayer.z * 0.5), (_33.refScreen.y - _33.refLayer.y) - (_33.refLayer.w * 0.5)) / _33.refScreen.xy) - center);
    float2 param = st;
    referenceColor = texture2DCv(refInput, refInputSmplr, param);
}

fragment refAM35_ea0f52d685790_out refAM35_ea0f52d685790(constant ReferenceUniformsea0f52d685790& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea0f52d685790_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, referenceColor, refInput, refInputSmplr);
    bool _203 = any(isnan(referenceColor));
    bool _210;
    if (!_203)
    {
        _210 = any(isinf(referenceColor));
    }
    else
    {
        _210 = _203;
    }
    if (_210)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    out.finalColor = referenceColor;
    return out;
}

