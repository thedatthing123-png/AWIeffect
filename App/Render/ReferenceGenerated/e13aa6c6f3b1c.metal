// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/difference.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse13aa6c6f3b1c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
};

struct refAM35_e13aa6c6f3b1c_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse13aa6c6f3b1c& _35, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = gl_FragCoord.xy / _35.refScreen.xy;
    float4 compColor = texture2DCv(refReference, refReferenceSmplr, param_1);
    referenceColor = float4(abs((compColor.xyz * texColor.w) - texColor.xyz), texColor.w);
}

fragment refAM35_e13aa6c6f3b1c_out refAM35_e13aa6c6f3b1c(constant ReferenceUniformse13aa6c6f3b1c& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e13aa6c6f3b1c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, refReference, refReferenceSmplr, referenceColor);
    bool _83 = any(isnan(referenceColor));
    bool _90;
    if (!_83)
    {
        _90 = any(isinf(referenceColor));
    }
    else
    {
        _90 = _83;
    }
    if (_90)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _104 = referenceColor;
    float3 _110 = fast::clamp(_104.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _110.x;
    referenceColor.y = _110.y;
    referenceColor.z = _110.z;
    out.finalColor = referenceColor;
    return out;
}

