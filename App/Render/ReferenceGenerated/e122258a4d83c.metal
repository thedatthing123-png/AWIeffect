// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxbbmaker.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse122258a4d83c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float start;
    char _m6_pad[12];
    float angle;
    float4 colorbg;
    float startA;
    char _m9_pad[12];
    float endA;
    char _m10_pad[12];
    float angleA;
    char _m11_pad[12];
    float featherA;
};

struct refAM35_e122258a4d83c_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse122258a4d83c& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = fast::clamp(gl_FragCoord.xy / _33.refScreen.xy, float2(0.0), float2(1.0));
    float2 param = uv;
    float4 source = texture2DCv(refInput, refInputSmplr, param);
    float amount = fast::clamp(_33.start / 100.0, 0.0, 0.4900000095367431640625);
    float useCustomBounds = step(9.9999997473787516355514526367188e-05, abs(_33.startA) + abs(_33.endA - 1.0));
    float low = mix(amount, fast::min(_33.startA, _33.endA), useCustomBounds);
    float high = mix(1.0 - amount, fast::max(_33.startA, _33.endA), useCustomBounds);
    low = fast::clamp(low, -0.5, 1.5);
    high = fast::clamp(high, -0.5, 1.5);
    float useCustomAngle = step(9.9999997473787516355514526367188e-05, abs(_33.angleA));
    float _degrees = mix(_33.angle, _33.angleA, useCustomAngle);
    float _radians = _degrees * 0.01745329238474369049072265625;
    float2 direction = fast::normalize(float2(cos(_radians), -sin(_radians)));
    float position = dot(((gl_FragCoord.xy - _33.refLayer.xy) / _33.refLayer.zw) - float2(0.5), direction) + 0.5;
    float feather = fast::max(_33.featherA / 100.0, 9.9999997473787516355514526367188e-06);
    float insideStart = smoothstep(low - feather, low + feather, position);
    float insideEnd = 1.0 - smoothstep(high - feather, high + feather, position);
    float inside = fast::clamp(insideStart * insideEnd, 0.0, 1.0);
    float bars = 1.0 - inside;
    float barAlpha = fast::clamp(_33.colorbg.w * bars, 0.0, 1.0);
    float3 outputRGB = mix(source.xyz, _33.colorbg.xyz, float3(barAlpha));
    float outputAlpha = source.w + (barAlpha * (1.0 - source.w));
    referenceColor = float4(outputRGB, outputAlpha);
}

fragment refAM35_e122258a4d83c_out refAM35_e122258a4d83c(constant ReferenceUniformse122258a4d83c& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e122258a4d83c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
    bool _221 = any(isnan(referenceColor));
    bool _228;
    if (!_221)
    {
        _228 = any(isinf(referenceColor));
    }
    else
    {
        _228 = _221;
    }
    if (_228)
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

