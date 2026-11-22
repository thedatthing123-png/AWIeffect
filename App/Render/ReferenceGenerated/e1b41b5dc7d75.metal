// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_native_colorBlend.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse1b41b5dc7d75
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amount;
    char _m6_pad[12];
    float radius;
    char _m7_pad[12];
    float scale;
    float4 colorA;
    float4 colorB;
};

struct refAM35_e1b41b5dc7d75_out
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
float aeLum(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float4 aeBlur9(thread const float2& uv, thread const float2& d, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = uv;
    float4 s = texture2DCv(refInput, refInputSmplr, param) * 0.23999999463558197021484375;
    float2 param_1 = uv + float2(d.x, 0.0);
    float2 param_2 = uv - float2(d.x, 0.0);
    s += ((texture2DCv(refInput, refInputSmplr, param_1) + texture2DCv(refInput, refInputSmplr, param_2)) * 0.14000000059604644775390625);
    float2 param_3 = uv + float2(0.0, d.y);
    float2 param_4 = uv - float2(0.0, d.y);
    s += ((texture2DCv(refInput, refInputSmplr, param_3) + texture2DCv(refInput, refInputSmplr, param_4)) * 0.14000000059604644775390625);
    float2 param_5 = uv + d;
    float2 param_6 = uv - d;
    float2 param_7 = uv + float2(d.x, -d.y);
    float2 param_8 = uv + float2(-d.x, d.y);
    s += ((((texture2DCv(refInput, refInputSmplr, param_5) + texture2DCv(refInput, refInputSmplr, param_6)) + texture2DCv(refInput, refInputSmplr, param_7)) + texture2DCv(refInput, refInputSmplr, param_8)) * 0.0500000007450580596923828125);
    return s;
}

static inline __attribute__((always_inline))
float aeHash(thread const float2& p)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse1b41b5dc7d75& _164, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _164.refScreen.xy;
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 px = float2(1.0) / fast::max(getTexSize(param), float2(1.0));
    float2 param_1 = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param_1);
    float4 outc = src;
    float m = 4.0;
    float v = 8.0;
    float3 param_2 = src.xyz;
    float lum = aeLum(param_2);
    float2 param_3 = uv;
    float2 param_4 = px * fast::max(1.0, _164.radius * 0.3499999940395355224609375);
    float4 soft = aeBlur9(param_3, param_4, refInput, refInputSmplr);
    if (m < 0.5)
    {
        float3 param_5 = soft.xyz;
        float3 g = soft.xyz * smoothstep(0.3499999940395355224609375, 1.0, aeLum(param_5));
        float3 _240 = float3(1.0) - ((float3(1.0) - src.xyz) * (float3(1.0) - (g * 1.60000002384185791015625)));
        outc.x = _240.x;
        outc.y = _240.y;
        outc.z = _240.z;
    }
    else
    {
        if (m < 1.5)
        {
            float2 d = (px * _164.radius) * 0.449999988079071044921875;
            float2 param_6 = uv + d;
            float2 param_7 = uv - d;
            outc = float4(texture2DCv(refInput, refInputSmplr, param_6).x, src.y, texture2DCv(refInput, refInputSmplr, param_7).z, src.w);
        }
        else
        {
            if (m < 2.5)
            {
                float3 _296 = powr(fast::max(src.xyz, float3(0.0)), float3(mix(1.35000002384185791015625, 0.7200000286102294921875, _164.amount)));
                outc.x = _296.x;
                outc.y = _296.y;
                outc.z = _296.z;
                float4 _303 = outc;
                float3 _313 = ((_303.xyz - float3(0.5)) * (1.0 + (0.3499999940395355224609375 * _164.amount))) + float3(0.5);
                outc.x = _313.x;
                outc.y = _313.y;
                outc.z = _313.z;
            }
            else
            {
                if (m < 3.5)
                {
                    float3 warm = (soft.xyz * float3(1.35000002384185791015625, 0.62000000476837158203125, 0.2800000011920928955078125)) * smoothstep(0.4799999892711639404296875, 1.0, lum);
                    float3 _346 = float3(1.0) - ((float3(1.0) - src.xyz) * (float3(1.0) - warm));
                    outc.x = _346.x;
                    outc.y = _346.y;
                    outc.z = _346.z;
                }
                else
                {
                    if (m < 4.5)
                    {
                        float3 _379 = mix(src.xyz, (src.xyz * _164.colorA.xyz) + (_164.colorB.xyz * (1.0 - lum)), float3(_164.amount));
                        outc.x = _379.x;
                        outc.y = _379.y;
                        outc.z = _379.z;
                    }
                    else
                    {
                        if (m < 5.5)
                        {
                            float3 _412 = float3(1.0) - ((float3(1.0) - src.xyz) * (float3(1.0) - (soft.xyz * mix(_164.colorA.xyz, _164.colorB.xyz, float3(lum)))));
                            outc.x = _412.x;
                            outc.y = _412.y;
                            outc.z = _412.z;
                        }
                        else
                        {
                            if (m < 6.5)
                            {
                                float g_1 = smoothstep(0.0, 1.0, uv.y + (0.180000007152557373046875 * sin(uv.x * 6.28299999237060546875)));
                                float3 _447 = src.xyz * exp2(((g_1 - 0.5) * 3.0) * _164.amount);
                                outc.x = _447.x;
                                outc.y = _447.y;
                                outc.z = _447.z;
                            }
                            else
                            {
                                if (m < 8.5)
                                {
                                    float3 param_8 = soft.xyz;
                                    float3 glow = soft.xyz * smoothstep(0.4199999868869781494140625, 1.0, aeLum(param_8));
                                    float3 _481 = src.xyz + (glow * mix(_164.colorA.xyz, float3(1.0), float3(0.550000011920928955078125)));
                                    outc.x = _481.x;
                                    outc.y = _481.y;
                                    outc.z = _481.z;
                                }
                                else
                                {
                                    if (m < 9.5)
                                    {
                                        float rays = powr(fast::max(0.0, sin((precise::atan2(uv.y - 0.5, uv.x - 0.5) * 10.0) + _164.refScreen.z)), 12.0);
                                        float3 _520 = src.xyz + ((_164.colorA.xyz * rays) * lum);
                                        outc.x = _520.x;
                                        outc.y = _520.y;
                                        outc.z = _520.z;
                                    }
                                    else
                                    {
                                        if (m < 10.5)
                                        {
                                            float burn = smoothstep(0.20000000298023223876953125, 0.85000002384185791015625, lum + (0.180000007152557373046875 * sin(((uv.x + uv.y) * 24.0) + v)));
                                            float3 _567 = mix(src.xyz, (_164.colorA.xyz * burn) + (src.xyz * _164.colorB.xyz), float3(_164.amount));
                                            outc.x = _567.x;
                                            outc.y = _567.y;
                                            outc.z = _567.z;
                                        }
                                        else
                                        {
                                            if (m < 11.5)
                                            {
                                                float3 _619 = mix(src.xyz, float3((src.x * _164.colorA.x) + (src.y * _164.colorB.x), (src.y * _164.colorA.y) + (src.z * _164.colorB.y), (src.z * _164.colorA.z) + (src.x * _164.colorB.z)), float3(_164.amount));
                                                outc.x = _619.x;
                                                outc.y = _619.y;
                                                outc.z = _619.z;
                                            }
                                            else
                                            {
                                                if (m < 12.5)
                                                {
                                                    float3 _645 = src.xyz + (((soft.xyz * soft.xyz) * _164.colorA.xyz) * 1.39999997615814208984375);
                                                    outc.x = _645.x;
                                                    outc.y = _645.y;
                                                    outc.z = _645.z;
                                                }
                                                else
                                                {
                                                    if (m < 13.5)
                                                    {
                                                        float key = smoothstep(0.25, 0.75, abs(src.x - src.y) + abs(src.y - src.z));
                                                        float3 _688 = mix(src.xyz, src.zxy * _164.colorA.xyz, float3(key * _164.amount));
                                                        outc.x = _688.x;
                                                        outc.y = _688.y;
                                                        outc.z = _688.z;
                                                    }
                                                    else
                                                    {
                                                        if (m < 14.5)
                                                        {
                                                            float3 _711 = ((src.xyz - float3(0.5)) * (1.0 + (_164.amount * 0.550000011920928955078125))) + float3(0.5);
                                                            outc.x = _711.x;
                                                            outc.y = _711.y;
                                                            outc.z = _711.z;
                                                            float4 _721 = outc;
                                                            float3 _723 = _721.xyz * float3(1.059999942779541015625, 1.0, 0.949999988079071044921875);
                                                            outc.x = _723.x;
                                                            outc.y = _723.y;
                                                            outc.z = _723.z;
                                                        }
                                                        else
                                                        {
                                                            if (m < 15.5)
                                                            {
                                                                float2 param_9 = float2(int2(refInput.get_width(), refInput.get_height()));
                                                                float2 param_10 = floor((uv * getTexSize(param_9)) / float2(fast::max(1.0, _164.scale)));
                                                                float n = aeHash(param_10);
                                                                float3 _769 = floor((src.xyz * mix(10.0, 42.0, _164.amount)) + float3(n)) / float3(mix(10.0, 42.0, _164.amount));
                                                                outc.x = _769.x;
                                                                outc.y = _769.y;
                                                                outc.z = _769.z;
                                                            }
                                                            else
                                                            {
                                                                if (m < 16.5)
                                                                {
                                                                    float3 _805 = mix(src.xyz, mix(_164.colorA.xyz, _164.colorB.xyz, float3(fast::clamp(uv.x + (0.1599999964237213134765625 * sin(uv.y * 12.0)), 0.0, 1.0))), float3(_164.amount));
                                                                    outc.x = _805.x;
                                                                    outc.y = _805.y;
                                                                    outc.z = _805.z;
                                                                }
                                                                else
                                                                {
                                                                    if (m < 17.5)
                                                                    {
                                                                        float3 pal = mix(_164.colorA.xyz, _164.colorB.xyz, float3(step(0.5, fract((lum * 4.0) + (v * 0.100000001490116119384765625)))));
                                                                        float3 _845 = mix(src.xyz, pal * mix(0.550000011920928955078125, 1.25, lum), float3(_164.amount));
                                                                        outc.x = _845.x;
                                                                        outc.y = _845.y;
                                                                        outc.z = _845.z;
                                                                    }
                                                                    else
                                                                    {
                                                                        if (m < 18.5)
                                                                        {
                                                                            float pulse = powr(fast::max(0.0, sin((_164.refScreen.z * 9.0) + v)), 18.0);
                                                                            float3 _875 = src.xyz + float3(pulse * 2.2000000476837158203125);
                                                                            outc.x = _875.x;
                                                                            outc.y = _875.y;
                                                                            outc.z = _875.z;
                                                                        }
                                                                        else
                                                                        {
                                                                            if (m < 19.5)
                                                                            {
                                                                                float2 param_11 = uv;
                                                                                float2 param_12 = float2(px.x * _164.radius, 0.0);
                                                                                float3 h = aeBlur9(param_11, param_12, refInput, refInputSmplr).xyz;
                                                                                float3 _906 = src.xyz + (h * _164.amount);
                                                                                outc.x = _906.x;
                                                                                outc.y = _906.y;
                                                                                outc.z = _906.z;
                                                                            }
                                                                            else
                                                                            {
                                                                                float2 param_13 = float2(int2(refInput.get_width(), refInput.get_height()));
                                                                                float2 param_14 = floor((uv * getTexSize(param_13)) / float2(2.0 + (_164.scale * 3.0)));
                                                                                float n_1 = aeHash(param_14);
                                                                                float3 _952 = mix(src.xyz, (src.xyz * mix(_164.colorA.xyz, _164.colorB.xyz, float3(n_1))) * 1.7000000476837158203125, float3(_164.amount));
                                                                                outc.x = _952.x;
                                                                                outc.y = _952.y;
                                                                                outc.z = _952.z;
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
            }
        }
    }
    referenceColor = mix(src, outc, float4(fast::clamp(_164.amount, 0.0, 1.0)));
    referenceColor.w = src.w;
}

fragment refAM35_e1b41b5dc7d75_out refAM35_e1b41b5dc7d75(constant ReferenceUniformse1b41b5dc7d75& _164 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e1b41b5dc7d75_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _164, referenceColor);
    bool _977 = any(isnan(referenceColor));
    bool _984;
    if (!_977)
    {
        _984 = any(isinf(referenceColor));
    }
    else
    {
        _984 = _977;
    }
    if (_984)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _996 = referenceColor;
    float3 _1002 = fast::clamp(_996.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1002.x;
    referenceColor.y = _1002.y;
    referenceColor.z = _1002.z;
    out.finalColor = referenceColor;
    return out;
}

