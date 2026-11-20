// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_s_clamp_chroma.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsee005827e6d32
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float minChroma;
    char _m6_pad[12];
    float maxChroma;
    char _m7_pad[12];
    float saturation;
    char _m8_pad[12];
    float mixAmount;
};

struct refAM35_ee005827e6d32_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float aeLuma(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsee005827e6d32& _49, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _49.refScreen.xy;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 param_1 = src.xyz;
    float y = aeLuma(param_1);
    float3 chroma = src.xyz - float3(y);
    float mag = length(chroma);
    float target = fast::clamp(mag * _49.saturation, _49.minChroma, _49.maxChroma);
    float3 mapped = float3(y) + (chroma * (target / fast::max(mag, 9.9999997473787516355514526367188e-05)));
    referenceColor = float4(mix(src.xyz, fast::clamp(mapped, float3(0.0), float3(1.0)), float3(_49.mixAmount)), src.w);
}

fragment refAM35_ee005827e6d32_out refAM35_ee005827e6d32(constant ReferenceUniformsee005827e6d32& _49 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ee005827e6d32_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _49, referenceColor);
    bool _128 = any(isnan(referenceColor));
    bool _135;
    if (!_128)
    {
        _135 = any(isinf(referenceColor));
    }
    else
    {
        _135 = _128;
    }
    if (_135)
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

