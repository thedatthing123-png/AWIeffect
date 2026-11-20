// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/zoomblur3.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsebde5c0d65142
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 centerPoint;
    char _m6_pad[8];
    float strength;
    char _m7_pad[12];
    uint adaptive;
};

struct refAM35_ebde5c0d65142_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsebde5c0d65142& _38, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 param = _38.refScreen.xy;
    float2 texelSize = float2(1.0) / getTexSize(param);
    float2 center = float2(0.5 + (_38.centerPoint.x / 500.0), 0.5 - (_38.centerPoint.y / 500.0));
    float2 v = (gl_FragCoord.xy / _38.refScreen.xy) - (float4(center, 0.0, 1.0) * _38.refLayerToScreen).xy;
    float speed = length(float2(_38.strength / 2.0) / texelSize);
    if (_38.adaptive != 0u)
    {
        speed *= length(((gl_FragCoord.xy - _38.refLayer.xy) / _38.refLayer.zw) - center);
    }
    else
    {
        speed *= smoothstep(0.0, length(texelSize) * 5.0, length(((gl_FragCoord.xy - _38.refLayer.xy) / _38.refLayer.zw) - center));
    }
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
    float2 param_1 = gl_FragCoord.xy / _38.refScreen.xy;
    float4 outColor = texture2DCv(refInput, refInputSmplr, param_1);
    float2 vnorm = (fast::normalize(v) * texelSize) * speed;
    float2 offsetScale = float2(1.0);
    if (_38.refScreen.y > _38.refScreen.x)
    {
        offsetScale.x *= (_38.refScreen.x / _38.refScreen.y);
    }
    else
    {
        offsetScale.y *= (_38.refScreen.y / _38.refScreen.x);
    }
    for (int i = 1; i < nSamples; i++)
    {
        float2 offset = vnorm * ((float(i) / float(nSamples - 1)) - 0.5);
        offset *= offsetScale;
        float2 param_2 = (gl_FragCoord.xy / _38.refScreen.xy) - offset;
        outColor += texture2DCv(refInput, refInputSmplr, param_2);
    }
    referenceColor = outColor / float4(float(nSamples));
}

fragment refAM35_ebde5c0d65142_out refAM35_ebde5c0d65142(constant ReferenceUniformsebde5c0d65142& _38 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ebde5c0d65142_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_38, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _243 = any(isnan(referenceColor));
    bool _250;
    if (!_243)
    {
        _250 = any(isinf(referenceColor));
    }
    else
    {
        _250 = _243;
    }
    if (_250)
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

