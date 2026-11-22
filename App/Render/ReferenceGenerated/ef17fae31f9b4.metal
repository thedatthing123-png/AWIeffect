// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/rgb_curves_gamma.xml
// Original source comments and attribution:
// Apply Gamma Curve per channel
// Apply Master Contrast
// Clamp values
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef17fae31f9b4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float redGamma;
    char _m6_pad[12];
    float greenGamma;
    char _m7_pad[12];
    float blueGamma;
    char _m8_pad[12];
    float masterContrast;
};

struct refAM35_ef17fae31f9b4_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsef17fae31f9b4& _35, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float3 col = texColor.xyz;
    col.x = powr(fast::max(col.x, 0.0), _35.redGamma);
    col.y = powr(fast::max(col.y, 0.0), _35.greenGamma);
    col.z = powr(fast::max(col.z, 0.0), _35.blueGamma);
    col = ((col - float3(0.5)) * _35.masterContrast) + float3(0.5);
    col = fast::clamp(col, float3(0.0), float3(1.0));
    referenceColor = float4(col, texColor.w);
}

fragment refAM35_ef17fae31f9b4_out refAM35_ef17fae31f9b4(constant ReferenceUniformsef17fae31f9b4& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef17fae31f9b4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, referenceColor);
    bool _112 = any(isnan(referenceColor));
    bool _119;
    if (!_112)
    {
        _119 = any(isinf(referenceColor));
    }
    else
    {
        _119 = _112;
    }
    if (_119)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _132 = referenceColor;
    float3 _138 = fast::clamp(_132.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _138.x;
    referenceColor.y = _138.y;
    referenceColor.z = _138.z;
    out.finalColor = referenceColor;
    return out;
}

