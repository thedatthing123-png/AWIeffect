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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformsebde5c0d65142& _52, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texelSize = float2(1.0) / getTexSize(param);
    float2 center = float2(0.5 + (_52.centerPoint.x / 500.0), 0.5 - (_52.centerPoint.y / 500.0));
    float2 v = (gl_FragCoord.xy / _52.refScreen.xy) - (float4(center, 0.0, 1.0) * _52.refLayerToScreen).xy;
    float speed = length(float2(_52.strength / 2.0) / texelSize);
    if (_52.adaptive != 0u)
    {
        speed *= length(((gl_FragCoord.xy - _52.refLayer.xy) / _52.refLayer.zw) - center);
    }
    else
    {
        speed *= smoothstep(0.0, length(texelSize) * 5.0, length(((gl_FragCoord.xy - _52.refLayer.xy) / _52.refLayer.zw) - center));
    }
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
    float2 param_1 = gl_FragCoord.xy / _52.refScreen.xy;
    float4 outColor = texture2DCv(refInput, refInputSmplr, param_1);
    float2 vnorm = (fast::normalize(v) * texelSize) * speed;
    float2 offsetScale = float2(1.0);
    if (_52.refScreen.y > _52.refScreen.x)
    {
        offsetScale.x *= (_52.refScreen.x / _52.refScreen.y);
    }
    else
    {
        offsetScale.y *= (_52.refScreen.y / _52.refScreen.x);
    }
    for (int i = 1; i < nSamples; i++)
    {
        float2 offset = vnorm * ((float(i) / float(nSamples - 1)) - 0.5);
        offset *= offsetScale;
        float2 param_2 = (gl_FragCoord.xy / _52.refScreen.xy) - offset;
        outColor += texture2DCv(refInput, refInputSmplr, param_2);
    }
    referenceColor = outColor / float4(float(nSamples));
}

fragment refAM35_ebde5c0d65142_out refAM35_ebde5c0d65142(constant ReferenceUniformsebde5c0d65142& _52 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ebde5c0d65142_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _52, gl_FragCoord, referenceColor);
    bool _245 = any(isnan(referenceColor));
    bool _252;
    if (!_245)
    {
        _252 = any(isinf(referenceColor));
    }
    else
    {
        _252 = _245;
    }
    if (_252)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _267 = referenceColor;
    float3 _273 = fast::clamp(_267.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _273.x;
    referenceColor.y = _273.y;
    referenceColor.z = _273.z;
    out.finalColor = referenceColor;
    return out;
}

