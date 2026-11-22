// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/magnify-background.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsece8ee8d914b3
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float scale;
    char _m6_pad[12];
    uint scaleMask;
    char _m7_pad[12];
    int ref_sample;
};

struct refAM35_ece8ee8d914b3_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformsece8ee8d914b3& _40)
{
    return (float4(v, 0.0, 1.0) * _40.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsece8ee8d914b3& _40, thread float4& gl_FragCoord, texture2d<float> refReference, sampler refReferenceSmplr, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st = (gl_FragCoord.xy - _40.refLayer.xy) / _40.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_40.refLayer.z / _40.refLayer.w);
    st /= float2(_40.scale);
    st.x /= (_40.refLayer.z / _40.refLayer.w);
    st += float2(0.5);
    float2 param = st;
    float2 sampleCoord = l2s(param, _40);
    if (_40.ref_sample == 0)
    {
        sampleCoord *= _40.refScreen.xy;
        sampleCoord = floor(sampleCoord) + float2(0.5);
        sampleCoord /= _40.refScreen.xy;
    }
    float2 param_1 = sampleCoord;
    float4 scaledTexColor = texture2DCv(refReference, refReferenceSmplr, param_1);
    if (_40.scaleMask != 0u)
    {
        float2 param_2 = sampleCoord;
        float4 baseColor = texture2DCv(refInput, refInputSmplr, param_2);
        referenceColor = scaledTexColor * baseColor.w;
    }
    else
    {
        float2 param_3 = gl_FragCoord.xy / _40.refScreen.xy;
        float4 baseColor_1 = texture2DCv(refInput, refInputSmplr, param_3);
        referenceColor = scaledTexColor * baseColor_1.w;
    }
}

fragment refAM35_ece8ee8d914b3_out refAM35_ece8ee8d914b3(constant ReferenceUniformsece8ee8d914b3& _40 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ece8ee8d914b3_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_40, gl_FragCoord, refReference, refReferenceSmplr, refInput, refInputSmplr, referenceColor);
    bool _170 = any(isnan(referenceColor));
    bool _177;
    if (!_170)
    {
        _177 = any(isinf(referenceColor));
    }
    else
    {
        _177 = _170;
    }
    if (_177)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _191 = referenceColor;
    float3 _197 = fast::clamp(_191.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _197.x;
    referenceColor.y = _197.y;
    referenceColor.z = _197.z;
    out.finalColor = referenceColor;
    return out;
}

