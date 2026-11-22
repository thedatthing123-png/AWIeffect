// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxglowribbon.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
// vec2 uvTrue = sampleCoord;
// vec2 uv = -1.0 + 2.0 * uvTrue;
// lineIntensity = 0.4 + squared(1.6 * abs(mod(uvTrue.x + i / 1.3 + progressb + 2.0) - 1.0)) + (offset * vec2(-1.,1.))/1000.0;
//
// yuv = yuv * huemat;
// normal
// multiply
// screen
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

struct ReferenceUniformse11a7cbe63246
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 colorkey;
    float AMOUNT;
    char _m7_pad[12];
    float progressa;
    char _m8_pad[12];
    float progressb;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    float luminance;
    char _m11_pad[8];
    float2 position;
    char _m12_pad[8];
    float2 stretch;
    char _m13_pad[8];
    float angle;
    char _m14_pad[12];
    float alpha;
    char _m15_pad[12];
    float hue;
    char _m16_pad[12];
    int blendMode;
};

struct refAM35_e11a7cbe63246_out
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
float squared(thread const float& value)
{
    return value * value;
}

static inline __attribute__((always_inline))
float getAmp(thread const float& frequency, texture2d<float> refImage1, sampler refImage1Smplr)
{
    float2 param = float2(frequency / 512.0, 0.0);
    return texture2DCv(refImage1, refImage1Smplr, param).x;
}

static inline __attribute__((always_inline))
float getWeight(thread const float& f, texture2d<float> refImage1, sampler refImage1Smplr)
{
    float param = f - 2.0;
    float param_1 = f - 1.0;
    float param_2 = f + 2.0;
    float param_3 = f + 1.0;
    float param_4 = f;
    return ((((getAmp(param, refImage1, refImage1Smplr) + getAmp(param_1, refImage1, refImage1Smplr)) + getAmp(param_2, refImage1, refImage1Smplr)) + getAmp(param_3, refImage1, refImage1Smplr)) + getAmp(param_4, refImage1, refImage1Smplr)) / 5.0;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refImage1, sampler refImage1Smplr, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse11a7cbe63246& _115, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _115.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float rad = _115.hue * 0.01745329983532428741455078125;
    float3x3 huemat = float3x3(float3(1.0, 0.0, 0.0), float3(0.0, cos(rad), sin(rad)), float3(0.0, -sin(rad), cos(rad)));
    float2 uvTrue = ((float2((gl_FragCoord.xy / _115.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _115.refScreen.xy).y) * _115.refScreen.xy) - float2(_115.refLayer.x + (_115.refLayer.z * 0.5), (_115.refScreen.y - _115.refLayer.y) - (_115.refLayer.w * 0.5))) / _115.refLayer.zw;
    uvTrue.y *= (_115.refLayer.w / _115.refLayer.z);
    float2 uv = uvTrue;
    uv /= float2(_115.scale);
    uv += ((_115.position * float2(-1.0, 1.0)) / float2(500.0));
    uv.x *= (_115.refLayer.z / _115.refLayer.w);
    float param_1 = _115.angle * 0.01745329983532428741455078125;
    uv *= rot2m(param_1);
    float2 scaleVec = float2(_115.scale * _115.stretch.x, _115.scale * _115.stretch.y);
    uv /= scaleVec;
    float3 color = float3(0.0);
    for (float i = 0.0; i < _115.AMOUNT; i += 1.0)
    {
        uv.y += (0.20000000298023223876953125 * sin((uv.x + (i / 7.0)) - (_115.progressa * 0.60000002384185791015625)));
        float param_2 = i;
        float param_3 = squared(param_2) * 20.0;
        float2 param_4 = float2(uvTrue.x, 1.0);
        float Y = uv.y + (getWeight(param_3, refImage1, refImage1Smplr) * (texture2DCv(refImage1, refImage1Smplr, param_4).x - 0.5));
        float param_5 = 1.60000002384185791015625 * abs(mod((uvTrue.x + (i / 1.2999999523162841796875)) + _115.progressb, 2.0) - 1.0);
        float lineIntensity = 0.4000000059604644775390625 + squared(param_5);
        float glowWidth = abs(lineIntensity / (150.0 * Y));
        color += float3(glowWidth * (_115.luminance + 0.909297406673431396484375), glowWidth * (_115.luminance - 0.0), glowWidth * (_115.luminance - 1.0));
    }
    float4 result = float4(color, 1.0);
    result *= 1.0;
    float3 rgb = result.xyz;
    float a = result.w;
    float3 yuv = rgb * rgb2yuv;
    float origSat = fast::min(1.0, length(yuv.yz) * 2.5);
    float2 satUV = yuv.yz * 1.0;
    float3 _412 = yuv;
    float2 _416 = mix(satUV, _412.yz, float2(origSat));
    yuv.y = _416.x;
    yuv.z = _416.y;
    float3 _421 = yuv;
    float2 _423 = _421.yz * 0.0;
    yuv.y = _423.x;
    yuv.z = _423.y;
    rgb = yuv * yuv2rgb;
    float4 huecolor = float4(rgb, a);
    float4 _442 = huecolor;
    float3 _444 = _442.xyz * _115.colorkey.xyz;
    huecolor.x = _444.x;
    huecolor.y = _444.y;
    huecolor.z = _444.z;
    float4 _452 = huecolor;
    float3 _454 = _452.xyz * huemat;
    huecolor.x = _454.x;
    huecolor.y = _454.y;
    huecolor.z = _454.z;
    float4 factor = mix(texColor, huecolor, float4(_115.alpha));
    float4 resultfinal;
    if (_115.blendMode == 0)
    {
        factor *= texColor.w;
        resultfinal = factor + (texColor * (1.0 - factor.w));
    }
    else
    {
        if (_115.blendMode == 1)
        {
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_115.blendMode == 2)
            {
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = resultfinal;
}

fragment refAM35_e11a7cbe63246_out refAM35_e11a7cbe63246(constant ReferenceUniformse11a7cbe63246& _115 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e11a7cbe63246_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refImage1, refImage1Smplr, refInput, refInputSmplr, gl_FragCoord, _115, referenceColor);
    bool _555 = any(isnan(referenceColor));
    bool _562;
    if (!_555)
    {
        _562 = any(isinf(referenceColor));
    }
    else
    {
        _562 = _555;
    }
    if (_562)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _575 = referenceColor;
    float3 _581 = fast::clamp(_575.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _581.x;
    referenceColor.y = _581.y;
    referenceColor.z = _581.z;
    out.finalColor = referenceColor;
    return out;
}

