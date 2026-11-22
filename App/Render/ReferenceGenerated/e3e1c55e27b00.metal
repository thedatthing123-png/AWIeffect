// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/checker2.xml
// Original source comments and attribution:
//st.y *= stretch;
//p = smoothstep(0.5+smoothing/2.0,0.5,p)*smoothstep(0.0,smoothing/0.2,p);
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

struct ReferenceUniformse3e1c55e27b00
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float amount;
    char _m7_pad[8];
    float2 stretch;
    float4 color;
    uint punchout;
    char _m10_pad[12];
    float angle;
    char _m11_pad[12];
    uint screenSpace;
};

struct refAM35_e3e1c55e27b00_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse3e1c55e27b00& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st;
    if (_36.screenSpace != 0u)
    {
        st = gl_FragCoord.xy / _36.refScreen.xy;
        st.y = 1.0 - st.y;
        st -= float2(0.5);
        st.x *= (_36.refScreen.x / _36.refScreen.y);
        st -= (_36.position / float2(1200.0));
    }
    else
    {
        st = (gl_FragCoord.xy - _36.refLayer.xy) / _36.refLayer.zw;
        st.y = 1.0 - st.y;
        st -= float2(0.5);
        st.x *= (_36.refLayer.z / _36.refLayer.w);
        st -= (_36.position / float2(1200.0));
    }
    float a = _36.angle * 0.01745329983532428741455078125;
    st *= float2x2(float2(sin(a), -cos(a)), float2(cos(a), sin(a)));
    float px = floor((st.x * _36.amount) / _36.stretch.y);
    float py = floor((st.y * _36.amount) / _36.stretch.x);
    float p = step(mod(px + py, 2.0), 0.5);
    float4 c = _36.color * p;
    if (_36.punchout != 0u)
    {
        referenceColor = texColor * (1.0 - p);
    }
    else
    {
        float alpha = c.w * texColor.w;
        referenceColor = (c * alpha) + (texColor * (1.0 - alpha));
    }
}

fragment refAM35_e3e1c55e27b00_out refAM35_e3e1c55e27b00(constant ReferenceUniformse3e1c55e27b00& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e3e1c55e27b00_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _217 = any(isnan(referenceColor));
    bool _224;
    if (!_217)
    {
        _224 = any(isinf(referenceColor));
    }
    else
    {
        _224 = _217;
    }
    if (_224)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _238 = referenceColor;
    float3 _244 = fast::clamp(_238.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _244.x;
    referenceColor.y = _244.y;
    referenceColor.z = _244.z;
    out.finalColor = referenceColor;
    return out;
}

