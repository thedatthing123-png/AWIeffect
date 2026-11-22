// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s_pixelsort.xml
// Original source comments and attribution:
// s_pixelsort v4 - Ultra Fidelity AE Logic
// Monochrome/Luma
// Seed influence on the base sampling pattern
// Intense search for high-contrast streaks (Sapphire "Smear" style)
// Maximum depth for thick glitch bars
// Break based on Randomly Restart + Seed + Temporal Jitter
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef9005da47ae5
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float threshold;
    char _m6_pad[12];
    float sortAngle;
    char _m7_pad[12];
    int sortDirection;
    char _m8_pad[12];
    int sortType;
    char _m9_pad[12];
    float randomlyRestart;
    char _m10_pad[12];
    float softenThreshold;
    char _m11_pad[12];
    float seed;
    char _m12_pad[12];
    float blurMatte;
    char _m13_pad[12];
    float mixWithSource;
};

struct refAM35_ef9005da47ae5_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash(thread const float2& p)
{
    return fract(sin(dot(p, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float getVal(thread const float3& col, thread const int& type)
{
    if (type == 1)
    {
        return col.x;
    }
    if (type == 2)
    {
        return col.y;
    }
    if (type == 3)
    {
        return col.z;
    }
    return dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsef9005da47ae5& _95, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _95.refScreen.xy;
    float rad = _95.sortAngle * 0.01745329238474369049072265625;
    float2 dir = float2(cos(rad), sin(rad));
    float2 param = float2(_95.seed, _95.seed * 0.5);
    float2 seedOff = float2(hash(param));
    float2 param_1 = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param_1);
    float3 param_2 = src.xyz;
    int param_3 = _95.sortType;
    float val = getVal(param_2, param_3);
    float soft = fast::max(_95.softenThreshold, 0.001000000047497451305389404296875);
    float tLow = _95.threshold - (soft * 0.5);
    float tHigh = _95.threshold + (soft * 0.5);
    float _167;
    if (_95.sortDirection == 0)
    {
        _167 = smoothstep(tLow, tHigh, val);
    }
    else
    {
        _167 = 1.0 - smoothstep(tLow, tHigh, val);
    }
    float weight = _167;
    float3 res = src.xyz;
    if (weight > 0.00999999977648258209228515625)
    {
        float stepSize = 0.00120000005699694156646728515625;
        int iterations = 80;
        float3 streakCol = src.xyz;
        float extremeVal = (_95.sortDirection == 0) ? (-1.0) : 2.0;
        bool _268;
        for (int i = 1; i < 80; i++)
        {
            float d = float(i) * stepSize;
            float2 sampleUv = uv - (dir * d);
            bool _226 = sampleUv.x < 0.0;
            bool _233;
            if (!_226)
            {
                _233 = sampleUv.x > 1.0;
            }
            else
            {
                _233 = _226;
            }
            bool _240;
            if (!_233)
            {
                _240 = sampleUv.y < 0.0;
            }
            else
            {
                _240 = _233;
            }
            bool _247;
            if (!_240)
            {
                _247 = sampleUv.y > 1.0;
            }
            else
            {
                _247 = _240;
            }
            if (_247)
            {
                break;
            }
            float2 param_4 = sampleUv;
            float4 sampleCol = texture2DCv(refInput, refInputSmplr, param_4);
            float3 param_5 = sampleCol.xyz;
            int param_6 = _95.sortType;
            float sampleVal = getVal(param_5, param_6);
            if (_95.sortDirection == 0)
            {
                _268 = sampleVal > tLow;
            }
            else
            {
                _268 = sampleVal < tHigh;
            }
            bool inRange = _268;
            if (inRange)
            {
                if (_95.sortDirection == 0)
                {
                    if (sampleVal > extremeVal)
                    {
                        extremeVal = sampleVal;
                        streakCol = sampleCol.xyz;
                    }
                }
                else
                {
                    if (sampleVal < extremeVal)
                    {
                        extremeVal = sampleVal;
                        streakCol = sampleCol.xyz;
                    }
                }
            }
            else
            {
                break;
            }
            bool _309 = _95.randomlyRestart > 0.0;
            bool _327;
            if (_309)
            {
                float2 param_7 = (sampleUv + seedOff) + float2(_95.refScreen.z * 0.00999999977648258209228515625);
                _327 = hash(param_7) < (_95.randomlyRestart * 0.20000000298023223876953125);
            }
            else
            {
                _327 = _309;
            }
            if (_327)
            {
                break;
            }
        }
        if (_95.blurMatte > 0.0)
        {
            float2 param_8 = uv + ((dir * 0.004999999888241291046142578125) * _95.blurMatte);
            float4 blurSample = texture2DCv(refInput, refInputSmplr, param_8);
            streakCol = mix(streakCol, blurSample.xyz, float3(_95.blurMatte * 0.4000000059604644775390625));
        }
        res = mix(src.xyz, streakCol, float3(weight));
    }
    res = mix(res, src.xyz, float3(_95.mixWithSource));
    referenceColor = float4(res, src.w);
}

fragment refAM35_ef9005da47ae5_out refAM35_ef9005da47ae5(constant ReferenceUniformsef9005da47ae5& _95 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef9005da47ae5_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _95, refInput, refInputSmplr, referenceColor);
    bool _388 = any(isnan(referenceColor));
    bool _395;
    if (!_388)
    {
        _395 = any(isinf(referenceColor));
    }
    else
    {
        _395 = _388;
    }
    if (_395)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _408 = referenceColor;
    float3 _414 = fast::clamp(_408.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _414.x;
    referenceColor.y = _414.y;
    referenceColor.z = _414.z;
    out.finalColor = referenceColor;
    return out;
}

