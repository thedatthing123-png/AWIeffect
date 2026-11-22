// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/T_edge_blur.xml
// Original source comments and attribution:
// 1. Setup
// Aspect correct pixel size for sampling
// --- 2. Edge Detection (Sobel Operator) ---
// Iterate over 3x3 kernel
// Sample neighbor pixel
// Convert to grayscale intensity (Luma)
// Sobel X Kernel: 
// -1  0  1
// -2  0  2
// -1  0  1
// Sobel Y Kernel:
// -1 -2 -1
//  0  0  0
//  1  2  1
// Calculate gradient magnitude
// Create a smooth mask based on threshold and gain
// 0.0 = Flat area, 1.0 = Edge
// --- 3. Blur Calculation ---
// We calculate a blurred color for the current pixel
// Fixed loop for consistent performance
// We simulate a larger radius by spreading the samples
// Adjust sample spacing based on the blurRadius uniform
// --- 4. Composite ---
// Mix the original image with the blurred version using the edge mask
// The edges become blurred, while non-edges stay sharp.
// Output
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsee9c0bd2ca418
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float edgeThreshold;
    char _m6_pad[12];
    float edgeGain;
    char _m7_pad[12];
    float blurRadius;
};

struct refAM35_ee9c0bd2ca418_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsee9c0bd2ca418& _40, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _40.refScreen.xy;
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texel = float2(1.0) / getTexSize(param);
    float gx = 0.0;
    float gy = 0.0;
    for (int i = -1; i <= 1; i++)
    {
        for (int j = -1; j <= 1; j++)
        {
            float2 param_1 = uv + (float2(float(i), float(j)) * texel);
            float3 s = texture2DCv(refInput, refInputSmplr, param_1).xyz;
            float intensity = dot(s, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
            if (i != 0)
            {
                gx += ((intensity * float(i)) * ((j == 0) ? 2.0 : 1.0));
            }
            if (j != 0)
            {
                gy += ((intensity * float(j)) * ((i == 0) ? 2.0 : 1.0));
            }
        }
    }
    float edge = sqrt((gx * gx) + (gy * gy));
    float mask = smoothstep(_40.edgeThreshold, _40.edgeThreshold + 0.100000001490116119384765625, edge * _40.edgeGain);
    mask = fast::clamp(mask, 0.0, 1.0);
    float3 blurCol = float3(0.0);
    float total = 0.0;
    float2 blurStep = texel * (_40.blurRadius / 4.0);
    for (int x = -4; x <= 4; x++)
    {
        for (int y = -4; y <= 4; y++)
        {
            float2 param_2 = uv + (float2(float(x), float(y)) * blurStep);
            blurCol += texture2DCv(refInput, refInputSmplr, param_2).xyz;
            total += 1.0;
        }
    }
    blurCol /= float3(total);
    float2 param_3 = uv;
    float4 original = texture2DCv(refInput, refInputSmplr, param_3);
    float3 col = mix(original.xyz, blurCol, float3(mask));
    referenceColor = float4(col, original.w);
}

fragment refAM35_ee9c0bd2ca418_out refAM35_ee9c0bd2ca418(constant ReferenceUniformsee9c0bd2ca418& _40 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ee9c0bd2ca418_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _40, refInput, refInputSmplr, referenceColor);
    bool _246 = any(isnan(referenceColor));
    bool _253;
    if (!_246)
    {
        _253 = any(isinf(referenceColor));
    }
    else
    {
        _253 = _246;
    }
    if (_253)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _266 = referenceColor;
    float3 _272 = fast::clamp(_266.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _272.x;
    referenceColor.y = _272.y;
    referenceColor.z = _272.z;
    out.finalColor = referenceColor;
    return out;
}

