// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/noise_distortion_ca.xml
// Original source comments and attribution:
// Simple 2D Hash function
// 2D Gradient Noise
// Normalized pixel coordinates (from 0 to 1)
// Fix aspect ratio for noise generation so it looks uniform
// Calculate Noise field for displacement
// Base displacement vector centered around 0
// --- Warp Blur & Chromatic Aberration Logic ---
// Number of samples for the blur
// Loop to accumulate samples along the displacement vector
// Normalized progress from 0.0 to 1.0
// Calculate a blur offset relative to the main displacement
// Centered around 0.5
// The total offset for this specific sample
// Calculate Chromatic coordinates based on spread
// Sample the channels and multiply by specific colors
// Box blur weight
// Average the samples
// Calculate standard non-chromatic, non-blurred center for mixing
// Mix based on user control 'chromaMix'
// Output to screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse40090140d122
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float distortion;
    char _m6_pad[12];
    float spread;
    char _m7_pad[12];
    float chromaMix;
    char _m8_pad[12];
    float scale;
    char _m9_pad[12];
    float speed;
    char _m10_pad[12];
    float blurStrength;
    float4 highlights;
    float4 midtones;
    float4 shadows;
};

struct refAM35_e40090140d122_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 hash2(thread float2& p)
{
    p = float2(dot(p, float2(127.09999847412109375, 311.70001220703125)), dot(p, float2(269.5, 183.3000030517578125)));
    return float2(-1.0) + (fract(sin(p) * 43758.546875) * 2.0);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i + float2(0.0);
    float2 _77 = hash2(param);
    float2 param_1 = i + float2(1.0, 0.0);
    float2 _86 = hash2(param_1);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 _100 = hash2(param_2);
    float2 param_3 = i + float2(1.0);
    float2 _108 = hash2(param_3);
    return mix(mix(dot(_77, f - float2(0.0)), dot(_86, f - float2(1.0, 0.0)), u.x), mix(dot(_100, f - float2(0.0, 1.0)), dot(_108, f - float2(1.0)), u.x), u.y);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse40090140d122& _129, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _129.refLayer.xy) / _129.refLayer.zw;
    float2 noiseUV = uv;
    noiseUV.x *= (_129.refLayer.z / _129.refLayer.w);
    float2 param = (noiseUV * _129.scale) + float2(_129.refScreen.z * _129.speed);
    float n = _noise(param);
    float2 param_1 = ((noiseUV * _129.scale) + float2(_129.refScreen.z * _129.speed)) + float2(17.299999237060546875, 2.900000095367431640625);
    float n2 = _noise(param_1);
    float2 disp = float2(n, n2) * _129.distortion;
    float3 accumulatedColor = float3(0.0);
    float totalWeight = 0.0;
    float accumulatedAlpha = 0.0;
    for (int i = 0; i < 16; i++)
    {
        float t = float(i) / 15.0;
        float2 blurOffset = (disp * (t - 0.5)) * _129.blurStrength;
        float2 currentDisp = disp + blurOffset;
        float2 uvR = uv + (currentDisp * (1.0 + (_129.spread * 5.0)));
        float2 uvG = uv + currentDisp;
        float2 uvB = uv + (currentDisp * (1.0 - (_129.spread * 5.0)));
        float2 param_2 = uvR;
        float r = texture2DCv(refInput, refInputSmplr, param_2).x * _129.highlights.x;
        float2 param_3 = uvG;
        float g = texture2DCv(refInput, refInputSmplr, param_3).y * _129.midtones.y;
        float2 param_4 = uvB;
        float b = texture2DCv(refInput, refInputSmplr, param_4).z * _129.shadows.z;
        float2 param_5 = uvG;
        float a = texture2DCv(refInput, refInputSmplr, param_5).w;
        float3 col = float3(r, g, b);
        float w = 1.0;
        accumulatedColor += (col * w);
        accumulatedAlpha += (a * w);
        totalWeight += w;
    }
    float3 chromaticBlurred = accumulatedColor / float3(totalWeight);
    float finalAlpha = accumulatedAlpha / totalWeight;
    float2 centerUV = uv + disp;
    float2 param_6 = centerUV;
    float3 standardColor = texture2DCv(refInput, refInputSmplr, param_6).xyz;
    float3 finalColor = mix(standardColor, chromaticBlurred, float3(_129.chromaMix));
    referenceColor = float4(finalColor, finalAlpha);
}

fragment refAM35_e40090140d122_out refAM35_e40090140d122(constant ReferenceUniformse40090140d122& _129 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e40090140d122_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _129, refInput, refInputSmplr, referenceColor);
    bool _351 = any(isnan(referenceColor));
    bool _358;
    if (!_351)
    {
        _358 = any(isinf(referenceColor));
    }
    else
    {
        _358 = _351;
    }
    if (_358)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _371 = referenceColor;
    float3 _377 = fast::clamp(_371.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _377.x;
    referenceColor.y = _377.y;
    referenceColor.z = _377.z;
    out.finalColor = referenceColor;
    return out;
}

