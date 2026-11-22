// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/blend-pin-light.xml
// Original source comments and attribution:
// Setup
// Blend top, bot
// Output result
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse107ba25ead0a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
};

struct refAM35_e107ba25ead0a_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse107ba25ead0a& _35, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = gl_FragCoord.xy / _35.refScreen.xy;
    float4 compColor = texture2DCv(refReference, refReferenceSmplr, param_1);
    float3 top = texColor.xyz;
    float3 bot = compColor.xyz * texColor.w;
    float3 t = smoothstep(float3(0.5), float3(0.5), top);
    float3 result = (t * fast::max(bot, (top - float3(0.5)) * 2.0)) + ((float3(1.0) - t) * fast::min(bot, top * 2.0));
    referenceColor = float4(result, texColor.w);
}

fragment refAM35_e107ba25ead0a_out refAM35_e107ba25ead0a(constant ReferenceUniformse107ba25ead0a& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e107ba25ead0a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, refReference, refReferenceSmplr, referenceColor);
    bool _111 = any(isnan(referenceColor));
    bool _118;
    if (!_111)
    {
        _118 = any(isinf(referenceColor));
    }
    else
    {
        _118 = _111;
    }
    if (_118)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _131 = referenceColor;
    float3 _137 = fast::clamp(_131.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _137.x;
    referenceColor.y = _137.y;
    referenceColor.z = _137.z;
    out.finalColor = referenceColor;
    return out;
}

