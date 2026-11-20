// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/tilerotate2.xml
// Original source comments and attribution:
//float dx = rand(vec2(px,py+3937.7249*seed));
//float dy = rand(vec2(px+328.7319+432.7249*seed,py-971.382));
//vec2 dv = (vec2(dx,dy) - 0.5)*2.0;
//vec2 sampCoord = acScreenNorm+dv*strength;
//sampColor.r = length(acScreenNorm-pcenter);
//sampColor.g = length(acScreenNorm-pcenter);
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

struct ReferenceUniformse8404b5764d4f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float rotation;
    char _m6_pad[8];
    float2 position;
    char _m7_pad[8];
    float amount;
    char _m8_pad[8];
    float2 stretch;
    char _m9_pad[8];
    float angle;
    char _m10_pad[12];
    float strength;
    char _m11_pad[12];
    float seed;
    char _m12_pad[12];
    uint screenSpace;
};

struct refAM35_e8404b5764d4f_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse8404b5764d4f& _66, thread float4& referenceColor)
{
    float offset = 0.5;
    float2 param = gl_FragCoord.xy / _66.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 relPos = _66.position / float2(1200.0);
    float layerSizeMag = length(_66.refLayer.zw);
    float2 st;
    if (_66.screenSpace != 0u)
    {
        st = gl_FragCoord.xy / _66.refScreen.xy;
        st.y = 1.0 - st.y;
        st -= float2(0.5);
        st.x *= (_66.refScreen.x / _66.refScreen.y);
        st -= relPos;
    }
    else
    {
        st = (((float2((gl_FragCoord.xy / _66.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _66.refScreen.xy).y) * _66.refScreen.xy) - float2(_66.refLayer.x + (_66.refLayer.z * 0.5), (_66.refScreen.y - _66.refLayer.y) - (_66.refLayer.w * 0.5))) / float2(layerSizeMag)) - relPos;
    }
    float a = _66.angle * 0.01745329983532428741455078125;
    float ra = _66.rotation * 0.01745329983532428741455078125;
    st *= float2x2(float2(cos(a), -sin(a)), float2(sin(a), cos(a)));
    float px = floor((st.x * _66.amount) / _66.stretch.x);
    float py = floor((st.y * _66.amount) / _66.stretch.y);
    float2 param_1 = float2(px, py + (3937.724853515625 * _66.seed));
    float rmag = rand(param_1);
    ra += ((((rmag - 0.5) * 2.0) * 6.28318023681640625) * _66.strength);
    float2 pcenter = float2((px + offset) / (_66.amount / _66.stretch.x), (py + offset) / (_66.amount / _66.stretch.y));
    pcenter *= float2x2(float2(cos(-a), -sin(-a)), float2(sin(-a), cos(-a)));
    if (_66.screenSpace != 0u)
    {
        pcenter += relPos;
        pcenter *= (_66.refScreen.y / _66.refScreen.x);
        pcenter += float2(0.5);
        pcenter.y = 1.0 - pcenter.y;
    }
    else
    {
        pcenter += relPos;
        pcenter *= layerSizeMag;
        pcenter += float2(_66.refLayer.x + (_66.refLayer.z * 0.5), (_66.refScreen.y - _66.refLayer.y) - (_66.refLayer.w * 0.5));
        pcenter /= _66.refScreen.xy;
        pcenter.y = 1.0 - pcenter.y;
    }
    float2 sampCoord = gl_FragCoord.xy / _66.refScreen.xy;
    sampCoord -= pcenter;
    sampCoord *= float2x2(float2(cos(ra), -sin(ra)), float2(sin(ra), cos(ra)));
    sampCoord += pcenter;
    sampCoord = abs(mod(sampCoord - float2(1.0), float2(2.0)) - float2(1.0));
    float2 param_2 = sampCoord;
    float4 sampColor = texture2DCv(refInput, refInputSmplr, param_2);
    referenceColor = sampColor * texColor.w;
}

fragment refAM35_e8404b5764d4f_out refAM35_e8404b5764d4f(constant ReferenceUniformse8404b5764d4f& _66 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8404b5764d4f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _66, referenceColor);
    bool _390 = any(isnan(referenceColor));
    bool _397;
    if (!_390)
    {
        _397 = any(isinf(referenceColor));
    }
    else
    {
        _397 = _390;
    }
    if (_397)
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

