// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/MultiScaleSharpen.xml
// Original source comments and attribution:
// Color space conversion tools
// Simple 4-tap blur for performance
// Base image
// --- MULTI-SCALE BANDPASS CALCULATION ---
// Generate blurred layers
// Isolate frequency bands (Difference of Gaussians approx)
// Combine bands with user weights
// --- THRESHOLDING ---
// --- LUMA / CHROMA SEPARATION ---
// Y (Luma)
// I (Chroma)
// Q (Chroma)
// --- RGB CHANNELS ---
// --- FINAL COMPOSITION ---
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse93a1a3d64a7f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float sharpenAmp;
    char _m6_pad[12];
    float edgeThreshold;
    char _m7_pad[12];
    float smallDetailSize;
    char _m8_pad[12];
    float scaleTiny;
    char _m9_pad[12];
    float scaleSmall;
    char _m10_pad[12];
    float scaleMedium;
    char _m11_pad[12];
    float scaleLarge;
    char _m12_pad[12];
    float sharpenLuma;
    char _m13_pad[12];
    float sharpenChroma;
    char _m14_pad[12];
    float sharpenRed;
    char _m15_pad[12];
    float sharpenGreen;
    char _m16_pad[12];
    float sharpenBlue;
};

struct refAM35_e93a1a3d64a7f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 getBlur(thread const float2& uv, thread const float& radius, constant ReferenceUniformse93a1a3d64a7f& _114, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 off = float2(radius) / _114.refScreen.xy;
    float2 param = uv + float2(-off.x, -off.y);
    float3 acc = texture2DCv(refInput, refInputSmplr, param).xyz;
    float2 param_1 = uv + float2(off.x, -off.y);
    acc += texture2DCv(refInput, refInputSmplr, param_1).xyz;
    float2 param_2 = uv + float2(-off.x, off.y);
    acc += texture2DCv(refInput, refInputSmplr, param_2).xyz;
    float2 param_3 = uv + float2(off.x, off.y);
    acc += texture2DCv(refInput, refInputSmplr, param_3).xyz;
    return acc * 0.25;
}

static inline __attribute__((always_inline))
float3 rgb2yiq(thread const float3& rgb)
{
    return float3(dot(rgb, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)), dot(rgb, float3(0.596000015735626220703125, -0.2750000059604644775390625, -0.3210000097751617431640625)), dot(rgb, float3(0.21199999749660491943359375, -0.5230000019073486328125, 0.31099998950958251953125)));
}

static inline __attribute__((always_inline))
float3 yiq2rgb(thread const float3& yiq)
{
    float3 rgb;
    rgb.x = (yiq.x + (0.95599997043609619140625 * yiq.y)) + (0.620999991893768310546875 * yiq.z);
    rgb.y = (yiq.x - (0.272000014781951904296875 * yiq.y)) - (0.647000014781951904296875 * yiq.z);
    rgb.z = (yiq.x - (1.105000019073486328125 * yiq.y)) + (1.70200002193450927734375 * yiq.z);
    return rgb;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse93a1a3d64a7f& _114, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _114.refScreen.xy;
    float2 param = uv;
    float3 c0 = texture2DCv(refInput, refInputSmplr, param).xyz;
    float s = _114.smallDetailSize;
    float2 param_1 = uv;
    float param_2 = s * 0.5;
    float3 bTiny = getBlur(param_1, param_2, _114, refInput, refInputSmplr);
    float2 param_3 = uv;
    float param_4 = s * 1.0;
    float3 bSmall = getBlur(param_3, param_4, _114, refInput, refInputSmplr);
    float2 param_5 = uv;
    float param_6 = s * 2.0;
    float3 bMed = getBlur(param_5, param_6, _114, refInput, refInputSmplr);
    float2 param_7 = uv;
    float param_8 = s * 4.0;
    float3 bLarge = getBlur(param_7, param_8, _114, refInput, refInputSmplr);
    float3 dTiny = c0 - bTiny;
    float3 dSmall = bTiny - bSmall;
    float3 dMed = bSmall - bMed;
    float3 dLarge = bMed - bLarge;
    float3 detail = (((dTiny * _114.scaleTiny) + (dSmall * _114.scaleSmall)) + (dMed * _114.scaleMedium)) + (dLarge * _114.scaleLarge);
    float detailLuma = dot(abs(detail), float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float gate = smoothstep(_114.edgeThreshold, _114.edgeThreshold + 0.0500000007450580596923828125, detailLuma);
    detail *= gate;
    float3 param_9 = detail;
    float3 detailYIQ = rgb2yiq(param_9);
    detailYIQ.x *= _114.sharpenLuma;
    detailYIQ.y *= _114.sharpenChroma;
    detailYIQ.z *= _114.sharpenChroma;
    float3 param_10 = detailYIQ;
    detail = yiq2rgb(param_10);
    detail *= float3(_114.sharpenRed, _114.sharpenGreen, _114.sharpenBlue);
    float3 result = c0 + (detail * _114.sharpenAmp);
    referenceColor = float4(result, 1.0);
}

fragment refAM35_e93a1a3d64a7f_out refAM35_e93a1a3d64a7f(constant ReferenceUniformse93a1a3d64a7f& _114 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e93a1a3d64a7f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_114, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _348 = any(isnan(referenceColor));
    bool _355;
    if (!_348)
    {
        _355 = any(isinf(referenceColor));
    }
    else
    {
        _355 = _348;
    }
    if (_355)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _369 = referenceColor;
    float3 _375 = fast::clamp(_369.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _375.x;
    referenceColor.y = _375.y;
    referenceColor.z = _375.z;
    out.finalColor = referenceColor;
    return out;
}

