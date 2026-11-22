// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_s_glow_dist.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse0eaef7a0da9e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float threshold;
    char _m6_pad[12];
    float radius;
    char _m7_pad[12];
    float intensity;
    float4 glowColor;
    float mixAmount;
};

struct refAM35_e0eaef7a0da9e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 aePx(constant ReferenceUniformse0eaef7a0da9e& _39)
{
    return float2(1.0) / fast::max(_39.refScreen.xy, float2(1.0));
}

static inline __attribute__((always_inline))
float aeLuma(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse0eaef7a0da9e& _39, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _39.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float2 p = aePx(_39) * _39.radius;
    float g = 0.0;
    float2 param_1 = uv + float2(p.x, 0.0);
    float3 param_2 = texture2DCv(refInput, refInputSmplr, param_1).xyz;
    g += fast::max(aeLuma(param_2) - _39.threshold, 0.0);
    float2 param_3 = uv + float2(-p.x, 0.0);
    float3 param_4 = texture2DCv(refInput, refInputSmplr, param_3).xyz;
    g += fast::max(aeLuma(param_4) - _39.threshold, 0.0);
    float2 param_5 = uv + float2(0.0, p.y);
    float3 param_6 = texture2DCv(refInput, refInputSmplr, param_5).xyz;
    g += fast::max(aeLuma(param_6) - _39.threshold, 0.0);
    float2 param_7 = uv + float2(0.0, -p.y);
    float3 param_8 = texture2DCv(refInput, refInputSmplr, param_7).xyz;
    g += fast::max(aeLuma(param_8) - _39.threshold, 0.0);
    float2 param_9 = uv + p;
    float3 param_10 = texture2DCv(refInput, refInputSmplr, param_9).xyz;
    g += fast::max(aeLuma(param_10) - _39.threshold, 0.0);
    float2 param_11 = uv - p;
    float3 param_12 = texture2DCv(refInput, refInputSmplr, param_11).xyz;
    g += fast::max(aeLuma(param_12) - _39.threshold, 0.0);
    float2 param_13 = uv + float2(p.x, -p.y);
    float3 param_14 = texture2DCv(refInput, refInputSmplr, param_13).xyz;
    g += fast::max(aeLuma(param_14) - _39.threshold, 0.0);
    float2 param_15 = uv + float2(-p.x, p.y);
    float3 param_16 = texture2DCv(refInput, refInputSmplr, param_15).xyz;
    g += fast::max(aeLuma(param_16) - _39.threshold, 0.0);
    g = fast::clamp((g * 0.125) / fast::max(1.0 - _39.threshold, 0.001000000047497451305389404296875), 0.0, 1.0);
    float3 result = src.xyz + (((_39.glowColor.xyz * _39.glowColor.w) * g) * _39.intensity);
    referenceColor = float4(mix(src.xyz, result, float3(_39.mixAmount)), src.w);
}

fragment refAM35_e0eaef7a0da9e_out refAM35_e0eaef7a0da9e(constant ReferenceUniformse0eaef7a0da9e& _39 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e0eaef7a0da9e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_39, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _269 = any(isnan(referenceColor));
    bool _276;
    if (!_269)
    {
        _276 = any(isinf(referenceColor));
    }
    else
    {
        _276 = _269;
    }
    if (_276)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _289 = referenceColor;
    float3 _295 = fast::clamp(_289.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _295.x;
    referenceColor.y = _295.y;
    referenceColor.z = _295.z;
    out.finalColor = referenceColor;
    return out;
}

