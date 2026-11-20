// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s_flicker.xml
// Original source comments and attribution:
/*
                AE/Sapphire-like brightness flicker:
                flicker is remapped from 0..1 to -1..1,
                then bias shifts the brightness direction.
            */
/*
                Strobe simulation.
            */
/*
                Sapphire-style independent RGB flicker.
            */
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse69ae7b9c2440
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float brightnessAmp;
    char _m6_pad[12];
    float colorAmp;
    char _m7_pad[12];
    float frequency;
    char _m8_pad[12];
    float smoothRandom;
    char _m9_pad[12];
    float bias0;
    char _m10_pad[12];
    float phase;
    char _m11_pad[12];
    int flickerMode;
    char _m12_pad[12];
    float frameBased;
    char _m13_pad[12];
    float strobeAmount;
    char _m14_pad[12];
    float strobeWidth;
    char _m15_pad[12];
    float redAmount;
    char _m16_pad[12];
    float greenAmount;
    char _m17_pad[12];
    float blueAmount;
    char _m18_pad[12];
    float baseBrightness;
    char _m19_pad[12];
    float contrast;
    char _m20_pad[12];
    float saturation;
    char _m21_pad[12];
    float seed;
    char _m22_pad[12];
    float blend;
};

struct refAM35_e69ae7b9c2440_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float hash(thread const float& n, constant ReferenceUniformse69ae7b9c2440& _59)
{
    return fract(sin((n * 12.98980045318603515625) + (_59.seed * 78.233001708984375)) * 43758.546875);
}

static inline __attribute__((always_inline))
float smoothNoise(thread const float& x, constant ReferenceUniformse69ae7b9c2440& _59)
{
    float i = floor(x);
    float f = fract(x);
    float param = i;
    float a = hash(param, _59);
    float param_1 = i + 1.0;
    float b = hash(param_1, _59);
    f = (f * f) * (3.0 - (2.0 * f));
    return mix(a, b, f);
}

static inline __attribute__((always_inline))
float getFlicker(thread const float& t, constant ReferenceUniformse69ae7b9c2440& _59)
{
    float timeValue = (t * _59.frequency) + (_59.phase * 100.0);
    float steppedTime = floor(timeValue);
    float mixedTime = mix(timeValue, steppedTime, _59.frameBased);
    float param = floor(timeValue);
    float hardRand = hash(param, _59);
    float param_1 = timeValue;
    float softRand = smoothNoise(param_1, _59);
    float randValue = mix(hardRand, softRand, _59.smoothRandom);
    float pulseValue = (sin(timeValue * 6.283185482025146484375) * 0.5) + 0.5;
    float randomPulse = pulseValue * randValue;
    float finalFlicker = randValue;
    if (_59.flickerMode == 0)
    {
        float param_2 = floor(mixedTime);
        finalFlicker = hash(param_2, _59);
    }
    else
    {
        if (_59.flickerMode == 1)
        {
            float param_3 = timeValue;
            finalFlicker = smoothNoise(param_3, _59);
        }
        else
        {
            if (_59.flickerMode == 2)
            {
                finalFlicker = pulseValue;
            }
            else
            {
                if (_59.flickerMode == 3)
                {
                    finalFlicker = randomPulse;
                }
            }
        }
    }
    float param_4 = timeValue;
    finalFlicker = mix(finalFlicker, smoothNoise(param_4, _59), _59.smoothRandom * 0.5);
    return finalFlicker;
}

static inline __attribute__((always_inline))
float hash2(thread const float& n, thread const float& s, constant ReferenceUniformse69ae7b9c2440& _59)
{
    return fract(sin(((n * 17.3710002899169921875) + (s * 91.7129974365234375)) + (_59.seed * 41.1699981689453125)) * 24634.634765625);
}

static inline __attribute__((always_inline))
float3 applyContrast(thread const float3& col, thread const float& con)
{
    return ((col - float3(0.5)) * con) + float3(0.5);
}

static inline __attribute__((always_inline))
float3 saturateColor(thread const float3& col, thread const float& sat)
{
    float grey = dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    return mix(float3(grey), col, float3(sat));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse69ae7b9c2440& _59, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _59.refScreen.xy;
    float t = _59.refScreen.z;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 col = src.xyz;
    float param_1 = t;
    float flicker = getFlicker(param_1, _59);
    float centered = (flicker - 0.5) * 2.0;
    centered += _59.bias0;
    centered = fast::clamp(centered, -2.0, 2.0);
    float brightnessMult = 1.0 + (centered * _59.brightnessAmp);
    float strobePhase = fract((t * _59.frequency) + _59.phase);
    float strobeMask = step(strobePhase, _59.strobeWidth);
    float strobeMult = mix(1.0, strobeMask * 2.0, _59.strobeAmount);
    brightnessMult *= strobeMult;
    col *= _59.baseBrightness;
    col *= brightnessMult;
    float rt = ((t * _59.frequency) + 13.1000003814697265625) + (_59.phase * 50.0);
    float gt = ((t * _59.frequency) + 37.700000762939453125) + (_59.phase * 80.0);
    float bt = ((t * _59.frequency) + 91.3000030517578125) + (_59.phase * 120.0);
    float param_2 = floor(rt);
    float param_3 = 1.0;
    float param_4 = rt;
    float rNoise = mix(hash2(param_2, param_3, _59), smoothNoise(param_4, _59), _59.smoothRandom);
    float param_5 = floor(gt);
    float param_6 = 2.0;
    float param_7 = gt;
    float gNoise = mix(hash2(param_5, param_6, _59), smoothNoise(param_7, _59), _59.smoothRandom);
    float param_8 = floor(bt);
    float param_9 = 3.0;
    float param_10 = bt;
    float bNoise = mix(hash2(param_8, param_9, _59), smoothNoise(param_10, _59), _59.smoothRandom);
    float rFlick = 1.0 + ((((rNoise - 0.5) * 2.0) * _59.colorAmp) * _59.redAmount);
    float gFlick = 1.0 + ((((gNoise - 0.5) * 2.0) * _59.colorAmp) * _59.greenAmount);
    float bFlick = 1.0 + ((((bNoise - 0.5) * 2.0) * _59.colorAmp) * _59.blueAmount);
    col *= float3(rFlick, gFlick, bFlick);
    float3 param_11 = col;
    float param_12 = _59.contrast;
    col = applyContrast(param_11, param_12);
    float3 param_13 = col;
    float param_14 = _59.saturation;
    col = saturateColor(param_13, param_14);
    col = fast::clamp(col, float3(0.0), float3(1.0));
    float4 result = float4(col, src.w);
    referenceColor = mix(src, result, float4(_59.blend));
}

fragment refAM35_e69ae7b9c2440_out refAM35_e69ae7b9c2440(constant ReferenceUniformse69ae7b9c2440& _59 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e69ae7b9c2440_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_59, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _485 = any(isnan(referenceColor));
    bool _492;
    if (!_485)
    {
        _492 = any(isinf(referenceColor));
    }
    else
    {
        _492 = _485;
    }
    if (_492)
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

