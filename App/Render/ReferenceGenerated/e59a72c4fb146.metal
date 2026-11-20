// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s_warp_puff.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse59a72c4fb146
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progress;
    char _m6_pad[12];
    float grid;
    char _m7_pad[12];
    float strength;
    char _m8_pad[12];
    float gravity;
    char _m9_pad[12];
    float rotation;
    char _m10_pad[12];
    float randomness;
    char _m11_pad[12];
    float seed;
};

struct refAM35_e59a72c4fb146_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float h(thread const float2& p, constant ReferenceUniformse59a72c4fb146& _33)
{
    return fract(sin(dot(p + float2(_33.seed), float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse59a72c4fb146& _33, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _33.refLayer.xy) / _33.refLayer.zw;
    float g = fast::max(_33.grid, 2.0);
    float2 cell = floor(uv * g);
    float2 local = fract(uv * g) - float2(0.5);
    float2 param = cell;
    float rnd = h(param, _33);
    float delay = (rnd * _33.randomness) * 0.550000011920928955078125;
    float t = fast::clamp((_33.progress - delay) / fast::max(1.0 - delay, 0.001000000047497451305389404296875), 0.0, 1.0);
    float a = (((rnd - 0.5) * _33.rotation) * 0.01745329983532428741455078125) * t;
    float2x2 R = float2x2(float2(cos(a), -sin(a)), float2(sin(a), cos(a)));
    local = R * local;
    float2 dir = fast::normalize((((cell + float2(0.5)) / float2(g)) - float2(0.5)) + float2(0.001000000047497451305389404296875));
    float2 moved = ((((cell + float2(0.5)) + local) / float2(g)) - (((dir * _33.strength) * t) * t)) - float2(0.0, ((_33.gravity * t) * t) * 0.25);
    float2 param_1 = fast::clamp(moved, float2(0.0), float2(1.0));
    float4 c = texture2DCv(refInput, refInputSmplr, param_1);
    float inside = step(fast::max(abs(local.x), abs(local.y)), 0.5);
    referenceColor = float4(c.xyz, (c.w * inside) * (1.0 - smoothstep(0.819999992847442626953125, 1.0, t)));
}

fragment refAM35_e59a72c4fb146_out refAM35_e59a72c4fb146(constant ReferenceUniformse59a72c4fb146& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e59a72c4fb146_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_33, gl_FragCoord, refInput, refInputSmplr, referenceColor);
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
    out.finalColor = referenceColor;
    return out;
}

