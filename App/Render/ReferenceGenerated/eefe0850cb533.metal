// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxflame.xml
// Original source comments and attribution:
/////////////////////////
// if (adaptive) { syamjaidtz = acScreenNorm; }
// else { 
// }
/////////////////////////
// vec2 p = syamjaidtz * dist / acScreenSize.xx;
// vec4 factor = mix(texColorX,gradmap,alpha);
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseefe0850cb533
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float progress;
    char _m7_pad[12];
    float scale;
    char _m8_pad[12];
    float bright;
    char _m9_pad[12];
    float alpha;
    char _m10_pad[12];
    float angle;
    float4 color1;
    float4 color2;
    float alphab;
    char _m14_pad[12];
    int blendMode;
};

struct refAM35_eefe0850cb533_out
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
float rand(thread const float2& n)
{
    return fract(sin(cos(dot(n, float2(12.98980045318603515625, 12.14140033721923828125)))) * 83758.546875);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& n)
{
    float2 b = floor(n);
    float2 f = smoothstep(float2(0.0), float2(1.0), fract(n));
    float2 param = b;
    float2 param_1 = b + float2(1.0, 0.0);
    float2 param_2 = b + float2(0.0, 1.0);
    float2 param_3 = b + float2(1.0);
    return mix(mix(rand(param), rand(param_1), f.x), mix(rand(param_2), rand(param_3), f.x), f.y);
}

static inline __attribute__((always_inline))
float fbm(thread float2& n)
{
    float total = 0.0;
    float amplitude = 1.0;
    for (int i = 0; i < 5; i++)
    {
        float2 param = n;
        total += (_noise(param) * amplitude);
        n += (n * 1.7000000476837158203125);
        amplitude *= 0.4699999988079071044921875;
    }
    return total;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseefe0850cb533& _157, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _157.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _157.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _157.refScreen.xy).y) * _157.refScreen.xy) - float2(_157.refLayer.x + (_157.refLayer.z * 0.5), (_157.refScreen.y - _157.refLayer.y) - (_157.refLayer.w * 0.5))) / _157.refLayer.zw;
    syamjaidtz.y *= (_157.refLayer.w / _157.refLayer.z);
    syamjaidtz.x = 1.0 - syamjaidtz.x;
    syamjaidtz /= float2(_157.scale);
    float param_1 = (180.0 + _157.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((float2(_157.position.x, 180.0 + _157.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 speed = float2(0.100000001490116119384765625, 0.89999997615814208984375);
    float shift = 1.32700002193450927734375 + (sin(_157.progress * 2.0) / 2.400000095367431640625);
    float dist = 3.5 - (sin(_157.progress * 0.4000000059604644775390625) / 1.88999998569488525390625);
    float2 uv = syamjaidtz;
    float2 p = syamjaidtz * dist;
    p += (sin((p.yx * 4.0) + (float2(0.20000000298023223876953125, -0.300000011920928955078125) * _157.progress)) * 0.039999999105930328369140625);
    p += (sin((p.yx * 8.0) + (float2(0.60000002384185791015625, 0.100000001490116119384765625) * _157.progress)) * 0.00999999977648258209228515625);
    p.x -= (_157.progress / 1.10000002384185791015625);
    float2 param_2 = (p - float2(_157.progress * 0.300000011920928955078125)) + float2((1.0 * sin(_157.progress + 0.5)) / 2.0);
    float _347 = fbm(param_2);
    float q = _347;
    float2 param_3 = (p - float2(_157.progress * 0.4000000059604644775390625)) + float2((0.100000001490116119384765625 * cos(_157.progress)) / 2.0);
    float _363 = fbm(param_3);
    float qb = _363;
    float2 param_4 = (p - float2(_157.progress * 0.439999997615814208984375)) - float2((5.0 * cos(_157.progress)) / 2.0);
    float _381 = fbm(param_4);
    float q2 = _381 - 6.0;
    float2 param_5 = (p - float2(_157.progress * 0.89999997615814208984375)) - float2((10.0 * cos(_157.progress)) / 15.0);
    float _401 = fbm(param_5);
    float q3 = _401 - 4.0;
    float2 param_6 = (p - float2(_157.progress * 1.39999997615814208984375)) - float2((20.0 * sin(_157.progress)) / 14.0);
    float _421 = fbm(param_6);
    float q4 = _421 + 2.0;
    q = ((((q + qb) - (0.4000000059604644775390625 * q2)) - (2.0 * q3)) + (0.60000002384185791015625 * q4)) / 3.7999999523162841796875;
    float2 param_7 = (((p + float2(q / 2.0)) + float2(_157.progress * speed.x)) - float2(p.x)) - float2(p.y);
    float _459 = fbm(param_7);
    float2 param_8 = (p + float2(q)) - float2(_157.progress * speed.y);
    float _472 = fbm(param_8);
    float2 r = float2(_459, _472);
    float2 param_9 = p + r;
    float _483 = fbm(param_9);
    float3 c = (mix(float3(0.5, 0.0, 0.100000001490116119384765625), float3(0.89999997615814208984375, 0.100000001490116119384765625, 0.0), float3(_483)) + mix(float3(0.20000000298023223876953125, 0.100000001490116119384765625, 0.699999988079071044921875), float3(1.0, 0.89999997615814208984375, 0.100000001490116119384765625), float3(r.x))) - mix(float3(0.100000001490116119384765625), float3(0.89999997615814208984375), float3(r.y));
    float3 color = (float3(1.0) / powr(c + float3(1.61000001430511474609375), float3(4.0))) * cos(shift * _157.refScreen.y);
    color = float3(1.0, 0.20000000298023223876953125, 0.0500000007450580596923828125) / float3(powr(((r.y + r.y) * fast::max(0.0, p.y)) + 0.100000001490116119384765625, 4.0));
    color += ((((float4(0.0, 0.0, 0.0, ((uv * 0.60000002384185791015625) + float2(0.5, 0.100000001490116119384765625)).x).xyz * 0.00999999977648258209228515625) * powr((r.y + r.y) * 0.64999997615814208984375, 5.0)) + float3(0.054999999701976776123046875)) * mix(float3(0.89999997615814208984375, 0.4000000059604644775390625, 0.300000011920928955078125), float3(0.699999988079071044921875, 0.5, 0.20000000298023223876953125), float3(uv.y)));
    color /= (float3(1.0) + fast::max(float3(0.0), color));
    float4 result = float4(color.x, color.y, color.z, 1.0);
    float luminance = dot(result.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 gradmap = mix(_157.color1, _157.color2, float4(luminance)) * result.w;
    float4 factorx = mix(result, gradmap, float4(_157.alphab));
    float4 factor = mix(texColorX, factorx, float4(_157.alpha));
    float4 resultfinal;
    if (_157.blendMode == 0)
    {
        resultfinal = (factor * _157.bright) * texColor.w;
    }
    else
    {
        if (_157.blendMode == 1)
        {
            factor *= _157.bright;
            float4 c_1 = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c_1.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_157.blendMode == 2)
            {
                factor *= _157.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = resultfinal;
}

fragment refAM35_eefe0850cb533_out refAM35_eefe0850cb533(constant ReferenceUniformseefe0850cb533& _157 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eefe0850cb533_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _157, referenceColor);
    bool _703 = any(isnan(referenceColor));
    bool _710;
    if (!_703)
    {
        _710 = any(isinf(referenceColor));
    }
    else
    {
        _710 = _703;
    }
    if (_710)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _723 = referenceColor;
    float3 _729 = fast::clamp(_723.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _729.x;
    referenceColor.y = _729.y;
    referenceColor.z = _729.z;
    out.finalColor = referenceColor;
    return out;
}

