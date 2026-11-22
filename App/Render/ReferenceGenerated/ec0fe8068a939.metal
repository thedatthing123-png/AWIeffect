// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/pinchbulge2.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec0fe8068a939
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
    float radius;
};

struct refAM35_ec0fe8068a939_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsec0fe8068a939& _33, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 UV = gl_FragCoord.xy / _33.refScreen.xy;
    float2 center = (float2(_33.refLayer.x + (_33.refLayer.z * 0.5), (_33.refScreen.y - _33.refLayer.y) - (_33.refLayer.w * 0.5)) / _33.refScreen.xy) - ((_33.centerPoint / float2(1000.0)) * float2(-1.0, 1.0));
    UV -= center;
    UV.x *= (_33.refScreen.x / _33.refScreen.y);
    float dist = length(UV);
    if (dist < _33.radius)
    {
        float p = dist / _33.radius;
        if (_33.strength > 0.0)
        {
            UV *= mix(1.0, smoothstep(0.0, _33.radius / dist, p), _33.strength * 0.75);
        }
        else
        {
            UV *= mix(1.0, (powr(p, 1.0 + (_33.strength * 0.75)) * _33.radius) / dist, 1.0 - p);
        }
    }
    UV.x /= (_33.refScreen.x / _33.refScreen.y);
    UV += center;
    float2 param = UV;
    referenceColor = texture2DCv(refInput, refInputSmplr, param);
}

fragment refAM35_ec0fe8068a939_out refAM35_ec0fe8068a939(constant ReferenceUniformsec0fe8068a939& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec0fe8068a939_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, referenceColor, refInput, refInputSmplr);
    bool _171 = any(isnan(referenceColor));
    bool _178;
    if (!_171)
    {
        _178 = any(isinf(referenceColor));
    }
    else
    {
        _178 = _171;
    }
    if (_178)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _192 = referenceColor;
    float3 _198 = fast::clamp(_192.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _198.x;
    referenceColor.y = _198.y;
    referenceColor.z = _198.z;
    out.finalColor = referenceColor;
    return out;
}

