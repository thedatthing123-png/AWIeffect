// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/omino-diffusion.xml
// Original source comments and attribution:
//v.x *= acScreenSize.y / acScreenSize.x;
// Black & white
// RGB 2-Level Posterize
// RGB 3-Level Posterize
// RGB 4-Level Posterize
// Gray 3 levels
// Gray 4 levels
// CGA Green/Red/Yellow
// CGA Cyan/Magenta/White
// CGA Blue/Cyan/Magenta/White
// Saturate and Posterize
//matchColor *= texColor.a;
// Multiply
// Screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse658cad5dcbff
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float angle;
    char _m6_pad[12];
    float strength;
    char _m7_pad[12];
    float steps;
    char _m8_pad[12];
    float errorWeight;
    char _m9_pad[12];
    float errorFalloff;
    char _m10_pad[12];
    int palette;
    char _m11_pad[12];
    float alpha;
    char _m12_pad[12];
    int blendMode;
    float4 color1;
    float4 color2;
    float4 color3;
    float4 color4;
    float4 color5;
    float4 color6;
};

struct refAM35_e658cad5dcbff_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rot2(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 saturate0(thread const float3& v)
{
    return fast::clamp(v, float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
float colorDiff(thread const float3& a, thread const float3& b)
{
    float3 d = abs(a - b);
    return (d.x + d.y) + d.z;
}

static inline __attribute__((always_inline))
void referenceMain(thread float3x3& rgb2yuv, thread float3x3& yuv2rgb, constant ReferenceUniformse658cad5dcbff& _117, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float param = (180.0 - _117.angle) * 0.01745329983532428741455078125;
    float2 v = float2(1.0, 0.0) * rot2(param);
    float2 dv = (v * _117.strength) / float2(_117.steps);
    float3 accumErr = float3(0.0);
    float4 outColor = float4(0.0);
    float3 _184;
    float3 matchColor;
    float3 _416;
    float3 _467;
    float3 _477;
    float3 _539;
    float3 _549;
    float3 _559;
    float3 _632;
    float3 _642;
    float3 _652;
    float3 _662;
    float3 _746;
    float3 _756;
    float3 _766;
    float3 _776;
    float3 _786;
    for (float i = _117.steps; i >= 0.0; i -= 1.0)
    {
        float pct = i / _117.steps;
        float2 param_1 = (gl_FragCoord.xy / _117.refScreen.xy) + (dv * i);
        float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
        if (texColor.w < 0.001000000047497451305389404296875)
        {
            _184 = float3(0.0);
        }
        else
        {
            _184 = texColor.xyz / float3(texColor.w);
        }
        float3 param_2 = _184 + accumErr;
        float3 baseColor = saturate0(param_2);
        if (_117.palette == 0)
        {
            float luminance = dot(baseColor, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            matchColor = select(float3(1.0), float3(0.0), bool3(luminance < 0.5));
        }
        else
        {
            if (_117.palette == 1)
            {
                matchColor = floor(baseColor * 2.0);
            }
            else
            {
                if (_117.palette == 2)
                {
                    matchColor = floor((baseColor + float3(0.25)) * 2.0) / float3(2.0);
                }
                else
                {
                    if (_117.palette == 3)
                    {
                        matchColor = floor((baseColor + float3(0.16666670143604278564453125)) * 3.0) / float3(3.0);
                    }
                    else
                    {
                        if (_117.palette == 4)
                        {
                            float luminance_1 = dot(baseColor, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
                            float adjLum = floor((luminance_1 + 0.25) * 2.0) / 2.0;
                            matchColor = float3(adjLum);
                        }
                        else
                        {
                            if (_117.palette == 5)
                            {
                                float luminance_2 = dot(baseColor, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
                                float adjLum_1 = floor((luminance_2 + 0.16666670143604278564453125) * 3.0) / 3.0;
                                matchColor = float3(adjLum_1);
                            }
                            else
                            {
                                if (_117.palette == 6)
                                {
                                    matchColor = floor(baseColor * 2.0);
                                    matchColor.z = 0.0;
                                }
                                else
                                {
                                    if (_117.palette == 7)
                                    {
                                        matchColor = floor(baseColor * 2.0);
                                        bool _320 = matchColor.x > 0.100000001490116119384765625;
                                        bool _327;
                                        if (!_320)
                                        {
                                            _327 = matchColor.y > 0.100000001490116119384765625;
                                        }
                                        else
                                        {
                                            _327 = _320;
                                        }
                                        matchColor.z = float(_327);
                                    }
                                    else
                                    {
                                        if (_117.palette == 8)
                                        {
                                            matchColor = floor(baseColor * 2.0);
                                            matchColor.z = 1.0;
                                        }
                                        else
                                        {
                                            if (_117.palette == 9)
                                            {
                                                float3 yuv = baseColor * rgb2yuv;
                                                float3 _352 = yuv;
                                                float2 _358 = ((_352.yz - float2(0.5)) * 2.0) + float2(0.5);
                                                yuv.y = _358.x;
                                                yuv.z = _358.y;
                                                yuv.x = floor((yuv.x + 0.16666699945926666259765625) * 3.0) / 3.0;
                                                matchColor = yuv * yuv2rgb;
                                            }
                                            else
                                            {
                                                if (_117.palette == 11)
                                                {
                                                    matchColor = _117.color1.xyz;
                                                }
                                                else
                                                {
                                                    if (_117.palette == 12)
                                                    {
                                                        float3 param_3 = baseColor;
                                                        float3 param_4 = _117.color1.xyz;
                                                        float d1 = colorDiff(param_3, param_4);
                                                        float3 param_5 = baseColor;
                                                        float3 param_6 = _117.color2.xyz;
                                                        float d2 = colorDiff(param_5, param_6);
                                                        float dmin = fast::min(d1, d2);
                                                        if (dmin == d1)
                                                        {
                                                            _416 = _117.color1.xyz;
                                                        }
                                                        else
                                                        {
                                                            _416 = _117.color2.xyz;
                                                        }
                                                        matchColor = _416;
                                                    }
                                                    else
                                                    {
                                                        if (_117.palette == 13)
                                                        {
                                                            float3 param_7 = baseColor;
                                                            float3 param_8 = _117.color1.xyz;
                                                            float d1_1 = colorDiff(param_7, param_8);
                                                            float3 param_9 = baseColor;
                                                            float3 param_10 = _117.color2.xyz;
                                                            float d2_1 = colorDiff(param_9, param_10);
                                                            float3 param_11 = baseColor;
                                                            float3 param_12 = _117.color3.xyz;
                                                            float d3 = colorDiff(param_11, param_12);
                                                            float dmin_1 = fast::min(fast::min(d1_1, d2_1), d3);
                                                            if (dmin_1 == d1_1)
                                                            {
                                                                _467 = _117.color1.xyz;
                                                            }
                                                            else
                                                            {
                                                                if (dmin_1 == d2_1)
                                                                {
                                                                    _477 = _117.color2.xyz;
                                                                }
                                                                else
                                                                {
                                                                    _477 = _117.color3.xyz;
                                                                }
                                                                _467 = _477;
                                                            }
                                                            matchColor = _467;
                                                        }
                                                        else
                                                        {
                                                            if (_117.palette == 14)
                                                            {
                                                                float3 param_13 = baseColor;
                                                                float3 param_14 = _117.color1.xyz;
                                                                float d1_2 = colorDiff(param_13, param_14);
                                                                float3 param_15 = baseColor;
                                                                float3 param_16 = _117.color2.xyz;
                                                                float d2_2 = colorDiff(param_15, param_16);
                                                                float3 param_17 = baseColor;
                                                                float3 param_18 = _117.color3.xyz;
                                                                float d3_1 = colorDiff(param_17, param_18);
                                                                float3 param_19 = baseColor;
                                                                float3 param_20 = _117.color4.xyz;
                                                                float d4 = colorDiff(param_19, param_20);
                                                                float dmin_2 = fast::min(fast::min(d1_2, d2_2), fast::min(d3_1, d4));
                                                                if (dmin_2 == d1_2)
                                                                {
                                                                    _539 = _117.color1.xyz;
                                                                }
                                                                else
                                                                {
                                                                    if (dmin_2 == d2_2)
                                                                    {
                                                                        _549 = _117.color2.xyz;
                                                                    }
                                                                    else
                                                                    {
                                                                        if (dmin_2 == d3_1)
                                                                        {
                                                                            _559 = _117.color3.xyz;
                                                                        }
                                                                        else
                                                                        {
                                                                            _559 = _117.color4.xyz;
                                                                        }
                                                                        _549 = _559;
                                                                    }
                                                                    _539 = _549;
                                                                }
                                                                matchColor = _539;
                                                            }
                                                            else
                                                            {
                                                                if (_117.palette == 15)
                                                                {
                                                                    float3 param_21 = baseColor;
                                                                    float3 param_22 = _117.color1.xyz;
                                                                    float d1_3 = colorDiff(param_21, param_22);
                                                                    float3 param_23 = baseColor;
                                                                    float3 param_24 = _117.color2.xyz;
                                                                    float d2_3 = colorDiff(param_23, param_24);
                                                                    float3 param_25 = baseColor;
                                                                    float3 param_26 = _117.color3.xyz;
                                                                    float d3_2 = colorDiff(param_25, param_26);
                                                                    float3 param_27 = baseColor;
                                                                    float3 param_28 = _117.color4.xyz;
                                                                    float d4_1 = colorDiff(param_27, param_28);
                                                                    float3 param_29 = baseColor;
                                                                    float3 param_30 = _117.color5.xyz;
                                                                    float d5 = colorDiff(param_29, param_30);
                                                                    float dmin_3 = fast::min(fast::min(fast::min(d1_3, d2_3), fast::min(d3_2, d4_1)), d5);
                                                                    if (dmin_3 == d1_3)
                                                                    {
                                                                        _632 = _117.color1.xyz;
                                                                    }
                                                                    else
                                                                    {
                                                                        if (dmin_3 == d2_3)
                                                                        {
                                                                            _642 = _117.color2.xyz;
                                                                        }
                                                                        else
                                                                        {
                                                                            if (dmin_3 == d3_2)
                                                                            {
                                                                                _652 = _117.color3.xyz;
                                                                            }
                                                                            else
                                                                            {
                                                                                if (dmin_3 == d4_1)
                                                                                {
                                                                                    _662 = _117.color4.xyz;
                                                                                }
                                                                                else
                                                                                {
                                                                                    _662 = _117.color5.xyz;
                                                                                }
                                                                                _652 = _662;
                                                                            }
                                                                            _642 = _652;
                                                                        }
                                                                        _632 = _642;
                                                                    }
                                                                    matchColor = _632;
                                                                }
                                                                else
                                                                {
                                                                    if (_117.palette == 16)
                                                                    {
                                                                        float3 param_31 = baseColor;
                                                                        float3 param_32 = _117.color1.xyz;
                                                                        float d1_4 = colorDiff(param_31, param_32);
                                                                        float3 param_33 = baseColor;
                                                                        float3 param_34 = _117.color2.xyz;
                                                                        float d2_4 = colorDiff(param_33, param_34);
                                                                        float3 param_35 = baseColor;
                                                                        float3 param_36 = _117.color3.xyz;
                                                                        float d3_3 = colorDiff(param_35, param_36);
                                                                        float3 param_37 = baseColor;
                                                                        float3 param_38 = _117.color4.xyz;
                                                                        float d4_2 = colorDiff(param_37, param_38);
                                                                        float3 param_39 = baseColor;
                                                                        float3 param_40 = _117.color5.xyz;
                                                                        float d5_1 = colorDiff(param_39, param_40);
                                                                        float3 param_41 = baseColor;
                                                                        float3 param_42 = _117.color6.xyz;
                                                                        float d6 = colorDiff(param_41, param_42);
                                                                        float dmin_4 = fast::min(fast::min(fast::min(d1_4, d2_4), fast::min(d3_3, d4_2)), fast::min(d5_1, d6));
                                                                        if (dmin_4 == d1_4)
                                                                        {
                                                                            _746 = _117.color1.xyz;
                                                                        }
                                                                        else
                                                                        {
                                                                            if (dmin_4 == d2_4)
                                                                            {
                                                                                _756 = _117.color2.xyz;
                                                                            }
                                                                            else
                                                                            {
                                                                                if (dmin_4 == d3_3)
                                                                                {
                                                                                    _766 = _117.color3.xyz;
                                                                                }
                                                                                else
                                                                                {
                                                                                    if (dmin_4 == d4_2)
                                                                                    {
                                                                                        _776 = _117.color4.xyz;
                                                                                    }
                                                                                    else
                                                                                    {
                                                                                        if (dmin_4 == d5_1)
                                                                                        {
                                                                                            _786 = _117.color5.xyz;
                                                                                        }
                                                                                        else
                                                                                        {
                                                                                            _786 = _117.color6.xyz;
                                                                                        }
                                                                                        _776 = _786;
                                                                                    }
                                                                                    _766 = _776;
                                                                                }
                                                                                _756 = _766;
                                                                            }
                                                                            _746 = _756;
                                                                        }
                                                                        matchColor = _746;
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
        }
        outColor = float4(matchColor, 1.0) * texColor.w;
        float3 err = baseColor - matchColor;
        accumErr = (err * _117.errorWeight) * mix(1.0, pct * pct, _117.errorFalloff);
    }
    float2 param_43 = gl_FragCoord.xy / _117.refScreen.xy;
    float4 origColor = texture2DCv(refInput, refInputSmplr, param_43);
    float4 result;
    if (_117.blendMode == 1)
    {
        float3 a = origColor.xyz / float3(fast::max(origColor.w, 9.9999997473787516355514526367188e-06));
        float3 b = outColor.xyz / float3(fast::max(outColor.w, 9.9999997473787516355514526367188e-06));
        result = float4(a * b, 1.0) * origColor.w;
    }
    else
    {
        if (_117.blendMode == 2)
        {
            float3 a_1 = origColor.xyz / float3(fast::max(origColor.w, 9.9999997473787516355514526367188e-06));
            float3 b_1 = outColor.xyz / float3(fast::max(outColor.w, 9.9999997473787516355514526367188e-06));
            result = float4(float3(1.0) - ((float3(1.0) - a_1) * (float3(1.0) - b_1)), 1.0) * origColor.w;
        }
        else
        {
            result = outColor;
        }
    }
    referenceColor = mix(origColor, result, float4(_117.alpha));
}

fragment refAM35_e658cad5dcbff_out refAM35_e658cad5dcbff(constant ReferenceUniformse658cad5dcbff& _117 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e658cad5dcbff_out out = {};
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float4 referenceColor = float4(0.0);
    referenceMain(rgb2yuv, yuv2rgb, _117, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _920 = any(isnan(referenceColor));
    bool _927;
    if (!_920)
    {
        _927 = any(isinf(referenceColor));
    }
    else
    {
        _927 = _920;
    }
    if (_927)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _940 = referenceColor;
    float3 _946 = fast::clamp(_940.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _946.x;
    referenceColor.y = _946.y;
    referenceColor.z = _946.z;
    out.finalColor = referenceColor;
    return out;
}

