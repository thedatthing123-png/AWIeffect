// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/directional_blur-1.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9093183a3660
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float blurLength;
    char _m6_pad[12];
    float direction;
    char _m7_pad[12];
    float spread;
    char _m8_pad[12];
    float mixAmount;
};

struct refAM35_e9093183a3660_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse9093183a3660& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _33.refLayer.xy) / _33.refLayer.zw;
    float a = _33.direction * 0.01745329238474369049072265625;
    float2 d = (float2(cos(a), sin(a)) * _33.blurLength) / fast::max(_33.refLayer.zw, float2(1.0));
    float4 c = float4(0.0);
    float2 param = fast::clamp(uv - (d * 0.5), float2(0.0), float2(1.0));
    c += texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = fast::clamp(uv - (d * 0.375), float2(0.0), float2(1.0));
    c += texture2DCv(refInput, refInputSmplr, param_1);
    float2 param_2 = fast::clamp(uv - (d * 0.25), float2(0.0), float2(1.0));
    c += texture2DCv(refInput, refInputSmplr, param_2);
    float2 param_3 = fast::clamp(uv - (d * 0.125), float2(0.0), float2(1.0));
    c += texture2DCv(refInput, refInputSmplr, param_3);
    float2 param_4 = uv;
    c += texture2DCv(refInput, refInputSmplr, param_4);
    float2 param_5 = fast::clamp(uv + (d * 0.125), float2(0.0), float2(1.0));
    c += texture2DCv(refInput, refInputSmplr, param_5);
    float2 param_6 = fast::clamp(uv + (d * 0.25), float2(0.0), float2(1.0));
    c += texture2DCv(refInput, refInputSmplr, param_6);
    float2 param_7 = fast::clamp(uv + (d * 0.375), float2(0.0), float2(1.0));
    c += texture2DCv(refInput, refInputSmplr, param_7);
    float2 param_8 = fast::clamp(uv + (d * 0.5), float2(0.0), float2(1.0));
    c += texture2DCv(refInput, refInputSmplr, param_8);
    c /= float4(9.0);
    float2 param_9 = uv;
    referenceColor = mix(texture2DCv(refInput, refInputSmplr, param_9), c, float4(_33.mixAmount));
}

fragment refAM35_e9093183a3660_out refAM35_e9093183a3660(constant ReferenceUniformse9093183a3660& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9093183a3660_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
    bool _192 = any(isnan(referenceColor));
    bool _199;
    if (!_192)
    {
        _199 = any(isinf(referenceColor));
    }
    else
    {
        _199 = _192;
    }
    if (_199)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _215 = referenceColor;
    float3 _221 = fast::clamp(_215.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _221.x;
    referenceColor.y = _221.y;
    referenceColor.z = _221.z;
    out.finalColor = referenceColor;
    return out;
}

