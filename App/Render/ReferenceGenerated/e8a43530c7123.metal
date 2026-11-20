// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/spot_exposure.xml
// Original source comments and attribution:
// Normalized screen coordinates (0 to 1)
// Fix aspect ratio so the spot is a perfect circle
// Handle center position
// Calculate distance from center
// Create the spot mask using smoothstep for softness
// 1.0 inside the spot, falling off to 0.0 outside
// Sample the input channel
// Calculate final exposure
// Mixes between Base Exposure and (Base + Boost) based on the mask
// Apply exposure to the color (preserving alpha)
// Output to screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse8a43530c7123
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float exposure;
    char _m6_pad[12];
    float spotBoost;
    char _m7_pad[12];
    float spotRadius;
    char _m8_pad[12];
    float spotSoftness;
    char _m9_pad[12];
    float centerX;
    char _m10_pad[12];
    float centerY;
};

struct refAM35_e8a43530c7123_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse8a43530c7123& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _33.refScreen.xy;
    float aspect = _33.refScreen.x / _33.refScreen.y;
    float2 p = uv;
    p.x *= aspect;
    float2 m = float2(_33.centerX, _33.centerY);
    m.x *= aspect;
    float dist = length(p - m);
    float spotMask = smoothstep(_33.spotRadius + _33.spotSoftness, _33.spotRadius, dist);
    float2 param = uv;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float currentExposure = _33.exposure + (_33.spotBoost * spotMask);
    float3 finalColor = texColor.xyz * currentExposure;
    referenceColor = float4(finalColor, texColor.w);
}

fragment refAM35_e8a43530c7123_out refAM35_e8a43530c7123(constant ReferenceUniformse8a43530c7123& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8a43530c7123_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
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
    out.finalColor = referenceColor;
    return out;
}

