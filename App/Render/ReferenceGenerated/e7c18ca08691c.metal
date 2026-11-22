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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse7c18ca08691c& _51, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texelSize = float2(1.0) / getTexSize(param);
    float2 center = float2(0.5 + (_51.centerPoint.x / 500.0), 0.5 - (_51.centerPoint.y / 500.0));
    float2 v = (gl_FragCoord.xy / _51.refScreen.xy) - (float4(center, 0.0, 1.0) * _51.refLayerToScreen).xy;
    float speed = length(float2(_51.strength / 2.0) / texelSize);
    speed *= length(((gl_FragCoord.xy - _51.refLayer.xy) / _51.refLayer.zw) - center);
    int nSamples = int(_51.quality);
    float2 param_1 = gl_FragCoord.xy / _51.refScreen.xy;
    float4 baseColor = texture2DCv(refInput, refInputSmplr, param_1);
    float2 vnorm = (fast::normalize(v) * texelSize) * speed;
    float2 offsetScale = float2(1.0);
    if (_51.refScreen.y > _51.refScreen.x)
    {
        offsetScale.x *= (_51.refScreen.x / _51.refScreen.y);
    }
    else
    {
        offsetScale.y *= (_51.refScreen.y / _51.refScreen.x);
    }
    float actualSamples = 1.0;
    float4 outColor = float4(0.0);
    float4 _224;
    for (int i = 1; i < nSamples; i++)
    {
        float p = float(i) / float(nSamples - 1);
        float2 offs = vnorm * p;
        offs *= offsetScale;
        float2 param_2 = (gl_FragCoord.xy / _51.refScreen.xy) - offs;
        float4 texColor = texture2DCv(refInput, refInputSmplr, param_2);
        float luminance = dot(texColor.xyz - _51.thresholdColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        if (luminance > _51.threshold)
        {
            _224 = mix(texColor, _51.fillColor, float4(_51.blend)) * (1.0 - p);
        }
        else
        {
            _224 = float4(0.0);
        }
        outColor += _224;
        actualSamples += float(luminance > _51.threshold);
    }
    referenceColor = baseColor + ((outColor * _51.intensity) / float4(float(nSamples)));
}

fragment refAM35_e7c18ca08691c_out refAM35_e7c18ca08691c(constant ReferenceUniformse7c18ca08691c& _51 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e7c18ca08691c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _51, gl_FragCoord, referenceColor);
    bool _269 = any(isnan(referenceColor));
    bool _276;
    if (!_269)
    {
        _276 = any(isinf(referenceColor));
    }
    else
    {
        _276 = _269;
    }
    if (_276)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _290 = referenceColor;
    float3 _296 = fast::clamp(_290.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _296.x;
    referenceColor.y = _296.y;
    referenceColor.z = _296.z;
    out.finalColor = referenceColor;
    return out;
}

