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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseccad7e332cdb& _55, thread float4& referenceColor)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 pixelSize = float2(1.0) / getTexSize(param);
    float2 tiledCoord = (gl_FragCoord.xy - _55.refLayer.xy) / _55.refLayer.zw;
    if (_55.vertoffs != 0u)
    {
        tiledCoord.y += (step(1.0, mod(tiledCoord.x, 2.0)) * _55.phase);
    }
    else
    {
        tiledCoord.x += (step(1.0, mod(tiledCoord.y, 2.0)) * _55.phase);
    }
    if (_55.mirror != 0u)
    {
        tiledCoord = abs(mod(tiledCoord - float2(1.0), float2(2.0)) - float2(1.0));
    }
    else
    {
        tiledCoord = mod(tiledCoord, float2(1.0));
    }
    float a = _55.angle * 0.01745329983532428741455078125;
    float2x2 rot = float2x2(float2(cos(a), -sin(a)), float2(sin(a), cos(a)));
    float2 scaledCoord = tiledCoord;
    scaledCoord -= float2(0.5);
    scaledCoord *= (float2(1.0) / (float2(_55.scale) + (pixelSize * 4.0)));
    scaledCoord.x *= (_55.refLayer.z / _55.refLayer.w);
    scaledCoord *= rot;
    scaledCoord.x *= (_55.refLayer.w / _55.refLayer.z);
    scaledCoord += float2(0.5);
    float2 param_1 = (float4(scaledCoord, 0.0, 1.0) * _55.refLayerToScreen).xy;
    referenceColor = texture2DCv(refInput, refInputSmplr, param_1);
}

fragment refAM35_eccad7e332cdb_out refAM35_eccad7e332cdb(constant ReferenceUniformseccad7e332cdb& _55 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eccad7e332cdb_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _55, referenceColor);
    bool _202 = any(isnan(referenceColor));
    bool _209;
    if (!_202)
    {
        _209 = any(isinf(referenceColor));
    }
    else
    {
        _209 = _202;
    }
    if (_209)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _223 = referenceColor;
    float3 _229 = fast::clamp(_223.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _229.x;
    referenceColor.y = _229.y;
    referenceColor.z = _229.z;
    out.finalColor = referenceColor;
    return out;
}

