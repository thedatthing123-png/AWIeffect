// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_s_glint_rainbow.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse99719be0ea0e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float threshold;
    char _m6_pad[12];
    float softness;
    char _m7_pad[12];
    float _length;
    char _m8_pad[12];
    float angle;
    char _m9_pad[12];
    float rainbow;
    char _m10_pad[12];
    float brightness;
    char _m11_pad[12];
    float mixAmount;
};

struct refAM35_e99719be0ea0e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 aePx(constant ReferenceUniformse99719be0ea0e& _44)
{
    return float2(1.0) / fast::max(_44.refScreen.xy, float2(1.0));
}

static inline __attribute__((always_inline))
float aeLuma(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float3 aeHue(thread const float& h)
{
    float3 p = abs((fract(float3(h) + float3(0.0, 0.666666686534881591796875, 0.333333313465118408203125)) * 6.0) - float3(3.0));
    return fast::clamp(p - float3(1.0), float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse99719be0ea0e& _44, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _44.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float a = _44.angle * 0.01745329238474369049072265625;
    float2 dir = (float2(cos(a), sin(a)) * aePx(_44)) * _44._length;
    float peak = 0.0;
    float2 param_1 = uv - (dir * 1.0);
    float3 param_2 = texture2DCv(refInput, refInputSmplr, param_1).xyz;
    peak = fast::max(peak, aeLuma(param_2));
    float2 param_3 = uv - (dir * 0.660000026226043701171875);
    float3 param_4 = texture2DCv(refInput, refInputSmplr, param_3).xyz;
    peak = fast::max(peak, aeLuma(param_4));
    float2 param_5 = uv - (dir * 0.3300000131130218505859375);
    float3 param_6 = texture2DCv(refInput, refInputSmplr, param_5).xyz;
    peak = fast::max(peak, aeLuma(param_6));
    float2 param_7 = uv;
    float3 param_8 = texture2DCv(refInput, refInputSmplr, param_7).xyz;
    peak = fast::max(peak, aeLuma(param_8));
    float2 param_9 = uv + (dir * 0.3300000131130218505859375);
    float3 param_10 = texture2DCv(refInput, refInputSmplr, param_9).xyz;
    peak = fast::max(peak, aeLuma(param_10));
    float2 param_11 = uv + (dir * 0.660000026226043701171875);
    float3 param_12 = texture2DCv(refInput, refInputSmplr, param_11).xyz;
    peak = fast::max(peak, aeLuma(param_12));
    float2 param_13 = uv + (dir * 1.0);
    float3 param_14 = texture2DCv(refInput, refInputSmplr, param_13).xyz;
    peak = fast::max(peak, aeLuma(param_14));
    float mask = smoothstep(_44.threshold, _44.threshold + _44.softness, peak);
    float hue = fract((((uv.x * cos(a)) + (uv.y * sin(a))) * _44.rainbow) + (_44.refScreen.z * 0.02999999932944774627685546875));
    float param_15 = hue;
    float3 glint = (aeHue(param_15) * mask) * _44.brightness;
    float3 result = src.xyz + glint;
    referenceColor = float4(mix(src.xyz, result, float3(_44.mixAmount)), src.w);
}

fragment refAM35_e99719be0ea0e_out refAM35_e99719be0ea0e(constant ReferenceUniformse99719be0ea0e& _44 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e99719be0ea0e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_44, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _273 = any(isnan(referenceColor));
    bool _280;
    if (!_273)
    {
        _280 = any(isinf(referenceColor));
    }
    else
    {
        _280 = _273;
    }
    if (_280)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _293 = referenceColor;
    float3 _299 = fast::clamp(_293.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _299.x;
    referenceColor.y = _299.y;
    referenceColor.z = _299.z;
    out.finalColor = referenceColor;
    return out;
}

