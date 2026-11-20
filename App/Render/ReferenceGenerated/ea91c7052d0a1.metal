// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/solidcolor.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea91c7052d0a1
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color;
    float alpha;
    char _m7_pad[12];
    int blendMode;
};

struct refAM35_ea91c7052d0a1_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsea91c7052d0a1& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 result;
    if (_36.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(texColor.w)) * _36.color.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_36.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - _36.color.xyz)), 1.0) * texColor.w;
        }
        else
        {
            result = float4(_36.color.xyz, 1.0) * texColor.w;
        }
    }
    referenceColor = mix(texColor, result, float4(_36.alpha));
}

fragment refAM35_ea91c7052d0a1_out refAM35_ea91c7052d0a1(constant ReferenceUniformsea91c7052d0a1& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea91c7052d0a1_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _135 = any(isnan(referenceColor));
    bool _142;
    if (!_135)
    {
        _142 = any(isinf(referenceColor));
    }
    else
    {
        _142 = _135;
    }
    if (_142)
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

