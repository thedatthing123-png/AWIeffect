// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/AE CC Toner.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec9d67f3d02bc
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 shadowColor;
    float shadowStrength;
    char _m7_pad[12];
    float shadowRange;
    float4 midColor;
    float midStrength;
    char _m10_pad[12];
    float midRange;
    char _m11_pad[12];
    float midWidth;
    float4 highlightColor;
    float highlightStrength;
    char _m14_pad[12];
    float highlightRange;
    char _m15_pad[12];
    int blendMode;
    char _m16_pad[12];
    float tonerMix;
    char _m17_pad[12];
    uint preserveLuminance;
    char _m18_pad[12];
    float contrast;
    char _m19_pad[12];
    float saturation;
    char _m20_pad[12];
    float gamma;
    char _m21_pad[12];
    float overallStrength;
    char _m22_pad[12];
    uint tonerOnly;
};

struct refAM35_ec9d67f3d02bc_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 srgbToLinear(thread const float3& c)
{
    float3 cut = step(float3(0.040449999272823333740234375), c);
    return mix(c / float3(12.9200000762939453125), powr((c + float3(0.054999999701976776123046875)) / float3(1.05499994754791259765625), float3(2.400000095367431640625)), cut);
}

static inline __attribute__((always_inline))
float luminance(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float3 applyToner(thread const float3& col, thread const float& lum, thread const float3& shadCol, thread const float& shadStr, thread const float& shadRange, thread const float3& midCol, thread const float& midStr, thread const float& midCtr, thread const float& midW, thread const float3& hiCol, thread const float& hiStr, thread const float& hiRange)
{
    float shadowMask = smoothstep(shadRange, 0.0, lum);
    float highlightMask = smoothstep(hiRange, 1.0, lum);
    float midMask = smoothstep(0.0, midW, lum - (midCtr - midW)) * smoothstep(0.0, midW, (midCtr + midW) - lum);
    float3 toned = col;
    toned = mix(toned, shadCol, float3(shadowMask * shadStr));
    toned = mix(toned, midCol, float3(midMask * midStr));
    toned = mix(toned, hiCol, float3(highlightMask * hiStr));
    return toned;
}

static inline __attribute__((always_inline))
float3 linearToSrgb(thread float3& c)
{
    c = fast::max(c, float3(0.0));
    float3 cut = step(float3(0.003130800090730190277099609375), c);
    return mix(c * 12.9200000762939453125, (powr(c, float3(0.4166666567325592041015625)) * 1.05499994754791259765625) - float3(0.054999999701976776123046875), cut);
}

static inline __attribute__((always_inline))
float3 blendOverlay(thread const float3& base, thread const float3& blend)
{
    float3 low = (base * 2.0) * blend;
    float3 high = float3(1.0) - (((float3(1.0) - base) * 2.0) * (float3(1.0) - blend));
    return mix(low, high, step(float3(0.5), base));
}

static inline __attribute__((always_inline))
float3 applyColorGrade(thread float3& col, thread const float& cont, thread const float& sat, thread const float& gam)
{
    float3 param = col;
    float lum = luminance(param);
    col = mix(float3(lum), col, float3(sat));
    col = ((col - float3(0.5)) * cont) + float3(0.5);
    col = powr(fast::clamp(col, float3(9.9999997473787516355514526367188e-05), float3(1.0)), float3(1.0 / fast::max(gam, 0.001000000047497451305389404296875)));
    return fast::clamp(col, float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsec9d67f3d02bc& _240, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _240.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 col = src.xyz;
    float3 param_1 = col;
    float3 colLin = srgbToLinear(param_1);
    float3 param_2 = colLin;
    float lum = luminance(param_2);
    lum = powr(fast::clamp(lum, 0.0, 1.0), 1.0 / fast::max(_240.gamma, 0.001000000047497451305389404296875));
    float3 param_3 = col;
    float param_4 = lum;
    float3 param_5 = _240.shadowColor.xyz;
    float param_6 = _240.shadowStrength;
    float param_7 = _240.shadowRange;
    float3 param_8 = _240.midColor.xyz;
    float param_9 = _240.midStrength;
    float param_10 = _240.midRange;
    float param_11 = _240.midWidth;
    float3 param_12 = _240.highlightColor.xyz;
    float param_13 = _240.highlightStrength;
    float param_14 = _240.highlightRange;
    float3 toned = applyToner(param_3, param_4, param_5, param_6, param_7, param_8, param_9, param_10, param_11, param_12, param_13, param_14);
    float bmf = float(_240.blendMode);
    float3 result;
    if (bmf < 1.5)
    {
        float3 param_15 = toned;
        float3 param_16 = srgbToLinear(param_15);
        float tonedLum = luminance(param_16);
        result = toned;
        if (_240.preserveLuminance != 0u)
        {
            float3 param_17 = colLin;
            float origLum = luminance(param_17);
            float scale = origLum / fast::max(tonedLum, 9.9999997473787516355514526367188e-05);
            result = fast::clamp(toned * scale, float3(0.0), float3(1.0));
        }
    }
    else
    {
        if (bmf < 2.5)
        {
            float3 param_18 = colLin;
            float origLum_1 = luminance(param_18);
            float3 param_19 = toned;
            float3 tonedLin = srgbToLinear(param_19);
            float3 param_20 = tonedLin;
            float tonedLumV = luminance(param_20);
            float3 chromaToned = tonedLin / float3(fast::max(tonedLumV, 9.9999997473787516355514526367188e-05));
            float3 param_21 = fast::clamp(chromaToned * origLum_1, float3(0.0), float3(1.0));
            float3 _396 = linearToSrgb(param_21);
            result = _396;
        }
        else
        {
            float3 param_22 = col;
            float3 param_23 = toned;
            result = blendOverlay(param_22, param_23);
        }
    }
    result = mix(result, toned, float3(_240.tonerMix));
    float3 param_24 = result;
    float param_25 = _240.contrast;
    float param_26 = _240.saturation;
    float param_27 = 1.0;
    float3 _421 = applyColorGrade(param_24, param_25, param_26, param_27);
    result = _421;
    result = mix(col, result, float3(_240.overallStrength));
    if (_240.tonerOnly != 0u)
    {
        float3 param_28 = col;
        float3 param_29 = srgbToLinear(param_28);
        float lumOnly = luminance(param_29);
        float shadowM = smoothstep(_240.shadowRange, 0.0, lumOnly);
        float highlightM = smoothstep(_240.highlightRange, 1.0, lumOnly);
        float midM = smoothstep(0.0, _240.midWidth, lumOnly - (_240.midRange - _240.midWidth)) * smoothstep(0.0, _240.midWidth, (_240.midRange + _240.midWidth) - lumOnly);
        float3 zones = ((float3(0.20000000298023223876953125, 0.0, 0.800000011920928955078125) * shadowM) + (float3(0.0, 0.800000011920928955078125, 0.20000000298023223876953125) * midM)) + (float3(0.89999997615814208984375, 0.800000011920928955078125, 0.0) * highlightM);
        referenceColor = float4(fast::clamp(zones, float3(0.0), float3(1.0)), src.w);
        return;
    }
    referenceColor = float4(result, src.w);
}

fragment refAM35_ec9d67f3d02bc_out refAM35_ec9d67f3d02bc(constant ReferenceUniformsec9d67f3d02bc& _240 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec9d67f3d02bc_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _240, refInput, refInputSmplr, referenceColor);
    bool _514 = any(isnan(referenceColor));
    bool _521;
    if (!_514)
    {
        _521 = any(isinf(referenceColor));
    }
    else
    {
        _521 = _514;
    }
    if (_521)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _534 = referenceColor;
    float3 _540 = fast::clamp(_534.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _540.x;
    referenceColor.y = _540.y;
    referenceColor.z = _540.z;
    out.finalColor = referenceColor;
    return out;
}

