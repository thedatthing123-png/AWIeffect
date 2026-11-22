// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/quality_enhancer-1.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse10176b54c318
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float clarityAmt;
    char _m6_pad[12];
    float detailAmt;
    char _m7_pad[12];
    float sharpenAmp;
    char _m8_pad[12];
    float outputGamma;
    char _m9_pad[12];
    float alpha;
};

struct refAM35_e10176b54c318_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse10176b54c318& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _33.refLayer.xy) / _33.refLayer.zw;
    float2 d = float2(1.0) / fast::max(_33.refLayer.zw, float2(1.0));
    float2 param = uv;
    float4 s = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = fast::clamp(uv + float2(d.x, 0.0), float2(0.0), float2(1.0));
    float2 param_2 = fast::clamp(uv - float2(d.x, 0.0), float2(0.0), float2(1.0));
    float2 param_3 = fast::clamp(uv + float2(0.0, d.y), float2(0.0), float2(1.0));
    float2 param_4 = fast::clamp(uv - float2(0.0, d.y), float2(0.0), float2(1.0));
    float3 b = ((texture2DCv(refInput, refInputSmplr, param_1).xyz + texture2DCv(refInput, refInputSmplr, param_2).xyz) + texture2DCv(refInput, refInputSmplr, param_3).xyz) + texture2DCv(refInput, refInputSmplr, param_4).xyz;
    b *= 0.25;
    float3 hi = s.xyz - b;
    float3 c = s.xyz + (hi * ((_33.sharpenAmp + (_33.clarityAmt * 0.64999997615814208984375)) + (_33.detailAmt * 0.3499999940395355224609375)));
    c = powr(fast::max(c, float3(0.0)), float3(1.0 / fast::max(_33.outputGamma, 0.00999999977648258209228515625)));
    referenceColor = float4(mix(s.xyz, c, float3(_33.alpha)), s.w);
}

fragment refAM35_e10176b54c318_out refAM35_e10176b54c318(constant ReferenceUniformse10176b54c318& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e10176b54c318_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
    bool _179 = any(isnan(referenceColor));
    bool _186;
    if (!_179)
    {
        _186 = any(isinf(referenceColor));
    }
    else
    {
        _186 = _179;
    }
    if (_186)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _199 = referenceColor;
    float3 _205 = fast::clamp(_199.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _205.x;
    referenceColor.y = _205.y;
    referenceColor.z = _205.z;
    out.finalColor = referenceColor;
    return out;
}

