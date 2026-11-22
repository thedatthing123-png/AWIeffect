// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/copy_background.xml
// Original source comments and attribution:
// full-frame pass-through of background
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef2888d105ad3
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
};

struct refAM35_ef2888d105ad3_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsef2888d105ad3& _33, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _33.refScreen.xy;
    float2 param = uv;
    float4 bg = texture2DCv(refReference, refReferenceSmplr, param);
    referenceColor = bg;
}

fragment refAM35_ef2888d105ad3_out refAM35_ef2888d105ad3(constant ReferenceUniformsef2888d105ad3& _33 [[buffer(0)]], texture2d<float> refReference [[texture(1)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef2888d105ad3_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refReference, refReferenceSmplr, referenceColor);
    bool _57 = any(isnan(referenceColor));
    bool _64;
    if (!_57)
    {
        _64 = any(isinf(referenceColor));
    }
    else
    {
        _64 = _57;
    }
    if (_64)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _81 = referenceColor;
    float3 _87 = fast::clamp(_81.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _87.x;
    referenceColor.y = _87.y;
    referenceColor.z = _87.z;
    out.finalColor = referenceColor;
    return out;
}

