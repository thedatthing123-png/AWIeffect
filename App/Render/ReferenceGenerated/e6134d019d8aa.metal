// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/sharpen.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse6134d019d8aa
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float radius;
};

struct refAM35_e6134d019d8aa_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse6134d019d8aa& _40, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st = gl_FragCoord.xy / _40.refScreen.xy;
    float2 param = _40.refScreen.xy;
    float2 fragSize = (float2(1.0) / getTexSize(param)) * _40.radius;
    float2 param_1 = float2((gl_FragCoord.xy / _40.refScreen.xy).x - fragSize.x, (gl_FragCoord.xy / _40.refScreen.xy).y);
    float4 w = texture2DCv(refInput, refInputSmplr, param_1);
    float2 param_2 = float2((gl_FragCoord.xy / _40.refScreen.xy).x + fragSize.x, (gl_FragCoord.xy / _40.refScreen.xy).y);
    float4 e = texture2DCv(refInput, refInputSmplr, param_2);
    float2 param_3 = float2((gl_FragCoord.xy / _40.refScreen.xy).x, (gl_FragCoord.xy / _40.refScreen.xy).y + fragSize.y);
    float4 n = texture2DCv(refInput, refInputSmplr, param_3);
    float2 param_4 = float2((gl_FragCoord.xy / _40.refScreen.xy).x, (gl_FragCoord.xy / _40.refScreen.xy).y - fragSize.y);
    float4 s = texture2DCv(refInput, refInputSmplr, param_4);
    float2 param_5 = gl_FragCoord.xy / _40.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_5);
    float centerWeight = 1.0 + (_40.strength * 4.0);
    float sideWeight = -_40.strength;
    referenceColor = ((((n * sideWeight) + (s * sideWeight)) + (e * sideWeight)) + (w * sideWeight)) + (texColor * centerWeight);
}

fragment refAM35_e6134d019d8aa_out refAM35_e6134d019d8aa(constant ReferenceUniformse6134d019d8aa& _40 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e6134d019d8aa_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _40, refInput, refInputSmplr, referenceColor);
    bool _200 = any(isnan(referenceColor));
    bool _207;
    if (!_200)
    {
        _207 = any(isinf(referenceColor));
    }
    else
    {
        _207 = _200;
    }
    if (_207)
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

