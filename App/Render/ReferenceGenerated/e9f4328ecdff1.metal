// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/energybeam.xml
// Original source comments and attribution:
// 2D Random
// 2D Noise based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
// Four corners in 2D of a tile
// Interpolation
// Mix 4 coorners percentages
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9f4328ecdff1
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 start;
    char _m6_pad[8];
    float2 end;
    float4 color1;
    float4 color2;
    float spread;
    char _m10_pad[12];
    float alpha;
    char _m11_pad[12];
    float glowAlpha;
    char _m12_pad[12];
    float haloAlpha;
    char _m13_pad[12];
    float haloSpread;
    float4 color3;
    float clip;
    char _m16_pad[12];
    float progress;
    char _m17_pad[12];
    float blur;
    char _m18_pad[12];
    int blendMode;
    char _m19_pad[12];
    float fstr;
    char _m20_pad[12];
    float freq;
    char _m21_pad[12];
    float vstr;
    char _m22_pad[12];
    float vfreq;
    char _m23_pad[12];
    float vphase;
    char _m24_pad[12];
    float randness;
    char _m25_pad[12];
    float evolution;
};

struct refAM35_e9f4328ecdff1_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float saturate0(thread const float& v)
{
    return fast::clamp(v, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float sdSegment(thread const float2& p, thread const float2& a, thread const float2& b)
{
    float2 pa = p - a;
    float2 ba = b - a;
    float h = fast::clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - (ba * h));
}

static inline __attribute__((always_inline))
float random(thread const float2& st)
{
    return fract(sin(dot(st, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& st)
{
    float2 i = floor(st);
    float2 f = fract(st);
    float2 param = i;
    float a = random(param);
    float2 param_1 = i + float2(1.0, 0.0);
    float b = random(param_1);
    float2 param_2 = i + float2(0.0, 1.0);
    float c = random(param_2);
    float2 param_3 = i + float2(1.0);
    float d = random(param_3);
    float2 u = smoothstep(float2(0.0), float2(1.0), f);
    return (mix(a, b, u.x) + (((c - a) * u.y) * (1.0 - u.x))) + (((d - b) * u.x) * u.y);
}

static inline __attribute__((always_inline))
float4 colorForPhase(thread const float2& st, thread const float& phase, thread const float2& a, thread const float2& v, constant ReferenceUniformse9f4328ecdff1& _175)
{
    float low = (0.5 + phase) - (_175.clip / 2.0);
    float high = low + _175.clip;
    float param = low;
    float2 aa = a + (v * saturate0(param));
    float param_1 = high;
    float2 bb = a + (v * saturate0(param_1));
    float dist = dot(st - a, v) / length(v);
    float2 param_2 = st;
    float2 param_3 = aa;
    float2 param_4 = bb;
    float p = fast::min(sdSegment(param_2, param_3, param_4), 0.5);
    float param_5 = 0.0 - high;
    p += saturate0(param_5);
    float param_6 = low - 1.0;
    p += saturate0(param_6);
    float variation = 1.0 + (sin(((dist * _175.vfreq) * 3.141590118408203125) + _175.vphase) * _175.vstr);
    if (_175.randness > 0.0)
    {
        float2 param_7 = float2(((dist * _175.vfreq) * 2.0) + _175.vphase, _175.evolution * 17.9559993743896484375);
        float v2 = 1.0 + (((_noise(param_7) - 0.5) * _175.vstr) * 2.0);
        variation = mix(variation, v2, _175.randness);
    }
    float falloff = fast::max(9.9999997473787516355514526367188e-05, 51.0 - _175.spread);
    float haloFalloff = fast::max(9.9999997473787516355514526367188e-05, 51.0 - _175.haloSpread);
    float h = (powr((1.0 - abs(powr(1.0 - p, haloFalloff) - 0.5)) * 0.5, 2.2320001125335693359375) * 2.5) * _175.haloAlpha;
    float sf = sin((_175.freq * _175.refScreen.z) * 3.141590118408203125);
    float ga = _175.glowAlpha * (1.0 + (sf * _175.fstr));
    float ca = 1.0 + ((sf * _175.fstr) * 0.5);
    float f2 = powr(falloff, 1.5);
    float4 color = float4(((powr(float3(powr(1.0 - fast::clamp(p * variation, 9.9999997473787516355514526367188e-05, 0.5), f2)), float3(1.0) / _175.color1.xyz) * ca) + (powr(float3(powr(1.0 - fast::clamp(p, 9.9999997473787516355514526367188e-05, 0.5), f2 / 5.0)), float3(1.0) / _175.color2.xyz) * ga)) + (_175.color3.xyz * h), 1.0);
    color *= _175.alpha;
    return fast::clamp(color, float4(0.0), float4(1.0));
}

static inline __attribute__((always_inline))
float4 saturate0(thread const float4& v)
{
    return fast::clamp(v, float4(0.0), float4(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse9f4328ecdff1& _175, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _175.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _175.refLayer.xy) / _175.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_175.refLayer.z / _175.refLayer.w);
    st.y *= (-1.0);
    float2 a = _175.start / float2(1000.0);
    float2 b = _175.end / float2(1000.0);
    float2 v = b - a;
    float toffs = (_175.progress - 0.5) * 2.0;
    float4 color;
    if (_175.blur <= 0.0)
    {
        float2 param_1 = st;
        float param_2 = toffs;
        float2 param_3 = a;
        float2 param_4 = v;
        color = colorForPhase(param_1, param_2, param_3, param_4, _175);
    }
    else
    {
        color = float4(0.0);
        int steps = 20;
        for (int i = 1; i <= steps; i++)
        {
            float d = (float(i) * _175.blur) * 0.00999999977648258209228515625;
            float2 param_5 = st;
            float param_6 = toffs + d;
            float2 param_7 = a;
            float2 param_8 = v;
            float4 param_9 = colorForPhase(param_5, param_6, param_7, param_8, _175);
            color += saturate0(param_9);
            float2 param_10 = st;
            float param_11 = toffs - d;
            float2 param_12 = a;
            float2 param_13 = v;
            float4 param_14 = colorForPhase(param_10, param_11, param_12, param_13, _175);
            color += saturate0(param_14);
        }
        color /= float4(float(steps) * 2.0);
    }
    float4 result;
    if (_175.blendMode == 0)
    {
        color *= texColor.w;
        result = color + (texColor * (1.0 - color.w));
    }
    else
    {
        if (_175.blendMode == 1)
        {
            float4 c = color + (float4(1.0) * (1.0 - color.w));
            result = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_175.blendMode == 2)
            {
                result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - color.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = result;
}

fragment refAM35_e9f4328ecdff1_out refAM35_e9f4328ecdff1(constant ReferenceUniformse9f4328ecdff1& _175 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9f4328ecdff1_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_175, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _637 = any(isnan(referenceColor));
    bool _644;
    if (!_637)
    {
        _644 = any(isinf(referenceColor));
    }
    else
    {
        _644 = _637;
    }
    if (_644)
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

