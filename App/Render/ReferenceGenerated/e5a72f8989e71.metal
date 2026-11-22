// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxvhsnoise.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
// vec2 syamjaidtz;
// syamjaidtz = acScreenNorm; 
// syamjaidtz /= scale;
// syamjaidtz *= rot2m((0.0+angle)*0.0174533);
// float cx = 0.5 + acLayerPivot.x/acLayerSize.x;
// float cy = 0.5 - acLayerPivot.y/acLayerSize.y;
/////////////////////////
// vec2 uv = fragCoord.xy / iResolution.xy;
// vec4 color  = texture2DCv(inputImg.texture,uv);
// if(abs(2.*fragCoord.y-acScreenSize.y)>acScreenSize.y-50.*noise(5.*progress+(uv.y>.5?0.:10.)))
// normal
// resultfinal = (newLayer(texColor, factor) * bright) * texColor.a;
// multiply
// screen
// }
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

struct ReferenceUniformse5a72f8989e71
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progress;
    char _m6_pad[12];
    float scale;
    char _m7_pad[8];
    float2 position;
    char _m8_pad[8];
    float2 stretch;
    char _m9_pad[8];
    float bright;
    char _m10_pad[12];
    float alpha;
    float4 color1;
    float4 color2;
    int blendMode;
};

struct refAM35_e5a72f8989e71_out
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
float hash11(thread const float& a)
{
    return fract(53.15599822998046875 * sin(a * 45.450000762939453125)) - 0.5;
}

static inline __attribute__((always_inline))
float dispnoise(thread const float& a)
{
    float param = floor(a);
    float a1 = hash11(param);
    float param_1 = ceil(a);
    float a2 = hash11(param_1);
    return 0.02999999932944774627685546875 * mix(a1, a2, powr(fract(a), 8.0));
}

static inline __attribute__((always_inline))
float4 grade(thread float4& color)
{
    color = powr(color, float4(2.2000000476837158203125));
    color *= float4(1.2999999523162841796875, 0.699999988079071044921875, 0.88999998569488525390625, 1.0);
    color = powr(color, float4(0.4000000059604644775390625));
    return color * 1.2999999523162841796875;
}

static inline __attribute__((always_inline))
float hash21(thread const float2& a, constant ReferenceUniformse5a72f8989e71& _117)
{
    return fract(sin(dot(a, float2(12.98980045318603515625, 78.233001708984375)) + _117.progress) * 43758.546875);
}

static inline __attribute__((always_inline))
float perlin(thread float2& a, constant ReferenceUniformse5a72f8989e71& _117)
{
    a *= float2(100.0, 500.0);
    float2 param = floor(a);
    float a1 = hash21(param, _117);
    float2 param_1 = floor(a) + float2(1.0, 0.0);
    float a2 = hash21(param_1, _117);
    float2 param_2 = floor(a) + float2(0.0, 1.0);
    float a3 = hash21(param_2, _117);
    float2 param_3 = ceil(a);
    float a4 = hash21(param_3, _117);
    return powr(mix(mix(a1, a2, fract(a.x)), mix(a3, a4, fract(a.x)), fract(a.y)), 2.0);
}

static inline __attribute__((always_inline))
float _noise(thread const float& a)
{
    float param = floor(a);
    float a1 = hash11(param);
    float param_1 = ceil(a);
    float a2 = hash11(param_1);
    return mix(a1 + 0.5, a2 + 0.5, powr(fract(a), 50.0));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse5a72f8989e71& _117, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _117.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param_1);
    float maxF = fast::max(_117.refScreen.x, _117.refScreen.y);
    float2 texelSize = float2(1.0) / float2(maxF);
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _117.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _117.refScreen.xy).y) * _117.refScreen.xy) - float2(_117.refLayer.x + (_117.refLayer.z * 0.5), (_117.refScreen.y - _117.refLayer.y) - (_117.refLayer.w * 0.5))) / _117.refLayer.zw;
    syamjaidtz.y *= (_117.refLayer.w / _117.refLayer.z);
    float2 scaleVec = float2(_117.scale * _117.stretch.x, _117.scale * _117.stretch.y);
    syamjaidtz /= scaleVec;
    syamjaidtz += ((float2((-375.0) + _117.position.x, (_117.progress * 50.0) + _117.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 uv = syamjaidtz;
    float param_2 = (0.699999988079071044921875 * uv.y) + (mod(_117.progress, 200.0) * 0.20000000298023223876953125);
    float disp = dispnoise(param_2);
    uv.x += disp;
    float param_3 = floor(_117.progress * 4.0) / 4.0;
    if (hash11(param_3) > 0.4699999988079071044921875)
    {
        float param_4 = floor(_117.progress * 8.0) / 4.0;
        uv.y += (0.5 * hash11(param_4));
    }
    uv = fract(uv);
    float4 color = float4(0.0, 0.0, 0.0, 1.0);
    float4 param_5 = color;
    float4 _379 = grade(param_5);
    color = _379;
    float param_6 = uv.y + (floor((_117.progress + uv.y) * 16.0) / 16.0);
    if (hash11(param_6) > 0.4970000088214874267578125)
    {
        float param_7 = floor(100.0 * (uv.x - _117.progress));
        color += float4(hash11(param_7) + 0.5);
    }
    float2 param_8 = uv * 0.300000011920928955078125;
    float _422 = perlin(param_8, _117);
    color = mix(color, float4(0.300000011920928955078125), float4(fast::max(0.0, (sin(uv.y * 20.0) * _422) * 0.5)));
    float4 fragColor = color;
    float param_9 = (5.0 * _117.progress) + ((uv.y > 0.5) ? 0.0 : 10.0);
    if (abs(syamjaidtz.y) > (_117.refScreen.y - (50.0 * _noise(param_9))))
    {
        float2 param_10 = uv;
        float _454 = perlin(param_10, _117);
        fragColor = float4(_454 + 0.5);
    }
    float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 gradmap = mix(_117.color1, _117.color2, float4(luminance)) * fragColor.w;
    float4 factor = mix(texColorX, gradmap, float4(1.0));
    float4 resultfinal;
    if (_117.blendMode == 0)
    {
        resultfinal = (factor * _117.bright) * texColor.w;
    }
    else
    {
        if (_117.blendMode == 1)
        {
            factor *= _117.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_117.blendMode == 2)
            {
                factor *= _117.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_117.alpha));
}

fragment refAM35_e5a72f8989e71_out refAM35_e5a72f8989e71(constant ReferenceUniformse5a72f8989e71& _117 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e5a72f8989e71_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_117, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _581 = any(isnan(referenceColor));
    bool _588;
    if (!_581)
    {
        _588 = any(isinf(referenceColor));
    }
    else
    {
        _588 = _581;
    }
    if (_588)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _601 = referenceColor;
    float3 _607 = fast::clamp(_601.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _607.x;
    referenceColor.y = _607.y;
    referenceColor.z = _607.z;
    out.finalColor = referenceColor;
    return out;
}

