// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_native_sshakeultra.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse4c2c2a58de22
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amplitude;
    char _m6_pad[12];
    float frequency;
    char _m7_pad[12];
    float rotation;
    char _m8_pad[12];
    float zoom;
    char _m9_pad[12];
    float rgbSplit;
    char _m10_pad[12];
    float seed;
    char _m11_pad[12];
    float phase;
    char _m12_pad[12];
    float mixAmount;
};

struct refAM35_e4c2c2a58de22_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float aeHash(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

static inline __attribute__((always_inline))
float aeNoise(thread const float& x, thread const float& seed)
{
    float i = floor(x);
    float f = fract(x);
    f = (f * f) * (3.0 - (2.0 * f));
    float param = i + seed;
    float param_1 = (i + 1.0) + seed;
    return (mix(aeHash(param), aeHash(param_1), f) * 2.0) - 1.0;
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float2 aeMirror(thread const float2& p)
{
    return abs((fract((p * 0.5) + float2(0.5)) * 2.0) - float2(1.0));
}

static inline __attribute__((always_inline))
float2 aeShakeUV(thread const float2& uv, thread const float& phaseOffset, constant ReferenceUniformse4c2c2a58de22& _106)
{
    float t = ((_106.refScreen.z * _106.frequency) + _106.phase) + phaseOffset;
    float param = t;
    float param_1 = _106.seed;
    float param_2 = t * 2.0299999713897705078125;
    float param_3 = _106.seed + 31.0;
    float nx = aeNoise(param, param_1) + (0.3499999940395355224609375 * aeNoise(param_2, param_3));
    float param_4 = t + 17.0;
    float param_5 = _106.seed + 71.0;
    float param_6 = t * 1.90999996662139892578125;
    float param_7 = _106.seed + 113.0;
    float ny = aeNoise(param_4, param_5) + (0.3499999940395355224609375 * aeNoise(param_6, param_7));
    float param_8 = (t * 0.730000019073486328125) + 39.0;
    float param_9 = _106.seed + 151.0;
    float nr = aeNoise(param_8, param_9);
    float2 param_10 = _106.refScreen.xy;
    float2 px = float2(1.0) / fast::max(getTexSize(param_10), float2(1.0));
    float2 p = (uv - float2(0.5)) - ((float2(nx, ny) * _106.amplitude) * px);
    float ang = ((-nr) * _106.rotation) * 0.01745329238474369049072265625;
    p = (float2x2(float2(cos(ang), -sin(ang)), float2(sin(ang), cos(ang))) * p) / float2(fast::max(1.0 + (_106.zoom * 0.00999999977648258209228515625), 0.75));
    float2 param_11 = p + float2(0.5);
    return aeMirror(param_11);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse4c2c2a58de22& _106, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _106.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float split = _106.rgbSplit * 0.0030000000260770320892333984375;
    float2 param_1 = uv;
    float param_2 = split;
    float2 param_3 = aeShakeUV(param_1, param_2, _106);
    float4 r = texture2DCv(refInput, refInputSmplr, param_3);
    float2 param_4 = uv;
    float param_5 = 0.0;
    float2 param_6 = aeShakeUV(param_4, param_5, _106);
    float4 g = texture2DCv(refInput, refInputSmplr, param_6);
    float2 param_7 = uv;
    float param_8 = -split;
    float2 param_9 = aeShakeUV(param_7, param_8, _106);
    float4 b = texture2DCv(refInput, refInputSmplr, param_9);
    float4 shaken = float4(r.x, g.y, b.z, g.w);
    referenceColor = mix(src, shaken, float4(fast::clamp(_106.mixAmount, 0.0, 1.0)));
    referenceColor.w = src.w;
}

fragment refAM35_e4c2c2a58de22_out refAM35_e4c2c2a58de22(constant ReferenceUniformse4c2c2a58de22& _106 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e4c2c2a58de22_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_106, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _326 = any(isnan(referenceColor));
    bool _333;
    if (!_326)
    {
        _333 = any(isinf(referenceColor));
    }
    else
    {
        _333 = _326;
    }
    if (_333)
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

