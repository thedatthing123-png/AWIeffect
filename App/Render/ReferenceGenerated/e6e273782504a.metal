// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/3drop shadow.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse6e273782504a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 shadowColor;
    float shadowAlpha;
    char _m7_pad[12];
    float direction;
    char _m8_pad[12];
    float _distance;
    char _m9_pad[12];
    float softness;
    char _m10_pad[12];
    uint shadowOnly;
};

struct refAM35_e6e273782504a_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse6e273782504a& _34, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _34.refLayer.xy) / _34.refLayer.zw;
    float a = _34.direction * 0.01745329238474369049072265625;
    float2 off = (float2(cos(a), -sin(a)) * _34._distance) / fast::max(_34.refLayer.zw, float2(1.0));
    float2 p = uv - off;
    float2 b = float2(_34.softness) / fast::max(_34.refLayer.zw, float2(1.0));
    float al = 0.0;
    float2 param = fast::clamp(p + float2(-b.x, -b.y), float2(0.0), float2(1.0));
    al += texture2DCv(refInput, refInputSmplr, param).w;
    float2 param_1 = fast::clamp(p + float2(0.0, -b.y), float2(0.0), float2(1.0));
    al += texture2DCv(refInput, refInputSmplr, param_1).w;
    float2 param_2 = fast::clamp(p + float2(b.x, -b.y), float2(0.0), float2(1.0));
    al += texture2DCv(refInput, refInputSmplr, param_2).w;
    float2 param_3 = fast::clamp(p + float2(-b.x, 0.0), float2(0.0), float2(1.0));
    al += texture2DCv(refInput, refInputSmplr, param_3).w;
    float2 param_4 = p;
    al += (texture2DCv(refInput, refInputSmplr, param_4).w * 2.0);
    float2 param_5 = fast::clamp(p + float2(b.x, 0.0), float2(0.0), float2(1.0));
    al += texture2DCv(refInput, refInputSmplr, param_5).w;
    float2 param_6 = fast::clamp(p + float2(-b.x, b.y), float2(0.0), float2(1.0));
    al += texture2DCv(refInput, refInputSmplr, param_6).w;
    float2 param_7 = fast::clamp(p + float2(0.0, b.y), float2(0.0), float2(1.0));
    al += texture2DCv(refInput, refInputSmplr, param_7).w;
    float2 param_8 = fast::clamp(p + float2(b.x, b.y), float2(0.0), float2(1.0));
    al += texture2DCv(refInput, refInputSmplr, param_8).w;
    al = fast::clamp((al / 10.0) * _34.shadowAlpha, 0.0, 1.0);
    float4 sh = float4(_34.shadowColor.xyz, al);
    float2 param_9 = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param_9);
    float4 _250;
    if (_34.shadowOnly != 0u)
    {
        _250 = sh;
    }
    else
    {
        _250 = src + (sh * (1.0 - src.w));
    }
    referenceColor = _250;
}

fragment refAM35_e6e273782504a_out refAM35_e6e273782504a(constant ReferenceUniformse6e273782504a& _34 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e6e273782504a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _34, refInput, refInputSmplr, referenceColor);
    bool _268 = any(isnan(referenceColor));
    bool _275;
    if (!_268)
    {
        _275 = any(isinf(referenceColor));
    }
    else
    {
        _275 = _268;
    }
    if (_275)
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

