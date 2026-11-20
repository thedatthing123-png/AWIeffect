// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/tileshift2.xml
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

struct ReferenceUniformseaeaf49f44c73
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[8];
    float2 position;
    char _m7_pad[8];
    float amount;
    char _m8_pad[8];
    float2 stretch;
    char _m9_pad[8];
    float angle;
    char _m10_pad[12];
    float seed;
    char _m11_pad[12];
    uint screenSpace;
};

struct refAM35_eaeaf49f44c73_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseaeaf49f44c73& _64, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _64.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st;
    if (_64.screenSpace != 0u)
    {
        st = gl_FragCoord.xy / _64.refScreen.xy;
        st.y = 1.0 - st.y;
        st -= float2(0.5);
        st.x *= (_64.refScreen.x / _64.refScreen.y);
        st -= (_64.position / float2(1200.0));
    }
    else
    {
        st = (((float2((gl_FragCoord.xy / _64.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _64.refScreen.xy).y) * _64.refScreen.xy) - float2(_64.refLayer.x + (_64.refLayer.z * 0.5), (_64.refScreen.y - _64.refLayer.y) - (_64.refLayer.w * 0.5))) / float2(length(_64.refLayer.zw))) - (_64.position / float2(1200.0));
    }
    float a = _64.angle * 0.01745329983532428741455078125;
    st *= float2x2(float2(sin(a), -cos(a)), float2(cos(a), sin(a)));
    float px = floor((st.x * _64.amount) / _64.stretch.y);
    float py = floor((st.y * _64.amount) / _64.stretch.x);
    float2 param_1 = float2(px, py + (3937.724853515625 * _64.seed));
    float dx = rand(param_1);
    float2 param_2 = float2((px + 328.731903076171875) + (432.72491455078125 * _64.seed), py - 971.38201904296875);
    float dy = rand(param_2);
    float2 dv = (float2(dx, dy) - float2(0.5)) * 2.0;
    float2 sampCoord = (gl_FragCoord.xy / _64.refScreen.xy) + (dv * _64.strength);
    sampCoord = abs(mod(sampCoord - float2(1.0), float2(2.0)) - float2(1.0));
    float2 param_3 = sampCoord;
    float4 sampColor = texture2DCv(refInput, refInputSmplr, param_3);
    referenceColor = sampColor * texColor.w;
}

fragment refAM35_eaeaf49f44c73_out refAM35_eaeaf49f44c73(constant ReferenceUniformseaeaf49f44c73& _64 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eaeaf49f44c73_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _64, referenceColor);
    bool _286 = any(isnan(referenceColor));
    bool _293;
    if (!_286)
    {
        _293 = any(isinf(referenceColor));
    }
    else
    {
        _293 = _286;
    }
    if (_293)
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

