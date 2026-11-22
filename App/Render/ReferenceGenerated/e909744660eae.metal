// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/pixelwave.xml
// Original source comments and attribution:
// Utility functions
// Overlay blend mode
// Normalize direction vector
// Calculate time-based animation
// Get original texture coordinates
// Apply pixelation
// Apply wave distortion
// Sample the input texture with distorted coordinates
// Apply tint color
// Apply blend mode
// Normal
// Multiply
// Screen
// Overlay
// Final output with alpha blending
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse909744660eae
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float frequency;
    char _m6_pad[12];
    float amplitude;
    char _m7_pad[12];
    float speed;
    char _m8_pad[12];
    float pixelSize;
    char _m9_pad[8];
    float2 direction;
    float4 tintColor;
    float alpha;
    char _m12_pad[12];
    int blendMode;
};

struct refAM35_e909744660eae_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 pixelate(thread const float2& uv, thread const float& pixelSize)
{
    return floor(uv * pixelSize) / float2(pixelSize);
}

static inline __attribute__((always_inline))
float wave(thread const float2& uv, thread const float& freq, thread const float& amp, thread const float& time, thread const float2& dir)
{
    float x = (uv.x * dir.x) + (uv.y * dir.y);
    return sin((x * freq) + time) * amp;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 blendOverlay(thread const float3& base, thread const float3& blend)
{
    return mix((base * 2.0) * blend, float3(1.0) - (((float3(1.0) - base) * 2.0) * (float3(1.0) - blend)), step(float3(0.5), base));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse909744660eae& _108, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float2 dir = fast::normalize(_108.direction);
    float time = _108.refScreen.z * _108.speed;
    float2 uv = gl_FragCoord.xy / _108.refScreen.xy;
    float2 param = uv;
    float param_1 = _108.pixelSize;
    float2 pixelUV = pixelate(param, param_1);
    float2 param_2 = pixelUV;
    float param_3 = _108.frequency;
    float param_4 = _108.amplitude / 1000.0;
    float param_5 = time;
    float2 param_6 = dir;
    float offset = wave(param_2, param_3, param_4, param_5, param_6);
    float2 distortedUV = uv + float2(offset * dir.y, (-offset) * dir.x);
    float2 param_7 = distortedUV;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_7);
    float2 param_8 = distortedUV;
    float4 compColor = texture2DCv(refReference, refReferenceSmplr, param_8);
    float3 tinted = texColor.xyz * _108.tintColor.xyz;
    float3 result;
    if (_108.blendMode == 0)
    {
        result = mix(texColor.xyz, tinted, float3(_108.tintColor.w));
    }
    else
    {
        if (_108.blendMode == 1)
        {
            result = texColor.xyz * mix(float3(1.0), _108.tintColor.xyz, float3(_108.tintColor.w));
        }
        else
        {
            if (_108.blendMode == 2)
            {
                result = float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - mix(float3(0.0), _108.tintColor.xyz, float3(_108.tintColor.w))));
            }
            else
            {
                float3 param_9 = texColor.xyz;
                float3 param_10 = _108.tintColor.xyz;
                result = mix(texColor.xyz, blendOverlay(param_9, param_10), float3(_108.tintColor.w));
            }
        }
    }
    referenceColor = mix(texColor, float4(result, texColor.w), float4(_108.alpha));
}

fragment refAM35_e909744660eae_out refAM35_e909744660eae(constant ReferenceUniformse909744660eae& _108 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e909744660eae_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_108, gl_FragCoord, refInput, refInputSmplr, refReference, refReferenceSmplr, referenceColor);
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

