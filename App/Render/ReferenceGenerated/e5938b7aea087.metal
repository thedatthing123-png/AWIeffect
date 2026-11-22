// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxs2dclouds.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
// (sqrt(3)-1)/2;
// (3-sqrt(3))/6;
//vec2 of = 0.5 + 0.5*vec2(sign(a.x-a.y), sign(a.y-a.x));
//////////////////////////
/////////////////////////
// float time = iTime * speed;
//ridged noise shape
//noise shape
//noise colour
//noise ridge colour
// vec3 cloudcolour = vec3(1.1, 1.1, 0.9) * clamp((clouddark + cloudlight*c), 0.0, 1.0);
// resultfinal = (newLayer(texColor, factor) * hardness) * texColor.a; }
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse5938b7aea087
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 skycolour2;
    float4 skycolour1;
    float4 ccolor;
    float PROGRESS;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    float angle;
    char _m11_pad[12];
    float clouddark;
    char _m12_pad[12];
    float cloudlight;
    char _m13_pad[12];
    float cloudcover;
    char _m14_pad[12];
    float cloudalpha;
    char _m15_pad[12];
    float skytint;
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

struct refAM35_e5938b7aea087_out
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
float2 hash(thread float2& p)
{
    p = float2(dot(p, float2(127.09999847412109375, 311.70001220703125)), dot(p, float2(269.5, 183.3000030517578125)));
    return float2(-1.0) + (fract(sin(p) * 43758.546875) * 2.0);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p + float2((p.x + p.y) * 0.3660254180431365966796875));
    float2 a = (p - i) + float2((i.x + i.y) * 0.211324870586395263671875);
    float2 o = select(float2(0.0, 1.0), float2(1.0, 0.0), bool2(a.x > a.y));
    float2 b = (a - o) + float2(0.211324870586395263671875);
    float2 c = (a - float2(1.0)) + float2(0.42264974117279052734375);
    float3 h = fast::max(float3(0.5) - float3(dot(a, a), dot(b, b), dot(c, c)), float3(0.0));
    float2 param = i + float2(0.0);
    float2 _189 = hash(param);
    float2 param_1 = i + o;
    float2 _196 = hash(param_1);
    float2 param_2 = i + float2(1.0);
    float2 _203 = hash(param_2);
    float3 n = (((h * h) * h) * h) * float3(dot(a, _189), dot(b, _196), dot(c, _203));
    return dot(n, float3(70.0));
}

static inline __attribute__((always_inline))
float fbm(thread float2& n)
{
    float total = 0.0;
    float amplitude = 0.100000001490116119384765625;
    for (int i = 0; i < 7; i++)
    {
        float2 param = n;
        total += (_noise(param) * amplitude);
        n = float2x2(float2(1.60000002384185791015625, 1.2000000476837158203125), float2(-1.2000000476837158203125, 1.60000002384185791015625)) * n;
        amplitude *= 0.4000000059604644775390625;
    }
    return total;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse5938b7aea087& _255, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_255.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _255.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_255.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _255.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_255.refScreen.x, _255.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _255.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _255.refScreen.xy).y) * _255.refScreen.xy) - float2(_255.refLayer.x + (_255.refLayer.z * 0.5), (_255.refScreen.y - _255.refLayer.y) - (_255.refLayer.w * 0.5))) / _255.refLayer.zw;
            syamjaidtz.y *= (_255.refLayer.w / _255.refLayer.z);
            syamjaidtz /= float2(_255.scale);
            float param_3 = (0.0 + _255.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _255.position.x, 0.0 + _255.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_255.scale * _255.stretch.x, _255.scale * _255.stretch.y);
            syamjaidtz /= scaleVec;
            float2 p = syamjaidtz;
            float2 uv = p * float2(iResolution.x / iResolution.y, 1.0);
            float time = _255.PROGRESS;
            float2 param_4 = (uv * 1.10000002384185791015625) * 0.5;
            float _435 = fbm(param_4);
            float q = _435;
            float r = 0.0;
            uv *= 1.10000002384185791015625;
            uv -= float2(q - time);
            float weight = 0.800000011920928955078125;
            for (int i = 0; i < 8; i++)
            {
                float2 param_5 = uv;
                r += abs(weight * _noise(param_5));
                uv = (float2x2(float2(1.60000002384185791015625, 1.2000000476837158203125), float2(-1.2000000476837158203125, 1.60000002384185791015625)) * uv) + float2(time);
                weight *= 0.699999988079071044921875;
            }
            float f = 0.0;
            uv = p * float2(iResolution.x / iResolution.y, 1.0);
            uv *= 1.10000002384185791015625;
            uv -= float2(q - time);
            weight = 0.699999988079071044921875;
            for (int i_1 = 0; i_1 < 8; i_1++)
            {
                float2 param_6 = uv;
                f += (weight * _noise(param_6));
                uv = (float2x2(float2(1.60000002384185791015625, 1.2000000476837158203125), float2(-1.2000000476837158203125, 1.60000002384185791015625)) * uv) + float2(time);
                weight *= 0.60000002384185791015625;
            }
            f *= (r + f);
            float c = 0.0;
            time = _255.PROGRESS * 2.0;
            uv = p * float2(iResolution.x / iResolution.y, 1.0);
            uv *= 2.2000000476837158203125;
            uv -= float2(q - time);
            weight = 0.4000000059604644775390625;
            for (int i_2 = 0; i_2 < 7; i_2++)
            {
                float2 param_7 = uv;
                c += (weight * _noise(param_7));
                uv = (float2x2(float2(1.60000002384185791015625, 1.2000000476837158203125), float2(-1.2000000476837158203125, 1.60000002384185791015625)) * uv) + float2(time);
                weight *= 0.60000002384185791015625;
            }
            float c1 = 0.0;
            time = _255.PROGRESS * 3.0;
            uv = p * float2(iResolution.x / iResolution.y, 1.0);
            uv *= 3.2999999523162841796875;
            uv -= float2(q - time);
            weight = 0.4000000059604644775390625;
            for (int i_3 = 0; i_3 < 7; i_3++)
            {
                float2 param_8 = uv;
                c1 += abs(weight * _noise(param_8));
                uv = (float2x2(float2(1.60000002384185791015625, 1.2000000476837158203125), float2(-1.2000000476837158203125, 1.60000002384185791015625)) * uv) + float2(time);
                weight *= 0.60000002384185791015625;
            }
            c += c1;
            float3 skycolour = mix(_255.skycolour2.xyz, _255.skycolour1.xyz, float3(p.y));
            float3 cloudcolour = float3(_255.ccolor.x + 0.100000001490116119384765625, _255.ccolor.y + 0.100000001490116119384765625, _255.ccolor.z) * fast::clamp(_255.clouddark + (_255.cloudlight * c), 0.0, 1.0);
            f = _255.cloudcover + ((_255.cloudalpha * f) * r);
            float3 result = mix(skycolour, fast::clamp((skycolour * _255.skytint) + cloudcolour, float3(0.0), float3(1.0)), float3(fast::clamp(f + c, 0.0, 1.0)));
            float4 fragColor = float4(result, _255.skycolour2.w);
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal;
            if (_255.blendMode == 0)
            {
                resultfinal = (factor * _255.hardness) * texColor.w;
            }
            else
            {
                if (_255.blendMode == 1)
                {
                    factor *= _255.hardness;
                    float4 c_1 = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c_1.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_255.blendMode == 2)
                    {
                        factor *= _255.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_255.blendMode == 3)
                        {
                            factor *= _255.hardness;
                            float4 param_9 = texColor;
                            float4 param_10 = factor;
                            resultfinal = (newLayer(param_9, param_10) * _255.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_255.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e5938b7aea087_out refAM35_e5938b7aea087(constant ReferenceUniformse5938b7aea087& _255 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e5938b7aea087_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_255, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _810 = any(isnan(referenceColor));
    bool _817;
    if (!_810)
    {
        _817 = any(isinf(referenceColor));
    }
    else
    {
        _817 = _810;
    }
    if (_817)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _830 = referenceColor;
    float3 _836 = fast::clamp(_830.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _836.x;
    referenceColor.y = _836.y;
    referenceColor.z = _836.z;
    out.finalColor = referenceColor;
    return out;
}

