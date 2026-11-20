// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/bcc_blur_h.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse02a0866ee9bc
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float xWidth;
    char _m6_pad[12];
    float glowRadius;
    char _m7_pad[12];
    uint mirrorEdge;
    char _m8_pad[12];
    float mixAmount;
};

struct refAM35_e02a0866ee9bc_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse02a0866ee9bc& _34, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _34.refLayer.xy) / _34.refLayer.zw;
    float px = 1.0 / fast::max(_34.refLayer.z, 1.0);
    float2 d = float2(px * _34.xWidth, 0.0);
    float2 param = uv;
    float4 c = texture2DCv(refInput, refInputSmplr, param) * 0.20000000298023223876953125;
    float2 param_1 = fast::clamp(uv + (d * 0.25), float2(0.0), float2(1.0));
    c += (texture2DCv(refInput, refInputSmplr, param_1) * 0.1599999964237213134765625);
    float2 param_2 = fast::clamp(uv - (d * 0.25), float2(0.0), float2(1.0));
    c += (texture2DCv(refInput, refInputSmplr, param_2) * 0.1599999964237213134765625);
    float2 param_3 = fast::clamp(uv + (d * 0.550000011920928955078125), float2(0.0), float2(1.0));
    c += (texture2DCv(refInput, refInputSmplr, param_3) * 0.12999999523162841796875);
    float2 param_4 = fast::clamp(uv - (d * 0.550000011920928955078125), float2(0.0), float2(1.0));
    c += (texture2DCv(refInput, refInputSmplr, param_4) * 0.12999999523162841796875);
    float2 param_5 = fast::clamp(uv + d, float2(0.0), float2(1.0));
    c += (texture2DCv(refInput, refInputSmplr, param_5) * 0.10999999940395355224609375);
    float2 param_6 = fast::clamp(uv - d, float2(0.0), float2(1.0));
    c += (texture2DCv(refInput, refInputSmplr, param_6) * 0.10999999940395355224609375);
    float2 param_7 = uv;
    float4 s = texture2DCv(refInput, refInputSmplr, param_7);
    referenceColor = mix(s, c, float4(_34.mixAmount));
}

fragment refAM35_e02a0866ee9bc_out refAM35_e02a0866ee9bc(constant ReferenceUniformse02a0866ee9bc& _34 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e02a0866ee9bc_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _34, refInput, refInputSmplr, referenceColor);
    bool _165 = any(isnan(referenceColor));
    bool _172;
    if (!_165)
    {
        _172 = any(isinf(referenceColor));
    }
    else
    {
        _172 = _165;
    }
    if (_172)
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

