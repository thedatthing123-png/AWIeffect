// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/invert.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse96fdd2c111c7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint invertRed;
    char _m6_pad[12];
    uint invertGreen;
    char _m7_pad[12];
    uint invertBlue;
};

struct refAM35_e96fdd2c111c7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse96fdd2c111c7& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float r = texColor.x;
    float g = texColor.y;
    float b = texColor.z;
    float a = texColor.w;
    if (_36.invertRed != 0u)
    {
        r = a - r;
    }
    if (_36.invertGreen != 0u)
    {
        g = a - g;
    }
    if (_36.invertBlue != 0u)
    {
        b = a - b;
    }
    referenceColor = float4(r, g, b, a);
}

fragment refAM35_e96fdd2c111c7_out refAM35_e96fdd2c111c7(constant ReferenceUniformse96fdd2c111c7& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e96fdd2c111c7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _105 = any(isnan(referenceColor));
    bool _112;
    if (!_105)
    {
        _112 = any(isinf(referenceColor));
    }
    else
    {
        _112 = _105;
    }
    if (_112)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _127 = referenceColor;
    float3 _133 = fast::clamp(_127.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _133.x;
    referenceColor.y = _133.y;
    referenceColor.z = _133.z;
    out.finalColor = referenceColor;
    return out;
}

