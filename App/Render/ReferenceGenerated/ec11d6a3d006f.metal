// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/blend-lighter-color.xml
// Original source comments and attribution:
// Setup
// Blend top, bot
// Output result
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec11d6a3d006f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
};

struct refAM35_ec11d6a3d006f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsec11d6a3d006f& _35, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = gl_FragCoord.xy / _35.refScreen.xy;
    float4 compColor = texture2DCv(refReference, refReferenceSmplr, param_1);
    float3 top = texColor.xyz;
    float3 bot = compColor.xyz * texColor.w;
    float3 result = select(bot, top, bool3(length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * top) > length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * bot)));
    referenceColor = float4(result, texColor.w);
}

fragment refAM35_ec11d6a3d006f_out refAM35_ec11d6a3d006f(constant ReferenceUniformsec11d6a3d006f& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec11d6a3d006f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, refReference, refReferenceSmplr, referenceColor);
    bool _102 = any(isnan(referenceColor));
    bool _109;
    if (!_102)
    {
        _109 = any(isinf(referenceColor));
    }
    else
    {
        _109 = _102;
    }
    if (_109)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _123 = referenceColor;
    float3 _129 = fast::clamp(_123.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _129.x;
    referenceColor.y = _129.y;
    referenceColor.z = _129.z;
    out.finalColor = referenceColor;
    return out;
}

