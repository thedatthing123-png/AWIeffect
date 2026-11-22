// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsrainydew.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//  from DAVE HOSKINS
// y = fract(y*10.0)+(st.y-0.5);
//m += st.x>a.y*.45 || st.y>a.x*.165 ? 1.2 : 0.0;
// float c = S(0.3, 0.0, d)*fract(n.z*10.0)*fade;
//////////////////////////
/////////////////////////
/// HEART
/// HEART
// remap drop time so it goes slower when it freezes
// more opaque glass towards the end
// build heart
// heart gets smaller and fades towards the end
// the rain is where the heart is
// inside the heart slighly less foggy
// zoom out a bit more
// expensive normals
/// HEART
// make time sync with first lightnoing
// subtle color shift
// fade in at the start
// lighting flicker
// lightning flash
// composite lightning
// vignette
/// HEART
// composite start and end fade
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

struct ReferenceUniformsefaa1c624f7db
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint xnxx;
    char _m6_pad[12];
    float progress;
    char _m7_pad[12];
    float scaleuv;
    char _m8_pad[12];
    float alpha;
    char _m9_pad[12];
    float angle;
    char _m10_pad[8];
    float2 position;
    char _m11_pad[8];
    float2 space;
    char _m12_pad[8];
    float scalex;
    char _m13_pad[12];
    float scaley;
    char _m14_pad[12];
    float scalez;
    char _m15_pad[12];
    float alpx;
    char _m16_pad[12];
    float alpy;
    char _m17_pad[12];
    uint xxx;
    char _m18_pad[12];
    uint lightfx;
    char _m19_pad[12];
    float aai;
};

struct refAM35_efaa1c624f7db_out
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
float3 N13(thread const float& p)
{
    float3 p3 = fract(float3(p) * float3(0.103100001811981201171875, 0.113689996302127838134765625, 0.13786999881267547607421875));
    p3 += float3(dot(p3, p3.yzx + float3(19.1900005340576171875)));
    return fract(float3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}

static inline __attribute__((always_inline))
float Saw(thread const float& b, thread const float& t)
{
    return smoothstep(0.0, b, t) * smoothstep(1.0, b, t);
}

static inline __attribute__((always_inline))
float StaticDrops(thread float2& uv, thread const float& t, constant ReferenceUniformsefaa1c624f7db& _164)
{
    uv *= 40.0;
    float2 id = floor(uv);
    uv = fract(uv) - float2(0.5);
    float param = (id.x * 107.4499969482421875) + (id.y * 3543.654052734375);
    float3 n = N13(param);
    float2 p = (n.xy - float2(0.5)) * 0.699999988079071044921875;
    float d = length(uv - p);
    float param_1 = 0.02500000037252902984619140625;
    float param_2 = fract(t + n.z);
    float fade = Saw(param_1, param_2);
    float c = ((smoothstep(0.300000011920928955078125, 0.0, d) * fract(n.z * 10.0)) * fade) * _164.alpx;
    return c;
}

static inline __attribute__((always_inline))
float N(thread const float& t)
{
    return fract(sin(t * 12345.564453125) * 7658.759765625);
}

static inline __attribute__((always_inline))
float2 DropLayer2(thread float2& uv, thread const float& t, constant ReferenceUniformsefaa1c624f7db& _164)
{
    float2 UV = uv;
    uv.y += (t * 0.75);
    float2 a = float2(_164.space.x, 1.0);
    float2 grid = a * 2.0;
    float2 id = floor(uv * grid);
    float param = id.x;
    float colShift = N(param);
    uv.y += colShift;
    id = floor(uv * grid);
    float param_1 = (id.x * 35.200000762939453125) + (id.y * 2376.10009765625);
    float3 n = N13(param_1);
    float2 st = fract(uv * grid) - float2(0.5, 0.0);
    float x = n.x - 0.5;
    float y = UV.y * 20.0;
    float wiggle = sin(y + sin(y));
    x += ((wiggle * (0.5 - abs(x))) * (n.z - 0.5));
    x *= 0.699999988079071044921875;
    float ti = fract(t + n.z);
    float param_2 = 0.85000002384185791015625;
    float param_3 = ti;
    y = ((Saw(param_2, param_3) - 0.5) * 0.89999997615814208984375) + 0.5;
    float2 p = float2(x, y);
    float d = length((st - p) * a.yx);
    float mainDrop = smoothstep(0.4000000059604644775390625, 0.0, d);
    float r = sqrt(smoothstep(1.0, y, st.y));
    float cd = abs(st.x - x);
    float trail = smoothstep(0.23000000417232513427734375 * r, (0.1500000059604644775390625 * r) * r, cd);
    float trailFront = smoothstep(-0.0199999995529651641845703125, 0.0199999995529651641845703125, st.y - y);
    trail *= ((trailFront * r) * r);
    y = UV.y;
    float trail2 = smoothstep(0.20000000298023223876953125 * r, 0.0, cd);
    float droplets = ((fast::max(0.0, sin((y * (1.0 - y)) * 120.0) - st.y) * trail2) * trailFront) * n.z;
    y = fract(y * _164.space.y) + (st.y - 0.5);
    float dd = length(st - float2(x, y));
    droplets = smoothstep(0.300000011920928955078125, 0.0, dd);
    float m = (mainDrop + ((droplets * r) * trailFront)) * _164.alpy;
    return float2(m, trail);
}

static inline __attribute__((always_inline))
float2 Drops(thread const float2& uv, thread const float& t, thread const float& l0, thread const float& l1, thread const float& l2, constant ReferenceUniformsefaa1c624f7db& _164)
{
    float2 param = uv * _164.scalex;
    float param_1 = t;
    float _445 = StaticDrops(param, param_1, _164);
    float s = _445 * l0;
    float2 param_2 = uv * _164.scaley;
    float param_3 = t;
    float2 _457 = DropLayer2(param_2, param_3, _164);
    float2 m1 = _457 * l1;
    float2 param_4 = uv * _164.scalez;
    float param_5 = t;
    float2 _469 = DropLayer2(param_4, param_5, _164);
    float2 m2 = _469 * l2;
    float c = (s + m1.x) + m2.x;
    c = smoothstep(0.300000011920928955078125, 1.0, c);
    return float2(c, fast::max(m1.y * l0, m2.y * l1));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsefaa1c624f7db& _164, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_164.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _164.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_164.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _164.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _164.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _164.refScreen.xy).y) * _164.refScreen.xy) - float2(_164.refLayer.x + (_164.refLayer.z * 0.5), (_164.refScreen.y - _164.refLayer.y) - (_164.refLayer.w * 0.5))) / _164.refLayer.zw;
            syamjaidtz.y *= (_164.refLayer.w / _164.refLayer.z);
            if (_164.xnxx != 0u)
            {
                syamjaidtz /= float2(_164.scaleuv + 1.5);
            }
            else
            {
                syamjaidtz /= float2(_164.scaleuv);
            }
            float param_2 = ((-180.0) + _164.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_2);
            syamjaidtz += ((float2(0.0 + _164.position.x, 0.0 + _164.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 uv = syamjaidtz;
            float2 UV = gl_FragCoord.xy / _164.refScreen.xy;
            float3 M = float3(0.0);
            float T = _164.progress + (M.x * 2.0);
            if (_164.xnxx != 0u)
            {
                T = mod(_164.progress, 102.0);
                T = mix(T, M.x * 102.0, float(M.z > 0.0));
            }
            float t = T * 0.20000000298023223876953125;
            float _683;
            if (false)
            {
                _683 = M.y;
            }
            else
            {
                _683 = (sin(T * 0.0500000007450580596923828125) * 0.300000011920928955078125) + 0.699999988079071044921875;
            }
            float rainAmount = _683;
            float maxBlur = mix(3.0, 6.0, rainAmount);
            float minBlur = 2.0;
            float story = 0.0;
            float heart = 0.0;
            if (_164.xnxx != 0u)
            {
                story = smoothstep(0.0, 70.0, T);
                t = fast::min(1.0, T / 70.0);
                t = 1.0 - t;
                t = (1.0 - (t * t)) * 70.0;
                minBlur = 4.0 + (smoothstep(0.5, 1.0, story) * 3.0);
                maxBlur = 6.0 + (smoothstep(0.5, 1.0, story) * 1.5);
                float2 hv = uv - float2(0.0, -0.100000001490116119384765625);
                hv.x *= 0.5;
                float s = smoothstep(110.0, 70.0, T);
                hv.y -= ((sqrt(abs(hv.x)) * 0.5) * s);
                heart = length(hv);
                heart = smoothstep(0.4000000059604644775390625 * s, 0.20000000298023223876953125 * s, heart) * s;
                rainAmount = heart;
                maxBlur -= heart;
                uv *= 1.5;
                t *= 0.25;
            }
            float staticDrops = smoothstep(-0.5, 1.0, rainAmount) * 2.0;
            float layer1 = smoothstep(0.25, 0.75, rainAmount);
            float layer2 = smoothstep(0.0, 0.5, rainAmount);
            float2 param_3 = uv;
            float param_4 = t;
            float param_5 = staticDrops;
            float param_6 = layer1;
            float param_7 = layer2;
            float2 c = Drops(param_3, param_4, param_5, param_6, param_7, _164);
            float2 e = float2(0.001000000047497451305389404296875, 0.0);
            float2 param_8 = uv + e;
            float param_9 = t;
            float param_10 = staticDrops;
            float param_11 = layer1;
            float param_12 = layer2;
            float cx = Drops(param_8, param_9, param_10, param_11, param_12, _164).x;
            float2 param_13 = uv + e.yx;
            float param_14 = t;
            float param_15 = staticDrops;
            float param_16 = layer1;
            float param_17 = layer2;
            float cy = Drops(param_13, param_14, param_15, param_16, param_17, _164).x;
            float2 n = float2(cx - c.x, cy - c.x);
            if (_164.xnxx != 0u)
            {
                n *= (1.0 - smoothstep(60.0, 85.0, T));
                c.y *= (1.0 - (smoothstep(80.0, 100.0, T) * 0.800000011920928955078125));
            }
            float focus = mix(maxBlur - c.y, minBlur, smoothstep(0.100000001490116119384765625, 0.20000000298023223876953125, c.x));
            float2 param_18 = UV + n;
            float4 col = texture2DCv(refInput, refInputSmplr, param_18);
            if (_164.xxx != 0u)
            {
                col.w *= focus;
            }
            else
            {
                col.w = focus;
            }
            if (_164.lightfx != 0u)
            {
                t = (T + 3.0) * 0.5;
                float colFade = ((sin(t * 0.20000000298023223876953125) * _164.aai) + 0.5) + (story * 1.0);
                float4 _923 = col;
                float3 _925 = _923.xyz * (mix(float3(1.0), float3(0.800000011920928955078125, 0.89999997615814208984375, 1.2999999523162841796875), float3(colFade)) * 1.0);
                col.x = _925.x;
                col.y = _925.y;
                col.z = _925.z;
                float fade = smoothstep(0.0, 10.0, T);
                float lightning = sin(t * sin(t * 10.0));
                lightning *= powr(fast::max(0.0, sin(t + sin(t))), 10.0);
                float4 _961 = col;
                float3 _963 = _961.xyz * (1.0 + (((lightning * fade) * mix(1.0, 0.100000001490116119384765625, story * story)) * 0.5));
                col.x = _963.x;
                col.y = _963.y;
                col.z = _963.z;
                float2 _970 = UV;
                float2 _972 = _970 - float2(0.5);
                UV = _972;
                float4 _977 = col;
                float3 _979 = _977.xyz * (1.0 - (dot(_972, UV) * 1.0));
                col.x = _979.x;
                col.y = _979.y;
                col.z = _979.z;
                if (_164.xnxx != 0u)
                {
                    float4 _991 = col;
                    float4 _996 = col;
                    float3 _1001 = mix(powr(_991.xyz, float3(1.2000000476837158203125)), _996.xyz, float3(heart)) * 1.0;
                    col.x = _1001.x;
                    col.y = _1001.y;
                    col.z = _1001.z;
                    fade *= smoothstep(102.0, 97.0, T);
                }
                float4 _1014 = col;
                float3 _1016 = _1014.xyz * fade;
                col.x = _1016.x;
                col.y = _1016.y;
                col.z = _1016.z;
            }
            float4 fragColor = col;
            referenceColor = mix(texColor, fragColor, float4(_164.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_efaa1c624f7db_out refAM35_efaa1c624f7db(constant ReferenceUniformsefaa1c624f7db& _164 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_efaa1c624f7db_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_164, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _1040 = any(isnan(referenceColor));
    bool _1047;
    if (!_1040)
    {
        _1047 = any(isinf(referenceColor));
    }
    else
    {
        _1047 = _1040;
    }
    if (_1047)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1060 = referenceColor;
    float3 _1066 = fast::clamp(_1060.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1066.x;
    referenceColor.y = _1066.y;
    referenceColor.z = _1066.z;
    out.finalColor = referenceColor;
    return out;
}

