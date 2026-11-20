// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/bccedgeglow.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsed50f32b27cc7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float edgeStrength;
    char _m6_pad[12];
    float edgeThickness;
    char _m7_pad[12];
    float edgeThreshold;
    char _m8_pad[12];
    float edgeSoftness;
    char _m9_pad[12];
    int edgeType;
    char _m10_pad[12];
    float glowAmount;
    char _m11_pad[12];
    float glowRadius;
    char _m12_pad[12];
    float glowFalloff;
    char _m13_pad[12];
    float innerGlow;
    char _m14_pad[12];
    float innerRadius;
    char _m15_pad[12];
    float innerSoftness;
    char _m16_pad[12];
    float outerGlow;
    char _m17_pad[12];
    float outerSpread;
    float4 edgeColor;
    float edgeColorStrength;
    char _m20_pad[12];
    uint useSourceColor;
    char _m21_pad[12];
    float edgeSaturation;
    float4 glowColorCore;
    float4 glowColorMid;
    float4 glowColorOuter;
    float colorMapStrength;
    char _m26_pad[12];
    float edgeBoost;
    char _m27_pad[12];
    float edgeContrast;
    char _m28_pad[12];
    float edgeGamma;
    char _m29_pad[12];
    uint edgeInvert;
    char _m30_pad[12];
    float pulseSpeed;
    char _m31_pad[12];
    float pulseAmount;
    char _m32_pad[12];
    float hueRotateSpeed;
    char _m33_pad[12];
    int blendMode;
    char _m34_pad[12];
    int quality;
    char _m35_pad[12];
    uint edgeOnly;
    char _m36_pad[12];
    uint glowOnly;
    char _m37_pad[12];
    float ditherAmt;
    char _m38_pad[12];
    float globalMix;
};

struct refAM35_ed50f32b27cc7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float aeLum(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float aeEdgeAt(thread const float2& uv, thread const float2& px, texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformsed50f32b27cc7& _153)
{
    float2 param = uv;
    float3 c = texture2DCv(refInput, refInputSmplr, param).xyz;
    float2 param_1 = fast::clamp(uv - float2(px.x, 0.0), float2(0.0), float2(1.0));
    float3 l = texture2DCv(refInput, refInputSmplr, param_1).xyz;
    float2 param_2 = fast::clamp(uv + float2(px.x, 0.0), float2(0.0), float2(1.0));
    float3 r = texture2DCv(refInput, refInputSmplr, param_2).xyz;
    float2 param_3 = fast::clamp(uv - float2(0.0, px.y), float2(0.0), float2(1.0));
    float3 t = texture2DCv(refInput, refInputSmplr, param_3).xyz;
    float2 param_4 = fast::clamp(uv + float2(0.0, px.y), float2(0.0), float2(1.0));
    float3 b = texture2DCv(refInput, refInputSmplr, param_4).xyz;
    float e;
    if (float(_153.edgeType) < 1.5)
    {
        float3 param_5 = l;
        float3 param_6 = r;
        float3 param_7 = t;
        float3 param_8 = b;
        e = abs(aeLum(param_5) - aeLum(param_6)) + abs(aeLum(param_7) - aeLum(param_8));
    }
    else
    {
        if (float(_153.edgeType) < 2.5)
        {
            float3 param_9 = r;
            float3 param_10 = l;
            float gx = aeLum(param_9) - aeLum(param_10);
            float3 param_11 = b;
            float3 param_12 = t;
            float gy = aeLum(param_11) - aeLum(param_12);
            e = sqrt((gx * gx) + (gy * gy)) * 2.0;
        }
        else
        {
            e = length(r - l) + length(b - t);
        }
    }
    e *= _153.edgeStrength;
    float softness = fast::max(_153.edgeSoftness, 0.00999999977648258209228515625);
    e = smoothstep(_153.edgeThreshold - (softness * 0.5), _153.edgeThreshold + (softness * 0.5), e);
    e = fast::clamp(((e - 0.5) * (1.0 + _153.edgeContrast)) + 0.5, 0.0, 1.0);
    e = powr(fast::max(e, 0.0), 1.0 / fast::max(_153.edgeGamma, 0.001000000047497451305389404296875));
    e = fast::min(e * (1.0 + _153.edgeBoost), 1.0);
    if (_153.edgeInvert != 0u)
    {
        e = 1.0 - e;
    }
    return e;
}

static inline __attribute__((always_inline))
float3 aeSaturateColor(thread const float3& c, thread const float& amount)
{
    float3 param = c;
    float l = aeLum(param);
    return mix(float3(l), c, float3(amount));
}

static inline __attribute__((always_inline))
float aeHash(thread const float2& p)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
float3 aeBlend(thread const float3& base, thread const float3& glow, thread const float& mode)
{
    if (mode < 1.5)
    {
        return base + glow;
    }
    if (mode < 2.5)
    {
        return float3(1.0) - ((float3(1.0) - base) * (float3(1.0) - glow));
    }
    if (mode < 3.5)
    {
        return (((float3(1.0) - (glow * 2.0)) * base) * base) + ((glow * 2.0) * base);
    }
    return glow;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformsed50f32b27cc7& _153, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _153.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = _153.refScreen.xy;
    float2 basePx = float2(1.0) / getTexSize(param_1);
    float2 edgePx = basePx * fast::max(_153.edgeThickness, 0.5);
    float2 param_2 = uv;
    float2 param_3 = edgePx;
    float core = aeEdgeAt(param_2, param_3, refInput, refInputSmplr, _153);
    float radiusScale = mix(0.550000011920928955078125, 1.0, fast::clamp((float(_153.quality) - 1.0) * 0.5, 0.0, 1.0));
    float2 glowPx = basePx * fast::max(_153.glowRadius * radiusScale, 0.5);
    float nearGlow = 0.0;
    float2 param_4 = fast::clamp(uv + float2(glowPx.x, 0.0), float2(0.0), float2(1.0));
    float2 param_5 = edgePx;
    nearGlow += aeEdgeAt(param_4, param_5, refInput, refInputSmplr, _153);
    float2 param_6 = fast::clamp(uv - float2(glowPx.x, 0.0), float2(0.0), float2(1.0));
    float2 param_7 = edgePx;
    nearGlow += aeEdgeAt(param_6, param_7, refInput, refInputSmplr, _153);
    float2 param_8 = fast::clamp(uv + float2(0.0, glowPx.y), float2(0.0), float2(1.0));
    float2 param_9 = edgePx;
    nearGlow += aeEdgeAt(param_8, param_9, refInput, refInputSmplr, _153);
    float2 param_10 = fast::clamp(uv - float2(0.0, glowPx.y), float2(0.0), float2(1.0));
    float2 param_11 = edgePx;
    nearGlow += aeEdgeAt(param_10, param_11, refInput, refInputSmplr, _153);
    nearGlow *= 0.25;
    float2 farPx = (glowPx * fast::max(_153.outerSpread, 0.25)) * 1.75;
    float farGlow = 0.0;
    float2 param_12 = fast::clamp(uv + farPx, float2(0.0), float2(1.0));
    float2 param_13 = edgePx;
    farGlow += aeEdgeAt(param_12, param_13, refInput, refInputSmplr, _153);
    float2 param_14 = fast::clamp(uv - farPx, float2(0.0), float2(1.0));
    float2 param_15 = edgePx;
    farGlow += aeEdgeAt(param_14, param_15, refInput, refInputSmplr, _153);
    float2 param_16 = fast::clamp(uv + float2(farPx.x, -farPx.y), float2(0.0), float2(1.0));
    float2 param_17 = edgePx;
    farGlow += aeEdgeAt(param_16, param_17, refInput, refInputSmplr, _153);
    float2 param_18 = fast::clamp(uv + float2(-farPx.x, farPx.y), float2(0.0), float2(1.0));
    float2 param_19 = edgePx;
    farGlow += aeEdgeAt(param_18, param_19, refInput, refInputSmplr, _153);
    farGlow *= 0.25;
    float pulse = 1.0 + ((sin((_153.refScreen.z * _153.pulseSpeed) * 6.283185482025146484375) * _153.pulseAmount) * 0.25);
    float glowMask = powr(fast::max(nearGlow, 0.0), fast::max(_153.glowFalloff, 0.100000001490116119384765625)) * _153.outerGlow;
    glowMask += ((core * _153.innerGlow) * mix(0.5, 1.0, _153.innerSoftness));
    glowMask += ((farGlow * _153.outerGlow) * 0.550000011920928955078125);
    glowMask *= (_153.glowAmount * pulse);
    float3 param_20 = src.xyz;
    float param_21 = _153.edgeSaturation;
    float3 sourceEdgeColor = aeSaturateColor(param_20, param_21);
    float3 selectedEdgeColor = mix(_153.edgeColor.xyz, sourceEdgeColor, float3(float(_153.useSourceColor != 0u)));
    selectedEdgeColor = mix(float3(1.0), selectedEdgeColor, float3(_153.edgeColorStrength));
    float3 mappedColor = mix(_153.glowColorMid.xyz, mix(_153.glowColorCore.xyz, _153.glowColorOuter.xyz, float3(fast::clamp(farGlow, 0.0, 1.0))), float3(_153.colorMapStrength));
    float3 edgeRGB = selectedEdgeColor * core;
    float3 glowRGB = mappedColor * glowMask;
    float2 param_22 = gl_FragCoord.xy + float2(_153.refScreen.z * 13.0);
    float _noise = (aeHash(param_22) - 0.5) * _153.ditherAmt;
    float3 effectRGB = (edgeRGB + glowRGB) + float3(_noise);
    float3 result;
    if (_153.edgeOnly != 0u)
    {
        result = edgeRGB;
    }
    else
    {
        if (_153.glowOnly != 0u)
        {
            result = glowRGB;
        }
        else
        {
            float3 param_23 = src.xyz;
            float3 param_24 = effectRGB;
            float param_25 = float(_153.blendMode);
            result = aeBlend(param_23, param_24, param_25);
        }
    }
    referenceColor = float4(mix(src.xyz, result, float3(_153.globalMix)), src.w);
}

fragment refAM35_ed50f32b27cc7_out refAM35_ed50f32b27cc7(constant ReferenceUniformsed50f32b27cc7& _153 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed50f32b27cc7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _153, gl_FragCoord, referenceColor);
    bool _707 = any(isnan(referenceColor));
    bool _714;
    if (!_707)
    {
        _714 = any(isinf(referenceColor));
    }
    else
    {
        _714 = _707;
    }
    if (_714)
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

