// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/3city_sdf.xml
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

struct ReferenceUniformse667ffd209ce2
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint autoMove;
    char _m6_pad[12];
    float progress;
    char _m7_pad[12];
    float speed;
    char _m8_pad[12];
    float seed;
    char _m9_pad[12];
    float cameraX;
    char _m10_pad[12];
    float cameraHeight;
    char _m11_pad[12];
    float yaw;
    char _m12_pad[12];
    float horizon;
    char _m13_pad[12];
    float buildingCount;
    char _m14_pad[12];
    float cityWidth;
    char _m15_pad[12];
    float cityDepth;
    char _m16_pad[12];
    float heightScale;
    char _m17_pad[12];
    float widthScale;
    char _m18_pad[12];
    float windowGlow;
    char _m19_pad[12];
    float fog;
    float4 skyTop;
    float4 skyBottom;
    float4 buildingColor;
    float4 windowColor;
    float sourceMix;
    char _m25_pad[12];
    float opacity;
};

struct refAM35_e667ffd209ce2_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float h(thread const float& n)
{
    return fract(sin(n * 127.09999847412109375) * 43758.546875);
}

static inline __attribute__((always_inline))
float box1(thread const float& v, thread const float& a, thread const float& b, thread const float& e)
{
    return smoothstep(a - e, a + e, v) * (1.0 - smoothstep(b - e, b + e, v));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse667ffd209ce2& _76, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (((gl_FragCoord.xy - _76.refLayer.xy) / _76.refLayer.zw) * 2.0) - float2(1.0);
    float asp = _76.refLayer.z / fast::max(_76.refLayer.w, 1.0);
    uv.x *= asp;
    float2 param = (gl_FragCoord.xy - _76.refLayer.xy) / _76.refLayer.zw;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float hl = _76.horizon - 0.119999997317790985107421875;
    float skyT = fast::clamp((uv.y - hl) / fast::max(1.0 - hl, 0.00999999977648258209228515625), 0.0, 1.0);
    float3 col = mix(_76.skyBottom.xyz, _76.skyTop.xyz, float3(skyT));
    col += ((_76.skyBottom.xyz * exp((-abs(uv.y - hl)) * 9.0)) * 0.20000000298023223876953125);
    float _183;
    if (_76.autoMove != 0u)
    {
        _183 = _76.refScreen.z * _76.speed;
    }
    else
    {
        _183 = 0.0;
    }
    float tm = _76.progress + _183;
    float yr = (_76.yaw * 3.1415927410125732421875) / 180.0;
    if (uv.y < hl)
    {
        float gd = _76.cameraHeight / fast::max(hl - uv.y, 0.0350000001490116119384765625);
        float wx = ((uv.x * gd) + _76.cameraX) + (tan(yr) * gd);
        float wz = gd + tm;
        float gx = abs(fract(wx * 1.35000002384185791015625) - 0.5);
        float gz = abs(fract(wz * 0.550000011920928955078125) - 0.5);
        float grid = (1.0 - smoothstep(0.4699999988079071044921875, 0.5, gx)) + (1.0 - smoothstep(0.4699999988079071044921875, 0.5, gz));
        float ff = exp(((-gd) * _76.fog) * 0.12999999523162841796875);
        float3 ground = (_76.buildingColor.xyz * 0.25) + (((_76.windowColor.xyz * grid) * ff) * 0.119999997317790985107421875);
        col = mix(col, ground, float3(fast::clamp((hl - uv.y) * 5.0, 0.0, 1.0)));
    }
    float best = 1000000.0;
    float selFi = 0.0;
    float selCX = 0.0;
    float selHW = 0.0;
    float selBY = 0.0;
    float selTY = 0.0;
    for (int i = 0; i < 56; i++)
    {
        float ref_active = 1.0 - step(_76.buildingCount, float(i));
        float fi = float(i) + (_76.seed * 17.3099994659423828125);
        float param_1 = fi * 2.309999942779541015625;
        float param_2 = fi * 7.099999904632568359375;
        float z = mod((h(param_1) * _76.cityDepth) - (tm * (0.550000011920928955078125 + (h(param_2) * 0.25))), _76.cityDepth) + 0.800000011920928955078125;
        float param_3 = fi * 5.1700000762939453125;
        float x = ((((h(param_3) * 2.0) - 1.0) * _76.cityWidth) - _76.cameraX) - (tan(yr) * z);
        float param_4 = fi * 9.13000011444091796875;
        float w = mix(0.1599999964237213134765625, 0.439999997615814208984375, h(param_4)) * _76.widthScale;
        float param_5 = fi * 11.69999980926513671875;
        float ht = mix(0.449999988079071044921875, 1.89999997615814208984375, powr(h(param_5), 1.60000002384185791015625)) * _76.heightScale;
        float cx = x / z;
        float hw = w / z;
        float by = hl - (_76.cameraHeight / z);
        float ty = by + (ht / z);
        float param_6 = uv.x;
        float param_7 = cx - hw;
        float param_8 = cx + hw;
        float param_9 = 0.0024999999441206455230712890625;
        float param_10 = uv.y;
        float param_11 = by;
        float param_12 = ty;
        float param_13 = 0.0024999999441206455230712890625;
        float inside = (box1(param_6, param_7, param_8, param_9) * box1(param_10, param_11, param_12, param_13)) * ref_active;
        if ((inside > 0.5) && (z < best))
        {
            best = z;
            selFi = fi;
            selCX = cx;
            selHW = hw;
            selBY = by;
            selTY = ty;
        }
    }
    if (best < 100000.0)
    {
        float lx = (uv.x - (selCX - selHW)) / fast::max(2.0 * selHW, 9.9999997473787516355514526367188e-05);
        float ly = (uv.y - selBY) / fast::max(selTY - selBY, 9.9999997473787516355514526367188e-05);
        float param_14 = fract(lx * 5.0);
        float param_15 = 0.180000007152557373046875;
        float param_16 = 0.7200000286102294921875;
        float param_17 = 0.0350000001490116119384765625;
        float wx_1 = box1(param_14, param_15, param_16, param_17);
        float param_18 = fract(ly * 9.0);
        float param_19 = 0.180000007152557373046875;
        float param_20 = 0.660000026226043701171875;
        float param_21 = 0.0350000001490116119384765625;
        float wy = box1(param_18, param_19, param_20, param_21);
        float param_22 = (floor(lx * 5.0) + (floor(ly * 9.0) * 17.0)) + selFi;
        float lit = step(0.4000000059604644775390625, h(param_22));
        float windows = (wx_1 * wy) * lit;
        float df = exp(((-best) * _76.fog) * 0.100000001490116119384765625);
        float3 facade = (_76.buildingColor.xyz * mix(0.519999980926513671875, 1.0, df)) + (((_76.windowColor.xyz * windows) * _76.windowGlow) * df);
        float edge = fast::min(fast::min(lx, 1.0 - lx), fast::min(ly, 1.0 - ly));
        facade *= mix(0.7200000286102294921875, 1.0, smoothstep(0.0, 0.0599999986588954925537109375, edge));
        col = mix(_76.skyBottom.xyz, col, float3((df * 0.180000007152557373046875) + 0.819999992847442626953125));
        col = facade;
    }
    float3 rgb = mix(col, src.xyz + (col * 0.25), float3(_76.sourceMix));
    referenceColor = float4(rgb, fast::clamp(fast::max(_76.opacity, src.w * _76.sourceMix), 0.0, 1.0));
}

fragment refAM35_e667ffd209ce2_out refAM35_e667ffd209ce2(constant ReferenceUniformse667ffd209ce2& _76 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e667ffd209ce2_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _76, refInput, refInputSmplr, referenceColor);
    bool _632 = any(isnan(referenceColor));
    bool _639;
    if (!_632)
    {
        _639 = any(isinf(referenceColor));
    }
    else
    {
        _639 = _632;
    }
    if (_639)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _652 = referenceColor;
    float3 _658 = fast::clamp(_652.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _658.x;
    referenceColor.y = _658.y;
    referenceColor.z = _658.z;
    out.finalColor = referenceColor;
    return out;
}

