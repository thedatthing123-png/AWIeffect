// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/rays.xml
// Original source comments and attribution:
//int nSamples = int(clamp(speed, 1.01, 200.01));
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse7c18ca08691c
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
    float intensity;
    char _m8_pad[12];
    float threshold;
    float4 thresholdColor;
    float4 fillColor;
    float blend;
    char _m12_pad[12];
    float quality;
};

struct refAM35_e7c18ca08691c_out
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
void referenceMain(constant ReferenceUniformse7c18ca08691c& _37, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 param = _37.refScreen.xy;
    float2 texelSize = float2(1.0) / getTexSize(param);
    float2 center = float2(0.5 + (_37.centerPoint.x / 500.0), 0.5 - (_37.centerPoint.y / 500.0));
    float2 v = (gl_FragCoord.xy / _37.refScreen.xy) - (float4(center, 0.0, 1.0) * _37.refLayerToScreen).xy;
    float speed = length(float2(_37.strength / 2.0) / texelSize);
    speed *= length(((gl_FragCoord.xy - _37.refLayer.xy) / _37.refLayer.zw) - center);
    int nSamples = int(_37.quality);
    float2 param_1 = gl_FragCoord.xy / _37.refScreen.xy;
    float4 baseColor = texture2DCv(refInput, refInputSmplr, param_1);
    float2 vnorm = (fast::normalize(v) * texelSize) * speed;
    float2 offsetScale = float2(1.0);
    if (_37.refScreen.y > _37.refScreen.x)
    {
        offsetScale.x *= (_37.refScreen.x / _37.refScreen.y);
    }
    else
    {
        offsetScale.y *= (_37.refScreen.y / _37.refScreen.x);
    }
    float actualSamples = 1.0;
    float4 outColor = float4(0.0);
    float4 _222;
    for (int i = 1; i < nSamples; i++)
    {
        float p = float(i) / float(nSamples - 1);
        float2 offs = vnorm * p;
        offs *= offsetScale;
        float2 param_2 = (gl_FragCoord.xy / _37.refScreen.xy) - offs;
        float4 texColor = texture2DCv(refInput, refInputSmplr, param_2);
        float luminance = dot(texColor.xyz - _37.thresholdColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        if (luminance > _37.threshold)
        {
            _222 = mix(texColor, _37.fillColor, float4(_37.blend)) * (1.0 - p);
        }
        else
        {
            _222 = float4(0.0);
        }
        outColor += _222;
        actualSamples += float(luminance > _37.threshold);
    }
    referenceColor = baseColor + ((outColor * _37.intensity) / float4(float(nSamples)));
}

fragment refAM35_e7c18ca08691c_out refAM35_e7c18ca08691c(constant ReferenceUniformse7c18ca08691c& _37 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e7c18ca08691c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_37, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _267 = any(isnan(referenceColor));
    bool _274;
    if (!_267)
    {
        _274 = any(isinf(referenceColor));
    }
    else
    {
        _274 = _267;
    }
    if (_274)
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

