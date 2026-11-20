// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/colortemperature.xml
// Original source comments and attribution:
// Valid from 1000 to 40000 K (and additionally 0 for pure full white)
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse7dd301114b90
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float temperature;
    char _m6_pad[12];
    float strength;
};

struct refAM35_e7dd301114b90_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 colorTemperatureToRGB(float temperature)
{
    float3x3 _36;
    if (temperature <= 6500.0)
    {
        _36 = float3x3(float3(0.0, -2902.195556640625, -8257.7998046875), float3(0.0, 1669.580322265625, 2575.28271484375), float3(1.0, 1.330267429351806640625, 1.899375438690185546875));
    }
    else
    {
        _36 = float3x3(float3(1745.04248046875, 1216.6168212890625, -8257.7998046875), float3(-2666.347412109375, -2173.101318359375, 2575.28271484375), float3(0.559953868389129638671875, 0.70381200313568115234375, 1.899375438690185546875));
    }
    float3x3 m = _36;
    return mix(fast::clamp((m[0] / (float3(fast::clamp(temperature, 1000.0, 40000.0)) + m[1])) + m[2], float3(0.0), float3(1.0)), float3(1.0), float3(smoothstep(1000.0, 0.0, temperature)));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse7dd301114b90& _99, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _99.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = texColor.xyz;
    float a = texColor.w;
    rgb = mix(rgb, rgb * colorTemperatureToRGB(_99.temperature * 1000.0), float3(_99.strength));
    referenceColor = float4(rgb, a);
}

fragment refAM35_e7dd301114b90_out refAM35_e7dd301114b90(constant ReferenceUniformse7dd301114b90& _99 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e7dd301114b90_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _99, referenceColor);
    bool _143 = any(isnan(referenceColor));
    bool _150;
    if (!_143)
    {
        _150 = any(isinf(referenceColor));
    }
    else
    {
        _150 = _143;
    }
    if (_150)
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

