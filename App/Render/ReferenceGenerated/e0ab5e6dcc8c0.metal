// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/turbulent_displace.xml
// Original source comments and attribution:
// Utility random and value noise
// Fractal Brownian Motion (FBM)
// Curl noise from fbm via finite differences
// 2D curl
// Repeat
// Mirror
// Clamp
// Time-evolved coordinate
// Domain warp for richer structures
// FBM vector displacement using two uncorrelated fields
// Center around 0
// Flow-like curl noise field
// Curl is already centered around 0
// Apply axis strength and amount
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse0ab5e6dcc8c0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amount;
    char _m6_pad[12];
    float scale;
    char _m7_pad[12];
    float octaves;
    char _m8_pad[12];
    float lacunarity;
    char _m9_pad[12];
    float gain;
    char _m10_pad[12];
    float xStrength;
    char _m11_pad[12];
    float yStrength;
    char _m12_pad[12];
    float warpAmount;
    char _m13_pad[12];
    float evolution;
    char _m14_pad[12];
    float evolutionSpeed;
    char _m15_pad[12];
    float seed;
    char _m16_pad[12];
    int mode;
    char _m17_pad[12];
    int wrapMode;
    char _m18_pad[12];
    float alpha;
};

struct refAM35_e0ab5e6dcc8c0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float random(thread const float2& st)
{
    return fract(sin(dot(st, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float valueNoise(thread const float2& st)
{
    float2 i = floor(st);
    float2 f = fract(st);
    float2 param = i;
    float a = random(param);
    float2 param_1 = i + float2(1.0, 0.0);
    float b = random(param_1);
    float2 param_2 = i + float2(0.0, 1.0);
    float c = random(param_2);
    float2 param_3 = i + float2(1.0);
    float d = random(param_3);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    return (mix(a, b, u.x) + (((c - a) * u.y) * (1.0 - u.x))) + (((d - b) * u.x) * u.y);
}

static inline __attribute__((always_inline))
float fbm(thread const float2& p, thread const float& oct, thread const float& lac, thread const float& g)
{
    float sum = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (float i = 0.0; i < 8.0; i += 1.0)
    {
        if (i >= oct)
        {
            break;
        }
        float2 param = p * freq;
        sum += (amp * valueNoise(param));
        freq *= lac;
        amp *= g;
    }
    return sum;
}

static inline __attribute__((always_inline))
float2 curl(thread const float2& p, thread const float& oct, thread const float& lac, thread const float& g)
{
    float eps = 0.001000000047497451305389404296875;
    float2 param = p + float2(0.0, eps);
    float param_1 = oct;
    float param_2 = lac;
    float param_3 = g;
    float n1 = fbm(param, param_1, param_2, param_3);
    float2 param_4 = p - float2(0.0, eps);
    float param_5 = oct;
    float param_6 = lac;
    float param_7 = g;
    float n2 = fbm(param_4, param_5, param_6, param_7);
    float2 param_8 = p + float2(eps, 0.0);
    float param_9 = oct;
    float param_10 = lac;
    float param_11 = g;
    float n3 = fbm(param_8, param_9, param_10, param_11);
    float2 param_12 = p - float2(eps, 0.0);
    float param_13 = oct;
    float param_14 = lac;
    float param_15 = g;
    float n4 = fbm(param_12, param_13, param_14, param_15);
    float dx = (n3 - n4) / (2.0 * eps);
    float dy = (n1 - n2) / (2.0 * eps);
    return float2(dy, -dx);
}

static inline __attribute__((always_inline))
float2 wrapUV(thread const float2& uv, constant ReferenceUniformse0ab5e6dcc8c0& _252)
{
    if (_252.wrapMode == 1)
    {
        return fract(uv);
    }
    else
    {
        if (_252.wrapMode == 2)
        {
            float2 wrapped = fract(uv);
            float2 mirror = step(float2(0.5), fract(uv * 0.5));
            return mix(wrapped, float2(1.0) - wrapped, mirror);
        }
        else
        {
            return fast::clamp(uv, float2(0.0), float2(1.0));
        }
    }
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse0ab5e6dcc8c0& _252, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _252.refScreen.xy;
    float t = (_252.evolution + (_252.refScreen.z * _252.evolutionSpeed)) + (_252.seed * 0.1234000027179718017578125);
    float2 baseP = (uv * _252.scale) + float2(t);
    float2 param = baseP + float2(13.1000003814697265625, 7.30000019073486328125);
    float param_1 = _252.octaves;
    float param_2 = _252.lacunarity;
    float param_3 = _252.gain;
    float nA = fbm(param, param_1, param_2, param_3);
    float2 param_4 = baseP + float2(-9.69999980926513671875, 2.599999904632568359375);
    float param_5 = _252.octaves;
    float param_6 = _252.lacunarity;
    float param_7 = _252.gain;
    float nB = fbm(param_4, param_5, param_6, param_7);
    float2 warpVec = float2(nA, nB) * _252.warpAmount;
    float2 p = baseP + (warpVec * 2.0);
    float2 disp;
    if (_252.mode == 0)
    {
        float2 param_8 = p + float2(5.19999980926513671875, 1.2999999523162841796875);
        float param_9 = _252.octaves;
        float param_10 = _252.lacunarity;
        float param_11 = _252.gain;
        float nx = fbm(param_8, param_9, param_10, param_11);
        float2 param_12 = p + float2(-3.099999904632568359375, 9.8999996185302734375);
        float param_13 = _252.octaves;
        float param_14 = _252.lacunarity;
        float param_15 = _252.gain;
        float ny = fbm(param_12, param_13, param_14, param_15);
        disp = float2(nx, ny) - float2(0.5);
    }
    else
    {
        float2 param_16 = p;
        float param_17 = _252.octaves;
        float param_18 = _252.lacunarity;
        float param_19 = _252.gain;
        disp = curl(param_16, param_17, param_18, param_19);
    }
    float2 offset = (disp * _252.amount) * float2(_252.xStrength, _252.yStrength);
    float2 param_20 = uv + offset;
    float2 sampleUV = wrapUV(param_20, _252);
    float2 param_21 = sampleUV;
    float4 color = texture2DCv(refInput, refInputSmplr, param_21);
    color.w *= _252.alpha;
    referenceColor = color;
}

fragment refAM35_e0ab5e6dcc8c0_out refAM35_e0ab5e6dcc8c0(constant ReferenceUniformse0ab5e6dcc8c0& _252 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e0ab5e6dcc8c0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_252, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _483 = any(isnan(referenceColor));
    bool _490;
    if (!_483)
    {
        _490 = any(isinf(referenceColor));
    }
    else
    {
        _490 = _483;
    }
    if (_490)
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

