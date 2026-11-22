// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/8bit.xml
// Original source comments and attribution:
// S_8Bit - Recreating Node Video's 8-bit effect with Bayer Dithering
// 1. Pixelation (Mosaic)
// Adjust scale based on screen size for consistent pixel size
// 2. Dithering Pre-pass
// 3. Palette Matching (Node Video style multi-color map)
// We compare the dithered color against the 7 provided palette colors
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

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformsef86ca044f297
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float mosaic;
    char _m6_pad[12];
    float dithering;
    float4 color1;
    float4 color2;
    float4 color3;
    float4 color4;
    float4 color5;
    float4 color6;
    float4 color7;
    float blending;
};

struct refAM35_ef86ca044f297_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float getDither(thread const float2& pos)
{
    int x = int(mod(pos.x, 4.0));
    int y = int(mod(pos.y, 4.0));
    if (x == 0)
    {
        if (y == 0)
        {
            return 0.0;
        }
        if (y == 1)
        {
            return 0.5;
        }
        if (y == 2)
        {
            return 0.125;
        }
        return 0.625;
    }
    else
    {
        if (x == 1)
        {
            if (y == 0)
            {
                return 0.75;
            }
            if (y == 1)
            {
                return 0.25;
            }
            if (y == 2)
            {
                return 0.875;
            }
            return 0.375;
        }
        else
        {
            if (x == 2)
            {
                if (y == 0)
                {
                    return 0.1875;
                }
                if (y == 1)
                {
                    return 0.6875;
                }
                if (y == 2)
                {
                    return 0.0625;
                }
                return 0.5625;
            }
            else
            {
                if (y == 0)
                {
                    return 0.9375;
                }
                if (y == 1)
                {
                    return 0.4375;
                }
                if (y == 2)
                {
                    return 0.8125;
                }
                return 0.3125;
            }
        }
    }
}

static inline __attribute__((always_inline))
float colorDist(thread const float3& c1, thread const float3& c2)
{
    return distance(c1, c2);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsef86ca044f297& _166, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _166.refScreen.xy;
    float resScale = _166.refScreen.y / 1080.0;
    float2 pixelSize = float2(_166.mosaic * resScale) / _166.refScreen.xy;
    float2 blockUv = (floor(uv / pixelSize) * pixelSize) + (pixelSize * 0.5);
    float2 param = blockUv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 col = src.xyz;
    float2 param_1 = (uv * _166.refScreen.xy) / float2(_166.mosaic * resScale);
    float ditherValue = getDither(param_1);
    col += float3((ditherValue - 0.5) * _166.dithering);
    spvUnsafeArray<float3, 7> palette;
    palette[0] = _166.color1.xyz;
    palette[1] = _166.color2.xyz;
    palette[2] = _166.color3.xyz;
    palette[3] = _166.color4.xyz;
    palette[4] = _166.color5.xyz;
    palette[5] = _166.color6.xyz;
    palette[6] = _166.color7.xyz;
    float3 closest = palette[0];
    float3 param_2 = col;
    float3 param_3 = palette[0];
    float minDist = colorDist(param_2, param_3);
    for (int i = 1; i < 7; i++)
    {
        float3 param_4 = col;
        float3 param_5 = palette[i];
        float d = colorDist(param_4, param_5);
        if (d < minDist)
        {
            minDist = d;
            closest = palette[i];
        }
    }
    float4 finalColor = float4(closest, src.w);
    float2 param_6 = uv;
    float4 original = texture2DCv(refInput, refInputSmplr, param_6);
    referenceColor = mix(original, finalColor, float4(_166.blending));
}

fragment refAM35_ef86ca044f297_out refAM35_ef86ca044f297(constant ReferenceUniformsef86ca044f297& _166 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef86ca044f297_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _166, refInput, refInputSmplr, referenceColor);
    bool _336 = any(isnan(referenceColor));
    bool _343;
    if (!_336)
    {
        _343 = any(isinf(referenceColor));
    }
    else
    {
        _343 = _336;
    }
    if (_343)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _357 = referenceColor;
    float3 _363 = fast::clamp(_357.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _363.x;
    referenceColor.y = _363.y;
    referenceColor.z = _363.z;
    out.finalColor = referenceColor;
    return out;
}

