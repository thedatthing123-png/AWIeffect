// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/blend-hard-light.xml
// Original source comments and attribution:
// Setup
// Blend top, bot
// Output result
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsecd9799211148
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
};

struct refAM35_ecd9799211148_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsecd9799211148& _35, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = gl_FragCoord.xy / _35.refScreen.xy;
    float4 compColor = texture2DCv(refReference, refReferenceSmplr, param_1);
    float3 top = texColor.xyz;
    float3 bot = compColor.xyz * texColor.w;
    float3 t = smoothstep(float3(0.5), float3(0.5), top);
    float3 result = (t * (float3(1.0) - ((float3(1.0) - bot) * (float3(1.0) - ((top - float3(0.5)) * 2.0))))) + ((float3(1.0) - t) * (bot * (top * 2.0)));
    referenceColor = float4(result, texColor.w);
}

fragment refAM35_ecd9799211148_out refAM35_ecd9799211148(constant ReferenceUniformsecd9799211148& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ecd9799211148_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, refReference, refReferenceSmplr, referenceColor);
    bool _117 = any(isnan(referenceColor));
    bool _124;
    if (!_117)
    {
        _124 = any(isinf(referenceColor));
    }
    else
    {
        _124 = _117;
    }
    if (_124)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _137 = referenceColor;
    float3 _143 = fast::clamp(_137.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _143.x;
    referenceColor.y = _143.y;
    referenceColor.z = _143.z;
    out.finalColor = referenceColor;
    return out;
}

