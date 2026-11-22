// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/cartoon_outline.xml
// Original source comments and attribution:
// Cartoon Outline Effect - Creates black outline around edges
// Sobel edge detection kernel
// Sample neighboring pixels
// Sobel X kernel: [-1  0  1; -2  0  2; -1  0  1]
// Sobel Y kernel: [-1 -2 -1;  0  0  0;  1  2  1]
// Additional edge detection for better outline quality
// Edge detection
// Apply intensity and smoothness
// Create outline color
// Composite with original
// Blend outline over original (preserves original colors)
// Replace with outline where detected
// Preserve original alpha
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseab75323f2408
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float outlineWidth;
    char _m6_pad[12];
    float outlineIntensity;
    float4 outlineColor;
    float edgeThreshold;
    char _m9_pad[12];
    uint smoothEdges;
    char _m10_pad[12];
    uint preserveOriginal;
};

struct refAM35_eab75323f2408_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 rgb2gray(thread const float3& c)
{
    return float3(dot(c, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)));
}

static inline __attribute__((always_inline))
float sobelEdge(thread const float2& uv, thread const float& threshold, constant ReferenceUniformseab75323f2408& _55, texture2d<float> refInput, sampler refInputSmplr)
{
    float s = _55.outlineWidth * 0.001000000047497451305389404296875;
    float gx = 0.0;
    float gy = 0.0;
    float2 param = uv + float2(-s, -s);
    float3 param_1 = texture2DCv(refInput, refInputSmplr, param).xyz;
    float tl = rgb2gray(param_1).x;
    float2 param_2 = uv + float2(0.0, -s);
    float3 param_3 = texture2DCv(refInput, refInputSmplr, param_2).xyz;
    float tm = rgb2gray(param_3).x;
    float2 param_4 = uv + float2(s, -s);
    float3 param_5 = texture2DCv(refInput, refInputSmplr, param_4).xyz;
    float tr = rgb2gray(param_5).x;
    float2 param_6 = uv + float2(-s, 0.0);
    float3 param_7 = texture2DCv(refInput, refInputSmplr, param_6).xyz;
    float ml = rgb2gray(param_7).x;
    float2 param_8 = uv + float2(s, 0.0);
    float3 param_9 = texture2DCv(refInput, refInputSmplr, param_8).xyz;
    float mr = rgb2gray(param_9).x;
    float2 param_10 = uv + float2(-s, s);
    float3 param_11 = texture2DCv(refInput, refInputSmplr, param_10).xyz;
    float bl = rgb2gray(param_11).x;
    float2 param_12 = uv + float2(0.0, s);
    float3 param_13 = texture2DCv(refInput, refInputSmplr, param_12).xyz;
    float bm = rgb2gray(param_13).x;
    float2 param_14 = uv + float2(s);
    float3 param_15 = texture2DCv(refInput, refInputSmplr, param_14).xyz;
    float br = rgb2gray(param_15).x;
    gx = (((((-tl) - (2.0 * ml)) - bl) + tr) + (2.0 * mr)) + br;
    gy = (((((-tl) - (2.0 * tm)) - tr) + bl) + (2.0 * bm)) + br;
    float edge = sqrt((gx * gx) + (gy * gy));
    return smoothstep(threshold, threshold * 2.0, edge);
}

static inline __attribute__((always_inline))
float advancedEdge(thread const float2& uv, thread const float& threshold, constant ReferenceUniformseab75323f2408& _55, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = uv;
    float param_1 = threshold;
    float edge1 = sobelEdge(param, param_1, _55, refInput, refInputSmplr);
    float s2 = _55.outlineWidth * 0.00200000009499490261077880859375;
    float2 param_2 = uv;
    float3 param_3 = texture2DCv(refInput, refInputSmplr, param_2).xyz;
    float center = rgb2gray(param_3).x;
    float edge2 = 0.0;
    for (int i = 0; i < 8; i++)
    {
        float angle = (float(i) * 3.141590118408203125) / 4.0;
        float2 offset = float2(cos(angle), sin(angle)) * s2;
        float2 param_4 = uv + offset;
        float3 param_5 = texture2DCv(refInput, refInputSmplr, param_4).xyz;
        float ref_sample = rgb2gray(param_5).x;
        edge2 += abs(center - ref_sample);
    }
    edge2 /= 8.0;
    return fast::max(edge1, smoothstep(threshold * 0.5, threshold, edge2));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseab75323f2408& _55, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _55.refScreen.xy;
    float2 param = uv;
    float4 originalColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = uv;
    float param_2 = _55.edgeThreshold;
    float edge = advancedEdge(param_1, param_2, _55, refInput, refInputSmplr);
    if (_55.smoothEdges != 0u)
    {
        edge = smoothstep(0.0, 1.0, edge * _55.outlineIntensity);
    }
    else
    {
        edge = step(0.100000001490116119384765625, edge * _55.outlineIntensity);
    }
    float4 outline = float4(_55.outlineColor.xyz, _55.outlineColor.w * edge);
    float4 result;
    if (_55.preserveOriginal != 0u)
    {
        result = mix(originalColor, outline, float4(outline.w));
    }
    else
    {
        result = mix(originalColor, outline, float4(edge));
    }
    result.w = originalColor.w;
    referenceColor = result;
}

fragment refAM35_eab75323f2408_out refAM35_eab75323f2408(constant ReferenceUniformseab75323f2408& _55 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eab75323f2408_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_55, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _376 = any(isnan(referenceColor));
    bool _383;
    if (!_376)
    {
        _383 = any(isinf(referenceColor));
    }
    else
    {
        _383 = _376;
    }
    if (_383)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _396 = referenceColor;
    float3 _402 = fast::clamp(_396.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _402.x;
    referenceColor.y = _402.y;
    referenceColor.z = _402.z;
    out.finalColor = referenceColor;
    return out;
}

