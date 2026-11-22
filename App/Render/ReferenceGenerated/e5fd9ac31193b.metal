// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/innerblur.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse5fd9ac31193b
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float iter;
};

struct refAM35_e5fd9ac31193b_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse5fd9ac31193b& _35, texture2d<float> refBuffer1, sampler refBuffer1Smplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 baseColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = gl_FragCoord.xy / _35.refScreen.xy;
    float4 compColor = texture2DCv(refBuffer1, refBuffer1Smplr, param_1);
    referenceColor = float4(compColor.xyz / float3(compColor.w), 1.0) * baseColor.w;
}

fragment refAM35_e5fd9ac31193b_out refAM35_e5fd9ac31193b(constant ReferenceUniformse5fd9ac31193b& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e5fd9ac31193b_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, refBuffer1, refBuffer1Smplr, referenceColor);
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
    float4 _102 = referenceColor;
    float3 _108 = fast::clamp(_102.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _108.x;
    referenceColor.y = _108.y;
    referenceColor.z = _108.z;
    out.finalColor = referenceColor;
    return out;
}

