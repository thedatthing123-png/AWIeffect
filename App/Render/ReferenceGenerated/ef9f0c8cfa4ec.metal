// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/halftonedots.xml
// Original source comments and attribution:
// Y Distance
// X Distance
// Sampling
//vec4 color1 = vec4(0., 0., 0., 1.);
//vec4 color2 = vec4(1., 1., 1., 1.);
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

struct ReferenceUniformsef9f0c8cfa4ec
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amount;
    char _m6_pad[12];
    float strength;
    char _m7_pad[12];
    float angle;
    char _m8_pad[12];
    float phase;
    float4 color1;
    float4 color2;
};

struct refAM35_ef9f0c8cfa4ec_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsef9f0c8cfa4ec& _30, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float rad = _30.angle * 0.01745329983532428741455078125;
    float2x2 rot = float2x2(float2(cos(rad), -sin(rad)), float2(sin(rad), cos(rad)));
    float2x2 invrot = float2x2(float2(cos(-rad), -sin(-rad)), float2(sin(-rad), cos(-rad)));
    float2 st = gl_FragCoord.xy / _30.refScreen.xy;
    st -= (float2(_30.refLayer.x + (_30.refLayer.z * 0.5), (_30.refScreen.y - _30.refLayer.y) - (_30.refLayer.w * 0.5)) / _30.refScreen.xy);
    st.y *= (_30.refScreen.y / _30.refScreen.x);
    st *= rot;
    float distY = mod(st.y * _30.amount, 1.0);
    if (distY < 0.5)
    {
        distY = -distY;
    }
    else
    {
        distY = 1.0 - distY;
    }
    float absDistY = abs(distY);
    distY /= _30.amount;
    float xoffs = step(1.0, mod((st.y * _30.amount) + 0.5, 2.0)) * _30.phase;
    float distX = mod((st.x * _30.amount) + xoffs, 1.0);
    if (distX < 0.5)
    {
        distX = -distX;
    }
    else
    {
        distX = 1.0 - distX;
    }
    float absDistX = abs(distX);
    distX /= _30.amount;
    st.y += distY;
    st.x += distX;
    st *= invrot;
    st.y /= (_30.refScreen.y / _30.refScreen.x);
    st += (float2(_30.refLayer.x + (_30.refLayer.z * 0.5), (_30.refScreen.y - _30.refLayer.y) - (_30.refLayer.w * 0.5)) / _30.refScreen.xy);
    float2 param = st;
    float4 samp = texture2DCv(refInput, refInputSmplr, param);
    float lum = dot(samp.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float p = smoothstep(0.4000000059604644775390625, 0.60000002384185791015625, (((lum + (1.0 - samp.w)) + length(float2(absDistX, absDistY))) + _30.strength) - 0.5);
    float2 param_1 = gl_FragCoord.xy / _30.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
    float4 outColor = mix(_30.color1, _30.color2, float4(p)) * texColor.w;
    referenceColor = outColor;
}

fragment refAM35_ef9f0c8cfa4ec_out refAM35_ef9f0c8cfa4ec(constant ReferenceUniformsef9f0c8cfa4ec& _30 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef9f0c8cfa4ec_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_30, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _296 = any(isnan(referenceColor));
    bool _303;
    if (!_296)
    {
        _303 = any(isinf(referenceColor));
    }
    else
    {
        _303 = _296;
    }
    if (_303)
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

