// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxburningwipe.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
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

struct ReferenceUniformsea93a6cc8fee5
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color;
    float4 colorbg;
    float progressa;
    char _m8_pad[12];
    float deltab;
    char _m9_pad[12];
    float deltac;
    char _m10_pad[12];
    float deltad;
    char _m11_pad[12];
    float scale;
    char _m12_pad[8];
    float2 position;
    char _m13_pad[8];
    float2 stretch;
    char _m14_pad[8];
    float alpha;
    char _m15_pad[12];
    float angle;
};

struct refAM35_ea93a6cc8fee5_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float Hash(thread const float2& p, constant ReferenceUniformsea93a6cc8fee5& _66)
{
    float3 p2 = float3(p, _66.deltad);
    return fract(sin(dot(p2, float3(37.09999847412109375, 61.700000762939453125, 12.3999996185302734375))) * 3758.54541015625);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p, constant ReferenceUniformsea93a6cc8fee5& _66)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f *= (f * (float2(3.0) - (f * 2.0)));
    float2 param = i + float2(0.0);
    float2 param_1 = i + float2(1.0, 0.0);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 param_3 = i + float2(1.0);
    return mix(mix(Hash(param, _66), Hash(param_1, _66), f.x), mix(Hash(param_2, _66), Hash(param_3, _66), f.x), f.y);
}

static inline __attribute__((always_inline))
float fbm(thread const float2& p, constant ReferenceUniformsea93a6cc8fee5& _66)
{
    float v = 0.0;
    float2 param = p * 1.0;
    v += (_noise(param, _66) * 0.5);
    float2 param_1 = p * 2.0;
    v += (_noise(param_1, _66) * 0.25);
    float2 param_2 = p * 4.0;
    v += (_noise(param_2, _66) * 0.125);
    return v;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsea93a6cc8fee5& _66, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _66.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _66.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _66.refScreen.xy).y) * _66.refScreen.xy) - float2(_66.refLayer.x + (_66.refLayer.z * 0.5), (_66.refScreen.y - _66.refLayer.y) - (_66.refLayer.w * 0.5))) / _66.refLayer.zw;
    syamjaidtz.y *= (_66.refLayer.w / _66.refLayer.z);
    syamjaidtz /= float2(_66.scale);
    float param_1 = (70.0 + _66.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((float2(520.0 + _66.position.x, 0.0 + _66.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 scaleVec = float2(_66.scale * _66.stretch.x, _66.scale * _66.stretch.y);
    syamjaidtz /= scaleVec;
    float2 uv = syamjaidtz;
    float2 param_2 = gl_FragCoord.xy / _66.refScreen.xy;
    float3 src = texture2DCv(refInput, refInputSmplr, param_2).xyz;
    float4 tgt = float4(_66.colorbg.xyz, 0.0);
    float4 col = float4(src, 1.0);
    float ctime = mod(_66.progressa * 0.5, 2.5);
    float2 param_3 = uv * _66.deltac;
    float d = ((uv.x + (uv.y * 0.5)) + (_66.deltab * fbm(param_3, _66))) + (ctime * 1.2999999523162841796875);
    if (d > 0.3499999940395355224609375)
    {
        float4 _348 = col;
        float3 _358 = fast::clamp(_348.xyz - float3((d - 0.3499999940395355224609375) * 10.0), float3(0.0), float3(1.0));
        col.x = _358.x;
        col.y = _358.y;
        col.z = _358.z;
    }
    if (d > 0.4699999988079071044921875)
    {
        if (d < 0.5)
        {
            float2 param_4 = (uv * 100.0) + float2((-ctime) * 2.0, 0.0);
            float4 _397 = col;
            float3 _399 = _397.xyz + (_66.color.xyz * ((((d - 0.4000000059604644775390625) * 33.0) * 0.5) * (0.0 + _noise(param_4, _66))));
            col.x = _399.x;
            col.y = _399.y;
            col.z = _399.z;
        }
        else
        {
            col += tgt;
        }
    }
    float4 fragColor = col * texColor.w;
    referenceColor = mix(texColor, fragColor, float4(_66.alpha));
}

fragment refAM35_ea93a6cc8fee5_out refAM35_ea93a6cc8fee5(constant ReferenceUniformsea93a6cc8fee5& _66 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea93a6cc8fee5_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_66, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _429 = any(isnan(referenceColor));
    bool _436;
    if (!_429)
    {
        _436 = any(isinf(referenceColor));
    }
    else
    {
        _436 = _429;
    }
    if (_436)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _449 = referenceColor;
    float3 _455 = fast::clamp(_449.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _455.x;
    referenceColor.y = _455.y;
    referenceColor.z = _455.z;
    out.finalColor = referenceColor;
    return out;
}

