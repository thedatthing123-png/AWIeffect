// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxscosmicycles.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//#define BURST
// #define NUM_LAYERS 5.
//////////////////////////
// vec3 star = brightness*vec3(0.6+p.x, 0.4, 0.6+p.y)*N.z*N.z;
// star *= 1.0+sin((t+n)*20.0)*smoothstep(sin(t)*0.5+0.5, 1.0, fract(10.0*n));
//////////////////////////
// vec2 syamjaidtz;
// syamjaidtz = acScreenNorm; 
/////////////////////////
// vec2 uv = (fragCoord-.5*iResolution.xy)/iResolution.y;
//AUTO ROTATE
// uv *= 2.0+sin(t*0.05); // AUTO SCALE
//////////////////////////
//////////////////////////
//sv.x += t;
//////////////////////////
//t = iTime*0.5;
// col += fade*0.2*vec3(1.0, 0.5, 0.1)*bla*burstFade;
//////////////////////////
// resultfinal = (newLayer(texColor, factor) * hardness) * texColor.a; }
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse1d78bb4e006a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 COL;
    float NUM_LAYERS;
    char _m7_pad[12];
    float PROGRESS;
    char _m8_pad[12];
    float scale;
    char _m9_pad[12];
    float angle;
    char _m10_pad[12];
    float xxg;
    char _m11_pad[12];
    float xxh;
    char _m12_pad[12];
    uint autop;
    char _m13_pad[12];
    uint rrr;
    char _m14_pad[12];
    uint autos;
    char _m15_pad[12];
    uint autor;
    char _m16_pad[12];
    uint BURST;
    char _m17_pad[12];
    float xxa;
    char _m18_pad[12];
    float xxb;
    float4 COLB;
    float2 position;
    char _m21_pad[8];
    float2 stretch;
    char _m22_pad[8];
    float alpha;
    char _m23_pad[12];
    float hardness;
    char _m24_pad[12];
    int blendMode;
};

struct refAM35_e1d78bb4e006a_out
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
float2x2 Rot(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float Hash21(thread float2& p)
{
    p = fract(p * float2(123.339996337890625, 145.5399932861328125));
    p += float2(dot(p, p + float2(45.229999542236328125)));
    return fract(p.x * p.y);
}

static inline __attribute__((always_inline))
float Star(thread const float2& uv, thread const float& a, thread const float& sparkle)
{
    float2 av1 = abs(uv);
    float param = a;
    float2 av2 = abs(uv * Rot(param));
    float2 av = fast::min(av1, av2);
    float3 col = float3(0.0);
    float d = length(uv);
    float star = av1.x * av1.y;
    star = fast::max(av1.x * av1.y, av2.x * av2.y);
    star = fast::max(0.0, 1.0 - (star * 1000.0));
    float m = fast::min(5.0, 0.00999999977648258209228515625 / d);
    return m + (powr(star, 4.0) * sparkle);
}

static inline __attribute__((always_inline))
float3 StarLayer(thread const float2& uv, thread float& t, thread const float& sparkle, constant ReferenceUniformse1d78bb4e006a& _205)
{
    float2 gv = fract(uv) - float2(0.5);
    float2 id = floor(uv);
    float3 col = float3(0.0);
    if (_205.BURST != 0u)
    {
        t = 0.0;
    }
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float2 offs = float2(float(x), float(y));
            float2 param = id - offs;
            float _244 = Hash21(param);
            float n = _244;
            float3 N = fract(float3(10.0, 100.0, 1000.0) * n);
            float2 p = (N.xy - float2(0.5)) * 0.699999988079071044921875;
            float2 param_1 = (gv - p) + offs;
            float param_2 = (n * 6.283100128173828125) + (t + _205.xxg);
            float param_3 = sparkle;
            float brightness = Star(param_1, param_2, param_3);
            float3 star = ((float3(_205.COL.x + p.x, _205.COL.y, _205.COL.y + p.y) * brightness) * N.z) * N.z;
            star *= (1.0 + (sin(((t + _205.xxh) + n) * 20.0) * smoothstep((sin(t) * 0.5) + 0.5, 1.0, fract(10.0 * n))));
            float d = length(gv + offs);
            col += (star * smoothstep(1.5, 0.800000011920928955078125, d));
        }
    }
    return col;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse1d78bb4e006a& _205, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_205.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _205.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_205.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _205.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_205.refScreen.x, _205.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _205.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _205.refScreen.xy).y) * _205.refScreen.xy) - float2(_205.refLayer.x + (_205.refLayer.z * 0.5), (_205.refScreen.y - _205.refLayer.y) - (_205.refLayer.w * 0.5))) / _205.refLayer.zw;
            syamjaidtz.y *= (_205.refLayer.w / _205.refLayer.z);
            syamjaidtz /= float2(_205.scale);
            float param_3 = (0.0 + _205.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _205.position.x, 0.0 + _205.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_205.scale * _205.stretch.x, _205.scale * _205.stretch.y);
            syamjaidtz /= scaleVec;
            float2 uv = syamjaidtz;
            float2 M = iMouse / iResolution;
            M *= 10.0;
            float _517;
            if (_205.autop != 0u)
            {
                float _524;
                if (_205.rrr != 0u)
                {
                    _524 = (_205.PROGRESS * 0.300000011920928955078125) - (_205.refScreen.z * 0.5);
                }
                else
                {
                    _524 = (_205.PROGRESS * 0.300000011920928955078125) + (_205.refScreen.z * 0.5);
                }
                _517 = _524;
            }
            else
            {
                _517 = _205.PROGRESS * 0.300000011920928955078125;
            }
            float t = _517;
            float twirl = sin(t * 0.100000001490116119384765625);
            twirl *= ((twirl * twirl) * sin(dot(uv, uv)));
            if (_205.autor != 0u)
            {
                float param_4 = (-t) * 0.20000000298023223876953125;
                uv *= Rot(param_4);
            }
            float3 col = float3(0.0);
            float speed = -0.20000000298023223876953125;
            float burst = sin(_205.xxa * 0.0500000007450580596923828125);
            float bla = (sin(t + sin(t + (sin(t) * 0.5))) * 0.5) + _205.xxb;
            float d = dot(uv, uv);
            float a = precise::atan2(uv.x, uv.y);
            if (_205.BURST != 0u)
            {
                speed = 0.100000001490116119384765625;
                uv /= float2(d);
                uv *= (burst + 0.20000000298023223876953125);
            }
            float _631 = 1.0 / _205.NUM_LAYERS;
            float _645;
            for (float stp = _631, i = 0.0; i < 1.0; i += stp)
            {
                if (_205.autos != 0u)
                {
                    _645 = fract((t * speed) + i);
                }
                else
                {
                    _645 = fract((0.5 * speed) + i);
                }
                float lt = _645;
                float scale = mix(10.0, 0.25, lt);
                float fade = smoothstep(0.0, 0.4000000059604644775390625, lt) * smoothstep(1.0, 0.949999988079071044921875, lt);
                float2 sv = ((uv * scale) + float2(i * 134.529998779296875)) - M;
                float2 param_5 = sv;
                float param_6 = t;
                float param_7 = fade;
                float3 _690 = StarLayer(param_5, param_6, param_7, _205);
                col += (_690 * fade);
            }
            if (_205.BURST != 0u)
            {
                float burstFade = smoothstep(0.0, 0.0199999995529651641845703125, abs(burst));
                float size = (0.89999997615814208984375 * sin(t)) + 1.0;
                size = fast::max(size, sqrt(size));
                float fade_1 = size / d;
                col *= mix(1.0, fade_1, burstFade);
                col += (((_205.COLB.xyz * (fade_1 * 0.20000000298023223876953125)) * bla) * burstFade);
                t *= 1.5;
                a -= (M.x * 0.100000001490116119384765625);
                float rays = sin((a * 5.0) + (t * 3.0)) - cos((a * 7.0) - t);
                rays *= ((sin((a + t) + (sin(a * 4.0) * 10.0)) * 0.5) + 0.5);
                col += float3(((rays * bla) * 0.100000001490116119384765625) * burstFade);
                col += float3(1.0 - burstFade);
            }
            else
            {
                col *= 4.0;
            }
            float4 fragColor = float4(col, 1.0);
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal;
            if (_205.blendMode == 0)
            {
                resultfinal = (factor * _205.hardness) * texColor.w;
            }
            else
            {
                if (_205.blendMode == 1)
                {
                    factor *= _205.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_205.blendMode == 2)
                    {
                        factor *= _205.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_205.blendMode == 3)
                        {
                            factor *= _205.hardness;
                            float4 param_8 = texColor;
                            float4 param_9 = factor;
                            resultfinal = (newLayer(param_8, param_9) * _205.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_205.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e1d78bb4e006a_out refAM35_e1d78bb4e006a(constant ReferenceUniformse1d78bb4e006a& _205 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e1d78bb4e006a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_205, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _922 = any(isnan(referenceColor));
    bool _929;
    if (!_922)
    {
        _929 = any(isinf(referenceColor));
    }
    else
    {
        _929 = _922;
    }
    if (_929)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _942 = referenceColor;
    float3 _948 = fast::clamp(_942.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _948.x;
    referenceColor.y = _948.y;
    referenceColor.z = _948.z;
    out.finalColor = referenceColor;
    return out;
}

