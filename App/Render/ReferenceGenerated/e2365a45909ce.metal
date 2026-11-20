// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/3wipeplasma.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse2365a45909ce
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float wipe_percent;
    char _m6_pad[12];
    float edge_softness;
    char _m7_pad[12];
    float frequency;
    char _m8_pad[12];
    float seed;
    char _m9_pad[12];
    float phase_speed;
    float4 fill_color;
};

struct refAM35_e2365a45909ce_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float h(thread const float2& p)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
float n(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i;
    float2 param_1 = i + float2(1.0, 0.0);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 param_3 = i + float2(1.0);
    return mix(mix(h(param), h(param_1), f.x), mix(h(param_2), h(param_3), f.x), f.y);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse2365a45909ce& _102, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _102.refLayer.xy) / _102.refLayer.zw;
    float t = (_102.refScreen.z * _102.phase_speed) + _102.seed;
    float2 param = (uv * _102.frequency) + float2(t * 0.20999999344348907470703125, (-t) * 0.12999999523162841796875);
    float2 param_1 = ((uv * _102.frequency) * 2.0299999713897705078125) - float2(t * 0.17000000178813934326171875, t * 0.10999999940395355224609375);
    float2 param_2 = ((uv * _102.frequency) * 4.070000171661376953125) + float2(_102.seed);
    float q = ((n(param) * 0.62000000476837158203125) + (n(param_1) * 0.25)) + (n(param_2) * 0.12999999523162841796875);
    float m = smoothstep(_102.wipe_percent - _102.edge_softness, _102.wipe_percent + _102.edge_softness, (uv.x + (q * 0.3499999940395355224609375)) - 0.180000007152557373046875);
    float2 param_3 = uv;
    float4 s = texture2DCv(refInput, refInputSmplr, param_3);
    float edge = 1.0 - smoothstep(0.0, fast::max(_102.edge_softness, 0.001000000047497451305389404296875), abs(((uv.x + (q * 0.3499999940395355224609375)) - 0.180000007152557373046875) - _102.wipe_percent));
    float3 rgb = mix(s.xyz, _102.fill_color.xyz, float3(edge * _102.fill_color.w));
    referenceColor = float4(rgb, s.w * m);
}

fragment refAM35_e2365a45909ce_out refAM35_e2365a45909ce(constant ReferenceUniformse2365a45909ce& _102 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e2365a45909ce_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _102, refInput, refInputSmplr, referenceColor);
    bool _258 = any(isnan(referenceColor));
    bool _265;
    if (!_258)
    {
        _265 = any(isinf(referenceColor));
    }
    else
    {
        _265 = _258;
    }
    if (_265)
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

