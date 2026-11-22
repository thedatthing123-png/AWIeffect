// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsbubble.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//////////////////////////
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

struct ReferenceUniformse8b3ce2e14963
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint autop;
    char _m6_pad[12];
    float PROGRESS;
    char _m7_pad[12];
    float SPEED;
    char _m8_pad[12];
    uint B1;
    char _m9_pad[12];
    uint B2;
    char _m10_pad[12];
    uint B3;
    char _m11_pad[12];
    uint B4;
    char _m12_pad[12];
    uint B5;
    char _m13_pad[12];
    uint B6;
    char _m14_pad[12];
    float scale;
    char _m15_pad[12];
    float angle;
    char _m16_pad[8];
    float2 position;
    char _m17_pad[8];
    float2 stretch;
    char _m18_pad[8];
    float alpha;
    char _m19_pad[12];
    float hardness;
    char _m20_pad[12];
    int blendMode;
};

struct refAM35_e8b3ce2e14963_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float2 hash2a(thread const float2& x, thread float& anim)
{
    float r = 523.0 * sin(dot(x, float2(53.315799713134765625, 43.614299774169921875)));
    float xa1 = fract(anim);
    float xb1 = anim - xa1;
    anim += 0.5;
    float xa2 = fract(anim);
    float xb2 = anim - xa2;
    float2 z1 = float2(fract(15.32353973388671875 * (r + xb1)), fract(17.2586498260498046875 * (r + xb1)));
    r += 1.0;
    float2 z2 = float2(fract(15.32353973388671875 * (r + xb1)), fract(17.2586498260498046875 * (r + xb1)));
    r += 1.0;
    float2 z3 = float2(fract(15.32353973388671875 * (r + xb2)), fract(17.2586498260498046875 * (r + xb2)));
    r += 1.0;
    float2 z4 = float2(fract(15.32353973388671875 * (r + xb2)), fract(17.2586498260498046875 * (r + xb2)));
    return (mix(z1, z2, float2(xa1)) + mix(z3, z4, float2(xa2))) * 0.5;
}

static inline __attribute__((always_inline))
float hashNull(thread const float2& x)
{
    float r = fract(523.0 * sin(dot(x, float2(53.315799713134765625, 43.614299774169921875))));
    return r;
}

static inline __attribute__((always_inline))
float2 hash2(thread const float2& n)
{
    return fract(sin(n) * 753.5452880859375);
}

static inline __attribute__((always_inline))
float _noise2(thread const float2& x, thread float4& NC0, thread float4& NC1)
{
    float2 p = floor(x);
    float2 f = fract(x);
    f = (f * f) * (float2(3.0) - (f * 2.0));
    float n = p.x + (p.y * 157.0);
    float2 param = float2(n) + NC0.xy;
    float2 param_1 = float2(n) + NC1.xy;
    float2 s1 = mix(hash2(param), hash2(param_1), float2(f.x));
    return mix(s1.x, s1.y, f.y);
}

static inline __attribute__((always_inline))
float4 booble(thread const float2& te, thread const float2& pos, thread const float& numCells, thread float4& NC0, thread float4& NC1)
{
    float d = dot(te, te);
    float2 te1 = te + (((pos - float2(0.5)) * 0.4000000059604644775390625) / float2(numCells));
    float2 te2 = -te1;
    float2 param = (te2 * 1000.1099853515625) * d;
    float zb1 = fast::max(powr(_noise2(param, NC0, NC1), 10.0), 0.00999999977648258209228515625);
    float2 param_1 = (te1 * 1000.1099853515625) * d;
    float zb2 = _noise2(param_1, NC0, NC1);
    float2 param_2 = (te1 * 200.1100006103515625) * d;
    float zb3 = _noise2(param_2, NC0, NC1);
    float2 param_3 = ((te1 * 200.1100006103515625) * d) + float2(20.0);
    float zb4 = _noise2(param_3, NC0, NC1);
    float4 colorb = float4(1.0);
    float4 _321 = colorb;
    float2 param_4 = (te1 * 1000.1099853515625) * d;
    float3 _333 = _321.xyz * (0.699999988079071044921875 + (_noise2(param_4, NC0, NC1) * 0.300000011920928955078125));
    colorb.x = _333.x;
    colorb.y = _333.y;
    colorb.z = _333.z;
    zb2 = fast::max(powr(zb2, 20.1000003814697265625), 0.00999999977648258209228515625);
    float4 _345 = colorb;
    float3 _350 = _345.xyz * (zb2 * 1.89999997615814208984375);
    colorb.x = _350.x;
    colorb.y = _350.y;
    colorb.z = _350.z;
    float2 param_5 = te2 * 10.80000019073486328125;
    float2 param_6 = (te2 * 9.5) + float2(15.0);
    float2 param_7 = (te2 * 11.19999980926513671875) + float2(12.0);
    float4 color = float4(_noise2(param_5, NC0, NC1), _noise2(param_6, NC0, NC1), _noise2(param_7, NC0, NC1), 1.0);
    float2 param_8 = (te2 * 20.5) + float2(200.0);
    color = mix(color, float4(1.0), float4(_noise2(param_8, NC0, NC1)));
    float4 _391 = color;
    float2 param_9 = (te2 * 1000.1099853515625) * d;
    float3 _401 = _391.xyz * (0.699999988079071044921875 + (_noise2(param_9, NC0, NC1) * 0.300000011920928955078125));
    color.x = _401.x;
    color.y = _401.y;
    color.z = _401.z;
    float4 _408 = color;
    float3 _414 = _408.xyz * (0.20000000298023223876953125 + (zb1 * 1.89999997615814208984375));
    color.x = _414.x;
    color.y = _414.y;
    color.z = _414.z;
    float r1 = fast::max(fast::min(((0.032999999821186065673828125 - fast::min(0.039999999105930328369140625, d)) * 100.0) / sqrt(numCells), 1.0), -1.60000002384185791015625);
    float d2 = (0.0599999986588954925537109375 - fast::min(0.0599999986588954925537109375, d)) * 10.0;
    d = (0.039999999105930328369140625 - fast::min(0.039999999105930328369140625, d)) * 10.0;
    float4 _445 = color;
    float3 _453 = _445.xyz + ((colorb.xyz * d) * 1.5);
    color.x = _453.x;
    color.y = _453.y;
    color.z = _453.z;
    float f1 = fast::min(d * 10.0, 0.5 - d) * 2.2000000476837158203125;
    f1 = powr(f1, 4.0);
    float f2 = fast::min((fast::min(d * 4.099999904632568359375, 0.89999997615814208984375 - d) * 2.0) * r1, 1.0);
    float f3 = fast::min(d2 * 2.0, 0.699999988079071044921875 - d2) * 2.2000000476837158203125;
    f3 = powr(f3, 4.0);
    return ((color * fast::max(fast::min(f1 + f2, 1.0), -0.5)) + (float4(zb3) * f3)) - ((float4(zb4) * ((f2 * 0.5) + f1)) * 0.5);
}

static inline __attribute__((always_inline))
float4 Cells(thread const float2& p, thread const float2& move, thread const float& numCells, thread const float& count, thread const float& blur, thread float4& NC0, thread float4& NC1, constant ReferenceUniformse8b3ce2e14963& _563, thread float2& uv)
{
    float2 inp = p + move;
    inp *= numCells;
    float d = 1.0;
    float _569;
    float2 pos;
    for (int xo = -1; xo <= 1; xo++)
    {
        for (int yo = -1; yo <= 1; yo++)
        {
            float2 tp = floor(inp) + float2(float(xo), float(yo));
            float2 rr = mod(tp, float2(numCells));
            if (_563.autop != 0u)
            {
                _569 = _563.PROGRESS + (_563.refScreen.z * _563.SPEED);
            }
            else
            {
                _569 = _563.PROGRESS;
            }
            float iTimee = _569;
            float2 param = rr;
            float param_1 = iTimee * 0.100000001490116119384765625;
            float2 _595 = hash2a(param, param_1);
            float2 param_2 = rr;
            float param_3 = (iTimee * 0.100000001490116119384765625) + 0.25;
            float2 _603 = hash2a(param_2, param_3);
            tp += ((_595 + _603) * 0.5);
            float2 l = inp - tp;
            float dr = dot(l, l);
            float2 param_4 = rr;
            if (hashNull(param_4) > count)
            {
                if (d > dr)
                {
                    d = dr;
                    pos = tp;
                }
            }
        }
    }
    if (d >= 0.0599999986588954925537109375)
    {
        return float4(0.0);
    }
    float2 te = inp - pos;
    if (d < 0.039999999105930328369140625)
    {
        uv += ((te * d) * 2.0);
    }
    if (blur > 9.9999997473787516355514526367188e-05)
    {
        float4 c = float4(0.0);
        for (float x = -1.0; x < 1.0; x += 0.5)
        {
            for (float y = -1.0; y < 1.0; y += 0.5)
            {
                float2 param_5 = te + (float2(x, y) * blur);
                float2 param_6 = p;
                float param_7 = numCells;
                c += booble(param_5, param_6, param_7, NC0, NC1);
            }
        }
        return c * 0.0500000007450580596923828125;
    }
    float2 param_8 = te;
    float2 param_9 = p;
    float param_10 = numCells;
    return booble(param_8, param_9, param_10, NC0, NC1);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& NC0, thread float4& NC1, constant ReferenceUniformse8b3ce2e14963& _563, thread float2& uv, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_563.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _563.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_563.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _563.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_563.refScreen.x, _563.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _563.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _563.refScreen.xy).y) * _563.refScreen.xy) - float2(_563.refLayer.x + (_563.refLayer.z * 0.5), (_563.refScreen.y - _563.refLayer.y) - (_563.refLayer.w * 0.5))) / _563.refLayer.zw;
            syamjaidtz.y *= (_563.refLayer.w / _563.refLayer.z);
            syamjaidtz /= float2(_563.scale);
            float param_3 = (0.0 + _563.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _563.position.x, 0.0 + _563.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_563.scale * _563.stretch.x, _563.scale * _563.stretch.y);
            syamjaidtz /= scaleVec;
            uv = syamjaidtz;
            float _871;
            if (_563.autop != 0u)
            {
                _871 = _563.PROGRESS + (_563.refScreen.z * _563.SPEED);
            }
            else
            {
                _871 = _563.PROGRESS;
            }
            float iTime = _871;
            float2 l1 = float2(iTime * 0.0199999995529651641845703125, iTime * 0.0199999995529651641845703125);
            float2 l2 = float2((-iTime) * 0.00999999977648258209228515625, iTime * 0.007000000216066837310791015625);
            float2 l3 = float2(0.0, iTime * 0.00999999977648258209228515625);
            float4 e = float4(0.0);
            float4 cr1;
            if (_563.B1 != 0u)
            {
                float2 param_4 = uv;
                float2 param_5 = float2(20.244899749755859375, 93.779998779296875) + l1;
                float param_6 = 2.0;
                float param_7 = 0.5;
                float param_8 = 0.004999999888241291046142578125;
                float4 _925 = Cells(param_4, param_5, param_6, param_7, param_8, NC0, NC1, _563, uv);
                cr1 = _925;
            }
            float4 cr2;
            if (_563.B2 != 0u)
            {
                float2 param_9 = uv;
                float2 param_10 = float2(0.0);
                float param_11 = 3.0;
                float param_12 = 0.5;
                float param_13 = 0.0030000000260770320892333984375;
                float4 _941 = Cells(param_9, param_10, param_11, param_12, param_13, NC0, NC1, _563, uv);
                cr2 = _941;
            }
            float4 cr3;
            if (_563.B3 != 0u)
            {
                float2 param_14 = uv;
                float2 param_15 = float2(230.7899932861328125, 193.1999969482421875) + l2;
                float param_16 = 4.0;
                float param_17 = 0.5;
                float param_18 = 0.0;
                float4 _960 = Cells(param_14, param_15, param_16, param_17, param_18, NC0, NC1, _563, uv);
                cr3 = _960;
            }
            float4 cr4;
            if (_563.B4 != 0u)
            {
                float2 param_19 = uv;
                float2 param_20 = float2(200.19000244140625, 393.20001220703125) + l3;
                float param_21 = 7.0;
                float param_22 = 0.800000011920928955078125;
                float param_23 = 0.00999999977648258209228515625;
                float4 _981 = Cells(param_19, param_20, param_21, param_22, param_23, NC0, NC1, _563, uv);
                cr4 = _981;
            }
            float4 cr5;
            if (_563.B5 != 0u)
            {
                float2 param_24 = uv;
                float2 param_25 = float2(10.32450008392333984375, 233.6450042724609375) + l3;
                float param_26 = 9.19999980926513671875;
                float param_27 = 0.89999997615814208984375;
                float param_28 = 0.0199999995529651641845703125;
                float4 _1001 = Cells(param_24, param_25, param_26, param_27, param_28, NC0, NC1, _563, uv);
                cr5 = _1001;
            }
            float4 cr6;
            if (_563.B6 != 0u)
            {
                float2 param_29 = uv;
                float2 param_30 = float2(10.32450008392333984375, 233.6450042724609375) + l3;
                float param_31 = 14.19999980926513671875;
                float param_32 = 0.949999988079071044921875;
                float param_33 = 0.0500000007450580596923828125;
                float4 _1019 = Cells(param_29, param_30, param_31, param_32, param_33, NC0, NC1, _563, uv);
                cr6 = _1019;
            }
            if (_563.B1 != 0u)
            {
                e = fast::max(e - (float4(dot(cr1, cr1)) * 0.100000001490116119384765625), float4(0.0)) + (cr1 * 1.7999999523162841796875);
            }
            if (_563.B2 != 0u)
            {
                e = fast::max(e - (float4(dot(cr2, cr2)) * 0.100000001490116119384765625), float4(0.0)) + (cr2 * 1.39999997615814208984375);
            }
            if (_563.B3 != 0u)
            {
                e = fast::max(e - (float4(dot(cr3, cr3)) * 0.100000001490116119384765625), float4(0.0)) + (cr3 * 1.10000002384185791015625);
            }
            if (_563.B4 != 0u)
            {
                e = fast::max(e - (float4(dot(cr4, cr4)) * 0.100000001490116119384765625), float4(0.0)) + (cr4 * 1.2999999523162841796875);
            }
            if (_563.B5 != 0u)
            {
                e = fast::max(e - (float4(dot(cr5, cr5)) * 0.100000001490116119384765625), float4(0.0)) + (cr5 * 1.60000002384185791015625);
            }
            if (_563.B6 != 0u)
            {
                e = fast::max(e - (float4(dot(cr6, cr6)) * 0.100000001490116119384765625), float4(0.0)) + (cr6 * 1.60000002384185791015625);
            }
            float4 fragColor = e;
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal;
            if (_563.blendMode == 0)
            {
                resultfinal = (factor * _563.hardness) * texColor.w;
            }
            else
            {
                if (_563.blendMode == 1)
                {
                    factor *= _563.hardness;
                    resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_563.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e8b3ce2e14963_out refAM35_e8b3ce2e14963(constant ReferenceUniformse8b3ce2e14963& _563 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8b3ce2e14963_out out = {};
    float4 NC0 = float4(0.0, 157.0, 113.0, 270.0);
    float4 NC1 = float4(1.0, 158.0, 114.0, 271.0);
    float4 referenceColor = float4(0.0);
    float2 uv;
    referenceMain(NC0, NC1, _563, uv, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _1196 = any(isnan(referenceColor));
    bool _1203;
    if (!_1196)
    {
        _1203 = any(isinf(referenceColor));
    }
    else
    {
        _1203 = _1196;
    }
    if (_1203)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1216 = referenceColor;
    float3 _1222 = fast::clamp(_1216.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1222.x;
    referenceColor.y = _1222.y;
    referenceColor.z = _1222.z;
    out.finalColor = referenceColor;
    return out;
}

