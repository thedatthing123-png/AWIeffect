// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/longshadow2.xml
// Original source comments and attribution:
//velocity *= acPreviewSize*texelSize;
//gl_FragColor = mix(mix(color * alpha * (1.0-dist*fade) * resultAlpha, baseColor, baseColor.a * fill),vec4(1.0,0.0,0.0,1.0),abs(sin(dist*25.0)));
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb09dba903d3f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float size;
    char _m6_pad[12];
    float angle;
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
};

struct refAM35_eb09dba903d3f_out
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
void referenceMain(constant ReferenceUniformseb09dba903d3f& _54, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = _54.refScreen.xy;
    float2 texelSize = float2(1.0) / getTexSize(param);
    float rad = _54.angle * 0.01745329983532428741455078125;
    float2 velocity = float2(cos(rad) * _54.size, (-sin(rad)) * _54.size);
    if (_54.refScreen.y > _54.refScreen.x)
    {
        velocity.y *= (_54.refScreen.x / _54.refScreen.y);
    }
    else
    {
        velocity.x *= (_54.refScreen.y / _54.refScreen.x);
    }
    float speed = length(velocity / texelSize);
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 500.010009765625));
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
        else
        {
            if (_54.fadeType == 2)
            {
                dist = abs(((gl_FragCoord.xy / _54.refScreen.xy) - (float2(_54.refLayer.x + (_54.refLayer.z * 0.5), (_54.refScreen.y - _54.refLayer.y) - (_54.refLayer.w * 0.5)) / _54.refScreen.xy)).x) / abs(velocity.x);
            }
            else
            {
                if (_54.fadeType == 3)
                {
                    dist = abs(((gl_FragCoord.xy / _54.refScreen.xy) - (float2(_54.refLayer.x + (_54.refLayer.z * 0.5), (_54.refScreen.y - _54.refLayer.y) - (_54.refLayer.w * 0.5)) / _54.refScreen.xy)).y) / abs(velocity.y);
                }
            }
        }
    }
    referenceColor = mix(((_54.color * _54.alpha) * (1.0 - (dist * _54.fade))) * resultAlpha, baseColor, float4(baseColor.w * _54.fill));
}

fragment refAM35_eb09dba903d3f_out refAM35_eb09dba903d3f(constant ReferenceUniformseb09dba903d3f& _54 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb09dba903d3f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_54, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _393 = any(isnan(referenceColor));
    bool _400;
    if (!_393)
    {
        _400 = any(isinf(referenceColor));
    }
    else
    {
        _400 = _393;
    }
    if (_400)
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

