// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/radialshadow2.xml
// Original source comments and attribution:
//velocity *= acPreviewSize * texelSize;
//velocity.x *= acScreenSize.y / acScreenSize.x;
//int nSamples = int(clamp(speed, 1.01, 500.01));
//gl_FragColor = mix(mix(color * alpha * (1.0-dist*fade) * resultAlpha, baseColor, baseColor.a * fill),vec4(1.0,0.0,0.0,1.0),abs(sin(dist*25.0)));
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse7b0d60717ad7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 light;
    char _m6_pad[8];
    float size;
    float4 color;
    float alpha;
    char _m9_pad[12];
    float solidity;
    char _m10_pad[12];
    float fill;
    char _m11_pad[12];
    float fade;
    char _m12_pad[12];
    int fadeType;
    char _m13_pad[12];
    float quality;
};

struct refAM35_e7b0d60717ad7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float projectAndClampDist(thread const float2& a, thread const float2& b)
{
    return fast::clamp(dot(a, b) / dot(b, b), 0.0, 1.0);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse7b0d60717ad7& _54, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 param = _54.refScreen.xy;
    float2 texelSize = float2(1.0) / getTexSize(param);
    float2 lightDirection = (gl_FragCoord.xy / _54.refScreen.xy) - ((float2(_54.refLayer.x + (_54.refLayer.z * 0.5), (_54.refScreen.y - _54.refLayer.y) - (_54.refLayer.w * 0.5)) / _54.refScreen.xy) + (float2(_54.light.x, -_54.light.y) / float2(1000.0)));
    float2 velocity = fast::normalize(lightDirection) * fast::min(_54.size, length(lightDirection));
    float speed = length(velocity / texelSize);
    int nSamples = int(_54.quality);
    float maxAlpha = 0.0;
    float accumAlpha = 0.0;
    int minDist = nSamples;
    float2 param_1 = gl_FragCoord.xy / _54.refScreen.xy;
    float4 baseColor = texture2DCv(refInput, refInputSmplr, param_1);
    for (int i = 1; i < nSamples; i++)
    {
        float2 offset = velocity * (float(i) / float(nSamples - 1));
        float2 sampleCoord = (gl_FragCoord.xy / _54.refScreen.xy) - offset;
        float insideTexture = ((step(0.0, sampleCoord.x) * step(sampleCoord.x, 1.0)) * step(0.0, sampleCoord.y)) * step(sampleCoord.y, 1.0);
        float2 param_2 = sampleCoord;
        float sampAlpha = texture2DCv(refInput, refInputSmplr, param_2).w * insideTexture;
        maxAlpha = fast::max(maxAlpha, sampAlpha);
        if (sampAlpha > 0.5)
        {
            minDist = min(minDist, i);
        }
        float adjAlpha = (sampAlpha * _54.solidity) * 0.25;
        accumAlpha = adjAlpha + (accumAlpha * (1.0 - adjAlpha));
    }
    float resultAlpha = mix(accumAlpha, maxAlpha, _54.solidity);
    float dist = 0.0;
    if (_54.fadeType == 0)
    {
        dist = float(minDist) / float(nSamples);
    }
    else
    {
        if (_54.fadeType == 1)
        {
            float2 param_3 = (gl_FragCoord.xy / _54.refScreen.xy) - (float2(_54.refLayer.x + (_54.refLayer.z * 0.5), (_54.refScreen.y - _54.refLayer.y) - (_54.refLayer.w * 0.5)) / _54.refScreen.xy);
            float2 param_4 = velocity;
            dist = projectAndClampDist(param_3, param_4);
        }
    }
    float4 result = mix(((_54.color * _54.alpha) * (1.0 - (dist * _54.fade))) * resultAlpha, baseColor, float4(baseColor.w * _54.fill));
    if (false)
    {
        float2 ld = lightDirection;
        ld.x *= (_54.refScreen.x / _54.refScreen.y);
        float4 lightColor = float4(0.0, 0.0, 0.0, 1.0);
        float lightSize = 0.01970000006258487701416015625;
        float lightIntensity = 0.5;
        result = mix(result, lightColor, float4(lightIntensity * smoothstep(0.0, 0.0500000007450580596923828125, (fast::max(0.0, lightSize - length(ld)) * (1.0 / lightSize)) - result.w)));
        lightColor = float4(1.0);
        lightSize = 0.01950000040233135223388671875;
        lightIntensity = 1.0;
        result = mix(result, lightColor, float4(lightIntensity * smoothstep(0.0, 0.0500000007450580596923828125, (fast::max(0.0, lightSize - length(ld)) * (1.0 / lightSize)) - result.w)));
    }
    referenceColor = result;
}

fragment refAM35_e7b0d60717ad7_out refAM35_e7b0d60717ad7(constant ReferenceUniformse7b0d60717ad7& _54 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e7b0d60717ad7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_54, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _375 = any(isnan(referenceColor));
    bool _382;
    if (!_375)
    {
        _382 = any(isinf(referenceColor));
    }
    else
    {
        _382 = _375;
    }
    if (_382)
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

