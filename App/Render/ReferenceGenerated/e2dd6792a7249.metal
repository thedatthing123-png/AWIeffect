// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/pose_shake.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse2dd6792a7249
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amplitude;
    char _m6_pad[12];
    float frequency;
    char _m7_pad[12];
    float seed;
    char _m8_pad[12];
    float dissolvePercent;
    char _m9_pad[12];
    float motionBlur;
};

struct refAM35_e2dd6792a7249_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float h(thread const float& n, constant ReferenceUniformse2dd6792a7249& _40)
{
    return fract(sin((n * 127.09999847412109375) + _40.seed) * 43758.546875);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float h2(thread const float2& p, constant ReferenceUniformse2dd6792a7249& _40)
{
    return fract(sin(dot(p + float2(_40.seed), float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse2dd6792a7249& _40, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float f = floor(_40.refScreen.z * _40.frequency);
    float param = f;
    float param_1 = f + 17.0;
    float2 o = ((float2(h(param, _40), h(param_1, _40)) - float2(0.5)) * _40.amplitude) / fast::max(_40.refLayer.zw, float2(1.0));
    float2 uv = fast::clamp(((gl_FragCoord.xy - _40.refLayer.xy) / _40.refLayer.zw) + o, float2(0.0), float2(1.0));
    float2 param_2 = uv;
    float4 c = texture2DCv(refInput, refInputSmplr, param_2);
    float2 param_3 = fast::clamp(uv - (o * _40.motionBlur), float2(0.0), float2(1.0));
    float4 b = texture2DCv(refInput, refInputSmplr, param_3);
    c = mix(c, b, float4(_40.motionBlur * 0.5));
    float2 param_4 = floor(((gl_FragCoord.xy - _40.refLayer.xy) / _40.refLayer.zw) * 120.0);
    float n = h2(param_4, _40);
    c.w *= step(_40.dissolvePercent, n);
    referenceColor = c;
}

fragment refAM35_e2dd6792a7249_out refAM35_e2dd6792a7249(constant ReferenceUniformse2dd6792a7249& _40 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e2dd6792a7249_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_40, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _183 = any(isnan(referenceColor));
    bool _190;
    if (!_183)
    {
        _190 = any(isinf(referenceColor));
    }
    else
    {
        _190 = _183;
    }
    if (_190)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _204 = referenceColor;
    float3 _210 = fast::clamp(_204.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _210.x;
    referenceColor.y = _210.y;
    referenceColor.z = _210.z;
    out.finalColor = referenceColor;
    return out;
}

