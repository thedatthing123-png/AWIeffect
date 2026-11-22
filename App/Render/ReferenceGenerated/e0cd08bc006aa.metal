// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/time_slice_mask.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse0cd08bc006aa
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

struct refAM35_e0cd08bc006aa_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse0cd08bc006aa& _20, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _20.refLayer.xy) / _20.refLayer.zw;
    float progress = fract(_20.refScreen.z * _20.speed);
    float rad = _20.angle * 0.01745329238474369049072265625;
    float2 v = fast::normalize(float2(cos(rad), -sin(rad)));
    float p = dot(uv - float2(0.5), v) + 0.5;
    float pr = smoothstep(-_20.smoothness, 0.0, p - (progress * (1.0 + _20.smoothness)));
    float cell = fract(_20.count * p);
    float useFeather = step(9.9999999747524270787835121154785e-07, _20.feather);
    float sHard = step(pr, cell);
    float sSoft = smoothstep(pr, pr + _20.feather, cell);
    float s = mix(sHard, sSoft, useFeather);
    referenceColor = float4(float3(s), s);
}

fragment refAM35_e0cd08bc006aa_out refAM35_e0cd08bc006aa(constant ReferenceUniformse0cd08bc006aa& _20 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e0cd08bc006aa_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _20, referenceColor);
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
    float4 _149 = referenceColor;
    float3 _155 = fast::clamp(_149.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _155.x;
    referenceColor.y = _155.y;
    referenceColor.z = _155.z;
    out.finalColor = referenceColor;
    return out;
}

