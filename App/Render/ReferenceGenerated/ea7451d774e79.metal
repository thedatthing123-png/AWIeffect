// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_s_gamma.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea7451d774e79
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float masterGamma;
    char _m6_pad[12];
    float redGamma;
    char _m7_pad[12];
    float greenGamma;
    char _m8_pad[12];
    float blueGamma;
    char _m9_pad[12];
    float mixAmount;
};

struct refAM35_ea7451d774e79_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsea7451d774e79& _35, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 expv = float3(1.0 / fast::max(_35.redGamma * _35.masterGamma, 0.001000000047497451305389404296875), 1.0 / fast::max(_35.greenGamma * _35.masterGamma, 0.001000000047497451305389404296875), 1.0 / fast::max(_35.blueGamma * _35.masterGamma, 0.001000000047497451305389404296875));
    float3 mapped = powr(fast::max(src.xyz, float3(0.0)), expv);
    referenceColor = float4(mix(src.xyz, mapped, float3(_35.mixAmount)), src.w);
}

fragment refAM35_ea7451d774e79_out refAM35_ea7451d774e79(constant ReferenceUniformsea7451d774e79& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea7451d774e79_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, referenceColor);
    bool _110 = any(isnan(referenceColor));
    bool _117;
    if (!_110)
    {
        _117 = any(isinf(referenceColor));
    }
    else
    {
        _117 = _110;
    }
    if (_117)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _130 = referenceColor;
    float3 _136 = fast::clamp(_130.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _136.x;
    referenceColor.y = _136.y;
    referenceColor.z = _136.z;
    out.finalColor = referenceColor;
    return out;
}

