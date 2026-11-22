// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/lensdistoration.xml
// Original source comments and attribution:
// Convert to range [-1, 1]
// Distance from center
// Lens distortion formula
// distortion strength
// Back to [0, 1]
// Only use distorted coordinates if inside bounds
// Blend with the original image
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse698f2bbd9994
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float blend;
};

struct refAM35_e698f2bbd9994_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse698f2bbd9994& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = ((gl_FragCoord.xy / _33.refScreen.xy) * 2.0) - float2(1.0);
    float r = length(uv);
    float k = _33.strength;
    float distortedR = r + ((k * r) * r);
    float2 distortedUV = uv * (distortedR / fast::max(r, 9.9999997473787516355514526367188e-05));
    distortedUV = (distortedUV + float2(1.0)) * 0.5;
    float4 color = float4(0.0);
    bool _85 = distortedUV.x >= 0.0;
    bool _91;
    if (_85)
    {
        _91 = distortedUV.x <= 1.0;
    }
    else
    {
        _91 = _85;
    }
    bool _98;
    if (_91)
    {
        _98 = distortedUV.y >= 0.0;
    }
    else
    {
        _98 = _91;
    }
    bool _104;
    if (_98)
    {
        _104 = distortedUV.y <= 1.0;
    }
    else
    {
        _104 = _98;
    }
    if (_104)
    {
        float2 param = distortedUV;
        color = texture2DCv(refInput, refInputSmplr, param);
    }
    float2 param_1 = gl_FragCoord.xy / _33.refScreen.xy;
    float4 orig = texture2DCv(refInput, refInputSmplr, param_1);
    float4 finalColor = mix(orig, color, float4(_33.blend));
    referenceColor = finalColor;
}

fragment refAM35_e698f2bbd9994_out refAM35_e698f2bbd9994(constant ReferenceUniformse698f2bbd9994& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e698f2bbd9994_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
    bool _135 = any(isnan(referenceColor));
    bool _142;
    if (!_135)
    {
        _142 = any(isinf(referenceColor));
    }
    else
    {
        _142 = _135;
    }
    if (_142)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _157 = referenceColor;
    float3 _163 = fast::clamp(_157.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _163.x;
    referenceColor.y = _163.y;
    referenceColor.z = _163.z;
    out.finalColor = referenceColor;
    return out;
}

