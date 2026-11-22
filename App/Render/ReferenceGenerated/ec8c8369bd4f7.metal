// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/wipe2.xml
// Original source comments and attribution:
//vec2 projectAndClamp(vec2 a, vec2 b) {
//    return clamp(dot(a,b)/dot(b,b),0.0,1.0) * b;
//}
//vec2 v = (vec4(normalize(vec2(cos(rad),-sin(rad))),0.0,1.0) * acLayerToScreen).xy;
//float p = length(projectAndClamp(acLayerNorm.st-vec2(0.5,0.5), v))/length(v)+0.5;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec8c8369bd4f7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float start;
    char _m6_pad[12];
    float end;
    char _m7_pad[12];
    float angle;
    char _m8_pad[12];
    float feather;
};

struct refAM35_ec8c8369bd4f7_out
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
void referenceMain(constant ReferenceUniformsec8c8369bd4f7& _53, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float adjStart = _53.start;
    float adjEnd = _53.end;
    float adjFeather = _53.feather / 100.0;
    float rad = _53.angle * 0.01745329983532428741455078125;
    float2 v = fast::normalize(float2(cos(rad), -sin(rad)));
    float p = dot(((gl_FragCoord.xy - _53.refLayer.xy) / _53.refLayer.zw) - float2(0.5), v) + 0.5;
    float param = adjStart - adjFeather;
    float param_1 = adjStart;
    float param_2 = p;
    float p0 = smoothstepRev(param, param_1, param_2);
    float param_3 = adjEnd;
    float param_4 = adjEnd + adjFeather;
    float param_5 = p;
    float p1 = 1.0 - smoothstepRev(param_3, param_4, param_5);
    float2 param_6 = gl_FragCoord.xy / _53.refScreen.xy;
    referenceColor = (texture2DCv(refInput, refInputSmplr, param_6) * p0) * p1;
}

fragment refAM35_ec8c8369bd4f7_out refAM35_ec8c8369bd4f7(constant ReferenceUniformsec8c8369bd4f7& _53 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec8c8369bd4f7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_53, gl_FragCoord, referenceColor, refInput, refInputSmplr);
    bool _148 = any(isnan(referenceColor));
    bool _155;
    if (!_148)
    {
        _155 = any(isinf(referenceColor));
    }
    else
    {
        _155 = _148;
    }
    if (_155)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _171 = referenceColor;
    float3 _177 = fast::clamp(_171.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _177.x;
    referenceColor.y = _177.y;
    referenceColor.z = _177.z;
    out.finalColor = referenceColor;
    return out;
}

