// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/posterize.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse5d4a39880b98
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float stepCount;
    char _m6_pad[12];
    float offset;
};

struct refAM35_e5d4a39880b98_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse5d4a39880b98& _30, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float actualOffset = _30.offset + 0.0500000007450580596923828125;
    float2 param = gl_FragCoord.xy / _30.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 _57 = texColor;
    float3 _59 = _57.xyz * _30.stepCount;
    texColor.x = _59.x;
    texColor.y = _59.y;
    texColor.z = _59.z;
    float4 _71 = texColor;
    float3 _74 = _71.xyz + float3(actualOffset);
    texColor.x = _74.x;
    texColor.y = _74.y;
    texColor.z = _74.z;
    float4 _81 = texColor;
    float3 _83 = floor(_81.xyz);
    texColor.x = _83.x;
    texColor.y = _83.y;
    texColor.z = _83.z;
    float4 _91 = texColor;
    float3 _94 = _91.xyz - float3(actualOffset);
    texColor.x = _94.x;
    texColor.y = _94.y;
    texColor.z = _94.z;
    float4 _103 = texColor;
    float3 _106 = _103.xyz / float3(_30.stepCount);
    texColor.x = _106.x;
    texColor.y = _106.y;
    texColor.z = _106.z;
    referenceColor = texColor;
}

fragment refAM35_e5d4a39880b98_out refAM35_e5d4a39880b98(constant ReferenceUniformse5d4a39880b98& _30 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e5d4a39880b98_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_30, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _123 = any(isnan(referenceColor));
    bool _130;
    if (!_123)
    {
        _130 = any(isinf(referenceColor));
    }
    else
    {
        _130 = _123;
    }
    if (_130)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _145 = referenceColor;
    float3 _151 = fast::clamp(_145.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _151.x;
    referenceColor.y = _151.y;
    referenceColor.z = _151.z;
    out.finalColor = referenceColor;
    return out;
}

