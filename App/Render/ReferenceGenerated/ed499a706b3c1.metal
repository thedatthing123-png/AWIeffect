// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/tunnel.xml
// Original source comments and attribution:
//st.x *= acLayerSize.x/acLayerSize.y;
//+(center/1200.0*vec2(1.,-1.));
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

struct ReferenceUniformsed499a706b3c1
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float phase;
    float4 fogColor;
    float fog;
    char _m8_pad[12];
    float depth;
    char _m9_pad[12];
    float twirl;
    char _m10_pad[12];
    float wrap;
    char _m11_pad[12];
    float crop;
    char _m12_pad[12];
    uint mirror;
};

struct refAM35_ed499a706b3c1_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsed499a706b3c1& _34, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st = (gl_FragCoord.xy - _34.refLayer.xy) / _34.refLayer.zw;
    st -= float2(0.5);
    float tr = _34.twirl * 0.01745329983532428741455078125;
    float angle = precise::atan2(st.x, st.y);
    float radius = length(st);
    angle += (tr * radius);
    float2 uv = float2((_34.depth / radius) + _34.phase, angle / (6.283185482025146484375 / _34.wrap));
    if (_34.mirror != 0u)
    {
        uv = abs(mod(uv, float2(2.0)) - float2(1.0));
    }
    else
    {
        uv = mod(uv, float2(1.0));
    }
    uv -= float2(0.5);
    uv *= _34.crop;
    uv += float2(0.5);
    float2 param = (float4(uv, 0.0, 1.0) * _34.refLayerToScreen).xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 _143;
    if (radius > 0.5)
    {
        _143 = float4(0.0);
    }
    else
    {
        _143 = mix(texColor, _34.fogColor, float4(fast::clamp((1.0 - (radius * 2.0)) * _34.fog, 0.0, 1.0)));
    }
    referenceColor = _143;
}

fragment refAM35_ed499a706b3c1_out refAM35_ed499a706b3c1(constant ReferenceUniformsed499a706b3c1& _34 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed499a706b3c1_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _34, refInput, refInputSmplr, referenceColor);
    bool _167 = any(isnan(referenceColor));
    bool _174;
    if (!_167)
    {
        _174 = any(isinf(referenceColor));
    }
    else
    {
        _174 = _167;
    }
    if (_174)
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

