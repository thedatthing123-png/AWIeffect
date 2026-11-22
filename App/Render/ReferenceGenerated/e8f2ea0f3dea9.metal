// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/hand_drawn.xml
// Original source comments and attribution:
// Simple hash function for noise
// 2D Value Noise
// Normalized pixel coordinates (from 0 to 1)
// --- 1. Hand Drawn Warp Effect ---
// Quantize time to simulate lower framerate
// Create random offsets for X and Y using the quantized time
// Distort the UVs
// --- 2. Outline Detection ---
// Sample the base color at warped coordinates
// Sample neighbors to detect edges
// Convert to luminance for edge checking
// Calculate edge intensity (gradient magnitude)
// --- 3. Final Composite ---
// Apply the black outline (multiply)
// Output to screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse8f2ea0f3dea9
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float warpAmount;
    char _m6_pad[12];
    float outlineStr;
    char _m7_pad[12];
    float fps;
};

struct refAM35_e8f2ea0f3dea9_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash(thread float2& p)
{
    p = fract(p * float2(123.339996337890625, 456.209991455078125));
    p += float2(dot(p, p + float2(45.31999969482421875)));
    return fract(p.x * p.y);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i;
    float _78 = hash(param);
    float a = _78;
    float2 param_1 = i + float2(1.0, 0.0);
    float _86 = hash(param_1);
    float b = _86;
    float2 param_2 = i + float2(0.0, 1.0);
    float _92 = hash(param_2);
    float c = _92;
    float2 param_3 = i + float2(1.0);
    float _98 = hash(param_3);
    float d = _98;
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse8f2ea0f3dea9& _122, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _122.refScreen.xy;
    float timeSnap = floor(_122.refScreen.z * _122.fps);
    float2 param = (uv * 15.0) + float2(timeSnap);
    float2 param_1 = ((uv * 15.0) + float2(timeSnap)) + float2(100.0);
    float2 noiseOffset = float2(_noise(param), _noise(param_1));
    float2 warpedUV = uv + ((noiseOffset - float2(0.5)) * _122.warpAmount);
    float2 pixel = float2(1.0) / _122.refScreen.xy;
    float2 param_2 = warpedUV;
    float4 texColorFull = texture2DCv(refInput, refInputSmplr, param_2);
    float3 texColor = texColorFull.xyz;
    float2 param_3 = warpedUV + float2(0.0, pixel.y);
    float3 n = texture2DCv(refInput, refInputSmplr, param_3).xyz;
    float2 param_4 = warpedUV + float2(pixel.x, 0.0);
    float3 e = texture2DCv(refInput, refInputSmplr, param_4).xyz;
    float2 param_5 = warpedUV - float2(0.0, pixel.y);
    float3 s = texture2DCv(refInput, refInputSmplr, param_5).xyz;
    float2 param_6 = warpedUV - float2(pixel.x, 0.0);
    float3 w = texture2DCv(refInput, refInputSmplr, param_6).xyz;
    float3 luma = float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625);
    float lumC = dot(texColor, luma);
    float lumN = dot(n, luma);
    float lumS = dot(s, luma);
    float lumE = dot(e, luma);
    float lumW = dot(w, luma);
    float edge = abs(lumN - lumS) + abs(lumE - lumW);
    float outline = 1.0 - fast::clamp(edge * _122.outlineStr, 0.0, 1.0);
    float3 finalColor = texColor * outline;
    referenceColor = float4(finalColor, texColorFull.w);
}

fragment refAM35_e8f2ea0f3dea9_out refAM35_e8f2ea0f3dea9(constant ReferenceUniformse8f2ea0f3dea9& _122 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8f2ea0f3dea9_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _122, refInput, refInputSmplr, referenceColor);
    bool _287 = any(isnan(referenceColor));
    bool _294;
    if (!_287)
    {
        _294 = any(isinf(referenceColor));
    }
    else
    {
        _294 = _287;
    }
    if (_294)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _307 = referenceColor;
    float3 _313 = fast::clamp(_307.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _313.x;
    referenceColor.y = _313.y;
    referenceColor.z = _313.z;
    out.finalColor = referenceColor;
    return out;
}

