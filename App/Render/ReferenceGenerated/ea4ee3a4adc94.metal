// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/palette-map.xml
// Original source comments and attribution:
// 0xFF = 255 = 1.000
// 0x55 =  85 = 0.333
// 0xAA = 170 = 0.667
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

struct ReferenceUniformsea4ee3a4adc94
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int palette;
    char _m6_pad[12];
    float alpha;
    float4 color1;
    float4 color2;
    float4 color3;
    float4 color4;
    float4 color5;
    float4 color6;
    float4 color7;
    float4 color8;
    uint shades;
};

struct refAM35_ea4ee3a4adc94_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsea4ee3a4adc94& _37, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _37.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float a = texColor.w;
    float3 rgb = texColor.xyz / float3(fast::max(9.9999997473787516355514526367188e-05, a));
    spvUnsafeArray<float3, 16> c;
    int ncolors;
    if (_37.palette == 0)
    {
        c[0] = float3(0.0);
        c[1] = float3(0.333000004291534423828125, 1.0, 0.333000004291534423828125);
        c[2] = float3(1.0, 0.333000004291534423828125, 0.333000004291534423828125);
        c[3] = float3(1.0, 1.0, 0.333000004291534423828125);
        ncolors = 4;
    }
    else
    {
        if (_37.palette == 1)
        {
            c[0] = float3(0.0);
            c[1] = float3(0.333000004291534423828125, 1.0, 1.0);
            c[2] = float3(1.0, 0.333000004291534423828125, 1.0);
            c[3] = float3(1.0);
            ncolors = 4;
        }
        else
        {
            if (_37.palette == 10)
            {
                c[0] = float3(0.333000004291534423828125, 0.333000004291534423828125, 1.0);
                c[1] = float3(0.333000004291534423828125, 1.0, 1.0);
                c[2] = float3(1.0, 0.333000004291534423828125, 1.0);
                c[3] = float3(1.0);
                ncolors = 4;
            }
            else
            {
                if (_37.palette == 2)
                {
                    c[0] = float3(0.0);
                    c[1] = float3(0.0, 0.0, 0.666999995708465576171875);
                    c[2] = float3(0.0, 0.666999995708465576171875, 0.0);
                    c[3] = float3(0.0, 0.666999995708465576171875, 0.666999995708465576171875);
                    c[4] = float3(0.666999995708465576171875, 0.0, 0.0);
                    c[5] = float3(0.666999995708465576171875, 0.0, 0.666999995708465576171875);
                    c[6] = float3(0.666999995708465576171875, 0.333000004291534423828125, 0.0);
                    c[7] = float3(0.666999995708465576171875);
                    c[8] = float3(0.333000004291534423828125);
                    c[9] = float3(0.333000004291534423828125, 0.333000004291534423828125, 1.0);
                    c[10] = float3(0.333000004291534423828125, 1.0, 0.333000004291534423828125);
                    c[11] = float3(0.333000004291534423828125, 1.0, 1.0);
                    c[12] = float3(1.0, 0.333000004291534423828125, 0.333000004291534423828125);
                    c[13] = float3(1.0, 0.333000004291534423828125, 1.0);
                    c[14] = float3(1.0, 1.0, 0.333000004291534423828125);
                    c[15] = float3(1.0);
                    ncolors = 16;
                }
                else
                {
                    if (_37.palette == 3)
                    {
                        c[0] = float3(0.0);
                        c[1] = float3(0.0, 0.0, 0.666999995708465576171875);
                        c[2] = float3(0.0, 0.666999995708465576171875, 0.0);
                        c[3] = float3(0.333000004291534423828125, 0.666999995708465576171875, 1.0);
                        c[4] = float3(0.666999995708465576171875, 0.0, 0.0);
                        c[5] = float3(0.666999995708465576171875, 0.0, 0.666999995708465576171875);
                        c[6] = float3(0.333000004291534423828125, 0.666999995708465576171875, 0.0);
                        c[7] = float3(0.666999995708465576171875);
                        c[8] = float3(0.333000004291534423828125);
                        c[9] = float3(0.333000004291534423828125, 0.333000004291534423828125, 1.0);
                        c[10] = float3(0.333000004291534423828125, 1.0, 0.333000004291534423828125);
                        c[11] = float3(0.333000004291534423828125, 1.0, 1.0);
                        c[12] = float3(1.0, 0.333000004291534423828125, 0.333000004291534423828125);
                        c[13] = float3(1.0, 0.333000004291534423828125, 1.0);
                        c[14] = float3(1.0, 1.0, 0.333000004291534423828125);
                        c[15] = float3(1.0);
                        ncolors = 16;
                    }
                    else
                    {
                        if (_37.palette == 4)
                        {
                            c[0] = float3(0.0);
                            c[1] = float3(0.333000004291534423828125, 0.333000004291534423828125, 1.0);
                            c[2] = float3(0.333000004291534423828125, 1.0, 0.333000004291534423828125);
                            c[3] = float3(0.333000004291534423828125, 1.0, 1.0);
                            c[4] = float3(1.0, 0.333000004291534423828125, 0.333000004291534423828125);
                            c[5] = float3(1.0, 0.333000004291534423828125, 1.0);
                            c[6] = float3(1.0, 1.0, 0.333000004291534423828125);
                            c[7] = float3(1.0);
                            ncolors = 8;
                        }
                        else
                        {
                            if (_37.palette == 5)
                            {
                                c[0] = float3(0.0);
                                c[1] = float3(0.333000004291534423828125);
                                c[2] = float3(0.666999995708465576171875);
                                c[3] = float3(1.0);
                                ncolors = 4;
                            }
                            else
                            {
                                if ((_37.palette == 6) && (_37.shades != 0u))
                                {
                                    c[0] = _37.color1.xyz;
                                    c[1] = _37.color2.xyz;
                                    c[2] = _37.color3.xyz;
                                    c[4] = _37.color1.xyz * 0.666999995708465576171875;
                                    c[5] = _37.color2.xyz * 0.666999995708465576171875;
                                    c[6] = _37.color3.xyz * 0.666999995708465576171875;
                                    ncolors = 6;
                                }
                                else
                                {
                                    if (_37.palette == 6)
                                    {
                                        c[0] = _37.color1.xyz;
                                        c[1] = _37.color2.xyz;
                                        c[2] = _37.color3.xyz;
                                        ncolors = 3;
                                    }
                                    else
                                    {
                                        if ((_37.palette == 7) && (_37.shades != 0u))
                                        {
                                            c[0] = _37.color1.xyz;
                                            c[1] = _37.color2.xyz;
                                            c[2] = _37.color3.xyz;
                                            c[3] = _37.color4.xyz;
                                            c[4] = _37.color1.xyz * 0.666999995708465576171875;
                                            c[5] = _37.color2.xyz * 0.666999995708465576171875;
                                            c[6] = _37.color3.xyz * 0.666999995708465576171875;
                                            c[7] = _37.color4.xyz * 0.666999995708465576171875;
                                            ncolors = 8;
                                        }
                                        else
                                        {
                                            if (_37.palette == 7)
                                            {
                                                c[0] = _37.color1.xyz;
                                                c[1] = _37.color2.xyz;
                                                c[2] = _37.color3.xyz;
                                                c[3] = _37.color4.xyz;
                                                ncolors = 4;
                                            }
                                            else
                                            {
                                                if ((_37.palette == 8) && (_37.shades != 0u))
                                                {
                                                    c[0] = _37.color1.xyz;
                                                    c[1] = _37.color2.xyz;
                                                    c[2] = _37.color3.xyz;
                                                    c[3] = _37.color4.xyz;
                                                    c[4] = _37.color5.xyz;
                                                    c[5] = _37.color6.xyz;
                                                    c[6] = _37.color1.xyz * 0.666999995708465576171875;
                                                    c[7] = _37.color2.xyz * 0.666999995708465576171875;
                                                    c[8] = _37.color3.xyz * 0.666999995708465576171875;
                                                    c[9] = _37.color4.xyz * 0.666999995708465576171875;
                                                    c[10] = _37.color5.xyz * 0.666999995708465576171875;
                                                    c[11] = _37.color6.xyz * 0.666999995708465576171875;
                                                    ncolors = 12;
                                                }
                                                else
                                                {
                                                    if (_37.palette == 8)
                                                    {
                                                        c[0] = _37.color1.xyz;
                                                        c[1] = _37.color2.xyz;
                                                        c[2] = _37.color3.xyz;
                                                        c[3] = _37.color4.xyz;
                                                        c[4] = _37.color5.xyz;
                                                        c[5] = _37.color6.xyz;
                                                        ncolors = 6;
                                                    }
                                                    else
                                                    {
                                                        if ((_37.palette == 9) && (_37.shades != 0u))
                                                        {
                                                            c[0] = _37.color1.xyz;
                                                            c[1] = _37.color2.xyz;
                                                            c[2] = _37.color3.xyz;
                                                            c[3] = _37.color4.xyz;
                                                            c[4] = _37.color5.xyz;
                                                            c[5] = _37.color6.xyz;
                                                            c[6] = _37.color7.xyz;
                                                            c[7] = _37.color8.xyz;
                                                            c[8] = _37.color1.xyz * 0.666999995708465576171875;
                                                            c[9] = _37.color2.xyz * 0.666999995708465576171875;
                                                            c[10] = _37.color3.xyz * 0.666999995708465576171875;
                                                            c[11] = _37.color4.xyz * 0.666999995708465576171875;
                                                            c[12] = _37.color5.xyz * 0.666999995708465576171875;
                                                            c[13] = _37.color6.xyz * 0.666999995708465576171875;
                                                            c[14] = _37.color7.xyz * 0.666999995708465576171875;
                                                            c[15] = _37.color8.xyz * 0.666999995708465576171875;
                                                            ncolors = 16;
                                                        }
                                                        else
                                                        {
                                                            if (_37.palette == 9)
                                                            {
                                                                c[0] = _37.color1.xyz;
                                                                c[1] = _37.color2.xyz;
                                                                c[2] = _37.color3.xyz;
                                                                c[3] = _37.color4.xyz;
                                                                c[4] = _37.color5.xyz;
                                                                c[5] = _37.color6.xyz;
                                                                c[6] = _37.color7.xyz;
                                                                c[7] = _37.color8.xyz;
                                                                ncolors = 8;
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    float3 bestColor = c[0];
    float bestDist = 100.0;
    for (int i = 0; i < ncolors; i++)
    {
        float l = length(c[i] - rgb);
        if (l < bestDist)
        {
            bestDist = l;
            bestColor = c[i];
        }
    }
    referenceColor = mix(texColor, float4(bestColor, 1.0) * a, float4(_37.alpha));
}

fragment refAM35_ea4ee3a4adc94_out refAM35_ea4ee3a4adc94(constant ReferenceUniformsea4ee3a4adc94& _37 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea4ee3a4adc94_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _37, referenceColor);
    bool _595 = any(isnan(referenceColor));
    bool _602;
    if (!_595)
    {
        _602 = any(isinf(referenceColor));
    }
    else
    {
        _602 = _595;
    }
    if (_602)
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

