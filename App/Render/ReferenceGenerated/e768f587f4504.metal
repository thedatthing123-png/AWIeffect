// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/filters.xml
// Original source comments and attribution:
// Advanced CC Filters - Hand-crafted cinematic looks
// --- Procedural Textures ---
// Chromatic Aberration (RGB Split)
// VHS Jitter/Tracking
// --- Filter Algorithms ---
// Teal & Orange
// Tint
// Moody Blue
// Desaturate
// Autumn Gold
// Bleach Bypass
// Urban Cyber
// Magenta tint
// Vintage 70s
// Faded blacks
// Cold Winter
// Brighten
// Pastel Soft
// Gamma up
// Fog/Milk
// Dramatic B&W
// Noir
// Lower max whites
// Sunset Glow
// Deep Forest
// Polaroid
// Blue shadows
// Infrared
// Kodak Gold
// Night Vision
// Sepia Modern
// Technicolor
// Hollywood Gold
// Lomo
// 8mm Film
// Bleach Bypass II
// Cool Night Shift
// Warm Retro
// Cyberpunk Red
// Matrix
// Washed Out
// High Key
// Low Key
// Dreamy Mist
// --- Apply Overlays ---
// Master Overlay Integration
// Mapping by Filter Personality - ALL 30 Filters covered
// Flicker
// Apply intensity
// --- Global Adjustments ---
// Pro Overlays
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse768f587f4504
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int filterMode;
    char _m6_pad[12];
    float intensity;
    char _m7_pad[12];
    float overlayStrength;
    char _m8_pad[12];
    float vhsMode;
    char _m9_pad[12];
    float bloomStrength;
    char _m10_pad[12];
    float vignette;
    char _m11_pad[12];
    float brightness;
    char _m12_pad[12];
    float contrast;
    char _m13_pad[12];
    float saturation;
    char _m14_pad[12];
    float blend;
};

struct refAM35_e768f587f4504_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float hash(thread const float2& p)
{
    return fract(sin(dot(p, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float3 applyContrast(thread const float3& col, thread const float& con)
{
    return ((col - float3(0.5)) * con) + float3(0.5);
}

static inline __attribute__((always_inline))
float3 saturateCol(thread const float3& col, thread const float& sat)
{
    float grey = dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    return mix(float3(grey), col, float3(sat));
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i;
    float2 param_1 = i + float2(1.0, 0.0);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 param_3 = i + float2(1.0);
    return mix(mix(hash(param), hash(param_1), f.x), mix(hash(param_2), hash(param_3), f.x), f.y);
}

static inline __attribute__((always_inline))
float3 getLightLeaks(thread const float2& uv, thread const float& t)
{
    float2 p = uv + float2(t * 0.100000001490116119384765625, sin(t * 0.5) * 0.20000000298023223876953125);
    float2 param = p * 2.0;
    float n = _noise(param);
    float3 c1 = float3(1.0, 0.4000000059604644775390625, 0.20000000298023223876953125) * smoothstep(0.4000000059604644775390625, 0.800000011920928955078125, n);
    float2 param_1 = (p * 3.0) + float2(10.0);
    float3 c2 = float3(0.20000000298023223876953125, 0.4000000059604644775390625, 1.0) * smoothstep(0.4000000059604644775390625, 0.800000011920928955078125, _noise(param_1));
    return (c1 + c2) * 0.5;
}

static inline __attribute__((always_inline))
float3 applyBloom(thread const float3& col, thread const float& str)
{
    float luma = dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float3 highlight = col * smoothstep(0.60000002384185791015625, 1.0, luma);
    return col + ((highlight * str) * 2.0);
}

static inline __attribute__((always_inline))
float getGrain(thread const float2& uv, thread const float& t)
{
    float2 param = uv + float2(t);
    return hash(param);
}

static inline __attribute__((always_inline))
float getScratches(thread const float2& uv, thread const float& t)
{
    float x = uv.x * 200.0;
    float2 param = float2(floor(x), floor(t * 10.0));
    float r = hash(param);
    if (r > 0.9900000095367431640625)
    {
        return smoothstep(0.100000001490116119384765625, 0.0, abs(fract(x) - 0.5));
    }
    return 0.0;
}

static inline __attribute__((always_inline))
float getDust(thread const float2& uv, thread const float& t)
{
    float2 p = uv * 50.0;
    float2 param = p + float2(t * 5.0);
    float n = _noise(param);
    float2 param_1 = uv + float2(t);
    return step(0.980000019073486328125, n) * hash(param_1);
}

static inline __attribute__((always_inline))
float getStatic(thread const float2& uv, thread const float& t)
{
    float2 param = uv + float2(t * 20.0);
    return hash(param);
}

static inline __attribute__((always_inline))
float3 getGlitch(thread const float2& uv, thread const float& t, thread const float& str, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 gUv = uv;
    float2 param = float2(floor(t * 10.0), floor(uv.y * 10.0));
    float gNoise = hash(param);
    if (gNoise > 0.980000019073486328125)
    {
        float2 param_1 = float2(t);
        gUv.x += (((hash(param_1) - 0.5) * 0.0500000007450580596923828125) * str);
    }
    float2 param_2 = gUv;
    return texture2DCv(refInput, refInputSmplr, param_2).xyz;
}

static inline __attribute__((always_inline))
float getLensDirt(thread const float2& uv, thread const float& t)
{
    float2 param = (uv * 10.0) + float2(t * 0.0500000007450580596923828125);
    float dirt = _noise(param);
    return smoothstep(0.699999988079071044921875, 1.0, dirt) * 0.100000001490116119384765625;
}

static inline __attribute__((always_inline))
float3 applyVignette(thread const float3& col, thread const float2& uv, thread const float& str)
{
    float d = distance(uv, float2(0.5));
    return col * smoothstep(0.800000011920928955078125, 0.4000000059604644775390625 + ((1.0 - str) * 0.4000000059604644775390625), d);
}

static inline __attribute__((always_inline))
float3 applyLetterbox(thread const float3& col, thread const float2& uv, thread const float& str)
{
    float mask = step(0.100000001490116119384765625 * str, uv.y) * step(uv.y, 1.0 - (0.100000001490116119384765625 * str));
    return col * mask;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse768f587f4504& _399, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _399.refScreen.xy;
    float t = _399.refScreen.z;
    float ca = _399.vhsMode * 0.004999999888241291046142578125;
    float2 param = uv + float2(ca, 0.0);
    float4 srcR = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = uv;
    float4 srcG = texture2DCv(refInput, refInputSmplr, param_1);
    float2 param_2 = uv - float2(ca, 0.0);
    float4 srcB = texture2DCv(refInput, refInputSmplr, param_2);
    float3 col = float3(srcR.x, srcG.y, srcB.z);
    float alpha = srcG.w;
    if (_399.vhsMode > 0.100000001490116119384765625)
    {
        float2 param_3 = float2(t, uv.y);
        float jitter = ((hash(param_3) - 0.5) * 0.00999999977648258209228515625) * _399.vhsMode;
        float2 param_4 = float2(t * 0.5);
        if (hash(param_4) > 0.980000019073486328125)
        {
            uv.x += jitter;
        }
        float2 param_5 = uv;
        col = texture2DCv(refInput, refInputSmplr, param_5).xyz;
    }
    float3 filterCol = col;
    if (_399.filterMode == 0)
    {
        float luma = dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        filterCol.x = powr(col.x, 0.800000011920928955078125) * 1.25;
        filterCol.y = col.y;
        filterCol.z = powr(col.z, 1.2000000476837158203125) * 0.85000002384185791015625;
        filterCol = mix(filterCol, float3(luma * 1.5, luma * 1.0, luma * 0.800000011920928955078125), float3(0.1500000059604644775390625));
    }
    else
    {
        if (_399.filterMode == 1)
        {
            filterCol = col * float3(0.800000011920928955078125, 0.89999997615814208984375, 1.10000002384185791015625);
            float3 param_6 = filterCol;
            float param_7 = 1.2000000476837158203125;
            filterCol = applyContrast(param_6, param_7);
            filterCol = mix(filterCol, float3(dot(filterCol, float3(0.300000011920928955078125, 0.589999973773956298828125, 0.10999999940395355224609375))), float3(0.20000000298023223876953125));
        }
        else
        {
            if (_399.filterMode == 2)
            {
                filterCol = col * float3(1.14999997615814208984375, 0.949999988079071044921875, 0.800000011920928955078125);
                filterCol.x = smoothstep(0.0, 1.0, filterCol.x * 1.10000002384185791015625);
                filterCol.z = powr(filterCol.z, 1.2999999523162841796875);
            }
            else
            {
                if (_399.filterMode == 3)
                {
                    float luma_1 = dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
                    float3 _584;
                    if (luma_1 < 0.5)
                    {
                        _584 = (col * 2.0) * luma_1;
                    }
                    else
                    {
                        _584 = float3(1.0) - (((float3(1.0) - col) * 2.0) * (1.0 - luma_1));
                    }
                    float3 overlay = _584;
                    filterCol = mix(col, overlay, float3(0.60000002384185791015625));
                    float3 param_8 = filterCol;
                    float param_9 = 0.4000000059604644775390625;
                    filterCol = saturateCol(param_8, param_9);
                }
                else
                {
                    if (_399.filterMode == 4)
                    {
                        filterCol = col * float3(1.10000002384185791015625, 0.800000011920928955078125, 1.2000000476837158203125);
                        filterCol.x = powr(filterCol.x, 0.89999997615814208984375);
                        filterCol.z = powr(filterCol.z, 0.85000002384185791015625);
                        float3 param_10 = filterCol;
                        float param_11 = 1.10000002384185791015625;
                        filterCol = applyContrast(param_10, param_11);
                    }
                    else
                    {
                        if (_399.filterMode == 5)
                        {
                            filterCol = col * float3(1.10000002384185791015625, 1.0499999523162841796875, 0.85000002384185791015625);
                            filterCol = mix(filterCol, float3(0.20000000298023223876953125, 0.1500000059604644775390625, 0.100000001490116119384765625), float3(0.100000001490116119384765625));
                            float3 param_12 = filterCol;
                            float param_13 = 0.800000011920928955078125;
                            filterCol = saturateCol(param_12, param_13);
                        }
                        else
                        {
                            if (_399.filterMode == 6)
                            {
                                filterCol = col * float3(0.89999997615814208984375, 1.10000002384185791015625, 1.25);
                                filterCol += float3(0.0500000007450580596923828125);
                                float3 param_14 = filterCol;
                                float param_15 = 0.949999988079071044921875;
                                filterCol = applyContrast(param_14, param_15);
                            }
                            else
                            {
                                if (_399.filterMode == 7)
                                {
                                    filterCol = powr(col, float3(0.800000011920928955078125));
                                    float3 param_16 = filterCol;
                                    float param_17 = 1.10000002384185791015625;
                                    filterCol = saturateCol(param_16, param_17);
                                    filterCol = mix(filterCol, float3(1.0), float3(0.100000001490116119384765625));
                                }
                                else
                                {
                                    if (_399.filterMode == 8)
                                    {
                                        float luma_2 = dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
                                        filterCol = float3(powr(luma_2, 1.39999997615814208984375) * 1.2000000476837158203125);
                                        float3 param_18 = filterCol;
                                        float param_19 = 1.2999999523162841796875;
                                        filterCol = applyContrast(param_18, param_19);
                                    }
                                    else
                                    {
                                        if (_399.filterMode == 9)
                                        {
                                            float luma_3 = dot(col, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
                                            filterCol = float3(smoothstep(0.100000001490116119384765625, 0.89999997615814208984375, luma_3));
                                            filterCol *= 0.89999997615814208984375;
                                        }
                                        else
                                        {
                                            if (_399.filterMode == 10)
                                            {
                                                filterCol = col * float3(1.2999999523162841796875, 0.89999997615814208984375, 0.699999988079071044921875);
                                                filterCol.y = powr(filterCol.y, 1.10000002384185791015625);
                                                filterCol.z = powr(filterCol.z, 1.39999997615814208984375);
                                            }
                                            else
                                            {
                                                if (_399.filterMode == 11)
                                                {
                                                    filterCol = col * float3(0.89999997615814208984375, 1.14999997615814208984375, 0.949999988079071044921875);
                                                    float3 _750 = filterCol;
                                                    float2 _753 = powr(_750.xz, float2(1.2000000476837158203125));
                                                    filterCol.x = _753.x;
                                                    filterCol.z = _753.y;
                                                    filterCol = mix(filterCol, float3(0.0, 0.100000001490116119384765625, 0.0500000007450580596923828125), float3(0.100000001490116119384765625));
                                                }
                                                else
                                                {
                                                    if (_399.filterMode == 12)
                                                    {
                                                        filterCol = col * float3(1.0, 1.0, 0.89999997615814208984375);
                                                        float3 param_20 = filterCol;
                                                        float param_21 = 1.14999997615814208984375;
                                                        filterCol = applyContrast(param_20, param_21);
                                                        filterCol = mix(filterCol, float3(0.100000001490116119384765625, 0.100000001490116119384765625, 0.20000000298023223876953125), float3(0.100000001490116119384765625));
                                                        float3 param_22 = filterCol;
                                                        float param_23 = 0.89999997615814208984375;
                                                        filterCol = saturateCol(param_22, param_23);
                                                    }
                                                    else
                                                    {
                                                        if (_399.filterMode == 13)
                                                        {
                                                            float luma_4 = dot(col, float3(0.20999999344348907470703125, 0.7200000286102294921875, 0.070000000298023223876953125));
                                                            filterCol = float3(luma_4 * 1.2000000476837158203125, luma_4 * 0.5, luma_4 * 0.89999997615814208984375);
                                                            filterCol.x = smoothstep(0.100000001490116119384765625, 0.89999997615814208984375, filterCol.x);
                                                        }
                                                        else
                                                        {
                                                            if (_399.filterMode == 14)
                                                            {
                                                                filterCol = col * float3(1.10000002384185791015625, 1.0, 0.800000011920928955078125);
                                                                float3 param_24 = filterCol;
                                                                float param_25 = 1.25;
                                                                filterCol = saturateCol(param_24, param_25);
                                                                float3 param_26 = filterCol;
                                                                float param_27 = 1.10000002384185791015625;
                                                                filterCol = applyContrast(param_26, param_27);
                                                            }
                                                            else
                                                            {
                                                                if (_399.filterMode == 15)
                                                                {
                                                                    float luma_5 = dot(col, float3(0.20999999344348907470703125, 0.7200000286102294921875, 0.070000000298023223876953125));
                                                                    filterCol = float3(luma_5 * 0.20000000298023223876953125, luma_5 * 1.5, luma_5 * 0.20000000298023223876953125);
                                                                }
                                                                else
                                                                {
                                                                    if (_399.filterMode == 16)
                                                                    {
                                                                        float luma_6 = dot(col, float3(0.20999999344348907470703125, 0.7200000286102294921875, 0.070000000298023223876953125));
                                                                        filterCol = float3(luma_6) * float3(1.2000000476837158203125, 1.0, 0.800000011920928955078125);
                                                                        float3 param_28 = filterCol;
                                                                        float param_29 = 1.10000002384185791015625;
                                                                        filterCol = applyContrast(param_28, param_29);
                                                                    }
                                                                    else
                                                                    {
                                                                        if (_399.filterMode == 17)
                                                                        {
                                                                            filterCol = powr(col, float3(0.800000011920928955078125));
                                                                            float3 param_30 = filterCol;
                                                                            float param_31 = 1.5;
                                                                            filterCol = saturateCol(param_30, param_31);
                                                                            float3 param_32 = filterCol;
                                                                            float param_33 = 1.2000000476837158203125;
                                                                            filterCol = applyContrast(param_32, param_33);
                                                                        }
                                                                        else
                                                                        {
                                                                            if (_399.filterMode == 18)
                                                                            {
                                                                                filterCol = col * float3(1.14999997615814208984375, 1.0499999523162841796875, 0.89999997615814208984375);
                                                                                filterCol = mix(filterCol, float3(1.0, 0.800000011920928955078125, 0.5), float3(0.0500000007450580596923828125));
                                                                            }
                                                                            else
                                                                            {
                                                                                if (_399.filterMode == 19)
                                                                                {
                                                                                    float3 param_34 = col;
                                                                                    float param_35 = 1.2999999523162841796875;
                                                                                    filterCol = applyContrast(param_34, param_35);
                                                                                    filterCol.x = powr(filterCol.x, 0.89999997615814208984375);
                                                                                    float luma_7 = dot(col, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
                                                                                    filterCol = float3(smoothstep(0.100000001490116119384765625, 0.89999997615814208984375, luma_7));
                                                                                    filterCol *= 0.89999997615814208984375;
                                                                                }
                                                                                else
                                                                                {
                                                                                    if (_399.filterMode == 20)
                                                                                    {
                                                                                        filterCol = col * float3(1.10000002384185791015625, 0.949999988079071044921875, 0.800000011920928955078125);
                                                                                        float3 param_36 = filterCol;
                                                                                        float param_37 = 1.2000000476837158203125;
                                                                                        filterCol = applyContrast(param_36, param_37);
                                                                                        float2 param_38 = uv;
                                                                                        float param_39 = t;
                                                                                        filterCol += (getLightLeaks(param_38, param_39) * 0.300000011920928955078125);
                                                                                    }
                                                                                    else
                                                                                    {
                                                                                        if (_399.filterMode == 21)
                                                                                        {
                                                                                            float luma_8 = dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
                                                                                            filterCol = mix(col, float3(luma_8), float3(0.699999988079071044921875));
                                                                                            float3 param_40 = filterCol;
                                                                                            float param_41 = 1.5;
                                                                                            filterCol = applyContrast(param_40, param_41);
                                                                                        }
                                                                                        else
                                                                                        {
                                                                                            if (_399.filterMode == 22)
                                                                                            {
                                                                                                filterCol = col * float3(0.699999988079071044921875, 0.85000002384185791015625, 1.2000000476837158203125);
                                                                                                filterCol.x = powr(filterCol.x, 1.2999999523162841796875);
                                                                                            }
                                                                                            else
                                                                                            {
                                                                                                if (_399.filterMode == 23)
                                                                                                {
                                                                                                    filterCol = col * float3(1.2000000476837158203125, 1.10000002384185791015625, 0.89999997615814208984375);
                                                                                                    filterCol = mix(filterCol, float3(1.0, 0.89999997615814208984375, 0.699999988079071044921875), float3(0.100000001490116119384765625));
                                                                                                }
                                                                                                else
                                                                                                {
                                                                                                    if (_399.filterMode == 24)
                                                                                                    {
                                                                                                        filterCol = col * float3(1.39999997615814208984375, 0.5, 1.2000000476837158203125);
                                                                                                        float3 param_42 = filterCol;
                                                                                                        float param_43 = 1.2000000476837158203125;
                                                                                                        filterCol = applyContrast(param_42, param_43);
                                                                                                    }
                                                                                                    else
                                                                                                    {
                                                                                                        if (_399.filterMode == 25)
                                                                                                        {
                                                                                                            filterCol = col * float3(0.5, 1.39999997615814208984375, 0.5);
                                                                                                            float3 param_44 = filterCol;
                                                                                                            float param_45 = 1.2999999523162841796875;
                                                                                                            filterCol = applyContrast(param_44, param_45);
                                                                                                        }
                                                                                                        else
                                                                                                        {
                                                                                                            if (_399.filterMode == 26)
                                                                                                            {
                                                                                                                filterCol = (col * 0.800000011920928955078125) + float3(0.20000000298023223876953125);
                                                                                                                float3 param_46 = filterCol;
                                                                                                                float param_47 = 0.60000002384185791015625;
                                                                                                                filterCol = saturateCol(param_46, param_47);
                                                                                                            }
                                                                                                            else
                                                                                                            {
                                                                                                                if (_399.filterMode == 27)
                                                                                                                {
                                                                                                                    filterCol = powr(col, float3(0.699999988079071044921875)) * 1.10000002384185791015625;
                                                                                                                    float3 param_48 = filterCol;
                                                                                                                    float param_49 = 0.800000011920928955078125;
                                                                                                                    filterCol = saturateCol(param_48, param_49);
                                                                                                                }
                                                                                                                else
                                                                                                                {
                                                                                                                    if (_399.filterMode == 28)
                                                                                                                    {
                                                                                                                        filterCol = powr(col, float3(1.7999999523162841796875));
                                                                                                                        float3 param_50 = filterCol;
                                                                                                                        float param_51 = 1.10000002384185791015625;
                                                                                                                        filterCol = applyContrast(param_50, param_51);
                                                                                                                    }
                                                                                                                    else
                                                                                                                    {
                                                                                                                        if (_399.filterMode == 29)
                                                                                                                        {
                                                                                                                            float3 param_52 = col;
                                                                                                                            float param_53 = 0.5;
                                                                                                                            filterCol = applyBloom(param_52, param_53);
                                                                                                                            float3 param_54 = filterCol;
                                                                                                                            float param_55 = 1.10000002384185791015625;
                                                                                                                            filterCol = saturateCol(param_54, param_55);
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
    float2 param_56 = uv;
    float param_57 = t;
    float grain = getGrain(param_56, param_57) * 0.1500000059604644775390625;
    float2 param_58 = uv;
    float param_59 = t;
    float scratches = getScratches(param_58, param_59) * 0.5;
    float2 param_60 = uv;
    float param_61 = t;
    float dust = getDust(param_60, param_61) * 0.800000011920928955078125;
    float scanline = sin(uv.y * 800.0) * 0.039999999105930328369140625;
    float2 param_62 = uv;
    float param_63 = t;
    float3 leaks = getLightLeaks(param_62, param_63) * 0.60000002384185791015625;
    if (_399.overlayStrength > 0.00999999977648258209228515625)
    {
        bool _1118 = _399.filterMode == 5;
        bool _1125;
        if (!_1118)
        {
            _1125 = _399.filterMode == 12;
        }
        else
        {
            _1125 = _1118;
        }
        bool _1132;
        if (!_1125)
        {
            _1132 = _399.filterMode == 14;
        }
        else
        {
            _1132 = _1125;
        }
        bool _1139;
        if (!_1132)
        {
            _1139 = _399.filterMode == 16;
        }
        else
        {
            _1139 = _1132;
        }
        bool _1146;
        if (!_1139)
        {
            _1146 = _399.filterMode == 17;
        }
        else
        {
            _1146 = _1139;
        }
        bool _1153;
        if (!_1146)
        {
            _1153 = _399.filterMode == 19;
        }
        else
        {
            _1153 = _1146;
        }
        bool _1160;
        if (!_1153)
        {
            _1160 = _399.filterMode == 20;
        }
        else
        {
            _1160 = _1153;
        }
        bool _1167;
        if (!_1160)
        {
            _1167 = _399.filterMode == 23;
        }
        else
        {
            _1167 = _1160;
        }
        bool _1174;
        if (!_1167)
        {
            _1174 = _399.filterMode == 26;
        }
        else
        {
            _1174 = _1167;
        }
        bool isVintage = _1174;
        bool _1178 = _399.filterMode == 4;
        bool _1185;
        if (!_1178)
        {
            _1185 = _399.filterMode == 13;
        }
        else
        {
            _1185 = _1178;
        }
        bool _1192;
        if (!_1185)
        {
            _1192 = _399.filterMode == 15;
        }
        else
        {
            _1192 = _1185;
        }
        bool _1199;
        if (!_1192)
        {
            _1199 = _399.filterMode == 24;
        }
        else
        {
            _1199 = _1192;
        }
        bool _1206;
        if (!_1199)
        {
            _1206 = _399.filterMode == 25;
        }
        else
        {
            _1206 = _1199;
        }
        bool isDigital = _1206;
        bool _1210 = _399.filterMode == 2;
        bool _1217;
        if (!_1210)
        {
            _1217 = _399.filterMode == 6;
        }
        else
        {
            _1217 = _1210;
        }
        bool _1224;
        if (!_1217)
        {
            _1224 = _399.filterMode == 7;
        }
        else
        {
            _1224 = _1217;
        }
        bool _1231;
        if (!_1224)
        {
            _1231 = _399.filterMode == 10;
        }
        else
        {
            _1231 = _1224;
        }
        bool _1238;
        if (!_1231)
        {
            _1238 = _399.filterMode == 27;
        }
        else
        {
            _1238 = _1231;
        }
        bool _1245;
        if (!_1238)
        {
            _1245 = _399.filterMode == 29;
        }
        else
        {
            _1245 = _1238;
        }
        bool isBright = _1245;
        bool _1249 = _399.filterMode == 0;
        bool _1256;
        if (!_1249)
        {
            _1256 = _399.filterMode == 1;
        }
        else
        {
            _1256 = _1249;
        }
        bool _1263;
        if (!_1256)
        {
            _1263 = _399.filterMode == 3;
        }
        else
        {
            _1263 = _1256;
        }
        bool _1270;
        if (!_1263)
        {
            _1270 = _399.filterMode == 8;
        }
        else
        {
            _1270 = _1263;
        }
        bool _1277;
        if (!_1270)
        {
            _1277 = _399.filterMode == 9;
        }
        else
        {
            _1277 = _1270;
        }
        bool _1284;
        if (!_1277)
        {
            _1284 = _399.filterMode == 11;
        }
        else
        {
            _1284 = _1277;
        }
        bool _1291;
        if (!_1284)
        {
            _1291 = _399.filterMode == 18;
        }
        else
        {
            _1291 = _1284;
        }
        bool _1298;
        if (!_1291)
        {
            _1298 = _399.filterMode == 21;
        }
        else
        {
            _1298 = _1291;
        }
        bool _1305;
        if (!_1298)
        {
            _1305 = _399.filterMode == 22;
        }
        else
        {
            _1305 = _1298;
        }
        bool _1312;
        if (!_1305)
        {
            _1312 = _399.filterMode == 28;
        }
        else
        {
            _1312 = _1305;
        }
        bool isCinematic = _1312;
        if (isVintage)
        {
            filterCol += float3(((grain + scratches) + dust) * _399.overlayStrength);
            filterCol += ((leaks * _399.overlayStrength) * 0.5);
            filterCol *= (1.0 + ((sin(t * 12.0) * 0.0199999995529651641845703125) * _399.overlayStrength));
        }
        if (isDigital)
        {
            filterCol -= float3(scanline * _399.overlayStrength);
            float2 param_64 = uv;
            float param_65 = t;
            filterCol += float3((getStatic(param_64, param_65) * 0.0500000007450580596923828125) * _399.overlayStrength);
            float2 param_66 = float2(t);
            if (hash(param_66) > 0.980000019073486328125)
            {
                float2 param_67 = uv;
                float param_68 = t;
                float param_69 = _399.overlayStrength;
                filterCol = getGlitch(param_67, param_68, param_69, refInput, refInputSmplr);
            }
        }
        if (isBright)
        {
            float2 param_70 = uv;
            float param_71 = t;
            filterCol += float3(getLensDirt(param_70, param_71) * _399.overlayStrength);
            filterCol += ((leaks * 0.300000011920928955078125) * _399.overlayStrength);
            float3 param_72 = filterCol;
            float param_73 = 0.20000000298023223876953125 * _399.overlayStrength;
            filterCol = applyBloom(param_72, param_73);
        }
        if (isCinematic)
        {
            float3 param_74 = filterCol;
            float2 param_75 = uv;
            float param_76 = 0.60000002384185791015625 * _399.overlayStrength;
            filterCol = applyVignette(param_74, param_75, param_76);
            float3 param_77 = filterCol;
            float2 param_78 = uv;
            float param_79 = 0.5 * _399.overlayStrength;
            filterCol = applyLetterbox(param_77, param_78, param_79);
            filterCol += float3((grain * 0.100000001490116119384765625) * _399.overlayStrength);
        }
    }
    col = mix(col, filterCol, float3(_399.intensity));
    col += float3(_399.brightness);
    float3 param_80 = col;
    float param_81 = _399.contrast;
    col = applyContrast(param_80, param_81);
    float3 param_82 = col;
    float param_83 = _399.saturation;
    col = saturateCol(param_82, param_83);
    float3 param_84 = col;
    float param_85 = _399.bloomStrength;
    col = applyBloom(param_84, param_85);
    float3 param_86 = col;
    float2 param_87 = uv;
    float param_88 = _399.vignette;
    col = applyVignette(param_86, param_87, param_88);
    referenceColor = (float4(col, alpha) * _399.blend) + (srcG * (1.0 - _399.blend));
}

fragment refAM35_e768f587f4504_out refAM35_e768f587f4504(constant ReferenceUniformse768f587f4504& _399 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e768f587f4504_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _399, referenceColor);
    bool _1499 = any(isnan(referenceColor));
    bool _1506;
    if (!_1499)
    {
        _1506 = any(isinf(referenceColor));
    }
    else
    {
        _1506 = _1499;
    }
    if (_1506)
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

