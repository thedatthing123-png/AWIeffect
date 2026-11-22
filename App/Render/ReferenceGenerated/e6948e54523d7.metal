// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/blend-luminance.xml
// Original source comments and attribution:
// Setup
// Blend top, bot
// Output result
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse6948e54523d7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
};

struct refAM35_e6948e54523d7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse6948e54523d7& _63, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float2 param = gl_FragCoord.xy / _63.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = gl_FragCoord.xy / _63.refScreen.xy;
    float4 compColor = texture2DCv(refReference, refReferenceSmplr, param_1);
    float3 top = texColor.xyz;
    float3 bot = compColor.xyz * texColor.w;
    float3 result = float3((top * rgb2yuv).x, (bot * rgb2yuv).yz) * yuv2rgb;
    referenceColor = float4(result, texColor.w);
}

fragment refAM35_e6948e54523d7_out refAM35_e6948e54523d7(constant ReferenceUniformse6948e54523d7& _63 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e6948e54523d7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _63, refReference, refReferenceSmplr, referenceColor);
    bool _126 = any(isnan(referenceColor));
    bool _133;
    if (!_126)
    {
        _133 = any(isinf(referenceColor));
    }
    else
    {
        _133 = _126;
    }
    if (_133)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _146 = referenceColor;
    float3 _152 = fast::clamp(_146.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _152.x;
    referenceColor.y = _152.y;
    referenceColor.z = _152.z;
    out.finalColor = referenceColor;
    return out;
}

