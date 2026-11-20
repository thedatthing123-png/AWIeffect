// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/pixeledge.xml
// Original source comments and attribution:
// Pixelate Edge Detection with 3-Color Gradient
// Pixelate sample
// Sobel edge detection (on pixelated image)
// 3-color gradient mapping
#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wmissing-braces"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

template<typename T, size_t Num>
struct spvUnsafeArray
{
    T elements[Num ? Num : 1];
    
    thread T& operator [] (size_t pos) thread
    {
        return elements[pos];
    }
    constexpr const thread T& operator [] (size_t pos) const thread
    {
        return elements[pos];
    }
    
    device T& operator [] (size_t pos) device
    {
        return elements[pos];
    }
    constexpr const device T& operator [] (size_t pos) const device
    {
        return elements[pos];
    }
    
    constexpr const constant T& operator [] (size_t pos) const constant
    {
        return elements[pos];
    }
    
    threadgroup T& operator [] (size_t pos) threadgroup
    {
        return elements[pos];
    }
    constexpr const threadgroup T& operator [] (size_t pos) const threadgroup
    {
        return elements[pos];
    }
};

struct ReferenceUniformse75f2a17f4488
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float pixelSize;
    float4 color1;
    float4 color2;
    float4 color3;
    float edgeThresh;
    char _m10_pad[12];
    float gradientBias;
};

struct refAM35_e75f2a17f4488_out
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
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse75f2a17f4488& _48, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _48.refScreen.xy;
    float p = _48.pixelSize;
    float2 pixUV = (floor(uv / float2(p)) * p) + float2(0.5 * p);
    float2 param = pixUV;
    float4 pixCol = texture2DCv(refInput, refInputSmplr, param);
    float s = p * 1.0;
    float gx = 0.0;
    float gy = 0.0;
    spvUnsafeArray<float, 9> k;
    k[0] = -1.0;
    k[1] = 0.0;
    k[2] = 1.0;
    k[3] = -2.0;
    k[4] = 0.0;
    k[5] = 2.0;
    k[6] = -1.0;
    k[7] = 0.0;
    k[8] = 1.0;
    spvUnsafeArray<float, 9> l;
    l[0] = -1.0;
    l[1] = -2.0;
    l[2] = -1.0;
    l[3] = 0.0;
    l[4] = 0.0;
    l[5] = 0.0;
    l[6] = 1.0;
    l[7] = 2.0;
    l[8] = 1.0;
    int idx = 0;
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float2 o = float2(float(x), float(y)) * s;
            float2 param_1 = pixUV + o;
            float3 param_2 = texture2DCv(refInput, refInputSmplr, param_1).xyz;
            float gray = rgb2gray(param_2).x;
            gx += (gray * k[idx]);
            gy += (gray * l[idx]);
            idx++;
        }
    }
    float edge = sqrt((gx * gx) + (gy * gy));
    edge = smoothstep(_48.edgeThresh, 1.0, edge);
    float gradBias = fast::clamp(_48.gradientBias, 9.9999997473787516355514526367188e-05, 0.99989998340606689453125);
    float3 gradCol = mix(_48.color1.xyz, _48.color2.xyz, float3(smoothstep(0.0, gradBias, edge)));
    gradCol = mix(gradCol, _48.color3.xyz, float3(smoothstep(gradBias, 1.0, edge)));
    referenceColor = float4(gradCol, 1.0);
}

fragment refAM35_e75f2a17f4488_out refAM35_e75f2a17f4488(constant ReferenceUniformse75f2a17f4488& _48 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e75f2a17f4488_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _48, refInput, refInputSmplr, referenceColor);
    float nativeAlpha = refInput.sample(refInputSmplr, (gl_FragCoord.xy / _48.refScreen.xy)).w;
    referenceColor = float4(referenceColor.xyz * nativeAlpha, nativeAlpha);
    bool _255 = any(isnan(referenceColor));
    bool _262;
    if (!_255)
    {
        _262 = any(isinf(referenceColor));
    }
    else
    {
        _262 = _255;
    }
    if (_262)
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

