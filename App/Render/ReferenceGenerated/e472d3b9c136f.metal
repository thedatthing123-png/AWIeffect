// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/rgb-gamma.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse472d3b9c136f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float redGamma;
    char _m6_pad[12];
    float greenGamma;
    char _m7_pad[12];
    float blueGamma;
};

struct refAM35_e472d3b9c136f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse472d3b9c136f& _35, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 _46 = texColor;
    float3 _63 = powr(_46.xyz, float3(1.0 / _35.redGamma, 1.0 / _35.greenGamma, 1.0 / _35.blueGamma));
    texColor.x = _63.x;
    texColor.y = _63.y;
    texColor.z = _63.z;
    referenceColor = texColor;
}

fragment refAM35_e472d3b9c136f_out refAM35_e472d3b9c136f(constant ReferenceUniformse472d3b9c136f& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e472d3b9c136f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, referenceColor);
    bool _85 = any(isnan(referenceColor));
    bool _92;
    if (!_85)
    {
        _92 = any(isinf(referenceColor));
    }
    else
    {
        _92 = _85;
    }
    if (_92)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _106 = referenceColor;
    float3 _112 = fast::clamp(_106.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _112.x;
    referenceColor.y = _112.y;
    referenceColor.z = _112.z;
    out.finalColor = referenceColor;
    return out;
}

