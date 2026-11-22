// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/stretch2.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9e38aadb715d
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float scale;
    char _m6_pad[12];
    float angle;
    char _m7_pad[12];
    uint contentOnly;
};

struct refAM35_e9e38aadb715d_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse9e38aadb715d& _31, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float rad = _31.angle * 0.01745329983532428741455078125;
    float2x2 rot = float2x2(float2(cos(rad), -sin(rad)), float2(sin(rad), cos(rad)));
    float2x2 invrot = float2x2(float2(cos(-rad), -sin(-rad)), float2(sin(-rad), cos(-rad)));
    float2 sampleCoord = ((((((gl_FragCoord.xy - _31.refLayer.xy) / _31.refLayer.zw) - float2(0.5)) * rot) * float2(1.0 / _31.scale, 1.0)) * invrot) + float2(0.5);
    sampleCoord = (float4(sampleCoord, 0.0, 1.0) * _31.refLayerToScreen).xy;
    if (_31.contentOnly != 0u)
    {
        float2 param = gl_FragCoord.xy / _31.refScreen.xy;
        float4 texColor = texture2DCv(refInput, refInputSmplr, param);
        float2 param_1 = sampleCoord;
        float4 newColor = texture2DCv(refInput, refInputSmplr, param_1) * texColor.w;
        referenceColor = newColor;
    }
    else
    {
        float2 param_2 = sampleCoord;
        referenceColor = texture2DCv(refInput, refInputSmplr, param_2);
    }
}

fragment refAM35_e9e38aadb715d_out refAM35_e9e38aadb715d(constant ReferenceUniformse9e38aadb715d& _31 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9e38aadb715d_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_31, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _154 = any(isnan(referenceColor));
    bool _161;
    if (!_154)
    {
        _161 = any(isinf(referenceColor));
    }
    else
    {
        _161 = _154;
    }
    if (_161)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _175 = referenceColor;
    float3 _181 = fast::clamp(_175.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _181.x;
    referenceColor.y = _181.y;
    referenceColor.z = _181.z;
    out.finalColor = referenceColor;
    return out;
}

