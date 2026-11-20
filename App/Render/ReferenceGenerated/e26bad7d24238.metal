// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxplasmawave.xml
// Original source comments and attribution:
/////////////////////////
/* This work is protected under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License
       * more information canbe found at:
       * https://creativecommons.org/licenses/by-nc-sa/3.0/deed.en_US
       */
// const vec4 lineColor = vec4(0.25, 0.5, 1.0, 1.0);
// const int AMOUNT = 16;
// const vec4 bgColors = vec4(0., 0., 0., 1);
// const vec4 bgColors = vec4(lineColor - vec4(0., 0., 0., 1.));
// (
// lineColor * 0.5,
// lineColor - vec4(0., 0., 0., 1.)
// );
// probably can optimize w/ noise, but currently using fourier transform
/////////////////////////
// if (adaptive) { 
// syamjaidtz = acScreenNorm; 
// }
// else { 
// }
/////////////////////////
// if(progressa <= 0.0) { gl_FragColor = texture2DCv(inputImg.texture,acScreenNorm); }
// else if(progressa >= 0.0001) { 
// vec2 space = (fragCoord - iResolution.xy / 2.0) / iResolution.x * 2.0 * scale;
// fun with nonlinear transformations! (wind / turbulence)
// fragColor = mix(color2, color3, uv.x);
// debug grid:
//fragColor = mix(fragColor, gridColor, drawGrid(space));
// const vec3 luminanceWeighting = vec3(0.2126, 0.7152, 0.0722);
// vec4 gradmap;
// float luminance = dot(fragColor.rgb, luminanceWeighting);
// gradmap = mix(color1,color2,luminance)*fragColor.a;
// vec4 factorx = mix(fragColor,gradmap,alphab);
// normal
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

struct ReferenceUniformse26bad7d24238
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float AMOUNT;
    char _m7_pad[8];
    float2 position;
    char _m8_pad[8];
    float progressa;
    char _m9_pad[12];
    float scalex;
    char _m10_pad[12];
    float bright;
    char _m11_pad[12];
    float alpha;
    char _m12_pad[12];
    float angle;
    char _m13_pad[12];
    int blendMode;
};

struct refAM35_e26bad7d24238_out
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
float random(thread const float& t)
{
    return ((cos(t) + cos((t * 1.2999999523162841796875) + 1.2999999523162841796875)) + cos((t * 1.39999997615814208984375) + 1.39999997615814208984375)) / 3.0;
}

static inline __attribute__((always_inline))
float getPlasmaY(thread const float& x, thread const float& horizontalFade, thread const float& offset, constant ReferenceUniformse26bad7d24238& _84)
{
    float param = (x * 0.20000000298023223876953125) + (_84.progressa * 0.20000000298023223876953125);
    return ((random(param) * horizontalFade) * 1.0) + offset;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse26bad7d24238& _84, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _84.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _84.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _84.refScreen.xy).y) * _84.refScreen.xy) - float2(_84.refLayer.x + (_84.refLayer.z * 0.5), (_84.refScreen.y - _84.refLayer.y) - (_84.refLayer.w * 0.5))) / _84.refLayer.zw;
    syamjaidtz.y *= (_84.refLayer.w / _84.refLayer.z);
    syamjaidtz /= float2(_84.scalex);
    float param_1 = ((-175.0) + _84.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((float2(0.0 + _84.position.x, 0.0 + _84.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 uv = gl_FragCoord.xy / _84.refScreen.xy;
    float2 space = syamjaidtz;
    float horizontalFade = 1.0 - ((cos(uv.x * 6.280000209808349609375) * 0.5) + 0.5);
    float verticalFade = 1.0 - ((cos(uv.y * 6.280000209808349609375) * 0.5) + 0.5);
    float param_2 = (space.x * 0.5) + (_84.progressa * 0.039999999105930328369140625);
    space.y += ((random(param_2) * 1.0) * (0.5 + horizontalFade));
    float param_3 = ((space.y * 0.5) + (_84.progressa * 0.039999999105930328369140625)) + 2.0;
    space.x += ((random(param_3) * 1.0) * horizontalFade);
    float4 lines = float4(0.0);
    for (float l = 0.0; l < _84.AMOUNT; l += 1.0)
    {
        float normalizedLineIndex = l / _84.AMOUNT;
        float offsetTime = _84.progressa * 0.2660000026226043701171875;
        float offsetPosition = l + (space.x * 0.5);
        float param_4 = offsetPosition + offsetTime;
        float rand = (random(param_4) * 0.5) + 0.5;
        float halfWidth = mix(0.0199999995529651641845703125, 0.5, rand * horizontalFade) / 2.0;
        float param_5 = offsetPosition + (offsetTime * (1.0 + normalizedLineIndex));
        float offset = random(param_5) * mix(0.60000002384185791015625, 2.0, horizontalFade);
        float param_6 = space.x;
        float param_7 = horizontalFade;
        float param_8 = offset;
        float linePosition = getPlasmaY(param_6, param_7, param_8, _84);
        float line = (smoothstep(halfWidth, 0.0, abs(linePosition - space.y)) / 2.0) + smoothstep((halfWidth * 0.1500000059604644775390625) + 0.014999999664723873138427734375, halfWidth * 0.1500000059604644775390625, abs(linePosition - space.y));
        float circleX = mod(l + (_84.progressa * 0.20000000298023223876953125), 25.0) - 12.0;
        float param_9 = circleX;
        float param_10 = horizontalFade;
        float param_11 = offset;
        float2 circlePosition = float2(circleX, getPlasmaY(param_9, param_10, param_11, _84));
        float circle = smoothstep(0.02500000037252902984619140625, 0.00999999977648258209228515625, length(space - circlePosition)) * 4.0;
        line += circle;
        lines += ((float4(_84.color1.xyz, 1.0) * line) * rand);
    }
    float4 fragColor = float4(0.0, 0.0, 0.0, 1.0);
    fragColor *= verticalFade;
    fragColor.w = 1.0;
    fragColor += lines;
    float4 factor = mix(texColorX, fragColor, float4(_84.alpha));
    float4 resultfinal;
    if (_84.blendMode == 0)
    {
        resultfinal = (factor * _84.bright) * texColor.w;
    }
    else
    {
        if (_84.blendMode == 1)
        {
            factor *= _84.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_84.blendMode == 2)
            {
                factor *= _84.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = resultfinal;
}

fragment refAM35_e26bad7d24238_out refAM35_e26bad7d24238(constant ReferenceUniformse26bad7d24238& _84 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e26bad7d24238_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_84, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _519 = any(isnan(referenceColor));
    bool _526;
    if (!_519)
    {
        _526 = any(isinf(referenceColor));
    }
    else
    {
        _526 = _519;
    }
    if (_526)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    out.finalColor = referenceColor;
    return out;
}

