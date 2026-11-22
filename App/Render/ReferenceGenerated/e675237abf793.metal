// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/circlewipe.xml
// Original source comments and attribution:
// Distance from custom center
// Circle edge with feather blend
// Sample image and apply alpha mask
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse675237abf793
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float size;
    char _m6_pad[12];
    float feather;
    char _m7_pad[12];
    float centerX;
    char _m8_pad[12];
    float centerY;
    char _m9_pad[12];
    uint invert;
};

struct refAM35_e675237abf793_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse675237abf793& _34, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _34.refScreen.xy;
    float2 center = float2(_34.centerX, _34.centerY);
    float dist = distance(uv, center);
    float edge = smoothstep(_34.size, _34.size - _34.feather, dist);
    if (_34.invert != 0u)
    {
        edge = 1.0 - edge;
    }
    float2 param = uv;
    float4 tex = texture2DCv(refInput, refInputSmplr, param);
    referenceColor = float4(tex.xyz * edge, tex.w * edge);
}

fragment refAM35_e675237abf793_out refAM35_e675237abf793(constant ReferenceUniformse675237abf793& _34 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e675237abf793_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _34, refInput, refInputSmplr, referenceColor);
    bool _108 = any(isnan(referenceColor));
    bool _115;
    if (!_108)
    {
        _115 = any(isinf(referenceColor));
    }
    else
    {
        _115 = _108;
    }
    if (_115)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _128 = referenceColor;
    float3 _134 = fast::clamp(_128.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _134.x;
    referenceColor.y = _134.y;
    referenceColor.z = _134.z;
    out.finalColor = referenceColor;
    return out;
}

