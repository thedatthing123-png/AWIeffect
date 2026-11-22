// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_s_channel_switcher.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse886f5cf1e803
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int redSource;
    char _m6_pad[12];
    int greenSource;
    char _m7_pad[12];
    int blueSource;
    char _m8_pad[12];
    float mixAmount;
};

struct refAM35_e886f5cf1e803_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float aeLuma(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float chooseChannel(thread const float3& c, thread const int& index)
{
    if (index == 0)
    {
        return c.x;
    }
    if (index == 1)
    {
        return c.y;
    }
    if (index == 2)
    {
        return c.z;
    }
    if (index == 3)
    {
        float3 param = c;
        return aeLuma(param);
    }
    return 0.0;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse886f5cf1e803& _98, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _98.refScreen.xy;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 param_1 = src.xyz;
    int param_2 = _98.redSource;
    float3 param_3 = src.xyz;
    int param_4 = _98.greenSource;
    float3 param_5 = src.xyz;
    int param_6 = _98.blueSource;
    float3 mapped = float3(chooseChannel(param_1, param_2), chooseChannel(param_3, param_4), chooseChannel(param_5, param_6));
    referenceColor = float4(mix(src.xyz, mapped, float3(_98.mixAmount)), src.w);
}

fragment refAM35_e886f5cf1e803_out refAM35_e886f5cf1e803(constant ReferenceUniformse886f5cf1e803& _98 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e886f5cf1e803_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _98, referenceColor);
    bool _156 = any(isnan(referenceColor));
    bool _163;
    if (!_156)
    {
        _163 = any(isinf(referenceColor));
    }
    else
    {
        _163 = _156;
    }
    if (_163)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _177 = referenceColor;
    float3 _183 = fast::clamp(_177.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _183.x;
    referenceColor.y = _183.y;
    referenceColor.z = _183.z;
    out.finalColor = referenceColor;
    return out;
}

