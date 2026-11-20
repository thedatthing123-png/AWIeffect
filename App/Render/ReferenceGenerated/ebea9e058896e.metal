// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/kaleidoscope.xml
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

struct ReferenceUniformsebea9e058896e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float rcount;
    char _m6_pad[8];
    float2 centerPoint;
    char _m7_pad[8];
    float offsetAngle;
    char _m8_pad[12];
    uint mirror;
};

struct refAM35_ebea9e058896e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsebea9e058896e& _32, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float segmentAngle = 360.0 / _32.rcount;
    float rad = segmentAngle * 0.01745329983532428741455078125;
    float offsetRad = _32.offsetAngle * 0.01745329983532428741455078125;
    float2 origin = ((_32.centerPoint * float2(1.0, -1.0)) / float2(1000.0)) + float2(0.5);
    float2 pos = ((gl_FragCoord.xy - _32.refLayer.xy) / _32.refLayer.zw) - origin;
    pos.x *= (_32.refLayer.z / _32.refLayer.w);
    float r = length(pos);
    float a = precise::atan2(pos.y, pos.x);
    float sampleAngle = mod(a, rad);
    if (_32.mirror != 0u)
    {
        sampleAngle = abs(sampleAngle - (rad / 2.0));
    }
    sampleAngle += offsetRad;
    float2x2 rmat = float2x2(float2(cos(sampleAngle), -sin(sampleAngle)), float2(sin(sampleAngle), cos(sampleAngle)));
    float2 sampleCoord = float2(r, 0.0) * rmat;
    sampleCoord.x /= (_32.refLayer.z / _32.refLayer.w);
    sampleCoord += origin;
    sampleCoord = (float4(sampleCoord, 0.0, 1.0) * _32.refLayerToScreen).xy;
    float2 param = sampleCoord;
    referenceColor = texture2DCv(refInput, refInputSmplr, param);
}

fragment refAM35_ebea9e058896e_out refAM35_ebea9e058896e(constant ReferenceUniformsebea9e058896e& _32 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ebea9e058896e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_32, gl_FragCoord, referenceColor, refInput, refInputSmplr);
    bool _177 = any(isnan(referenceColor));
    bool _184;
    if (!_177)
    {
        _184 = any(isinf(referenceColor));
    }
    else
    {
        _184 = _177;
    }
    if (_184)
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

