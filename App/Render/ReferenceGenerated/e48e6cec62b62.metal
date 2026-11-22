// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/rays_edge_detect.xml
// Original source comments and attribution:
// Sobel gradient
// Simple feather by neighbor max
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse48e6cec62b62
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float edgeThreshold;
    char _m6_pad[12];
    float brightThreshold;
    char _m7_pad[12];
    float feather;
    char _m8_pad[12];
    uint useLuma;
};

struct refAM35_e48e6cec62b62_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 s(thread const float2& uv, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = uv;
    return texture2DCv(refInput, refInputSmplr, param);
}

static inline __attribute__((always_inline))
float lum(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse48e6cec62b62& _58, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _58.refLayer.xy) / _58.refLayer.zw;
    float2 px = float2(1.0) / _58.refLayer.zw;
    float2 param = uv;
    float4 c = s(param, refInput, refInputSmplr);
    float a = c.w;
    float _95;
    if (_58.useLuma != 0u)
    {
        float3 param_1 = c.xyz;
        _95 = lum(param_1);
    }
    else
    {
        _95 = a;
    }
    float v = _95;
    float _109;
    if (_58.useLuma != 0u)
    {
        float2 param_2 = uv + float2(-px.x, -px.y);
        float3 param_3 = s(param_2, refInput, refInputSmplr).xyz;
        _109 = lum(param_3);
    }
    else
    {
        float2 param_4 = uv + float2(-px.x, -px.y);
        _109 = s(param_4, refInput, refInputSmplr).w;
    }
    float tl = _109;
    float _145;
    if (_58.useLuma != 0u)
    {
        float2 param_5 = uv + float2(0.0, -px.y);
        float3 param_6 = s(param_5, refInput, refInputSmplr).xyz;
        _145 = lum(param_6);
    }
    else
    {
        float2 param_7 = uv + float2(0.0, -px.y);
        _145 = s(param_7, refInput, refInputSmplr).w;
    }
    float tc = _145;
    float _175;
    if (_58.useLuma != 0u)
    {
        float2 param_8 = uv + float2(px.x, -px.y);
        float3 param_9 = s(param_8, refInput, refInputSmplr).xyz;
        _175 = lum(param_9);
    }
    else
    {
        float2 param_10 = uv + float2(px.x, -px.y);
        _175 = s(param_10, refInput, refInputSmplr).w;
    }
    float tr = _175;
    float _208;
    if (_58.useLuma != 0u)
    {
        float2 param_11 = uv + float2(-px.x, 0.0);
        float3 param_12 = s(param_11, refInput, refInputSmplr).xyz;
        _208 = lum(param_12);
    }
    else
    {
        float2 param_13 = uv + float2(-px.x, 0.0);
        _208 = s(param_13, refInput, refInputSmplr).w;
    }
    float ml = _208;
    float _237;
    if (_58.useLuma != 0u)
    {
        float2 param_14 = uv + float2(px.x, 0.0);
        float3 param_15 = s(param_14, refInput, refInputSmplr).xyz;
        _237 = lum(param_15);
    }
    else
    {
        float2 param_16 = uv + float2(px.x, 0.0);
        _237 = s(param_16, refInput, refInputSmplr).w;
    }
    float mr = _237;
    float _264;
    if (_58.useLuma != 0u)
    {
        float2 param_17 = uv + float2(-px.x, px.y);
        float3 param_18 = s(param_17, refInput, refInputSmplr).xyz;
        _264 = lum(param_18);
    }
    else
    {
        float2 param_19 = uv + float2(-px.x, px.y);
        _264 = s(param_19, refInput, refInputSmplr).w;
    }
    float bl = _264;
    float _297;
    if (_58.useLuma != 0u)
    {
        float2 param_20 = uv + float2(0.0, px.y);
        float3 param_21 = s(param_20, refInput, refInputSmplr).xyz;
        _297 = lum(param_21);
    }
    else
    {
        float2 param_22 = uv + float2(0.0, px.y);
        _297 = s(param_22, refInput, refInputSmplr).w;
    }
    float bc = _297;
    float _324;
    if (_58.useLuma != 0u)
    {
        float2 param_23 = uv + float2(px.x, px.y);
        float3 param_24 = s(param_23, refInput, refInputSmplr).xyz;
        _324 = lum(param_24);
    }
    else
    {
        float2 param_25 = uv + float2(px.x, px.y);
        _324 = s(param_25, refInput, refInputSmplr).w;
    }
    float br = _324;
    float gx = ((tr + (2.0 * mr)) + br) - ((tl + (2.0 * ml)) + bl);
    float gy = ((bl + (2.0 * bc)) + br) - ((tl + (2.0 * tc)) + tr);
    float g = length(float2(gx, gy));
    float e = smoothstep(_58.edgeThreshold, 1.0, g);
    float b = smoothstep(_58.brightThreshold - 0.0199999995529651641845703125, _58.brightThreshold + 0.0199999995529651641845703125, v);
    float m = e * b;
    float f = _58.feather;
    float2 k = px * f;
    float m1 = m;
    float _421;
    if (_58.useLuma != 0u)
    {
        float2 param_26 = uv + float2(k.x, 0.0);
        float3 param_27 = s(param_26, refInput, refInputSmplr).xyz;
        _421 = lum(param_27);
    }
    else
    {
        float2 param_28 = uv + float2(k.x, 0.0);
        _421 = s(param_28, refInput, refInputSmplr).w;
    }
    m1 = fast::max(m1, _421 * m);
    float _451;
    if (_58.useLuma != 0u)
    {
        float2 param_29 = uv + float2(-k.x, 0.0);
        float3 param_30 = s(param_29, refInput, refInputSmplr).xyz;
        _451 = lum(param_30);
    }
    else
    {
        float2 param_31 = uv + float2(-k.x, 0.0);
        _451 = s(param_31, refInput, refInputSmplr).w;
    }
    m1 = fast::max(m1, _451 * m);
    float _483;
    if (_58.useLuma != 0u)
    {
        float2 param_32 = uv + float2(0.0, k.y);
        float3 param_33 = s(param_32, refInput, refInputSmplr).xyz;
        _483 = lum(param_33);
    }
    else
    {
        float2 param_34 = uv + float2(0.0, k.y);
        _483 = s(param_34, refInput, refInputSmplr).w;
    }
    m1 = fast::max(m1, _483 * m);
    float _513;
    if (_58.useLuma != 0u)
    {
        float2 param_35 = uv + float2(0.0, -k.y);
        float3 param_36 = s(param_35, refInput, refInputSmplr).xyz;
        _513 = lum(param_36);
    }
    else
    {
        float2 param_37 = uv + float2(0.0, -k.y);
        _513 = s(param_37, refInput, refInputSmplr).w;
    }
    m1 = fast::max(m1, _513 * m);
    m1 *= a;
    referenceColor = float4(float3(m1), m1);
}

fragment refAM35_e48e6cec62b62_out refAM35_e48e6cec62b62(constant ReferenceUniformse48e6cec62b62& _58 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e48e6cec62b62_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _58, referenceColor);
    bool _558 = any(isnan(referenceColor));
    bool _565;
    if (!_558)
    {
        _565 = any(isinf(referenceColor));
    }
    else
    {
        _565 = _558;
    }
    if (_565)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _578 = referenceColor;
    float3 _584 = fast::clamp(_578.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _584.x;
    referenceColor.y = _584.y;
    referenceColor.z = _584.z;
    out.finalColor = referenceColor;
    return out;
}

