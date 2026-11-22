// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_s_monochrome.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef3abc6169292
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float redWeight;
    char _m6_pad[12];
    float greenWeight;
    char _m7_pad[12];
    float blueWeight;
    char _m8_pad[12];
    float contrast;
    float4 tintColor;
    float mixAmount;
};

struct refAM35_ef3abc6169292_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsef3abc6169292& _35, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 w = fast::max(float3(_35.redWeight, _35.greenWeight, _35.blueWeight), float3(0.0));
    w /= float3(fast::max((w.x + w.y) + w.z, 9.9999997473787516355514526367188e-05));
    float y = dot(src.xyz, w);
    y = fast::clamp(((y - 0.5) * _35.contrast) + 0.5, 0.0, 1.0);
    float3 mapped = (float3(y) * _35.tintColor.xyz) * _35.tintColor.w;
    referenceColor = float4(mix(src.xyz, mapped, float3(_35.mixAmount)), src.w);
}

fragment refAM35_ef3abc6169292_out refAM35_ef3abc6169292(constant ReferenceUniformsef3abc6169292& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef3abc6169292_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, referenceColor);
    bool _129 = any(isnan(referenceColor));
    bool _136;
    if (!_129)
    {
        _136 = any(isinf(referenceColor));
    }
    else
    {
        _136 = _129;
    }
    if (_136)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _149 = referenceColor;
    float3 _155 = fast::clamp(_149.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _155.x;
    referenceColor.y = _155.y;
    referenceColor.z = _155.z;
    out.finalColor = referenceColor;
    return out;
}

