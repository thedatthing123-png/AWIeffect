// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s_glow.xml
// Original source comments and attribution:
// S_Glow Ultra-Smooth Implementation for Alight Motion
// Unifying to screen coordinates to fix squeeze/stretch issues
// Scaled weights based on dispersion (Match: 1.0, 1.4, 2.2)
// Non-linear distribution: pow(fraction, 0.8)
// Correct for screen resolution to keep glow circular
// True Gaussian weight
// Chromatic sampling
// Sample and Threshold
// Normalize, Apply Brightness, and Dither
// Screen Combine mode
// Subtle contrast adjustment
// Handle mixing - use original source as base to avoid global screen filling
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse2b36e815b6cb
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float brightness;
    char _m6_pad[12];
    float threshold;
    char _m7_pad[12];
    float glowWidth;
    char _m8_pad[12];
    float widthX;
    char _m9_pad[12];
    float widthY;
    char _m10_pad[12];
    float dispersion;
    char _m11_pad[12];
    float quality;
    char _m12_pad[12];
    float blend;
};

struct refAM35_e2b36e815b6cb_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float dither(thread const float2& uv)
{
    return fract(sin(dot(uv, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875) * 0.0040000001899898052215576171875;
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse2b36e815b6cb& _50, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _50.refScreen.xy;
    float aspect = _50.refScreen.x / _50.refScreen.y;
    float2 param = uv;
    float4 source = texture2DCv(refInput, refInputSmplr, param);
    float3 glowSum = float3(0.0);
    float totalWeight = 0.0;
    int samples = int(_50.quality);
    float3 colorWeights = float3(1.0, 1.0 + (_50.dispersion * 0.4000000059604644775390625), 1.0 + (_50.dispersion * 1.2000000476837158203125));
    for (int i = 0; i < 32; i++)
    {
        if (i >= samples)
        {
            break;
        }
        float fraction = float(i) / float(samples);
        float angle = float(i) * 2.3999631404876708984375;
        float dist = powr(fraction, 0.800000011920928955078125);
        float2 dir = float2(cos(angle), sin(angle));
        float2 scale = (float2(_50.widthX, _50.widthY) * _50.glowWidth) * 0.119999997317790985107421875;
        scale.x /= aspect;
        float weight = exp(((-dist) * dist) * 5.0);
        float2 uvR = uv + (((dir * dist) * scale) * colorWeights.x);
        float2 uvG = uv + (((dir * dist) * scale) * colorWeights.y);
        float2 uvB = uv + (((dir * dist) * scale) * colorWeights.z);
        float2 param_1 = uvR;
        float r = fast::max(texture2DCv(refInput, refInputSmplr, param_1).x - _50.threshold, 0.0);
        float2 param_2 = uvG;
        float g = fast::max(texture2DCv(refInput, refInputSmplr, param_2).y - _50.threshold, 0.0);
        float2 param_3 = uvB;
        float b = fast::max(texture2DCv(refInput, refInputSmplr, param_3).z - _50.threshold, 0.0);
        glowSum += (float3(r, g, b) * weight);
        totalWeight += weight;
    }
    float3 finalGlow = (glowSum / float3(totalWeight)) * _50.brightness;
    float2 param_4 = uv;
    finalGlow += float3(dither(param_4));
    float3 result = float3(1.0) - ((float3(1.0) - source.xyz) * (float3(1.0) - finalGlow));
    result = powr(fast::max(result, float3(0.0)), float3(0.949999988079071044921875));
    float4 finalColor = float4(result, source.w);
    referenceColor = mix(source, finalColor, float4(_50.blend));
}

fragment refAM35_e2b36e815b6cb_out refAM35_e2b36e815b6cb(constant ReferenceUniformse2b36e815b6cb& _50 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e2b36e815b6cb_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _50, refInput, refInputSmplr, referenceColor);
    bool _296 = any(isnan(referenceColor));
    bool _303;
    if (!_296)
    {
        _303 = any(isinf(referenceColor));
    }
    else
    {
        _303 = _296;
    }
    if (_303)
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

