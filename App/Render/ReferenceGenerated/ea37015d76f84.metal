// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/lift.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea37015d76f84
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float fill;
};

struct refAM35_ea37015d76f84_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsea37015d76f84& _35, thread float4& referenceColor, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = gl_FragCoord.xy / _35.refScreen.xy;
    referenceColor = mix(texture2DCv(refReference, refReferenceSmplr, param_1) * texColor.w, texColor, float4(_35.fill));
}

fragment refAM35_ea37015d76f84_out refAM35_ea37015d76f84(constant ReferenceUniformsea37015d76f84& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea37015d76f84_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, referenceColor, refReference, refReferenceSmplr);
    bool _76 = any(isnan(referenceColor));
    bool _83;
    if (!_76)
    {
        _83 = any(isinf(referenceColor));
    }
    else
    {
        _83 = _76;
    }
    if (_83)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _98 = referenceColor;
    float3 _104 = fast::clamp(_98.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _104.x;
    referenceColor.y = _104.y;
    referenceColor.z = _104.z;
    out.finalColor = referenceColor;
    return out;
}

