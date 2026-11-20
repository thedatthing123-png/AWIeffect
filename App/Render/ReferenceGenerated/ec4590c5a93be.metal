// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxpixelsorter.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
//////////////////////////
// float step_y;
// if( stepy ) { step_y = texel.y*(rand(uv.x)*100.0); }
// else { step_y = texel.y*(rand(uv.x)*MAX_OFFSET) * (sin(sin(-1.57*0.5))*2.0+1.3); }
// shake offset and modulate it
// more noisy spikes
//////////////////////////
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec4590c5a93be
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progressx;
    char _m6_pad[12];
    float progressb;
    char _m7_pad[12];
    float deltax;
    char _m8_pad[12];
    float pixel;
    char _m9_pad[12];
    float angle;
    char _m10_pad[12];
    float alpha;
    char _m11_pad[12];
    float maxoffset;
    char _m12_pad[12];
    uint offside;
};

struct refAM35_ec4590c5a93be_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float rand(thread const float& co, constant ReferenceUniformsec4590c5a93be& _75)
{
    return fract(sin(co * (91.34580230712890625 + _75.deltax)) * 47453.546875);
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsec4590c5a93be& _75, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _75.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 uv = gl_FragCoord.xy / _75.refScreen.xy;
    float2 texel = float2(1.0) / (gl_FragCoord.xy / _75.refScreen.xy);
    float param_1 = _75.angle * 0.01745329983532428741455078125;
    texel *= rot2m(param_1);
    texel += ((float2(-1.0, 1.0) * _75.progressb) / float2(500.0));
    float4 img = texColor;
    float param_2 = uv.x;
    float step_y = (texel.y * (rand(param_2, _75) * _75.maxoffset)) * 0.001154343248344957828521728515625;
    float param_3 = (uv.x * uv.y) * 1.0;
    step_y += ((rand(param_3, _75) * _75.pixel) * 0.8414709568023681640625);
    float param_4 = uv.x * 0.0;
    step_y = mix(step_y, (step_y * rand(param_4, _75)) * 0.5, sin(1.57000005245208740234375 * _75.progressx));
    if (dot(img, float4(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625, 0.0)) > 0.92817366123199462890625)
    {
        uv.y += step_y;
    }
    else
    {
        uv.y -= step_y;
    }
    float2 param_5 = uv;
    img = texture2DCv(refInput, refInputSmplr, param_5);
    float4 result = mix(texColor, img, float4(1.0)) * texColor.w;
    if (_75.offside != 0u)
    {
        result = mix(texColor, img, float4(1.0));
    }
    float4 param_6 = texColor;
    float4 param_7 = result;
    referenceColor = newLayer(param_6, param_7);
}

fragment refAM35_ec4590c5a93be_out refAM35_ec4590c5a93be(constant ReferenceUniformsec4590c5a93be& _75 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec4590c5a93be_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_75, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _246 = any(isnan(referenceColor));
    bool _253;
    if (!_246)
    {
        _253 = any(isinf(referenceColor));
    }
    else
    {
        _253 = _246;
    }
    if (_253)
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

