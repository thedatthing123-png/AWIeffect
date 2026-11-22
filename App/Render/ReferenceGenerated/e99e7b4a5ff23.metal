// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/stretchsegment.xml
// Original source comments and attribution:
//float d = min(stretch/500.0,abs(dist));
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse99e7b4a5ff23
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float angle;
    char _m6_pad[12];
    float stretch;
    char _m7_pad[12];
    float offset;
    char _m8_pad[12];
    float ref_smooth;
};

struct refAM35_e99e7b4a5ff23_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float sminCubic(thread const float& a, thread const float& b, thread const float& k)
{
    float h = fast::max(k - abs(a - b), 0.0) / k;
    return fast::min(a, b) - ((((h * h) * h) * k) * 0.16666667163372039794921875);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse99e7b4a5ff23& _85, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float param = _85.angle * 0.01745329983532428741455078125;
    float2 v = float2(1.0, 0.0) * rot(param);
    float2 st = gl_FragCoord.xy / _85.refScreen.xy;
    st -= (float2(_85.refLayer.x + (_85.refLayer.z * 0.5), (_85.refScreen.y - _85.refLayer.y) - (_85.refLayer.w * 0.5)) / _85.refScreen.xy);
    float dist = dot(st, v) + (_85.offset / 1000.0);
    float adjStretch = _85.stretch / 500.0;
    float param_1 = adjStretch;
    float param_2 = abs(dist);
    float param_3 = fast::max(9.9999997473787516355514526367188e-06, _85.ref_smooth * adjStretch);
    float d = sminCubic(param_1, param_2, param_3);
    float2 param_4 = (gl_FragCoord.xy / _85.refScreen.xy) + ((v * d) * (-sign(dist)));
    float4 color = texture2DCv(refInput, refInputSmplr, param_4);
    if (false)
    {
        float4 guideCenterColor = float4(1.0, 0.0, 0.0, 1.0);
        float4 guideStretchColor = float4(1.0, 1.0, 0.0, 1.0);
        referenceColor = mix(mix(color, guideStretchColor, float4(fast::min(0.300000011920928955078125, 1.0 - step(_85.stretch / 500.0, abs(dist))))), guideCenterColor, float4(1.0 - step(2.0 / length(_85.refScreen.xy), abs(dist))));
    }
    else
    {
        referenceColor = color;
    }
}

fragment refAM35_e99e7b4a5ff23_out refAM35_e99e7b4a5ff23(constant ReferenceUniformse99e7b4a5ff23& _85 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e99e7b4a5ff23_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_85, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _229 = any(isnan(referenceColor));
    bool _236;
    if (!_229)
    {
        _236 = any(isinf(referenceColor));
    }
    else
    {
        _236 = _229;
    }
    if (_236)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _250 = referenceColor;
    float3 _256 = fast::clamp(_250.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _256.x;
    referenceColor.y = _256.y;
    referenceColor.z = _256.z;
    out.finalColor = referenceColor;
    return out;
}

