// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxglitchpixel.xml
// Original source comments and attribution:
/////////////////////////
// vec4 texColor = texture2DCv(inputImg.texture,sampleCoord);
/////////////////////////
// vec2 uvv = sampleCoord;
// hp += vec2((0.0+position.x), (0.0+position.y))*vec2(-1.,1.)/500.;
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

struct ReferenceUniformse30b77c55f65f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint repeat;
    char _m6_pad[12];
    float progressa;
    char _m7_pad[12];
    float progress;
    char _m8_pad[12];
    float scale;
    char _m9_pad[12];
    float angle;
    char _m10_pad[12];
    float progressr;
    char _m11_pad[12];
    float progressg;
    char _m12_pad[12];
    float progressb;
};

struct refAM35_e30b77c55f65f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float hash(thread const float2& p)
{
    float h = dot(p, float2(127.09999847412109375, 311.70001220703125));
    return (-1.0) + (2.0 * fract(sin(h) * 43758.546875));
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i + float2(0.0);
    float2 param_1 = i + float2(1.0, 0.0);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 param_3 = i + float2(1.0);
    return mix(mix(hash(param), hash(param_1), u.x), mix(hash(param_2), hash(param_3), u.x), u.y);
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float _noise(thread float2& p, thread const int& oct)
{
    float2x2 m = float2x2(float2(1.60000002384185791015625, 1.2000000476837158203125), float2(-1.2000000476837158203125, 1.60000002384185791015625));
    float f = 0.0;
    for (int i = 1; i < 3; i++)
    {
        float mul = 1.0 / powr(2.0, float(i));
        float2 param = p;
        f += (mul * _noise(param));
        p = m * p;
    }
    return f;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse30b77c55f65f& _195, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _195.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 uvv = gl_FragCoord.xy / _195.refScreen.xy;
    float _217;
    if (_195.repeat != 0u)
    {
        _217 = powr((cos((_195.progressa + 7.5) * 0.5) * 1.2000000476837158203125) + 1.0, 1.2000000476837158203125);
    }
    else
    {
        _217 = _195.progressa;
    }
    float glitch = _217;
    float2 param_1 = float2(0.5);
    if ((_noise(param_1) * glitch) > 0.62000000476837158203125)
    {
        float2 param_2 = float2(4.0, 0.0);
        uvv.y = mod(uvv.y + _noise(param_2), 1.2000000476837158203125);
    }
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _195.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _195.refScreen.xy).y) * _195.refScreen.xy) - float2(_195.refLayer.x + (_195.refLayer.z * 0.5), (_195.refScreen.y - _195.refLayer.y) - (_195.refLayer.w * 0.5))) / _195.refLayer.zw;
    syamjaidtz.y *= (_195.refLayer.w / _195.refLayer.z);
    float2 hp = float2(_195.progress, uvv.y);
    hp /= float2(_195.scale);
    float param_3 = (0.0 + _195.angle) * 0.01745329983532428741455078125;
    hp *= rot2m(param_3);
    float2 param_4 = (hp * 7.0) + float2(_195.progress * 10.0);
    int param_5 = 3;
    float _341 = _noise(param_4, param_5);
    float2 param_6 = hp + float2(0.89999997615814208984375);
    float nh = _341 * (_noise(param_6) * 0.800000011920928955078125);
    float2 param_7 = (hp * 100.0) + float2(100.0);
    int param_8 = 3;
    float _358 = _noise(param_7, param_8);
    nh += (_358 * 0.0199999995529651641845703125);
    float rnd = 0.0;
    if (glitch > 0.0)
    {
        float2 param_9 = uvv;
        rnd = hash(param_9);
        if (glitch < 1.0)
        {
            rnd *= glitch;
        }
    }
    nh *= (glitch + rnd);
    float2 param_10 = uvv + (float2(nh, _195.progressr) * nh);
    float r = texture2DCv(refInput, refInputSmplr, param_10).x;
    float2 param_11 = uvv + (float2(nh - _195.progressg, 0.0) * nh);
    float g = texture2DCv(refInput, refInputSmplr, param_11).y;
    float2 param_12 = uvv + (float2(nh, _195.progressb) * nh);
    float b = texture2DCv(refInput, refInputSmplr, param_12).z;
    float3 col = float3(r, g, b);
    float4 result = float4(col, 1.0);
    float4 targetLuma = result;
    float luma = dot(targetLuma.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float lowThresholdB = 0.061999998986721038818359375;
    float lowThresholdA = lowThresholdB - 0.0500000007450580596923828125;
    float highThresholdA = 1.00100004673004150390625;
    float highThresholdB = highThresholdA + 0.0500000007450580596923828125;
    float lowBlend = smoothstep(lowThresholdA, lowThresholdB, luma);
    float highBlend = 1.0 - smoothstep(highThresholdA, highThresholdB, luma);
    float lumafx = fast::min(lowBlend, highBlend);
    float4 fxLuma = targetLuma * lumafx;
    float4 param_13 = texColor;
    float4 param_14 = fxLuma;
    referenceColor = newLayer(param_13, param_14) * texColor.w;
}

fragment refAM35_e30b77c55f65f_out refAM35_e30b77c55f65f(constant ReferenceUniformse30b77c55f65f& _195 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e30b77c55f65f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _195, referenceColor);
    bool _491 = any(isnan(referenceColor));
    bool _498;
    if (!_491)
    {
        _498 = any(isinf(referenceColor));
    }
    else
    {
        _498 = _491;
    }
    if (_498)
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

