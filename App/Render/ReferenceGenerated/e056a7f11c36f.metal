// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/blocknoise2.xml
// Original source comments and attribution:
//clampRange? 1.0 : 2.0;
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

struct ReferenceUniformse056a7f11c36f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float size;
    char _m6_pad[8];
    float2 stretch;
    char _m7_pad[8];
    float amount;
    char _m8_pad[12];
    uint mono;
    char _m9_pad[12];
    uint freeze;
    char _m10_pad[12];
    uint extremes;
    char _m11_pad[8];
    float2 position;
    char _m12_pad[8];
    float overshoot;
    char _m13_pad[12];
    float seed;
};

struct refAM35_e056a7f11c36f_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse056a7f11c36f& _64, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _64.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = floor((((float2((gl_FragCoord.xy / _64.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _64.refScreen.xy).y) * _64.refScreen.xy) - float2(_64.refLayer.x + (_64.refLayer.z * 0.5), (_64.refScreen.y - _64.refLayer.y) - (_64.refLayer.w * 0.5))) - _64.position) + float2(1234.22998046875, 5678.56005859375)) / _64.refLayer.zw;
    float2 actualSize = float2(_64.size * _64.stretch.x, _64.size * _64.stretch.y);
    actualSize = float2(150.0) / actualSize;
    st = floor(st * actualSize) / actualSize;
    float c = _64.overshoot;
    float _169;
    if (_64.freeze != 0u)
    {
        _169 = 1.0;
    }
    else
    {
        _169 = _64.refScreen.z;
    }
    float t = _169;
    t += (_64.seed * 3197.379150390625);
    if (_64.mono != 0u)
    {
        float t_1 = mod(t, 2.7999999523162841796875) + 2.7000000476837158203125;
        float2 param_1 = st * t_1;
        float r = rand(param_1);
        if (_64.extremes != 0u)
        {
            r = step(0.5, r);
        }
        r = (((r * _64.amount) * c) + 1.0) - _64.amount;
        referenceColor = float4(float3(r), 1.0) * texColor;
    }
    else
    {
        float tr = mod(t, 4.69999980926513671875) + 2.86999988555908203125;
        float tg = mod(t, 2.7999999523162841796875) + 1.5499999523162841796875;
        float tb = mod(t, 3.25) + 6.270999908447265625;
        float2 param_2 = st * tr;
        float r_1 = rand(param_2);
        float2 param_3 = st * tg;
        float g = rand(param_3);
        float2 param_4 = st * tb;
        float b = rand(param_4);
        if (_64.extremes != 0u)
        {
            r_1 = step(0.5, r_1);
        }
        if (_64.extremes != 0u)
        {
            g = step(0.5, g);
        }
        if (_64.extremes != 0u)
        {
            b = step(0.5, b);
        }
        r_1 = (((r_1 * _64.amount) * c) + 1.0) - _64.amount;
        g = (((g * _64.amount) * c) + 1.0) - _64.amount;
        b = (((b * _64.amount) * c) + 1.0) - _64.amount;
        referenceColor = float4(float3(r_1, g, b), 1.0) * texColor;
    }
}

fragment refAM35_e056a7f11c36f_out refAM35_e056a7f11c36f(constant ReferenceUniformse056a7f11c36f& _64 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e056a7f11c36f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _64, referenceColor);
    bool _334 = any(isnan(referenceColor));
    bool _341;
    if (!_334)
    {
        _341 = any(isinf(referenceColor));
    }
    else
    {
        _341 = _334;
    }
    if (_341)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _354 = referenceColor;
    float3 _360 = fast::clamp(_354.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _360.x;
    referenceColor.y = _360.y;
    referenceColor.z = _360.z;
    out.finalColor = referenceColor;
    return out;
}

