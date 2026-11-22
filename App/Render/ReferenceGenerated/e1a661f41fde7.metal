// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/atimeslice.xml
// Original source comments and attribution:
// Converted from provided Shadertoy snippet to Alight Motion (no Y flip)
// Rotate axis by angle
// 0..1 along rotated axis
// Shadertoy transition with adjustable count/smoothness
// Feather to match atimeslice.xml: one-sided soft edge
// Optional reverse: rev=0 -> from->to, rev=1 -> to->from
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse1a661f41fde7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float count;
    char _m6_pad[12];
    float smoothness;
    char _m7_pad[12];
    float speed;
    char _m8_pad[12];
    float angle;
    char _m9_pad[12];
    float feather;
    char _m10_pad[12];
    float reverse;
};

struct refAM35_e1a661f41fde7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 getFromColor(thread const float2& coord, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = coord;
    return texture2DCv(refInput, refInputSmplr, param);
}

static inline __attribute__((always_inline))
float4 getToColor(thread const float2& coord, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float2 param = coord;
    return texture2DCv(refReference, refReferenceSmplr, param);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse1a661f41fde7& _52, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _52.refLayer.xy) / _52.refLayer.zw;
    float progress = fract(_52.refScreen.z * _52.speed);
    float rad = _52.angle * 0.01745329238474369049072265625;
    float2 v = fast::normalize(float2(cos(rad), -sin(rad)));
    float p = dot(uv - float2(0.5), v) + 0.5;
    float pr = smoothstep(-_52.smoothness, 0.0, p - (progress * (1.0 + _52.smoothness)));
    float cell = fract(_52.count * p);
    float useFeather = step(9.9999999747524270787835121154785e-07, _52.feather);
    float sHard = step(pr, cell);
    float sSoft = smoothstep(pr, pr + _52.feather, cell);
    float s = mix(sHard, sSoft, useFeather);
    float2 param = uv;
    float4 fromCol = getFromColor(param, refInput, refInputSmplr);
    float2 param_1 = uv;
    float4 toCol = getToColor(param_1, refReference, refReferenceSmplr);
    float rev = step(0.5, _52.reverse);
    float4 f = mix(fromCol, toCol, float4(rev));
    float4 t = mix(toCol, fromCol, float4(rev));
    float4 col = mix(f, t, float4(s));
    referenceColor = col;
}

fragment refAM35_e1a661f41fde7_out refAM35_e1a661f41fde7(constant ReferenceUniformse1a661f41fde7& _52 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e1a661f41fde7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, refReference, refReferenceSmplr, gl_FragCoord, _52, referenceColor);
    bool _185 = any(isnan(referenceColor));
    bool _192;
    if (!_185)
    {
        _192 = any(isinf(referenceColor));
    }
    else
    {
        _192 = _185;
    }
    if (_192)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _207 = referenceColor;
    float3 _213 = fast::clamp(_207.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _213.x;
    referenceColor.y = _213.y;
    referenceColor.z = _213.z;
    out.finalColor = referenceColor;
    return out;
}

