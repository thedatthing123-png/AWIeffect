// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/S_BleachPyBass.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsed21040ef427c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float bypassStrength;
    char _m6_pad[12];
    int blendMode;
    char _m7_pad[12];
    float shadowContrast;
    char _m8_pad[12];
    float highlightContrast;
    char _m9_pad[12];
    float midContrast;
    char _m10_pad[12];
    float blackPoint;
    char _m11_pad[12];
    float whitePoint;
    char _m12_pad[12];
    float shadowDesat;
    char _m13_pad[12];
    float midDesat;
    char _m14_pad[12];
    float highlightDesat;
    char _m15_pad[12];
    uint grainEnable;
    char _m16_pad[12];
    float grainStrength;
    char _m17_pad[12];
    float grainSize;
    char _m18_pad[12];
    float grainSpeed;
    char _m19_pad[12];
    uint halationEnable;
    char _m20_pad[12];
    float halationStrength;
    char _m21_pad[12];
    float halationThreshold;
    float4 halationColor;
    float liftShadows;
    char _m24_pad[12];
    float gainHighlights;
    char _m25_pad[12];
    float gamma;
    float4 shadowTint;
    float shadowTintStr;
    float4 highlightTint;
    float highlightTintStr;
    char _m30_pad[12];
    float overallStrength;
    char _m31_pad[12];
    uint bwPreview;
};

struct refAM35_ed21040ef427c_out
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
float filmContrast(thread float& lum, thread const float& shadowC, thread const float& highlightC, thread const float& midC, thread const float& bPoint, thread const float& wPoint)
{
    lum = (lum - bPoint) / fast::max(wPoint - bPoint, 9.9999997473787516355514526367188e-05);
    lum = fast::clamp(lum, 0.0, 1.0);
    float shadowMask = smoothstep(0.4000000059604644775390625, 0.0, lum);
    float highlightMask = smoothstep(0.60000002384185791015625, 1.0, lum);
    float midMask = (1.0 - shadowMask) - highlightMask;
    midMask = fast::clamp(midMask, 0.0, 1.0);
    float contMult = ((shadowMask * shadowC) + (highlightMask * highlightC)) + (midMask * midC);
    lum = ((lum - 0.5) * contMult) + 0.5;
    return fast::clamp(lum, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float toneCurve(thread float& v, thread const float& lift, thread const float& gain, thread const float& gam)
{
    v = fast::clamp(v, 0.0, 1.0);
    v = (v * (gain - lift)) + lift;
    v = powr(fast::max(v, 9.9999997473787516355514526367188e-05), 1.0 / fast::max(gam, 0.001000000047497451305389404296875));
    return fast::clamp(v, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float3 applyDesat(thread const float3& col, thread const float& lum, thread const float& shadowD, thread const float& midD, thread const float& highlightD)
{
    float shadowMask = smoothstep(0.4000000059604644775390625, 0.0, lum);
    float highlightMask = smoothstep(0.60000002384185791015625, 1.0, lum);
    float midMask = fast::clamp((1.0 - shadowMask) - highlightMask, 0.0, 1.0);
    float desatAmt = ((shadowMask * shadowD) + (midMask * midD)) + (highlightMask * highlightD);
    return mix(col, float3(lum), float3(desatAmt));
}

static inline __attribute__((always_inline))
float3 blendOverlay(thread const float3& base, thread const float3& blend)
{
    float3 low = (base * 2.0) * blend;
    float3 high = float3(1.0) - (((float3(1.0) - base) * 2.0) * (float3(1.0) - blend));
    return mix(low, high, step(float3(0.5), base));
}

static inline __attribute__((always_inline))
float3 blendSoftLight(thread const float3& base, thread const float3& blend)
{
    float3 low = ((base * 2.0) * blend) + ((base * base) * (float3(1.0) - (blend * 2.0)));
    float3 high = (sqrt(base) * ((blend * 2.0) - float3(1.0))) + ((base * 2.0) * (float3(1.0) - blend));
    return mix(low, high, step(float3(0.5), blend));
}

static inline __attribute__((always_inline))
float3 blendHardLight(thread const float3& base, thread const float3& blend)
{
    float3 low = (base * 2.0) * blend;
    float3 high = float3(1.0) - (((float3(1.0) - base) * 2.0) * (float3(1.0) - blend));
    return mix(low, high, step(float3(0.5), blend));
}

static inline __attribute__((always_inline))
float3 applyHalation(thread const float3& col, thread const float& lum, thread const float& strength, thread const float& threshold, thread const float3& hColor)
{
    float halMask = smoothstep(threshold - 0.100000001490116119384765625, threshold + 0.100000001490116119384765625, lum);
    float3 halGlow = (hColor * halMask) * strength;
    return fast::clamp(col + halGlow, float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
float3 applyTint(thread float3& col, thread const float& lum, thread const float3& sTint, thread const float& sStr, thread const float3& hTint, thread const float& hStr)
{
    float shadowMask = smoothstep(0.4000000059604644775390625, 0.0, lum);
    float highlightMask = smoothstep(0.60000002384185791015625, 1.0, lum);
    col = mix(col, (col * sTint) * 2.0, float3(shadowMask * sStr));
    col = mix(col, (col * hTint) * 2.0, float3(highlightMask * hStr));
    return fast::clamp(col, float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
float hash21(thread const float2& p)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
float filmGrain(thread const float2& uv, thread const float& time, thread const float& speed, thread const float& size)
{
    float t = floor(time * speed);
    float2 scaledUV = uv * (500.0 / fast::max(size, 0.100000001490116119384765625));
    float2 param = scaledUV + float2(t * 1.7000000476837158203125, t * 3.099999904632568359375);
    float n = hash21(param);
    float2 param_1 = (scaledUV * 1.2999999523162841796875) + float2(t * 2.2999999523162841796875, t * 1.5);
    float n2 = hash21(param_1);
    return (n + n2) * 0.5;
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsed21040ef427c& _439, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _439.refScreen.xy;
    float t = _439.refScreen.z;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 col = src.xyz;
    float3 param_1 = col;
    float3 param_2 = srgbToLinear(param_1);
    float lum = luminance(param_2);
    float param_3 = lum;
    float param_4 = _439.shadowContrast;
    float param_5 = _439.highlightContrast;
    float param_6 = _439.midContrast;
    float param_7 = _439.blackPoint;
    float param_8 = _439.whitePoint;
    float _489 = filmContrast(param_3, param_4, param_5, param_6, param_7, param_8);
    float lumContrast = _489;
    float param_9 = lumContrast;
    float param_10 = _439.liftShadows;
    float param_11 = _439.gainHighlights;
    float param_12 = _439.gamma;
    float _504 = toneCurve(param_9, param_10, param_11, param_12);
    lumContrast = _504;
    float3 bwHigh = float3(lumContrast);
    float3 param_13 = col;
    float param_14 = lum;
    float param_15 = _439.shadowDesat;
    float param_16 = _439.midDesat;
    float param_17 = _439.highlightDesat;
    float3 colDesat = applyDesat(param_13, param_14, param_15, param_16, param_17);
    float bmf = float(_439.blendMode);
    float3 blended;
    if (bmf < 1.5)
    {
        float3 param_18 = colDesat;
        float3 param_19 = bwHigh;
        blended = blendOverlay(param_18, param_19);
    }
    else
    {
        if (bmf < 2.5)
        {
            float3 param_20 = colDesat;
            float3 param_21 = bwHigh;
            blended = blendSoftLight(param_20, param_21);
        }
        else
        {
            float3 param_22 = colDesat;
            float3 param_23 = bwHigh;
            blended = blendHardLight(param_22, param_23);
        }
    }
    float3 result = mix(colDesat, blended, float3(_439.bypassStrength));
    float3 param_24 = result;
    float3 param_25 = srgbToLinear(param_24);
    float lumResult = luminance(param_25);
    if (_439.halationEnable != 0u)
    {
        float3 param_26 = result;
        float param_27 = lumResult;
        float param_28 = _439.halationStrength;
        float param_29 = _439.halationThreshold;
        float3 param_30 = _439.halationColor.xyz;
        result = applyHalation(param_26, param_27, param_28, param_29, param_30);
    }
    float3 param_31 = result;
    float param_32 = lumResult;
    float3 param_33 = _439.shadowTint.xyz;
    float param_34 = _439.shadowTintStr;
    float3 param_35 = _439.highlightTint.xyz;
    float param_36 = _439.highlightTintStr;
    float3 _622 = applyTint(param_31, param_32, param_33, param_34, param_35, param_36);
    result = _622;
    if (_439.grainEnable != 0u)
    {
        float2 param_37 = uv;
        float param_38 = t;
        float param_39 = _439.grainSpeed;
        float param_40 = _439.grainSize;
        float grain = filmGrain(param_37, param_38, param_39, param_40);
        float grainMask = 1.0 - (abs(lumResult - 0.5) * 0.5);
        result += float3(((grain - 0.5) * _439.grainStrength) * grainMask);
        result = fast::clamp(result, float3(0.0), float3(1.0));
    }
    result = mix(col, result, float3(_439.overallStrength));
    if (_439.bwPreview != 0u)
    {
        float3 param_41 = col;
        float3 param_42 = srgbToLinear(param_41);
        float param_43 = luminance(param_42);
        float param_44 = _439.shadowContrast;
        float param_45 = _439.highlightContrast;
        float param_46 = _439.midContrast;
        float param_47 = _439.blackPoint;
        float param_48 = _439.whitePoint;
        float _699 = filmContrast(param_43, param_44, param_45, param_46, param_47, param_48);
        float bwLum = _699;
        float param_49 = bwLum;
        float param_50 = _439.liftShadows;
        float param_51 = _439.gainHighlights;
        float param_52 = _439.gamma;
        float _711 = toneCurve(param_49, param_50, param_51, param_52);
        bwLum = _711;
        referenceColor = float4(float3(bwLum), src.w);
        return;
    }
    referenceColor = float4(result, src.w);
}

fragment refAM35_ed21040ef427c_out refAM35_ed21040ef427c(constant ReferenceUniformsed21040ef427c& _439 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed21040ef427c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _439, refInput, refInputSmplr, referenceColor);
    bool _736 = any(isnan(referenceColor));
    bool _743;
    if (!_736)
    {
        _743 = any(isinf(referenceColor));
    }
    else
    {
        _743 = _736;
    }
    if (_743)
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

