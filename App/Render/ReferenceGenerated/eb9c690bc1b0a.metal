// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/lumakey3.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb9c690bc1b0a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float lowThreshold;
    char _m6_pad[12];
    float highThreshold;
    char _m7_pad[12];
    float feather;
    char _m8_pad[12];
    uint invert;
    char _m9_pad[12];
    uint weighted;
};

struct refAM35_eb9c690bc1b0a_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseb9c690bc1b0a& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float luma = dot(texColor.xyz, select(float3(0.33329999446868896484375, 0.3334000110626220703125, 0.33329999446868896484375), float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875), bool3(_36.weighted != 0u)));
    float lowThresholdB = (_36.lowThreshold * (1.0 + _36.feather)) - 0.001000000047497451305389404296875;
    float lowThresholdA = lowThresholdB - fast::max(_36.feather, 9.9999997473787516355514526367188e-06);
    float highThresholdA = ((_36.highThreshold * (1.0 + _36.feather)) - _36.feather) + 0.001000000047497451305389404296875;
    float highThresholdB = highThresholdA + fast::max(_36.feather, 9.9999997473787516355514526367188e-06);
    float lowBlend = smoothstep(lowThresholdA, lowThresholdB, luma);
    float highBlend = 1.0 - smoothstep(highThresholdA, highThresholdB, luma);
    float alpha = fast::min(lowBlend, highBlend);
    if (_36.invert != 0u)
    {
        alpha = 1.0 - alpha;
    }
    referenceColor = texColor * alpha;
}

fragment refAM35_eb9c690bc1b0a_out refAM35_eb9c690bc1b0a(constant ReferenceUniformseb9c690bc1b0a& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb9c690bc1b0a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _141 = any(isnan(referenceColor));
    bool _148;
    if (!_141)
    {
        _148 = any(isinf(referenceColor));
    }
    else
    {
        _148 = _141;
    }
    if (_148)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    out.finalColor = referenceColor;
    return out;
}

