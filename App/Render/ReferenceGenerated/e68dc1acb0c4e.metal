// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_s_duotone.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse68dc1acb0c4e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 shadowColor;
    float4 highlightColor;
    float balance;
    char _m8_pad[12];
    float contrast;
    char _m9_pad[12];
    float mixAmount;
};

struct refAM35_e68dc1acb0c4e_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse68dc1acb0c4e& _49, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _49.refScreen.xy;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 param_1 = src.xyz;
    float y = aeLuma(param_1);
    float t = fast::clamp(((y - _49.balance) * _49.contrast) + 0.5, 0.0, 1.0);
    float3 mapped = mix(_49.shadowColor.xyz, _49.highlightColor.xyz, float3(t));
    float alphaScale = mix(_49.shadowColor.w, _49.highlightColor.w, t);
    referenceColor = float4(mix(src.xyz, mapped * alphaScale, float3(_49.mixAmount)), src.w);
}

fragment refAM35_e68dc1acb0c4e_out refAM35_e68dc1acb0c4e(constant ReferenceUniformse68dc1acb0c4e& _49 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e68dc1acb0c4e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _49, referenceColor);
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
    out.finalColor = referenceColor;
    return out;
}

