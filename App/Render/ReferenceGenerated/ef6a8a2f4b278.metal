// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/cartoon.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef6a8a2f4b278
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    float4 outline_color;
};

struct refAM35_ef6a8a2f4b278_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsef6a8a2f4b278& _35, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 p = powr(texColor, float4(2.2000000476837158203125));
    float2 param_1 = (gl_FragCoord.xy / _35.refScreen.xy) + (float2(0.5) / _35.refScreen.xy);
    float4 s = powr(texture2DCv(refInput, refInputSmplr, param_1), float4(2.2000000476837158203125));
    float l = fast::clamp((powr(length(p - s), 1.0) * _35.strength) + (-0.5), 0.0, 1.0);
    p = floor(powr(p, float4(0.4545454680919647216796875)) * 6.999000072479248046875) / float4(6.0);
    float4 outColor = mix(p, _35.outline_color, float4(l));
    referenceColor = float4(outColor.xyz, texColor.w);
}

fragment refAM35_ef6a8a2f4b278_out refAM35_ef6a8a2f4b278(constant ReferenceUniformsef6a8a2f4b278& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef6a8a2f4b278_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, referenceColor);
    bool _121 = any(isnan(referenceColor));
    bool _128;
    if (!_121)
    {
        _128 = any(isinf(referenceColor));
    }
    else
    {
        _128 = _121;
    }
    if (_128)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _141 = referenceColor;
    float3 _147 = fast::clamp(_141.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _147.x;
    referenceColor.y = _147.y;
    referenceColor.z = _147.z;
    out.finalColor = referenceColor;
    return out;
}

