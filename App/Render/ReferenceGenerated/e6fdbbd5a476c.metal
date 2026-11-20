// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/radialwipe.xml
// Original source comments and attribution:
// a<adjFeather?a+twopi:
// a<adjFeather?a+twopi:
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

struct ReferenceUniformse6fdbbd5a476c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progress;
    char _m6_pad[12];
    float offset;
    char _m7_pad[8];
    float2 centerPoint;
    char _m8_pad[8];
    float feather;
    char _m9_pad[12];
    int direction;
    char _m10_pad[12];
    float repeatCount;
};

struct refAM35_e6fdbbd5a476c_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse6fdbbd5a476c& _34, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 st = (gl_FragCoord.xy - _34.refLayer.xy) / _34.refLayer.zw;
    st.y = 1.0 - st.y;
    st -= float2(0.5);
    st.x *= (_34.refLayer.z / _34.refLayer.w);
    st -= (_34.centerPoint / float2(1200.0));
    float _86;
    if (_34.direction == 1)
    {
        _86 = 360.0 - _34.progress;
    }
    else
    {
        _86 = _34.progress;
    }
    float adjProgress = _86;
    float start = 0.0;
    float end = adjProgress;
    end -= 180.0;
    end *= ((360.0 + _34.feather) / 360.0);
    end += 180.0;
    float _124;
    if (_34.direction == 2)
    {
        _124 = (end / 2.0) / _34.repeatCount;
    }
    else
    {
        _124 = 0.0;
    }
    float offsetRad = ((_34.offset - 90.0) + _124) * 0.01745329983532428741455078125;
    float2x2 offsetRot = float2x2(float2(cos(offsetRad), -sin(offsetRad)), float2(sin(offsetRad), cos(offsetRad)));
    st *= offsetRot;
    float adjFeather = fast::max(0.00999999977648258209228515625, _34.feather * 0.01745329983532428741455078125);
    float halfFeather = adjFeather / 2.0;
    float startRad = start * 0.01745329983532428741455078125;
    float endRad = end * 0.01745329983532428741455078125;
    float a = precise::atan2(st.y, st.x) + 3.141590118408203125;
    a = mod(a * _34.repeatCount, 6.283185482025146484375);
    float p0 = smoothstep(adjFeather, 0.0, a);
    float p1 = smoothstep(endRad - halfFeather, endRad + halfFeather, a);
    float p2 = smoothstep((endRad - 6.283185482025146484375) + halfFeather, (endRad - 6.283185482025146484375) - halfFeather, a);
    float _214;
    if (adjProgress <= 9.9999997473787516355514526367188e-05)
    {
        _214 = 1.0;
    }
    else
    {
        float _221;
        if (adjProgress >= 359.998992919921875)
        {
            _221 = 0.0;
        }
        else
        {
            _221 = fast::min(1.0, (p1 + p0) - p2);
        }
        _214 = _221;
    }
    float pp = _214;
    if (_34.direction == 1)
    {
        pp = 1.0 - pp;
    }
    float2 param = gl_FragCoord.xy / _34.refScreen.xy;
    referenceColor = texture2DCv(refInput, refInputSmplr, param) * pp;
}

fragment refAM35_e6fdbbd5a476c_out refAM35_e6fdbbd5a476c(constant ReferenceUniformse6fdbbd5a476c& _34 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e6fdbbd5a476c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _34, referenceColor, refInput, refInputSmplr);
    bool _259 = any(isnan(referenceColor));
    bool _266;
    if (!_259)
    {
        _266 = any(isinf(referenceColor));
    }
    else
    {
        _266 = _259;
    }
    if (_266)
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

