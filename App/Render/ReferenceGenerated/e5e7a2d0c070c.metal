// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/lensblur2.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse5e7a2d0c070c
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
    float radius;
};

struct refAM35_e5e7a2d0c070c_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse5e7a2d0c070c& _51, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texelSize = float2(1.0) / getTexSize(param);
    float2 center = float2(0.5 + (_51.centerPoint.x / 500.0), 0.5 - (_51.centerPoint.y / 500.0));
    float2 v = (gl_FragCoord.xy / _51.refScreen.xy) - (float4(center, 0.0, 1.0) * _51.refLayerToScreen).xy;
    float speed = length(float2(_51.strength / 2.0) / texelSize);
    speed *= smoothstep(_51.radius, 1.0, length(((gl_FragCoord.xy - _51.refLayer.xy) / _51.refLayer.zw) - center));
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
    float2 param_1 = gl_FragCoord.xy / _51.refScreen.xy;
    float4 outColor = texture2DCv(refInput, refInputSmplr, param_1);
    float2 vnorm = (fast::normalize(v) * texelSize) * speed;
    for (int i = 1; i < nSamples; i++)
    {
        float2 offset = vnorm * ((float(i) / float(nSamples - 1)) - 0.5);
        float2 param_2 = (gl_FragCoord.xy / _51.refScreen.xy) - offset;
        outColor += texture2DCv(refInput, refInputSmplr, param_2);
    }
    referenceColor = outColor / float4(float(nSamples));
}

fragment refAM35_e5e7a2d0c070c_out refAM35_e5e7a2d0c070c(constant ReferenceUniformse5e7a2d0c070c& _51 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e5e7a2d0c070c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _51, gl_FragCoord, referenceColor);
    bool _190 = any(isnan(referenceColor));
    bool _197;
    if (!_190)
    {
        _197 = any(isinf(referenceColor));
    }
    else
    {
        _197 = _190;
    }
    if (_197)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _212 = referenceColor;
    float3 _218 = fast::clamp(_212.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _218.x;
    referenceColor.y = _218.y;
    referenceColor.z = _218.z;
    out.finalColor = referenceColor;
    return out;
}

