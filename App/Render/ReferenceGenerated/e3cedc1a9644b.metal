// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/hexrotate.xml
// Original source comments and attribution:
// hexRatio;
// * vec2(1.,-1.);
//float px = id.x;
//float py = id.y;
//float dx = rand(vec2(px,py+3937.7249*(seed+0.01)));
//float dy = rand(vec2(px+328.7319+432.7249*(seed+0.01),py-971.382));
//vec2 dv = (vec2(dx,dy) - 0.5)*2.0;
//vec2 sampCoord = acScreenNorm+dv*strength;
//sampCoord = abs(mod(sampCoord-1.0,2.0)-1.0);
//gl_FragColor = sampColor; // * texColor.a;
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

struct ReferenceUniformse3cedc1a9644b
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float rotate;
    char _m6_pad[12];
    float warpAngle;
    char _m7_pad[8];
    float2 position;
    char _m8_pad[8];
    float size;
    char _m9_pad[8];
    float2 stretch;
    char _m10_pad[8];
    float angle;
    char _m11_pad[12];
    uint screenSpace;
    char _m12_pad[12];
    float twirl;
    char _m13_pad[12];
    float seed;
    char _m14_pad[12];
    uint maskToLayer;
};

struct refAM35_e3cedc1a9644b_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float hexDist(thread const float2& p)
{
    return fast::max(dot(abs(p), float2(0.500444352626800537109375, 0.865768730640411376953125)), abs(p.x));
}

static inline __attribute__((always_inline))
void hexTile(thread const float2& st, thread float2& uv, thread float2& huv, thread float2& id)
{
    float2 grid = mod(st, float2(1.0, 1.730000019073486328125)) - float2(0.5, 0.8650000095367431640625);
    float2 offsetGrid = mod(st - float2(0.5, 0.8650000095367431640625), float2(1.0, 1.730000019073486328125)) - float2(0.5, 0.8650000095367431640625);
    uv = select(offsetGrid, grid, bool2(length(grid) < length(offsetGrid)));
    float2 param = uv;
    huv = float2(precise::atan2(uv.x, uv.y), (0.5 - hexDist(param)) * 2.0);
    id = float2(st.x - uv.x, st.y - uv.y);
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, thread const float4x4& acLTS)
{
    return (float4(v, 0.0, 1.0) * acLTS).xy;
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse3cedc1a9644b& _174, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _174.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st;
    if (_174.screenSpace != 0u)
    {
        st = gl_FragCoord.xy / _174.refScreen.xy;
        st -= float2(0.5);
        st.x *= (_174.refScreen.x / _174.refScreen.y);
    }
    else
    {
        st = (gl_FragCoord.xy - _174.refLayer.xy) / _174.refLayer.zw;
        st -= float2(0.5);
        st.x *= (_174.refLayer.z / _174.refLayer.w);
    }
    float2 scale = float2((_174.size / 100.0) * _174.stretch.x, (_174.size / 100.0) * _174.stretch.y);
    float2 pos = (_174.position / float2(500.0)) * float2(1.0, -1.0);
    st /= scale;
    float param_1 = _174.angle * 0.01745329983532428741455078125;
    st *= rot(param_1);
    float param_2 = (-_174.angle) * 0.01745329983532428741455078125;
    pos *= rot(param_2);
    float2 modPos = mod(pos, float2(2.0, 3.46000003814697265625));
    float2 basePos = pos - modPos;
    float2 stepPos = basePos;
    st -= modPos;
    float2 param_3 = st;
    float2 param_4;
    float2 param_5;
    float2 param_6;
    hexTile(param_3, param_4, param_5, param_6);
    float2 uv = param_4;
    float2 huv = param_5;
    float2 id = param_6;
    id -= stepPos;
    id += float2(1000.0);
    float2 hexCenterScreenCoord = st - uv;
    hexCenterScreenCoord += modPos;
    float param_7 = (-_174.angle) * 0.01745329983532428741455078125;
    hexCenterScreenCoord *= rot(param_7);
    hexCenterScreenCoord *= scale;
    hexCenterScreenCoord.x /= (_174.refLayer.z / _174.refLayer.w);
    hexCenterScreenCoord += float2(0.5);
    float2 param_8 = hexCenterScreenCoord;
    float4x4 param_9 = _174.refLayerToScreen;
    hexCenterScreenCoord = l2s(param_8, param_9);
    float2 param_10 = float2(id.x, id.y + (1937.724853515625 * (_174.seed + 0.00999999977648258209228515625)));
    float randAngle = ((0.5 - rand(param_10)) * 2.0) * 6.28318023681640625;
    float adjWarpAngle = _174.warpAngle * smoothstep(0.0, 1.0, length(uv));
    float2 dc = (gl_FragCoord.xy / _174.refScreen.xy) - hexCenterScreenCoord;
    dc.x *= (_174.refScreen.x / _174.refScreen.y);
    float param_11 = ((_174.rotate + adjWarpAngle) * 0.01745329983532428741455078125) + ((_174.twirl / 360.0) * randAngle);
    dc *= rot(param_11);
    dc.x /= (_174.refScreen.x / _174.refScreen.y);
    float2 sampCoord = hexCenterScreenCoord + dc;
    sampCoord = abs(mod(sampCoord - float2(1.0), float2(2.0)) - float2(1.0));
    float2 param_12 = sampCoord;
    float4 sampColor = texture2DCv(refInput, refInputSmplr, param_12);
    if (_174.maskToLayer != 0u)
    {
        sampColor *= texColor.w;
        referenceColor = (texColor * (1.0 - sampColor.w)) + sampColor;
    }
    else
    {
        referenceColor = sampColor;
    }
}

fragment refAM35_e3cedc1a9644b_out refAM35_e3cedc1a9644b(constant ReferenceUniformse3cedc1a9644b& _174 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e3cedc1a9644b_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _174, referenceColor);
    bool _471 = any(isnan(referenceColor));
    bool _478;
    if (!_471)
    {
        _478 = any(isinf(referenceColor));
    }
    else
    {
        _478 = _471;
    }
    if (_478)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _492 = referenceColor;
    float3 _498 = fast::clamp(_492.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _498.x;
    referenceColor.y = _498.y;
    referenceColor.z = _498.z;
    out.finalColor = referenceColor;
    return out;
}

