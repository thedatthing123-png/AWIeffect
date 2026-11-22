// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/blend-linear-light.xml
// Original source comments and attribution:
// Setup
// Blend top, bot
// Output result
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse0eab7d6dffc8
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
};

struct refAM35_e0eab7d6dffc8_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse0eab7d6dffc8& _35, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = gl_FragCoord.xy / _35.refScreen.xy;
    float4 compColor = texture2DCv(refReference, refReferenceSmplr, param_1);
    float3 top = texColor.xyz;
    float3 bot = compColor.xyz * texColor.w;
    float3 t = smoothstep(float3(0.5), float3(0.5), top);
    float3 result = (t * (bot + ((top - float3(0.5)) * 2.0))) + ((float3(1.0) - t) * ((bot + (top * 2.0)) - float3(1.0)));
    referenceColor = float4(result, texColor.w);
}

fragment refAM35_e0eab7d6dffc8_out refAM35_e0eab7d6dffc8(constant ReferenceUniformse0eab7d6dffc8& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e0eab7d6dffc8_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, refReference, refReferenceSmplr, referenceColor);
    bool _113 = any(isnan(referenceColor));
    bool _120;
    if (!_113)
    {
        _120 = any(isinf(referenceColor));
    }
    else
    {
        _120 = _113;
    }
    if (_120)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _133 = referenceColor;
    float3 _139 = fast::clamp(_133.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _139.x;
    referenceColor.y = _139.y;
    referenceColor.z = _139.z;
    out.finalColor = referenceColor;
    return out;
}

