// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/rays_generate.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsee63cf8dafb63
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 centerPoint;
    char _m6_pad[8];
    float strength;
    char _m7_pad[12];
    float _length;
    char _m8_pad[12];
    float decay;
    char _m9_pad[12];
    float threshold;
    float4 fillColor;
    float blend;
};

struct refAM35_ee63cf8dafb63_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsee63cf8dafb63& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _33.refLayer.xy) / _33.refLayer.zw;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = uv;
    float3 center = texture2DCv(refInput, refInputSmplr, param_1).xyz;
    float2 c = _33.centerPoint;
    float2 stepv = ((c - uv) * _33._length) / float2(12.0);
    float3 rays = float3(0.0);
    float w = 1.0;
    float2 p = uv;
    for (int i = 0; i < 12; i++)
    {
        p += stepv;
        float2 param_2 = fast::clamp(p, float2(0.0), float2(1.0));
        float3 q = texture2DCv(refInput, refInputSmplr, param_2).xyz;
        float l = fast::max(fast::max(q.x, q.y), q.z);
        rays += ((q * step(_33.threshold, l)) * w);
        w *= _33.decay;
    }
    rays *= (_33.strength / 12.0);
    float3 outc = src.xyz + ((rays * _33.fillColor.xyz) * _33.fillColor.w);
    referenceColor = float4(mix(src.xyz, outc, float3(_33.blend)), src.w);
}

fragment refAM35_ee63cf8dafb63_out refAM35_ee63cf8dafb63(constant ReferenceUniformsee63cf8dafb63& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ee63cf8dafb63_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
    bool _178 = any(isnan(referenceColor));
    bool _185;
    if (!_178)
    {
        _185 = any(isinf(referenceColor));
    }
    else
    {
        _185 = _178;
    }
    if (_185)
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

