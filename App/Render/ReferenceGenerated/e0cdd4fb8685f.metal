// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/scanlines.xml
// Original source comments and attribution:
// Hash helpers similar to original
// 0..1
// Scanline baseline
// Grain
// Glitch (probabilistic per whole frame)
// Vertical band
// manual placement
// default before possible band
// Original color and final blend
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse0cdd4fb8685f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float blendFactor;
    char _m6_pad[12];
    float scanlineHeight;
    char _m7_pad[12];
    float scanlineIntensity;
    char _m8_pad[12];
    float scrollSpeed;
    float4 scanColor;
    float progress;
    char _m11_pad[12];
    float grainIntensity;
    char _m12_pad[12];
    float grainTimeScale;
    char _m13_pad[12];
    float glitchProbability;
    char _m14_pad[12];
    float glitchIntensityX;
    char _m15_pad[12];
    float glitchIntensityY;
    char _m16_pad[12];
    float glitchPhase;
    char _m17_pad[12];
    float bandSpeed;
    char _m18_pad[12];
    float bandHeight;
    char _m19_pad[12];
    float bandIntensity;
    char _m20_pad[12];
    float bandChoppiness;
    char _m21_pad[12];
    float staticAmount;
    char _m22_pad[12];
    float warpFactor;
    char _m23_pad[12];
    float chromaAmount;
    char _m24_pad[12];
    float bandPos;
};

struct refAM35_e0cdd4fb8685f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash12(thread const float2& p)
{
    return fract(sin(dot(p, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse0cdd4fb8685f& _44, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 res = _44.refScreen.xy;
    float2 uv = gl_FragCoord.xy / _44.refScreen.xy;
    float scanline = sin(((uv.y * res.y) - (_44.progress * _44.scrollSpeed)) * (1.0 / fast::max(_44.scanlineHeight, 1.0)));
    float3 vhsColor = (_44.scanColor.xyz * scanline) * _44.scanlineIntensity;
    float2 grainSeed = float2(12.98980045318603515625, 78.233001708984375) + float2(_44.progress * _44.grainTimeScale);
    float grain = fract(sin(dot((uv * res) * uv, grainSeed)) * 43758.546875);
    vhsColor += (float3(grain) * _44.grainIntensity);
    float2 tuv = uv;
    if (_44.glitchPhase < _44.glitchProbability)
    {
        float glitchOffsetX = (fract(sin(_44.progress * 12.98980045318603515625) * 43758.546875) - 0.5) * _44.glitchIntensityX;
        float glitchOffsetY = (fract(cos(_44.progress * 78.233001708984375) * 43758.546875) - 0.5) * _44.glitchIntensityY;
        tuv += float2(glitchOffsetX, glitchOffsetY);
    }
    float bandPosVal = _44.bandPos;
    float2 param = uv * res;
    float bandNoise = hash12(param);
    float2 param_1 = tuv;
    float3 chromaColor = texture2DCv(refInput, refInputSmplr, param_1).xyz;
    if (abs(uv.y - bandPosVal) < _44.bandHeight)
    {
        float randomStatic = bandNoise * _44.bandChoppiness;
        vhsColor += (float3(randomStatic) * _44.staticAmount);
        tuv.x += (sin(((uv.y * res.y) * 10.0) + randomStatic) * _44.warpFactor);
        float2 param_2 = tuv + float2(_44.chromaAmount * randomStatic, 0.0);
        float2 param_3 = tuv;
        float2 param_4 = tuv - float2(_44.chromaAmount * randomStatic, 0.0);
        chromaColor = float3(texture2DCv(refInput, refInputSmplr, param_2).x, texture2DCv(refInput, refInputSmplr, param_3).y, texture2DCv(refInput, refInputSmplr, param_4).z);
        float adjustedIntensity = _44.bandIntensity * (1.0 - randomStatic);
        vhsColor = mix(vhsColor, chromaColor, float3(adjustedIntensity));
    }
    float2 param_5 = tuv;
    float3 originalColor = texture2DCv(refInput, refInputSmplr, param_5).xyz;
    float3 finalColor = mix(originalColor, vhsColor, float3(_44.blendFactor));
    referenceColor = float4(finalColor, 1.0);
}

fragment refAM35_e0cdd4fb8685f_out refAM35_e0cdd4fb8685f(constant ReferenceUniformse0cdd4fb8685f& _44 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e0cdd4fb8685f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_44, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _294 = any(isnan(referenceColor));
    bool _301;
    if (!_294)
    {
        _301 = any(isinf(referenceColor));
    }
    else
    {
        _301 = _294;
    }
    if (_301)
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

