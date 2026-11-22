// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/halftonecmyk.xml
// Original source comments and attribution:
// Y Distance
// X Distance
// Sampling
// CMYK
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformsecaa448a463ac
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amount;
    char _m6_pad[12];
    float strength;
    char _m7_pad[12];
    float blackWeight;
    char _m8_pad[12];
    float angle;
    char _m9_pad[12];
    float phase;
};

struct refAM35_ecaa448a463ac_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float halftone(thread const float& a, thread const float4& mask, thread float4& gl_FragCoord, constant ReferenceUniformsecaa448a463ac& _78, texture2d<float> refInput, sampler refInputSmplr)
{
    float rad = a * 0.01745329983532428741455078125;
    float2x2 rot = float2x2(float2(cos(rad), -sin(rad)), float2(sin(rad), cos(rad)));
    float2x2 invrot = float2x2(float2(cos(-rad), -sin(-rad)), float2(sin(-rad), cos(-rad)));
    float2 st = gl_FragCoord.xy / _78.refScreen.xy;
    st -= (float2(_78.refLayer.x + (_78.refLayer.z * 0.5), (_78.refScreen.y - _78.refLayer.y) - (_78.refLayer.w * 0.5)) / _78.refScreen.xy);
    st.y *= (_78.refScreen.y / _78.refScreen.x);
    st *= rot;
    float distY = mod(st.y * _78.amount, 1.0);
    if (distY < 0.5)
    {
        distY = -distY;
    }
    else
    {
        distY = 1.0 - distY;
    }
    float absDistY = abs(distY);
    distY /= _78.amount;
    float xoffs = step(1.0, mod((st.y * _78.amount) + 0.5, 2.0)) * _78.phase;
    float distX = mod((st.x * _78.amount) + xoffs, 1.0);
    if (distX < 0.5)
    {
        distX = -distX;
    }
    else
    {
        distX = 1.0 - distX;
    }
    float absDistX = abs(distX);
    distX /= _78.amount;
    st.y += distY;
    st.x += distX;
    st *= invrot;
    st.y /= (_78.refScreen.y / _78.refScreen.x);
    st += (float2(_78.refLayer.x + (_78.refLayer.z * 0.5), (_78.refScreen.y - _78.refLayer.y) - (_78.refLayer.w * 0.5)) / _78.refScreen.xy);
    float2 param = st;
    float4 samp = texture2DCv(refInput, refInputSmplr, param);
    float k = fast::min(1.0 - samp.x, fast::min(1.0 - samp.y, 1.0 - samp.z)) * _78.blackWeight;
    float _260;
    if (k >= 1.0)
    {
        _260 = 0.0;
    }
    else
    {
        _260 = ((1.0 - samp.x) - k) / (1.0 - k);
    }
    float c = _260;
    float _276;
    if (k >= 1.0)
    {
        _276 = 0.0;
    }
    else
    {
        _276 = ((1.0 - samp.y) - k) / (1.0 - k);
    }
    float m = _276;
    float _292;
    if (k >= 1.0)
    {
        _292 = 0.0;
    }
    else
    {
        _292 = ((1.0 - samp.z) - k) / (1.0 - k);
    }
    float y = _292;
    float4 cmyk = float4(c, m, y, k);
    float lum = length(cmyk * mask) / length(mask);
    float dist = length(float2(absDistX, absDistY));
    float radius = _78.strength * 2.0;
    float mag = fast::max(0.0, radius - dist);
    float p = smoothstep(0.4000000059604644775390625, 0.60000002384185791015625, mag * lum) * samp.w;
    return p;
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsecaa448a463ac& _78, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float param = _78.angle + 15.0;
    float4 param_1 = float4(1.0, 0.0, 0.0, 0.0);
    float c = halftone(param, param_1, gl_FragCoord, _78, refInput, refInputSmplr);
    float param_2 = _78.angle + 75.0;
    float4 param_3 = float4(0.0, 1.0, 0.0, 0.0);
    float m = halftone(param_2, param_3, gl_FragCoord, _78, refInput, refInputSmplr);
    float param_4 = _78.angle + 0.0;
    float4 param_5 = float4(0.0, 0.0, 1.0, 0.0);
    float y = halftone(param_4, param_5, gl_FragCoord, _78, refInput, refInputSmplr);
    float param_6 = _78.angle + 45.0;
    float4 param_7 = float4(0.0, 0.0, 0.0, 1.0);
    float k = halftone(param_6, param_7, gl_FragCoord, _78, refInput, refInputSmplr);
    float2 param_8 = gl_FragCoord.xy / _78.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_8);
    float4 outColor = float4((1.0 - c) - k, (1.0 - m) - k, (1.0 - y) - k, 1.0) * texColor.w;
    referenceColor = outColor;
}

fragment refAM35_ecaa448a463ac_out refAM35_ecaa448a463ac(constant ReferenceUniformsecaa448a463ac& _78 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ecaa448a463ac_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _78, refInput, refInputSmplr, referenceColor);
    bool _417 = any(isnan(referenceColor));
    bool _424;
    if (!_417)
    {
        _424 = any(isinf(referenceColor));
    }
    else
    {
        _424 = _417;
    }
    if (_424)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _438 = referenceColor;
    float3 _444 = fast::clamp(_438.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _444.x;
    referenceColor.y = _444.y;
    referenceColor.z = _444.z;
    out.finalColor = referenceColor;
    return out;
}

