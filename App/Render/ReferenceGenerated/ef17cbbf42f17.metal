// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/dblur.xml
// Original source comments and attribution:
//velocity *= acPreviewSize * texelSize;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef17cbbf42f17
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float angle;
};

struct refAM35_ef17cbbf42f17_out
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
void referenceMain(constant ReferenceUniformsef17cbbf42f17& _37, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = _37.refScreen.xy;
    float2 texelSize = float2(1.0) / getTexSize(param);
    float rad = _37.angle * 0.01745329983532428741455078125;
    float2 velocity = float2(cos(rad) * _37.strength, (-sin(rad)) * _37.strength);
    velocity.x *= (_37.refScreen.y / _37.refScreen.x);
    float speed = length(velocity / texelSize);
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
    float2 param_1 = gl_FragCoord.xy / _37.refScreen.xy;
    float4 outColor = texture2DCv(refInput, refInputSmplr, param_1);
    for (int i = 1; i < nSamples; i++)
    {
        float2 offset = velocity * ((float(i) / float(nSamples - 1)) - 0.5);
        float2 sampleCoord = (gl_FragCoord.xy / _37.refScreen.xy) - offset;
        float insideTexture = ((step(0.0, sampleCoord.x) * step(sampleCoord.x, 1.0)) * step(0.0, sampleCoord.y)) * step(sampleCoord.y, 1.0);
        float2 param_2 = sampleCoord;
        outColor += (texture2DCv(refInput, refInputSmplr, param_2) * insideTexture);
    }
    referenceColor = outColor / float4(float(nSamples));
}

fragment refAM35_ef17cbbf42f17_out refAM35_ef17cbbf42f17(constant ReferenceUniformsef17cbbf42f17& _37 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef17cbbf42f17_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_37, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _176 = any(isnan(referenceColor));
    bool _183;
    if (!_176)
    {
        _183 = any(isinf(referenceColor));
    }
    else
    {
        _183 = _176;
    }
    if (_183)
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

