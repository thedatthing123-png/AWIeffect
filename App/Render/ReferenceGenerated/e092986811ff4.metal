// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/blend-color-multiply.xml
// Original source comments and attribution:
// Setup
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse092986811ff4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
};

struct refAM35_e092986811ff4_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse092986811ff4& _35, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = gl_FragCoord.xy / _35.refScreen.xy;
    float4 compColor = texture2DCv(refReference, refReferenceSmplr, param_1);
    float4 backgrnd = (float4(1.0) * (1.0 - compColor.w)) + (compColor * compColor.w);
    referenceColor = texColor * backgrnd;
}

fragment refAM35_e092986811ff4_out refAM35_e092986811ff4(constant ReferenceUniformse092986811ff4& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e092986811ff4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, refReference, refReferenceSmplr, referenceColor);
    bool _82 = any(isnan(referenceColor));
    bool _89;
    if (!_82)
    {
        _89 = any(isinf(referenceColor));
    }
    else
    {
        _89 = _82;
    }
    if (_89)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _103 = referenceColor;
    float3 _109 = fast::clamp(_103.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _109.x;
    referenceColor.y = _109.y;
    referenceColor.z = _109.z;
    out.finalColor = referenceColor;
    return out;
}

