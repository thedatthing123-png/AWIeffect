// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/hexshift.xml
// Original source comments and attribution:
// hexRatio;
// * vec2(1.,-1.);
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

struct ReferenceUniformse4f4cabb4ff42
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
    float size;
    char _m8_pad[8];
    float2 stretch;
    char _m9_pad[8];
    float angle;
    char _m10_pad[12];
    float seed;
    char _m11_pad[12];
    uint screenSpace;
    char _m12_pad[12];
    uint maskToLayer;
};

struct refAM35_e4f4cabb4ff42_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse4f4cabb4ff42& _159, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _159.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st;
    if (_159.screenSpace != 0u)
    {
        st = gl_FragCoord.xy / _159.refScreen.xy;
        st -= float2(0.5);
        st.x *= (_159.refScreen.x / _159.refScreen.y);
    }
    else
    {
        st = (gl_FragCoord.xy - _159.refLayer.xy) / _159.refLayer.zw;
        st -= float2(0.5);
        st.x *= (_159.refLayer.z / _159.refLayer.w);
    }
    float2 scale = float2((_159.size / 100.0) * _159.stretch.x, (_159.size / 100.0) * _159.stretch.y);
    float2 pos = (_159.position / float2(500.0)) * float2(1.0, -1.0);
    st /= scale;
    float param_1 = _159.angle * 0.01745329983532428741455078125;
    st *= rot(param_1);
    float param_2 = (-_159.angle) * 0.01745329983532428741455078125;
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
    float px = id.x;
    float py = id.y;
    float2 param_7 = float2(px, py + (3937.724853515625 * (_159.seed + 0.00999999977648258209228515625)));
    float dx = rand(param_7);
    float2 param_8 = float2((px + 328.731903076171875) + (432.72491455078125 * (_159.seed + 0.00999999977648258209228515625)), py - 971.38201904296875);
    float dy = rand(param_8);
    float2 dv = (float2(dx, dy) - float2(0.5)) * 2.0;
    dv.x *= (_159.refScreen.x / _159.refScreen.y);
    float2 sampCoord = (gl_FragCoord.xy / _159.refScreen.xy) + (dv * _159.strength);
    sampCoord = abs(mod(sampCoord - float2(1.0), float2(2.0)) - float2(1.0));
    float2 param_9 = sampCoord;
    float4 sampColor = texture2DCv(refInput, refInputSmplr, param_9);
    if (_159.maskToLayer != 0u)
    {
        sampColor *= texColor.w;
        referenceColor = (texColor * (1.0 - sampColor.w)) + sampColor;
    }
    else
    {
        referenceColor = sampColor;
    }
}

fragment refAM35_e4f4cabb4ff42_out refAM35_e4f4cabb4ff42(constant ReferenceUniformse4f4cabb4ff42& _159 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e4f4cabb4ff42_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _159, referenceColor);
    bool _406 = any(isnan(referenceColor));
    bool _413;
    if (!_406)
    {
        _413 = any(isinf(referenceColor));
    }
    else
    {
        _413 = _406;
    }
    if (_413)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _427 = referenceColor;
    float3 _433 = fast::clamp(_427.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _433.x;
    referenceColor.y = _433.y;
    referenceColor.z = _433.z;
    out.finalColor = referenceColor;
    return out;
}

