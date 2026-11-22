// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/chromatic.xml
// Original source comments and attribution:
// Chromatic Displacement Search
// Single-pass RGB displacement with soft-edged scanning beam
// Beam mask (horizontal band by default)
// Displacement vector
// Sample shifted channels
// Assemble RGB from displaced samples
// Original sample
// Blend original and displaced inside the beam
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef9ec2b77c95e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 beamCenter;
    char _m6_pad[8];
    float beamWidth;
    char _m7_pad[12];
    float beamFeather;
    char _m8_pad[12];
    float dispDist;
    char _m9_pad[12];
    float angle;
    char _m10_pad[12];
    float beamIntensity;
};

struct refAM35_ef9ec2b77c95e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsef9ec2b77c95e& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _33.refScreen.xy;
    float2 d = uv - _33.beamCenter;
    float halfW = _33.beamWidth * 0.5;
    float mask = smoothstep(halfW + _33.beamFeather, halfW - _33.beamFeather, abs(d.x));
    float weight = mask * _33.beamIntensity;
    float2 offset = (float2(cos(_33.angle), sin(_33.angle)) * _33.dispDist) * weight;
    float2 param = uv + offset;
    float4 colR = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = uv;
    float4 colG = texture2DCv(refInput, refInputSmplr, param_1);
    float2 param_2 = uv - offset;
    float4 colB = texture2DCv(refInput, refInputSmplr, param_2);
    float4 displaced = float4(colR.x, colG.y, colB.z, colG.w);
    float2 param_3 = uv;
    float4 original = texture2DCv(refInput, refInputSmplr, param_3);
    referenceColor = mix(original, displaced, float4(weight));
}

fragment refAM35_ef9ec2b77c95e_out refAM35_ef9ec2b77c95e(constant ReferenceUniformsef9ec2b77c95e& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef9ec2b77c95e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
    bool _142 = any(isnan(referenceColor));
    bool _149;
    if (!_142)
    {
        _149 = any(isinf(referenceColor));
    }
    else
    {
        _149 = _142;
    }
    if (_149)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _164 = referenceColor;
    float3 _170 = fast::clamp(_164.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _170.x;
    referenceColor.y = _170.y;
    referenceColor.z = _170.z;
    out.finalColor = referenceColor;
    return out;
}

