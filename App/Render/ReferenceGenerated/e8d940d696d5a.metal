// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/dualtexture.xml
// Original source comments and attribution:
// edgeMode: 0 clamp, 1 repeat
// channelPair: 0 RG, 1 RB, 2 GB
// 0..1
// choose map source
// Shadertoy-like offset
// Channel routing and amount
// Wrapped/clamped displaced sample
// Edge feather: blend toward clamped sample when going out-of-bounds
// 0..0.25 in UV space
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse8d940d696d5a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float offsetX;
    char _m6_pad[12];
    float offsetY;
    char _m7_pad[12];
    float mapAmount;
    char _m8_pad[12];
    uint useLayerBelow;
    char _m9_pad[12];
    int channelPair;
    char _m10_pad[12];
    int edgeMode;
    char _m11_pad[12];
    float edgeFeather;
};

struct refAM35_e8d940d696d5a_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 pickChannels(thread const float4& c, constant ReferenceUniformse8d940d696d5a& _39)
{
    if (_39.channelPair == 0)
    {
        return c.xy;
    }
    else
    {
        if (_39.channelPair == 1)
        {
            return c.xz;
        }
        else
        {
            return c.yz;
        }
    }
}

static inline __attribute__((always_inline))
float2 wrapUV(thread const float2& p, constant ReferenceUniformse8d940d696d5a& _39)
{
    if (_39.edgeMode == 0)
    {
        return fast::clamp(p, float2(0.0), float2(1.0));
    }
    else
    {
        return fract(p);
    }
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse8d940d696d5a& _39, thread float4& gl_FragCoord, texture2d<float> refReference, sampler refReferenceSmplr, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _39.refScreen.xy;
    float4 _102;
    if (_39.useLayerBelow != 0u)
    {
        float2 param = uv;
        _102 = texture2DCv(refReference, refReferenceSmplr, param);
    }
    else
    {
        float2 param_1 = uv;
        _102 = texture2DCv(refInput, refInputSmplr, param_1);
    }
    float4 jc = _102;
    uv -= float2(_39.offsetX, _39.offsetY);
    float4 param_2 = jc;
    float2 disp = pickChannels(param_2, _39) * _39.mapAmount;
    float2 dispUV = uv + disp;
    float2 param_3 = dispUV;
    float2 sampleUV = wrapUV(param_3, _39);
    float2 param_4 = sampleUV;
    float4 displacedCol = texture2DCv(refInput, refInputSmplr, param_4);
    float2 overNeg = fast::max(-dispUV, float2(0.0));
    float2 overPos = fast::max(dispUV - float2(1.0), float2(0.0));
    float o = fast::max(fast::max(overNeg.x, overNeg.y), fast::max(overPos.x, overPos.y));
    float2 clampUV = fast::clamp(dispUV, float2(0.0), float2(1.0));
    float2 param_5 = clampUV;
    float4 clampCol = texture2DCv(refInput, refInputSmplr, param_5);
    float feather = _39.edgeFeather;
    float _185;
    if (feather > 0.0)
    {
        _185 = smoothstep(0.0, feather, o);
    }
    else
    {
        _185 = 0.0;
    }
    float m = _185;
    float4 col = mix(displacedCol, clampCol, float4(m));
    referenceColor = col;
}

fragment refAM35_e8d940d696d5a_out refAM35_e8d940d696d5a(constant ReferenceUniformse8d940d696d5a& _39 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8d940d696d5a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_39, gl_FragCoord, refReference, refReferenceSmplr, refInput, refInputSmplr, referenceColor);
    bool _207 = any(isnan(referenceColor));
    bool _214;
    if (!_207)
    {
        _214 = any(isinf(referenceColor));
    }
    else
    {
        _214 = _207;
    }
    if (_214)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _229 = referenceColor;
    float3 _235 = fast::clamp(_229.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _235.x;
    referenceColor.y = _235.y;
    referenceColor.z = _235.z;
    out.finalColor = referenceColor;
    return out;
}

