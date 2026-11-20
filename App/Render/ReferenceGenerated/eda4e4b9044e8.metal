// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/tritone.xml
// Original source comments and attribution:
// 1. Calculate Luminance (standard weights for grayscale)
// 2. Map colors based on luminance
// Map Shadows to Midtones
// Map Midtones to Highlights
// 3. Blend with original
// 4. Output with original alpha
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseda4e4b9044e8
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 highlights;
    float4 midtones;
    float4 shadows;
    float blend;
};

struct refAM35_eda4e4b9044e8_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformseda4e4b9044e8& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _33.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float lum = dot(src.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float3 tritoneCol;
    if (lum < 0.5)
    {
        tritoneCol = mix(_33.shadows.xyz, _33.midtones.xyz, float3(lum * 2.0));
    }
    else
    {
        tritoneCol = mix(_33.midtones.xyz, _33.highlights.xyz, float3((lum - 0.5) * 2.0));
    }
    float3 finalCol = mix(tritoneCol, src.xyz, float3(_33.blend));
    referenceColor = float4(finalCol, 1.0) * src.w;
}

fragment refAM35_eda4e4b9044e8_out refAM35_eda4e4b9044e8(constant ReferenceUniformseda4e4b9044e8& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eda4e4b9044e8_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
    bool _120 = any(isnan(referenceColor));
    bool _127;
    if (!_120)
    {
        _127 = any(isinf(referenceColor));
    }
    else
    {
        _127 = _120;
    }
    if (_127)
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

