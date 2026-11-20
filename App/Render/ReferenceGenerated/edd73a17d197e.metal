// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/fill.xml
// Original source comments and attribution:
// Solid Color Wipe
// - Wipe in from start and end with feather, matching wipe2.xml math.
// - Blend like solidcolor.xml with Normal/Multiply/Screen and opacity.
// for sampling
// Wipe mask following wipe2.xml conventions
// Blend like solidcolor.xml
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsedd73a17d197e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 fillColor;
    float alpha;
    char _m7_pad[12];
    int blendMode;
    char _m8_pad[12];
    float start;
    char _m9_pad[12];
    float end;
    char _m10_pad[12];
    float angle;
    char _m11_pad[12];
    float feather;
};

struct refAM35_edd73a17d197e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float smoothstepRev(thread const float& edge0, thread const float& edge1, thread const float& x)
{
    if (edge0 == edge1)
    {
        return step(edge0, x);
    }
    else
    {
        return smoothstep(edge0, edge1, x);
    }
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsedd73a17d197e& _58, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _58.refScreen.xy;
    float adjStart = _58.start;
    float adjEnd = _58.end;
    float adjFeather = _58.feather / 100.0;
    float rad = _58.angle * 0.01745329983532428741455078125;
    float2 v = fast::normalize(float2(cos(rad), -sin(rad)));
    float p = dot(((gl_FragCoord.xy - _58.refLayer.xy) / _58.refLayer.zw) - float2(0.5), v) + 0.5;
    float param = adjStart - adjFeather;
    float param_1 = adjStart;
    float param_2 = p;
    float p0 = smoothstepRev(param, param_1, param_2);
    float param_3 = adjEnd;
    float param_4 = adjEnd + adjFeather;
    float param_5 = p;
    float p1 = 1.0 - smoothstepRev(param_3, param_4, param_5);
    float mask = fast::clamp(p0 * p1, 0.0, 1.0);
    float2 param_6 = uv;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_6);
    float4 result;
    if (_58.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(texColor.w)) * _58.fillColor.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_58.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - _58.fillColor.xyz)), 1.0) * texColor.w;
        }
        else
        {
            result = float4(_58.fillColor.xyz, 1.0) * texColor.w;
        }
    }
    referenceColor = mix(texColor, result, float4(_58.alpha * mask));
}

fragment refAM35_edd73a17d197e_out refAM35_edd73a17d197e(constant ReferenceUniformsedd73a17d197e& _58 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_edd73a17d197e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _58, refInput, refInputSmplr, referenceColor);
    bool _232 = any(isnan(referenceColor));
    bool _239;
    if (!_232)
    {
        _239 = any(isinf(referenceColor));
    }
    else
    {
        _239 = _232;
    }
    if (_239)
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

