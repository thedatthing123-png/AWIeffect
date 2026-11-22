// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/grunge.xml
// Original source comments and attribution:
//p - (tc * (1.-p));
// Edge
// Center
// Fill
// Edge
// Center
// Fill
// Glow
// Multiply
// Screen
// Punch out
// Punch out
// Normal
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformse616b758142ef
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    uint t1active;
    char _m7_pad[12];
    int t1region;
    char _m8_pad[12];
    float t1grain;
    char _m9_pad[12];
    float t1scale;
    char _m10_pad[12];
    float t1angle;
    char _m11_pad[8];
    float2 t1offset;
    char _m12_pad[8];
    float t1gamma;
    char _m13_pad[12];
    float t1contrast;
    char _m14_pad[12];
    float t1alpha;
    float4 t1color;
    float t1burn;
    char _m17_pad[12];
    float t1spread;
    char _m18_pad[12];
    float t1choke;
    char _m19_pad[12];
    uint t1invert;
    char _m20_pad[12];
    uint t1light;
    char _m21_pad[12];
    float t1lightAngle;
    char _m22_pad[12];
    int t1blendMode;
    char _m23_pad[12];
    uint t2active;
    char _m24_pad[12];
    int t2region;
    char _m25_pad[12];
    float t2grain;
    char _m26_pad[12];
    float t2scale;
    char _m27_pad[12];
    float t2angle;
    char _m28_pad[8];
    float2 t2offset;
    char _m29_pad[8];
    float t2gamma;
    char _m30_pad[12];
    float t2contrast;
    char _m31_pad[12];
    float t2alpha;
    float4 t2color;
    float t2burn;
    char _m34_pad[12];
    float t2spread;
    char _m35_pad[12];
    float t2choke;
    char _m36_pad[12];
    uint t2invert;
    char _m37_pad[12];
    uint t2light;
    char _m38_pad[12];
    float t2lightAngle;
    char _m39_pad[12];
    int t2blendMode;
    char _m40_pad[12];
    uint t3active;
    char _m41_pad[12];
    int t3region;
    char _m42_pad[12];
    float t3grain;
    char _m43_pad[12];
    float t3scale;
    char _m44_pad[12];
    float t3angle;
    char _m45_pad[8];
    float2 t3offset;
    char _m46_pad[8];
    float t3gamma;
    char _m47_pad[12];
    float t3contrast;
    char _m48_pad[12];
    float t3alpha;
    float4 t3color;
    float t3burn;
    char _m51_pad[12];
    float t3spread;
    char _m52_pad[12];
    float t3choke;
    char _m53_pad[12];
    uint t3invert;
    char _m54_pad[12];
    uint t3light;
    char _m55_pad[12];
    float t3lightAngle;
    char _m56_pad[12];
    int t3blendMode;
    char _m57_pad[12];
    uint t4active;
    char _m58_pad[12];
    int t4region;
    char _m59_pad[12];
    float t4grain;
    char _m60_pad[12];
    float t4scale;
    char _m61_pad[12];
    float t4angle;
    char _m62_pad[8];
    float2 t4offset;
    char _m63_pad[8];
    float t4gamma;
    char _m64_pad[12];
    float t4contrast;
    char _m65_pad[12];
    float t4alpha;
    float4 t4color;
    float t4burn;
    char _m68_pad[12];
    float t4spread;
    char _m69_pad[12];
    float t4choke;
    char _m70_pad[12];
    uint t4invert;
    char _m71_pad[12];
    uint t4light;
    char _m72_pad[12];
    float t4lightAngle;
    char _m73_pad[12];
    int t4blendMode;
    char _m74_pad[12];
    uint t5active;
    char _m75_pad[12];
    int t5region;
    char _m76_pad[12];
    float t5grain;
    char _m77_pad[12];
    float t5scale;
    char _m78_pad[12];
    float t5angle;
    char _m79_pad[8];
    float2 t5offset;
    char _m80_pad[8];
    float t5gamma;
    char _m81_pad[12];
    float t5contrast;
    char _m82_pad[12];
    float t5alpha;
    float4 t5color;
    float t5burn;
    char _m85_pad[12];
    float t5spread;
    char _m86_pad[12];
    float t5choke;
    char _m87_pad[12];
    uint t5invert;
    char _m88_pad[12];
    uint t5light;
    char _m89_pad[12];
    float t5lightAngle;
    char _m90_pad[12];
    int t5blendMode;
    char _m91_pad[12];
    uint t6active;
    char _m92_pad[12];
    int t6region;
    char _m93_pad[12];
    float t6grain;
    char _m94_pad[12];
    float t6scale;
    char _m95_pad[12];
    float t6angle;
    char _m96_pad[8];
    float2 t6offset;
    char _m97_pad[8];
    float t6gamma;
    char _m98_pad[12];
    float t6contrast;
    char _m99_pad[12];
    float t6alpha;
    float4 t6color;
    float t6burn;
    char _m102_pad[12];
    float t6spread;
    char _m103_pad[12];
    float t6choke;
    char _m104_pad[12];
    uint t6invert;
    char _m105_pad[12];
    uint t6light;
    char _m106_pad[12];
    float t6lightAngle;
    char _m107_pad[12];
    int t6blendMode;
    char _m108_pad[12];
    uint t7active;
    char _m109_pad[12];
    int t7region;
    char _m110_pad[12];
    float t7grain;
    char _m111_pad[12];
    float t7scale;
    char _m112_pad[12];
    float t7angle;
    char _m113_pad[8];
    float2 t7offset;
    char _m114_pad[8];
    float t7gamma;
    char _m115_pad[12];
    float t7contrast;
    char _m116_pad[12];
    float t7alpha;
    float4 t7color;
    float t7burn;
    char _m119_pad[12];
    float t7spread;
    char _m120_pad[12];
    float t7choke;
    char _m121_pad[12];
    uint t7invert;
    char _m122_pad[12];
    uint t7light;
    char _m123_pad[12];
    float t7lightAngle;
    char _m124_pad[12];
    int t7blendMode;
    char _m125_pad[12];
    uint t8active;
    char _m126_pad[12];
    int t8region;
    char _m127_pad[12];
    float t8grain;
    char _m128_pad[12];
    float t8scale;
    char _m129_pad[12];
    float t8angle;
    char _m130_pad[8];
    float2 t8offset;
    char _m131_pad[8];
    float t8gamma;
    char _m132_pad[12];
    float t8contrast;
    char _m133_pad[12];
    float t8alpha;
    float4 t8color;
    float t8burn;
    char _m136_pad[12];
    float t8spread;
    char _m137_pad[12];
    float t8choke;
    char _m138_pad[12];
    uint t8invert;
    char _m139_pad[12];
    uint t8light;
    char _m140_pad[12];
    float t8lightAngle;
    char _m141_pad[12];
    int t8blendMode;
    char _m142_pad[12];
    uint d1active;
    char _m143_pad[12];
    int d1region;
    char _m144_pad[8];
    float2 d1offset;
    char _m145_pad[8];
    uint d1fromctr;
    char _m146_pad[12];
    float d1grain;
    char _m147_pad[12];
    float d1scale;
    char _m148_pad[12];
    float d1angle;
    char _m149_pad[8];
    float2 d1toffset;
    char _m150_pad[8];
    float d1gamma;
    char _m151_pad[12];
    float d1contrast;
    char _m152_pad[12];
    uint d2active;
    char _m153_pad[12];
    int d2region;
    char _m154_pad[8];
    float2 d2offset;
    char _m155_pad[8];
    uint d2fromctr;
    char _m156_pad[12];
    float d2grain;
    char _m157_pad[12];
    float d2scale;
    char _m158_pad[12];
    float d2angle;
    char _m159_pad[8];
    float2 d2toffset;
    char _m160_pad[8];
    float d2gamma;
    char _m161_pad[12];
    float d2contrast;
    char _m162_pad[12];
    uint c1active;
    float4 fillColor;
    float fillColorBlend;
};

struct refAM35_e616b758142ef_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float saturate0(thread const float& v)
{
    return fast::clamp(v, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float2x2 rot2(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, s), float2(-s, c));
}

static inline __attribute__((always_inline))
float sampleGrain(thread float2& uv, thread const int& grainType, thread const float& gamma, thread const float& contrast, thread const float& scale, thread const float& angle, thread const float2& offset, thread const bool& invert, texture2d<float> refImage1, sampler refImage1Smplr, texture2d<float> refImage2, sampler refImage2Smplr)
{
    uv -= float2(0.5);
    float param = angle * 0.01745329983532428741455078125;
    uv *= rot2(param);
    uv /= float2(scale);
    uv += float2(0.5);
    uv -= ((offset * float2(1.0, -1.0)) / float2(500.0));
    uv = fract(uv);
    float grainLuma;
    if (grainType == 1)
    {
        grainLuma = refImage1.sample(refImage1Smplr, uv).x;
    }
    else
    {
        if (grainType == 2)
        {
            grainLuma = refImage1.sample(refImage1Smplr, uv).y;
        }
        else
        {
            if (grainType == 3)
            {
                grainLuma = refImage1.sample(refImage1Smplr, uv).z;
            }
            else
            {
                if (grainType == 4)
                {
                    grainLuma = refImage2.sample(refImage2Smplr, uv).x;
                }
                else
                {
                    if (grainType == 5)
                    {
                        grainLuma = refImage2.sample(refImage2Smplr, uv).y;
                    }
                    else
                    {
                        if (grainType == 6)
                        {
                            grainLuma = refImage2.sample(refImage2Smplr, uv).z;
                        }
                        else
                        {
                            if (grainType == 7)
                            {
                                grainLuma = dot(refImage1.sample(refImage1Smplr, uv).xyz, float3(1.0)) / 3.0;
                            }
                            else
                            {
                                if (grainType == 8)
                                {
                                    grainLuma = dot(refImage2.sample(refImage2Smplr, uv).xyz, float3(1.0)) / 3.0;
                                }
                                else
                                {
                                    if (grainType == 9)
                                    {
                                        grainLuma = dot(refImage2.sample(refImage2Smplr, uv).xz, float2(1.0)) / 2.0;
                                    }
                                    else
                                    {
                                        if (grainType == 10)
                                        {
                                            uv *= 16.0;
                                            float2 st = fract(uv);
                                            float2 id = floor(uv);
                                            if (mod(id.x + id.y, 2.0) == 0.0)
                                            {
                                                st = st.yx;
                                            }
                                            float pp = 6.0;
                                            float p = powr(sin((st.x * 3.141590118408203125) * 1.0), pp);
                                            st = st.yx;
                                            float q = fast::clamp(powr(sin((st.x * 3.141590118408203125) * 1.0), pp), 0.0, 1.0);
                                            p += (q * powr(1.0 - p, 10.0));
                                            grainLuma = p;
                                        }
                                        else
                                        {
                                            if (grainType == 11)
                                            {
                                                float2 st_1 = uv * 16.0;
                                                float2 id_1 = floor(st_1);
                                                st_1 = fract(st_1);
                                                if (mod(id_1.x + id_1.y, 2.0) == 0.0)
                                                {
                                                    st_1 = st_1.yx;
                                                }
                                                float pp_1 = 6.0;
                                                float p_1 = powr(sin((st_1.x * 3.141590118408203125) * 1.0), pp_1);
                                                st_1 = st_1.yx;
                                                float q_1 = fast::clamp(powr(sin((st_1.x * 3.141590118408203125) * 1.0), pp_1), 0.0, 1.0);
                                                p_1 += (q_1 * powr(1.0 - p_1, 10.0));
                                                float param_1 = p_1;
                                                p_1 = saturate0(param_1);
                                                float tc = refImage2.sample(refImage2Smplr, uv).z;
                                                grainLuma = p_1 * abs(p_1 - tc);
                                            }
                                            else
                                            {
                                                if (grainType == 12)
                                                {
                                                    grainLuma = (sin((uv.y * 30.0) * 3.141590118408203125) * 0.5) + 0.5;
                                                }
                                                else
                                                {
                                                    if (grainType == 13)
                                                    {
                                                        grainLuma = fast::min((sin((uv.y * 30.0) * 3.141590118408203125) * 0.5) + 0.5, (sin((uv.x * 30.0) * 3.141590118408203125) * 0.5) + 0.5);
                                                    }
                                                    else
                                                    {
                                                        if (grainType == 14)
                                                        {
                                                            grainLuma = ((sin((uv.y * 30.0) * 3.141590118408203125) * sin((uv.x * 30.0) * 3.141590118408203125)) * 0.5) + 0.5;
                                                        }
                                                        else
                                                        {
                                                            if (grainType == 15)
                                                            {
                                                                grainLuma = uv.y;
                                                            }
                                                            else
                                                            {
                                                                if (grainType == 16)
                                                                {
                                                                    grainLuma = 1.0;
                                                                }
                                                                else
                                                                {
                                                                    grainLuma = 0.5;
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
    float param_2 = ((grainLuma - 0.5) * (1.0 + contrast)) + 0.5;
    grainLuma = saturate0(param_2);
    grainLuma = powr(grainLuma, 1.0 / gamma);
    if (invert)
    {
        grainLuma = 1.0 - grainLuma;
    }
    return grainLuma;
}

static inline __attribute__((always_inline))
float2 applyDisplace(thread const float2& displace, thread const float4& blurColor, thread const float2& offset, thread const bool& fromCtr, thread const int& region, thread const float2& uv, thread const int& grainType, thread const float& gamma, thread const float& contrast, thread const float& scale, thread const float& angle, thread const float2& texOffset, texture2d<float> refImage1, sampler refImage1Smplr, texture2d<float> refImage2, sampler refImage2Smplr)
{
    float p;
    if (region == 1)
    {
        float param = (blurColor.w - 0.5) * 2.0;
        p = 1.0 - saturate0(param);
    }
    else
    {
        if (region == 2)
        {
            float param_1 = (blurColor.w - 0.5) * 2.0;
            p = saturate0(param_1);
        }
        else
        {
            if (region == 3)
            {
                p = 1.0;
            }
            else
            {
                p = 0.0;
            }
        }
    }
    float2 param_2 = uv;
    int param_3 = grainType;
    float param_4 = gamma;
    float param_5 = contrast;
    float param_6 = scale;
    float param_7 = angle;
    float2 param_8 = texOffset;
    bool param_9 = false;
    float _520 = sampleGrain(param_2, param_3, param_4, param_5, param_6, param_7, param_8, param_9, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
    float g = _520;
    if (fromCtr)
    {
        g = (g - 0.5) * 2.0;
    }
    return displace + ((((offset * float2(1.0, -1.0)) / float2(2000.0)) * g) * p);
}

static inline __attribute__((always_inline))
float4 composite(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
float4 blendGrain(thread const float4& baseColor, thread const float4& originalColor, thread const float4& blurColor, thread const float4& color, thread const float& alpha, thread const int& blendMode, thread const int& region, thread const float& spread, thread const float& rawChoke, thread const float& burn, thread const float2& uv, thread const int& grainType, thread const float& gamma, thread const float& contrast, thread const float& scale, thread const float& angle, thread const float2& offset, thread const bool& invert, thread const bool& light, thread const float& lightAngle, texture2d<float> refImage1, sampler refImage1Smplr, texture2d<float> refImage2, sampler refImage2Smplr)
{
    float choke = fast::clamp(rawChoke, 0.0, 0.999000012874603271484375);
    float m;
    float p;
    if (region == 1)
    {
        m = baseColor.w;
        float param = (blurColor.w - 0.5) * 2.0;
        p = 1.0 - saturate0(param);
    }
    else
    {
        if (region == 2)
        {
            m = baseColor.w;
            float param_1 = (blurColor.w - 0.5) * 2.0;
            p = saturate0(param_1);
        }
        else
        {
            if (region == 3)
            {
                m = baseColor.w;
                p = 1.0;
            }
            else
            {
                if (region == 4)
                {
                    m = 1.0 - baseColor.w;
                    float param_2 = (blurColor.w * 2.0) - baseColor.w;
                    p = saturate0(param_2);
                }
                else
                {
                    m = 0.0;
                    p = 0.0;
                }
            }
        }
    }
    float param_3 = (p - choke) / (fast::max(1.0 - spread, choke + 9.9999997473787516355514526367188e-05) - choke);
    p = saturate0(param_3);
    float g;
    if (light)
    {
        float param_4 = lightAngle * 0.01745329983532428741455078125;
        float2 lv = float2(0.00200000009499490261077880859375, 0.0) * rot2(param_4);
        float2 param_5 = uv + lv;
        int param_6 = grainType;
        float param_7 = gamma;
        float param_8 = contrast;
        float param_9 = scale;
        float param_10 = angle;
        float2 param_11 = offset;
        bool param_12 = invert;
        float _640 = sampleGrain(param_5, param_6, param_7, param_8, param_9, param_10, param_11, param_12, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
        float g1 = _640;
        float2 param_13 = uv - lv;
        int param_14 = grainType;
        float param_15 = gamma;
        float param_16 = contrast;
        float param_17 = scale;
        float param_18 = angle;
        float2 param_19 = offset;
        bool param_20 = invert;
        float _660 = sampleGrain(param_13, param_14, param_15, param_16, param_17, param_18, param_19, param_20, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
        float g2 = _660;
        float param_21 = (g1 - g2) * 5.0;
        g = saturate0(param_21);
    }
    else
    {
        float2 param_22 = uv;
        int param_23 = grainType;
        float param_24 = gamma;
        float param_25 = contrast;
        float param_26 = scale;
        float param_27 = angle;
        float2 param_28 = offset;
        bool param_29 = invert;
        float _686 = sampleGrain(param_22, param_23, param_24, param_25, param_26, param_27, param_28, param_29, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
        g = _686;
    }
    float4 c = color;
    if (burn < 0.0)
    {
        float4 _693 = c;
        float4 _695 = c;
        float4 _699 = c;
        float3 _716 = mix(_693.xyz, float3(1.0) - ((float3(1.0) - _695.xyz) * (float3(1.0) - (float3(0.5) + (_699.xyz * 0.5)))), float3(((-burn) * g) * g));
        c.x = _716.x;
        c.y = _716.y;
        c.z = _716.z;
    }
    else
    {
        float4 _724 = c;
        float4 _726 = c;
        float4 _728 = c;
        float3 _739 = mix(_724.xyz, (_726.xyz * _728.xyz) * 0.25, float3((burn * g) * g));
        c.x = _739.x;
        c.y = _739.y;
        c.z = _739.z;
    }
    c *= ((alpha * p) * g);
    if (region == 4)
    {
        float4 param_30 = baseColor;
        float4 param_31 = c * m;
        return composite(param_30, param_31);
    }
    else
    {
        if (blendMode == 1)
        {
            float3 baseRgb = baseColor.xyz / float3(fast::max(baseColor.w, 9.9999997473787516355514526367188e-06));
            float3 rgb = c.xyz / float3(fast::max(c.w, 9.9999997473787516355514526367188e-06));
            float3 adj = baseRgb * rgb;
            float4 param_32 = baseColor;
            float4 param_33 = (float4(adj, 1.0) * c.w) * baseColor.w;
            return composite(param_32, param_33);
        }
        else
        {
            if (blendMode == 2)
            {
                float3 baseRgb_1 = baseColor.xyz / float3(fast::max(baseColor.w, 9.9999997473787516355514526367188e-06));
                float3 rgb_1 = c.xyz / float3(fast::max(c.w, 9.9999997473787516355514526367188e-06));
                float3 adj_1 = float3(1.0) - ((float3(1.0) - baseRgb_1) * (float3(1.0) - rgb_1));
                float4 param_34 = baseColor;
                float4 param_35 = (float4(adj_1, 1.0) * c.w) * baseColor.w;
                return composite(param_34, param_35);
            }
            else
            {
                if (blendMode == 3)
                {
                    return baseColor * (1.0 - c.w);
                }
                else
                {
                    if (blendMode == 4)
                    {
                        float4 param_36 = baseColor;
                        float4 param_37 = originalColor * (c.w * m);
                        return composite(param_36, param_37);
                    }
                    else
                    {
                        float4 param_38 = baseColor;
                        float4 param_39 = c * m;
                        return composite(param_38, param_39);
                    }
                }
            }
        }
    }
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refImage1, sampler refImage1Smplr, texture2d<float> refImage2, sampler refImage2Smplr, texture2d<float> refBuffer3, sampler refBuffer3Smplr, thread float4& gl_FragCoord, constant ReferenceUniformse616b758142ef& _901, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _901.refScreen.xy;
    float4 blurTexColor = texture2DCv(refBuffer3, refBuffer3Smplr, param);
    float2 uv = (gl_FragCoord.xy - _901.refLayer.xy) / _901.refLayer.zw;
    uv.x *= (_901.refLayer.z / _901.refLayer.w);
    float2 displace = float2(0.0);
    float2 param_1 = displace;
    float4 param_2 = blurTexColor;
    float2 param_3 = _901.d1offset;
    bool param_4 = _901.d1fromctr != 0u;
    int param_5 = _901.d1region;
    float2 param_6 = uv;
    int param_7 = int(_901.d1grain);
    float param_8 = _901.d1gamma;
    float param_9 = _901.d1contrast;
    float param_10 = _901.d1scale;
    float param_11 = _901.d1angle;
    float2 param_12 = _901.d1toffset;
    displace = applyDisplace(param_1, param_2, param_3, param_4, param_5, param_6, param_7, param_8, param_9, param_10, param_11, param_12, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
    uv += displace;
    float2 param_13 = displace;
    float4 param_14 = blurTexColor;
    float2 param_15 = _901.d2offset;
    bool param_16 = _901.d2fromctr != 0u;
    int param_17 = _901.d2region;
    float2 param_18 = uv;
    int param_19 = int(_901.d2grain);
    float param_20 = _901.d2gamma;
    float param_21 = _901.d2contrast;
    float param_22 = _901.d2scale;
    float param_23 = _901.d2angle;
    float2 param_24 = _901.d2toffset;
    displace = applyDisplace(param_13, param_14, param_15, param_16, param_17, param_18, param_19, param_20, param_21, param_22, param_23, param_24, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
    uv += displace;
    displace.x *= (_901.refScreen.x / _901.refScreen.y);
    float2 param_25 = (gl_FragCoord.xy / _901.refScreen.xy) + displace;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_25);
    texColor = mix(texColor, _901.fillColor * texColor.w, float4(_901.fillColorBlend));
    float4 result = texColor;
    int _1071;
    if (_901.t1active != 0u)
    {
        _1071 = _901.t1region;
    }
    else
    {
        _1071 = 0;
    }
    float4 param_26 = result;
    float4 param_27 = texColor;
    float4 param_28 = blurTexColor;
    float4 param_29 = _901.t1color;
    float param_30 = _901.t1alpha;
    int param_31 = _901.t1blendMode;
    int param_32 = _1071;
    float param_33 = _901.t1spread;
    float param_34 = _901.t1choke;
    float param_35 = _901.t1burn;
    float2 param_36 = uv;
    int param_37 = int(_901.t1grain);
    float param_38 = _901.t1gamma;
    float param_39 = _901.t1contrast;
    float param_40 = _901.t1scale;
    float param_41 = _901.t1angle;
    float2 param_42 = _901.t1offset;
    bool param_43 = _901.t1invert != 0u;
    bool param_44 = _901.t1light != 0u;
    float param_45 = _901.t1lightAngle;
    result = blendGrain(param_26, param_27, param_28, param_29, param_30, param_31, param_32, param_33, param_34, param_35, param_36, param_37, param_38, param_39, param_40, param_41, param_42, param_43, param_44, param_45, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
    int _1148;
    if (_901.t2active != 0u)
    {
        _1148 = _901.t2region;
    }
    else
    {
        _1148 = 0;
    }
    float4 param_46 = result;
    float4 param_47 = texColor;
    float4 param_48 = blurTexColor;
    float4 param_49 = _901.t2color;
    float param_50 = _901.t2alpha;
    int param_51 = _901.t2blendMode;
    int param_52 = _1148;
    float param_53 = _901.t2spread;
    float param_54 = _901.t2choke;
    float param_55 = _901.t2burn;
    float2 param_56 = uv;
    int param_57 = int(_901.t2grain);
    float param_58 = _901.t2gamma;
    float param_59 = _901.t2contrast;
    float param_60 = _901.t2scale;
    float param_61 = _901.t2angle;
    float2 param_62 = _901.t2offset;
    bool param_63 = _901.t2invert != 0u;
    bool param_64 = _901.t2light != 0u;
    float param_65 = _901.t2lightAngle;
    result = blendGrain(param_46, param_47, param_48, param_49, param_50, param_51, param_52, param_53, param_54, param_55, param_56, param_57, param_58, param_59, param_60, param_61, param_62, param_63, param_64, param_65, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
    int _1233;
    if (_901.t3active != 0u)
    {
        _1233 = _901.t3region;
    }
    else
    {
        _1233 = 0;
    }
    float4 param_66 = result;
    float4 param_67 = texColor;
    float4 param_68 = blurTexColor;
    float4 param_69 = _901.t3color;
    float param_70 = _901.t3alpha;
    int param_71 = _901.t3blendMode;
    int param_72 = _1233;
    float param_73 = _901.t3spread;
    float param_74 = _901.t3choke;
    float param_75 = _901.t3burn;
    float2 param_76 = uv;
    int param_77 = int(_901.t3grain);
    float param_78 = _901.t3gamma;
    float param_79 = _901.t3contrast;
    float param_80 = _901.t3scale;
    float param_81 = _901.t3angle;
    float2 param_82 = _901.t3offset;
    bool param_83 = _901.t3invert != 0u;
    bool param_84 = _901.t3light != 0u;
    float param_85 = _901.t3lightAngle;
    result = blendGrain(param_66, param_67, param_68, param_69, param_70, param_71, param_72, param_73, param_74, param_75, param_76, param_77, param_78, param_79, param_80, param_81, param_82, param_83, param_84, param_85, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
    int _1318;
    if (_901.t4active != 0u)
    {
        _1318 = _901.t4region;
    }
    else
    {
        _1318 = 0;
    }
    float4 param_86 = result;
    float4 param_87 = texColor;
    float4 param_88 = blurTexColor;
    float4 param_89 = _901.t4color;
    float param_90 = _901.t4alpha;
    int param_91 = _901.t4blendMode;
    int param_92 = _1318;
    float param_93 = _901.t4spread;
    float param_94 = _901.t4choke;
    float param_95 = _901.t4burn;
    float2 param_96 = uv;
    int param_97 = int(_901.t4grain);
    float param_98 = _901.t4gamma;
    float param_99 = _901.t4contrast;
    float param_100 = _901.t4scale;
    float param_101 = _901.t4angle;
    float2 param_102 = _901.t4offset;
    bool param_103 = _901.t4invert != 0u;
    bool param_104 = _901.t4light != 0u;
    float param_105 = _901.t4lightAngle;
    result = blendGrain(param_86, param_87, param_88, param_89, param_90, param_91, param_92, param_93, param_94, param_95, param_96, param_97, param_98, param_99, param_100, param_101, param_102, param_103, param_104, param_105, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
    int _1403;
    if (_901.t5active != 0u)
    {
        _1403 = _901.t5region;
    }
    else
    {
        _1403 = 0;
    }
    float4 param_106 = result;
    float4 param_107 = texColor;
    float4 param_108 = blurTexColor;
    float4 param_109 = _901.t5color;
    float param_110 = _901.t5alpha;
    int param_111 = _901.t5blendMode;
    int param_112 = _1403;
    float param_113 = _901.t5spread;
    float param_114 = _901.t5choke;
    float param_115 = _901.t5burn;
    float2 param_116 = uv;
    int param_117 = int(_901.t5grain);
    float param_118 = _901.t5gamma;
    float param_119 = _901.t5contrast;
    float param_120 = _901.t5scale;
    float param_121 = _901.t5angle;
    float2 param_122 = _901.t5offset;
    bool param_123 = _901.t5invert != 0u;
    bool param_124 = _901.t5light != 0u;
    float param_125 = _901.t5lightAngle;
    result = blendGrain(param_106, param_107, param_108, param_109, param_110, param_111, param_112, param_113, param_114, param_115, param_116, param_117, param_118, param_119, param_120, param_121, param_122, param_123, param_124, param_125, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
    int _1488;
    if (_901.t6active != 0u)
    {
        _1488 = _901.t6region;
    }
    else
    {
        _1488 = 0;
    }
    float4 param_126 = result;
    float4 param_127 = texColor;
    float4 param_128 = blurTexColor;
    float4 param_129 = _901.t6color;
    float param_130 = _901.t6alpha;
    int param_131 = _901.t6blendMode;
    int param_132 = _1488;
    float param_133 = _901.t6spread;
    float param_134 = _901.t6choke;
    float param_135 = _901.t6burn;
    float2 param_136 = uv;
    int param_137 = int(_901.t6grain);
    float param_138 = _901.t6gamma;
    float param_139 = _901.t6contrast;
    float param_140 = _901.t6scale;
    float param_141 = _901.t6angle;
    float2 param_142 = _901.t6offset;
    bool param_143 = _901.t6invert != 0u;
    bool param_144 = _901.t6light != 0u;
    float param_145 = _901.t6lightAngle;
    result = blendGrain(param_126, param_127, param_128, param_129, param_130, param_131, param_132, param_133, param_134, param_135, param_136, param_137, param_138, param_139, param_140, param_141, param_142, param_143, param_144, param_145, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
    int _1573;
    if (_901.t7active != 0u)
    {
        _1573 = _901.t7region;
    }
    else
    {
        _1573 = 0;
    }
    float4 param_146 = result;
    float4 param_147 = texColor;
    float4 param_148 = blurTexColor;
    float4 param_149 = _901.t7color;
    float param_150 = _901.t7alpha;
    int param_151 = _901.t7blendMode;
    int param_152 = _1573;
    float param_153 = _901.t7spread;
    float param_154 = _901.t7choke;
    float param_155 = _901.t7burn;
    float2 param_156 = uv;
    int param_157 = int(_901.t7grain);
    float param_158 = _901.t7gamma;
    float param_159 = _901.t7contrast;
    float param_160 = _901.t7scale;
    float param_161 = _901.t7angle;
    float2 param_162 = _901.t7offset;
    bool param_163 = _901.t7invert != 0u;
    bool param_164 = _901.t7light != 0u;
    float param_165 = _901.t7lightAngle;
    result = blendGrain(param_146, param_147, param_148, param_149, param_150, param_151, param_152, param_153, param_154, param_155, param_156, param_157, param_158, param_159, param_160, param_161, param_162, param_163, param_164, param_165, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
    int _1658;
    if (_901.t8active != 0u)
    {
        _1658 = _901.t8region;
    }
    else
    {
        _1658 = 0;
    }
    float4 param_166 = result;
    float4 param_167 = texColor;
    float4 param_168 = blurTexColor;
    float4 param_169 = _901.t8color;
    float param_170 = _901.t8alpha;
    int param_171 = _901.t8blendMode;
    int param_172 = _1658;
    float param_173 = _901.t8spread;
    float param_174 = _901.t8choke;
    float param_175 = _901.t8burn;
    float2 param_176 = uv;
    int param_177 = int(_901.t8grain);
    float param_178 = _901.t8gamma;
    float param_179 = _901.t8contrast;
    float param_180 = _901.t8scale;
    float param_181 = _901.t8angle;
    float2 param_182 = _901.t8offset;
    bool param_183 = _901.t8invert != 0u;
    bool param_184 = _901.t8light != 0u;
    float param_185 = _901.t8lightAngle;
    result = blendGrain(param_166, param_167, param_168, param_169, param_170, param_171, param_172, param_173, param_174, param_175, param_176, param_177, param_178, param_179, param_180, param_181, param_182, param_183, param_184, param_185, refImage1, refImage1Smplr, refImage2, refImage2Smplr);
    referenceColor = result;
}

fragment refAM35_e616b758142ef_out refAM35_e616b758142ef(constant ReferenceUniformse616b758142ef& _901 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], texture2d<float> refImage2 [[texture(2)]], texture2d<float> refBuffer3 [[texture(3)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], sampler refImage2Smplr [[sampler(2)]], sampler refBuffer3Smplr [[sampler(3)]], float4 gl_FragCoord [[position]])
{
    refAM35_e616b758142ef_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refImage1, refImage1Smplr, refImage2, refImage2Smplr, refBuffer3, refBuffer3Smplr, gl_FragCoord, _901, refInput, refInputSmplr, referenceColor);
    bool _1744 = any(isnan(referenceColor));
    bool _1751;
    if (!_1744)
    {
        _1751 = any(isinf(referenceColor));
    }
    else
    {
        _1751 = _1744;
    }
    if (_1751)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1764 = referenceColor;
    float3 _1770 = fast::clamp(_1764.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1770.x;
    referenceColor.y = _1770.y;
    referenceColor.z = _1770.z;
    out.finalColor = referenceColor;
    return out;
}

