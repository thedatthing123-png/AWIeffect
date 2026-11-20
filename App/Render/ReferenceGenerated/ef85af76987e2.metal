// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s_psykoblobs.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef85af76987e2
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float noiseFreq;
    char _m6_pad[12];
    float sourceScale;
    char _m7_pad[12];
    float freqColors;
    char _m8_pad[12];
    float phaseSpeed;
    char _m9_pad[12];
    float saturation;
    char _m10_pad[12];
    float outlineStrength;
    char _m11_pad[12];
    float mixWithSource;
};

struct refAM35_ef85af76987e2_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float gray(thread const float3& c)
{
    return dot(c, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
}

static inline __attribute__((always_inline))
float hash(thread const float2& p)
{
    return fract(sin(dot(p, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float smoothNoise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i;
    float2 param_1 = i + float2(1.0, 0.0);
    float bottom = mix(hash(param), hash(param_1), f.x);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 param_3 = i + float2(1.0);
    float top = mix(hash(param_2), hash(param_3), f.x);
    return mix(bottom, top, f.y);
}

static inline __attribute__((always_inline))
float fbm(thread float2& p)
{
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0);
    for (int i = 0; i < 3; i++)
    {
        float2 param = p;
        v += (a * smoothNoise(param));
        p = (p * 2.0) + shift;
        a *= 0.5;
    }
    return v;
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsef85af76987e2& _161, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _161.refScreen.xy;
    float2 param = uv;
    float4 srcSample = texture2DCv(refInput, refInputSmplr, param);
    float3 param_1 = srcSample.xyz;
    float srcLuma = gray(param_1);
    float2 noiseUV = uv * _161.noiseFreq;
    float2 param_2 = noiseUV;
    float _188 = fbm(param_2);
    float blobs = _188;
    float combinedVal = (srcLuma * _161.sourceScale) + blobs;
    float3 freqRGB = float3(1.0, 1.14999997615814208984375, 1.2999999523162841796875);
    float3 phaseRGB = float3(0.0, 0.3300000131130218505859375, 0.670000016689300537109375);
    float3 colorPhase = ((freqRGB * (combinedVal * _161.freqColors)) + phaseRGB) + float3(_161.refScreen.z * _161.phaseSpeed);
    float3 outCol = float3(0.5) + (sin(colorPhase * 6.28318500518798828125) * 0.5);
    float3 param_3 = outCol;
    float lumaOut = gray(param_3);
    outCol = mix(float3(lumaOut), outCol, float3(_161.saturation));
    float outlineMask = smoothstep(0.0500000007450580596923828125, 0.300000011920928955078125 * _161.outlineStrength, srcLuma);
    outCol *= mix(1.0, outlineMask, _161.outlineStrength);
    float3 finalCol = mix(outCol, srcSample.xyz, float3(_161.mixWithSource));
    referenceColor = float4(finalCol, srcSample.w);
}

fragment refAM35_ef85af76987e2_out refAM35_ef85af76987e2(constant ReferenceUniformsef85af76987e2& _161 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef85af76987e2_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _161, refInput, refInputSmplr, referenceColor);
    bool _283 = any(isnan(referenceColor));
    bool _290;
    if (!_283)
    {
        _290 = any(isinf(referenceColor));
    }
    else
    {
        _290 = _283;
    }
    if (_290)
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

