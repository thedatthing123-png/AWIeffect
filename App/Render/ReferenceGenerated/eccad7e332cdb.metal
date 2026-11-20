// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/tile.xml
// Original source comments and attribution:

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

struct ReferenceUniformseccad7e332cdb
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float scale;
    char _m6_pad[12];
    float phase;
    char _m7_pad[12];
    uint mirror;
    char _m8_pad[12];
    uint vertoffs;
    char _m9_pad[12];
    float angle;
};

struct refAM35_eccad7e332cdb_out
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
void referenceMain(constant ReferenceUniformseccad7e332cdb& _38, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = _38.refScreen.xy;
    float2 pixelSize = float2(1.0) / getTexSize(param);
    float2 tiledCoord = (gl_FragCoord.xy - _38.refLayer.xy) / _38.refLayer.zw;
    if (_38.vertoffs != 0u)
    {
        tiledCoord.y += (step(1.0, mod(tiledCoord.x, 2.0)) * _38.phase);
    }
    else
    {
        tiledCoord.x += (step(1.0, mod(tiledCoord.y, 2.0)) * _38.phase);
    }
    if (_38.mirror != 0u)
    {
        tiledCoord = abs(mod(tiledCoord - float2(1.0), float2(2.0)) - float2(1.0));
    }
    else
    {
        tiledCoord = mod(tiledCoord, float2(1.0));
    }
    float a = _38.angle * 0.01745329983532428741455078125;
    float2x2 rot = float2x2(float2(cos(a), -sin(a)), float2(sin(a), cos(a)));
    float2 scaledCoord = tiledCoord;
    scaledCoord -= float2(0.5);
    scaledCoord *= (float2(1.0) / (float2(_38.scale) + (pixelSize * 4.0)));
    scaledCoord.x *= (_38.refLayer.z / _38.refLayer.w);
    scaledCoord *= rot;
    scaledCoord.x *= (_38.refLayer.w / _38.refLayer.z);
    scaledCoord += float2(0.5);
    float2 param_1 = (float4(scaledCoord, 0.0, 1.0) * _38.refLayerToScreen).xy;
    referenceColor = texture2DCv(refInput, refInputSmplr, param_1);
}

fragment refAM35_eccad7e332cdb_out refAM35_eccad7e332cdb(constant ReferenceUniformseccad7e332cdb& _38 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eccad7e332cdb_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_38, gl_FragCoord, referenceColor, refInput, refInputSmplr);
    bool _200 = any(isnan(referenceColor));
    bool _207;
    if (!_200)
    {
        _207 = any(isinf(referenceColor));
    }
    else
    {
        _207 = _200;
    }
    if (_207)
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

