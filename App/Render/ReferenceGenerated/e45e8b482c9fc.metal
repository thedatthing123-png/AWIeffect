// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/threshold.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse45e8b482c9fc
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float threshold;
    char _m6_pad[12];
    float feather;
    char _m7_pad[12];
    uint invert;
    char _m8_pad[12];
    int blendMode;
};

struct refAM35_e45e8b482c9fc_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse45e8b482c9fc& _37, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _37.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float luminance = dot(texColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float f = fast::max(fast::min(_37.feather / 4.0, abs(0.5 - _37.threshold)), 0.00196000002324581146240234375);
    float t = ((_37.threshold - 0.5) * (1.0030000209808349609375 + (f * 2.0))) + 0.5;
    float p = smoothstep(t - f, t + f, luminance);
    if (_37.invert != 0u)
    {
        p = 1.0 - p;
    }
    float3 rgb;
    if (_37.blendMode == 1)
    {
        rgb = texColor.xyz * p;
    }
    else
    {
        if (_37.blendMode == 2)
        {
            rgb = float3(1.0) - ((float3(1.0) - texColor.xyz) * (1.0 - p));
        }
        else
        {
            rgb = float3(p);
        }
    }
    referenceColor = float4(rgb, texColor.w);
}

fragment refAM35_e45e8b482c9fc_out refAM35_e45e8b482c9fc(constant ReferenceUniformse45e8b482c9fc& _37 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e45e8b482c9fc_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _37, referenceColor);
    bool _153 = any(isnan(referenceColor));
    bool _160;
    if (!_153)
    {
        _160 = any(isinf(referenceColor));
    }
    else
    {
        _160 = _153;
    }
    if (_160)
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

