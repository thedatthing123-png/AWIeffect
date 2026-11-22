// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/spinblur2.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse5ce70fd654b4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 centerPoint;
    char _m6_pad[8];
    float angle;
};

struct refAM35_e5ce70fd654b4_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse5ce70fd654b4& _53, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param);
    float2 texelSize = float2(1.0) / image_size;
    float2 relCenter = float2(0.5 + (_53.centerPoint.x / 500.0), 0.5 - (_53.centerPoint.y / 500.0));
    float2 center = (float4(relCenter, 0.0, 1.0) * _53.refLayerToScreen).xy;
    float2 v = (gl_FragCoord.xy / _53.refScreen.xy) - center;
    v.y *= (image_size.y / image_size.x);
    float r = length(v);
    float d = 6.28318500518798828125 * r;
    float l = (d * _53.angle) / 360.0;
    float a = _53.angle * 0.01745329983532428741455078125;
    float amin = a / 2.0;
    float speed = l / texelSize.x;
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
    float2 param_1 = gl_FragCoord.xy / _53.refScreen.xy;
    float4 outColor = texture2DCv(refInput, refInputSmplr, param_1);
    for (int i = 1; i < nSamples; i++)
    {
        float sampleAngle = (-amin) + ((a * float(i)) / float(nSamples));
        float s = sin(sampleAngle);
        float c = cos(sampleAngle);
        float2x2 rot = float2x2(float2(c, -s), float2(s, c));
        float2 temp = v * rot;
        temp.y = (temp.y * image_size.x) / image_size.y;
        float2 param_2 = center + temp;
        outColor += texture2DCv(refInput, refInputSmplr, param_2);
    }
    referenceColor = outColor / float4(float(nSamples));
}

fragment refAM35_e5ce70fd654b4_out refAM35_e5ce70fd654b4(constant ReferenceUniformse5ce70fd654b4& _53 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e5ce70fd654b4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _53, gl_FragCoord, referenceColor);
    bool _222 = any(isnan(referenceColor));
    bool _229;
    if (!_222)
    {
        _229 = any(isinf(referenceColor));
    }
    else
    {
        _229 = _222;
    }
    if (_229)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _244 = referenceColor;
    float3 _250 = fast::clamp(_244.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _250.x;
    referenceColor.y = _250.y;
    referenceColor.z = _250.z;
    out.finalColor = referenceColor;
    return out;
}

