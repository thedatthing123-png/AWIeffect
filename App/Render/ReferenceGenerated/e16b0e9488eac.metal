// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/dissolve.xml
// Original source comments and attribution:
//float c = overshoot; //clampRange? 1.0 : 2.0;
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

struct ReferenceUniformse16b0e9488eac
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amount;
    char _m6_pad[12];
    float seed;
};

struct refAM35_e16b0e9488eac_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float rand(thread const float2& co)
{
    float a = 719.30999755859375;
    float b = 178.233001708984375;
    float c = 33758.546875;
    float dt = dot(co, float2(a, b));
    float sn = mod(dt, 3.1400001049041748046875);
    return fract(sin(sn) * c);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse16b0e9488eac& _63, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _63.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = floor((float2((gl_FragCoord.xy / _63.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _63.refScreen.xy).y) * _63.refScreen.xy) - float2(_63.refLayer.x + (_63.refLayer.z * 0.5), (_63.refScreen.y - _63.refLayer.y) - (_63.refLayer.w * 0.5))) / _63.refLayer.zw;
    float t = _63.seed * 3197.379150390625;
    t = mod(t, 2.7999999523162841796875) + 2.7000000476837158203125;
    float2 param_1 = st * t;
    float r = rand(param_1);
    r = step(_63.amount, r);
    referenceColor = texColor * r;
}

fragment refAM35_e16b0e9488eac_out refAM35_e16b0e9488eac(constant ReferenceUniformse16b0e9488eac& _63 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e16b0e9488eac_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _63, referenceColor);
    bool _159 = any(isnan(referenceColor));
    bool _166;
    if (!_159)
    {
        _166 = any(isinf(referenceColor));
    }
    else
    {
        _166 = _159;
    }
    if (_166)
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

