// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/pagecurl.xml
// Original source comments and attribution:
// Created by Eduardo Castineyra - casty/2015
// Creative Commons Attribution 4.0 International License
// https://www.shadertoy.com/view/MtBSzR
/// 1D function x: cylFun(t); y: normal at that point.
/// Before the curl
/// After the curl
/// Inside the curl
/// We see the back face
/// Front face before the curve starts
/// Front face curve
/// Before the curl
/// After the curl
/// Inside the curl
/// Front face before the curve starts
/// Front face curve
// Multiply
// Screen
// Normal
//, acScreenSize.y/acScreenSize.x);
//((progress-0.5) * h)+0.5;
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

struct ReferenceUniformse8a16b62f87bf
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progress;
    char _m6_pad[12];
    float radius;
    char _m7_pad[12];
    float angle;
    char _m8_pad[12];
    float alpha;
    char _m9_pad[12];
    float strength;
    float4 backColor;
    float backAlpha;
    char _m12_pad[12];
    int backBlendMode;
    float4 shineColor;
    float shineAlpha;
    char _m15_pad[12];
    float shineSpec;
    char _m16_pad[12];
    int shineBlendMode;
    float4 dropShadowColor;
    float dropShadowAlpha;
    char _m19_pad[12];
    uint softDropShadow;
    float4 frontShadowColor;
    float frontShadowAlpha;
    char _m22_pad[12];
    int frontShadowBlendMode;
};

struct refAM35_e8a16b62f87bf_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rot2(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, s), float2(-s, c));
}

static inline __attribute__((always_inline))
float2 curlFunFront(thread const float& t, thread const float& maxt, thread const float3& cyl, constant ReferenceUniformse8a16b62f87bf& _97)
{
    float2 ret = float2(t, 1.0);
    if (t < (cyl.z - _97.radius))
    {
        return ret;
    }
    if (t > (cyl.z + _97.radius))
    {
        return float2(-1.0);
    }
    float a = asin((t - cyl.z) / _97.radius);
    float ca = (-a) + 3.1415920257568359375;
    ret.x = cyl.z + (ca * _97.radius);
    ret.y = cos(ca);
    if (t < cyl.z)
    {
        return float2(t, 1.0);
    }
    ret.y = cos(a);
    ret.x = cyl.z + (a * _97.radius);
    return select(float2(-1.0), ret, bool2(ret.x < maxt));
}

static inline __attribute__((always_inline))
float2 curlFun(thread const float& t, thread const float& maxt, thread const float3& cyl, constant ReferenceUniformse8a16b62f87bf& _97)
{
    float2 ret = float2(t, 1.0);
    if (t < (cyl.z - _97.radius))
    {
        return ret;
    }
    if (t > (cyl.z + _97.radius))
    {
        return float2(-1.0);
    }
    float a = asin((t - cyl.z) / _97.radius);
    float ca = (-a) + 3.1415920257568359375;
    ret.x = cyl.z + (ca * _97.radius);
    ret.y = cos(ca);
    if (ret.x < maxt)
    {
        return ret;
    }
    if (t < cyl.z)
    {
        return float2(t, 1.0);
    }
    ret.y = cos(a);
    ret.x = cyl.z + (a * _97.radius);
    return select(float2(-1.0), ret, bool2(ret.x < maxt));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse8a16b62f87bf& _97)
{
    return (float4(v, 0.0, 1.0) * _97.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float saturate0(thread const float& v)
{
    return fast::clamp(v, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float4 blendColor(thread const float4& base, thread const float4& color, thread const int& mode, thread const float& p)
{
    if (mode == 1)
    {
        float3 aa = base.xyz / float3(fast::max(base.w, 9.9999997473787516355514526367188e-06));
        float3 bb = color.xyz / float3(fast::max(color.w, 9.9999997473787516355514526367188e-06));
        float3 cc = aa * bb;
        float4 adjColor = (float4(cc, 1.0) * color.w) * p;
        return (base * (1.0 - adjColor.w)) + adjColor;
    }
    else
    {
        if (mode == 2)
        {
            float3 aa_1 = base.xyz / float3(fast::max(base.w, 9.9999997473787516355514526367188e-06));
            float3 bb_1 = color.xyz / float3(fast::max(color.w, 9.9999997473787516355514526367188e-06));
            float3 cc_1 = float3(1.0) - ((float3(1.0) - aa_1) * (float3(1.0) - bb_1));
            float4 adjColor_1 = (float4(cc_1, 1.0) * color.w) * p;
            return (base * (1.0 - adjColor_1.w)) + adjColor_1;
        }
        else
        {
            float4 adjColor_2 = color * p;
            return (base * (1.0 - adjColor_2.w)) + adjColor_2;
        }
    }
}

static inline __attribute__((always_inline))
float4 composite(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse8a16b62f87bf& _97, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refBuffer1, sampler refBuffer1Smplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _97.refLayer.xy) / _97.refLayer.zw;
    float2 ur = float2(1.0);
    float h = sqrt(tan(0.785398006439208984375 - abs(mod(_97.angle * 0.01745329983532428741455078125, 1.57079601287841796875) - 0.785398006439208984375)) + 1.0);
    float d = (1.0 - _97.progress) * h;
    d = 1.0 - ((1.0 - d) * (1.0 + _97.radius));
    float param = _97.angle * 0.01745329983532428741455078125;
    float2 cd = float2(1.0, 0.0) * rot2(param);
    float2 iv = step(cd, float2(0.0));
    uv = iv + (uv * (float2(1.0) - (iv * 2.0)));
    float3 cyl = float3(abs(cd), d);
    d = dot(uv, cyl.xy);
    float2 end = abs((ur - uv) / cyl.xy);
    float maxt = d + fast::min(end.x, end.y);
    float param_1 = d;
    float param_2 = maxt;
    float3 param_3 = cyl;
    float2 cff = curlFunFront(param_1, param_2, param_3, _97);
    float param_4 = d;
    float param_5 = maxt;
    float3 param_6 = cyl;
    float2 cf = curlFun(param_4, param_5, param_6, _97);
    float2 tuv = uv + (cyl.xy * (cf.x - d));
    float2 tuvf = uv + (cyl.xy * (cff.x - d));
    tuv /= ur;
    tuv = iv + (tuv * (float2(1.0) - (iv * 2.0)));
    tuvf /= ur;
    tuvf = iv + (tuvf * (float2(1.0) - (iv * 2.0)));
    float shadow = 1.0 - smoothstep(0.0, _97.radius * 2.0, -(d - cyl.z));
    shadow *= smoothstep(-_97.radius, _97.radius, maxt - ((cf.x + (4.71238803863525390625 * _97.radius)) + _97.radius));
    float2 param_7 = gl_FragCoord.xy / _97.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_7);
    float2 param_8 = gl_FragCoord.xy / _97.refScreen.xy;
    float4 blurColor = texture2DCv(refBuffer1, refBuffer1Smplr, param_8);
    float2 param_9 = tuvf;
    float2 param_10 = l2s(param_9, _97);
    float4 frontColor = texture2DCv(refInput, refInputSmplr, param_10);
    float2 param_11 = tuv;
    float2 param_12 = l2s(param_11, _97);
    float4 result = texture2DCv(refInput, refInputSmplr, param_12);
    float param_13 = 1.0 - cff.y;
    float4 param_14 = frontColor;
    float4 param_15 = (_97.frontShadowColor * _97.frontShadowAlpha) * frontColor.w;
    int param_16 = _97.frontShadowBlendMode;
    float param_17 = saturate0(param_13);
    float4 front = blendColor(param_14, param_15, param_16, param_17);
    float4 _642;
    if (cf.y > 0.0)
    {
        _642 = front;
    }
    else
    {
        float4 param_18 = front;
        float4 param_19 = mix((texColor * (1.0 - blurColor.w)) + blurColor, result, float4(_97.alpha));
        float4 param_20 = composite(param_18, param_19);
        float4 param_21 = (_97.backColor * _97.backAlpha) * result.w;
        int param_22 = _97.backBlendMode;
        float param_23 = (1.0 * step(uv.x, 1.0)) * step(uv.y, 1.0);
        float4 param_24 = blendColor(param_20, param_21, param_22, param_23);
        float4 param_25 = (_97.shineColor * _97.shineAlpha) * result.w;
        int param_26 = _97.shineBlendMode;
        float param_27 = (powr(-cf.y, _97.shineSpec) * step(uv.x, 1.0)) * step(uv.y, 1.0);
        _642 = blendColor(param_24, param_25, param_26, param_27);
    }
    result = _642;
    shadow = smoothstep(0.0, _97.radius * 2.0, d - cyl.z);
    if (_97.softDropShadow != 0u)
    {
        float param_28 = (1.0 - shadow) * 2.0;
        shadow = saturate0(param_28) * (1.0 - powr(length(((gl_FragCoord.xy - _97.refLayer.xy) / _97.refLayer.zw) - float2(0.5)) * 2.0, 2.0));
        float4 adjShadowColor = (((_97.dropShadowColor * _97.dropShadowAlpha) * shadow) * smoothstep(0.5, 1.0, blurColor.w)) * texColor.w;
        float4 _784;
        if (cf.x > 0.0)
        {
            float4 param_29 = adjShadowColor;
            float4 param_30 = result;
            _784 = composite(param_29, param_30);
        }
        else
        {
            _784 = adjShadowColor;
        }
        referenceColor = (_784 * step(uv.x, 1.0)) * step(uv.y, 1.0);
    }
    else
    {
        float4 _807;
        if (cf.x > 0.0)
        {
            _807 = result;
        }
        else
        {
            float param_31 = (1.0 - shadow) * 2.0;
            _807 = ((_97.dropShadowColor * _97.dropShadowAlpha) * saturate0(param_31)) * texColor.w;
        }
        referenceColor = (_807 * step(uv.x, 1.0)) * step(uv.y, 1.0);
    }
}

fragment refAM35_e8a16b62f87bf_out refAM35_e8a16b62f87bf(constant ReferenceUniformse8a16b62f87bf& _97 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8a16b62f87bf_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_97, gl_FragCoord, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr, referenceColor);
    bool _840 = any(isnan(referenceColor));
    bool _847;
    if (!_840)
    {
        _847 = any(isinf(referenceColor));
    }
    else
    {
        _847 = _840;
    }
    if (_847)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _860 = referenceColor;
    float3 _866 = fast::clamp(_860.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _866.x;
    referenceColor.y = _866.y;
    referenceColor.z = _866.z;
    out.finalColor = referenceColor;
    return out;
}

