// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/chromatic-zoomblur.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wmissing-braces"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

template<typename T, size_t Num>
struct spvUnsafeArray
{
    T elements[Num ? Num : 1];
    
    thread T& operator [] (size_t pos) thread
    {
        return elements[pos];
    }
    constexpr const thread T& operator [] (size_t pos) const thread
    {
        return elements[pos];
    }
    
    device T& operator [] (size_t pos) device
    {
        return elements[pos];
    }
    constexpr const device T& operator [] (size_t pos) const device
    {
        return elements[pos];
    }
    
    constexpr const constant T& operator [] (size_t pos) const constant
    {
        return elements[pos];
    }
    
    threadgroup T& operator [] (size_t pos) threadgroup
    {
        return elements[pos];
    }
    constexpr const threadgroup T& operator [] (size_t pos) const threadgroup
    {
        return elements[pos];
    }
};

struct ReferenceUniformsea601aa767c60
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 centerPoint;
    char _m6_pad[8];
    float strength;
    char _m7_pad[12];
    uint adaptive;
};

struct refAM35_ea601aa767c60_out
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
void referenceMain(constant ReferenceUniformsea601aa767c60& _38, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 param = _38.refScreen.xy;
    float2 texelSize = float2(1.0) / getTexSize(param);
    float2 center = float2(0.5 + (_38.centerPoint.x / 500.0), 0.5 - (_38.centerPoint.y / 500.0));
    float2 v = (gl_FragCoord.xy / _38.refScreen.xy) - (float4(center, 0.0, 1.0) * _38.refLayerToScreen).xy;
    float speed = length(float2(_38.strength / 2.0) / texelSize);
    if (_38.adaptive != 0u)
    {
        speed *= length(((gl_FragCoord.xy - _38.refLayer.xy) / _38.refLayer.zw) - center);
    }
    else
    {
        speed *= smoothstep(0.0, length(texelSize) * 5.0, length(((gl_FragCoord.xy - _38.refLayer.xy) / _38.refLayer.zw) - center));
    }
    int nSamples = int(fast::clamp(speed, 7.0100002288818359375, 100.01000213623046875));
    float4 outColor = float4(0.0);
    float2 vnorm = (fast::normalize(v) * texelSize) * speed;
    float2 offsetScale = float2(1.0);
    if (_38.refScreen.y > _38.refScreen.x)
    {
        offsetScale.x *= (_38.refScreen.x / _38.refScreen.y);
    }
    else
    {
        offsetScale.y *= (_38.refScreen.y / _38.refScreen.x);
    }
    spvUnsafeArray<float4, 7> chromas;
    chromas[0] = float4(0.20000000298023223876953125, 0.0, 0.0, 1.0);
    chromas[1] = float4(0.300000011920928955078125, 0.0, 0.0, 1.0);
    chromas[2] = float4(0.5, 0.33329999446868896484375, 0.0, 1.0);
    chromas[3] = float4(0.0, 0.3333300054073333740234375, 0.0, 1.0);
    chromas[4] = float4(0.0, 0.3333300054073333740234375, 0.5, 1.0);
    chromas[5] = float4(0.0, 0.0, 0.300000011920928955078125, 1.0);
    chromas[6] = float4(0.0, 0.0, 0.20000000298023223876953125, 1.0);
    for (int i = 0; i < nSamples; i++)
    {
        float2 offset = vnorm * ((float(i) / float(nSamples)) - 0.5);
        offset *= offsetScale;
        float c = fast::min((float(i) * 7.0) / float(nSamples), 6.0);
        float fr = fract(c);
        int cidx = int(c);
        float4 chroma = mix(chromas[cidx], chromas[cidx + 1], float4(fr));
        float2 param_1 = (gl_FragCoord.xy / _38.refScreen.xy) - offset;
        outColor += (texture2DCv(refInput, refInputSmplr, param_1) * chroma);
    }
    outColor.w /= float(nSamples);
    float4 _287 = outColor;
    float3 _290 = _287.xyz / float3(float(nSamples) / 7.0);
    outColor.x = _290.x;
    outColor.y = _290.y;
    outColor.z = _290.z;
    referenceColor = outColor;
}

fragment refAM35_ea601aa767c60_out refAM35_ea601aa767c60(constant ReferenceUniformsea601aa767c60& _38 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea601aa767c60_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_38, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _305 = any(isnan(referenceColor));
    bool _312;
    if (!_305)
    {
        _312 = any(isinf(referenceColor));
    }
    else
    {
        _312 = _305;
    }
    if (_312)
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

