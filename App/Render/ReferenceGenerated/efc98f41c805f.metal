// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/spill-cleaner.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsefc98f41c805f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
};

struct refAM35_efc98f41c805f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 sampleTex(thread const float2& uv, constant ReferenceUniformsefc98f41c805f& _80, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr)
{
    if (as_type<int>(_80.refComposition.z) == 1)
    {
        float2 param = uv;
        return texture2DCv(refBuffer1, refBuffer1Smplr, param);
    }
    else
    {
        float2 param_1 = uv;
        return texture2DCv(refBuffer2, refBuffer2Smplr, param_1);
    }
}

static inline __attribute__((always_inline))
float4 xstreak(constant ReferenceUniformsefc98f41c805f& _80, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr, thread float4& gl_FragCoord)
{
    float texelSize = 1.0 / _80.refScreen.x;
    float dist = _80.strength * 0.0500000007450580596923828125;
    int nSamples = int(fast::clamp(dist / texelSize, 1.0099999904632568359375, 100.01000213623046875));
    float4 c = float4(0.0);
    for (int i = 1; i < nSamples; i++)
    {
        float offset = dist * ((float(i) / float(nSamples - 1)) - 0.5);
        float2 sampleCoord = (gl_FragCoord.xy / _80.refScreen.xy) + float2(offset, 0.0);
        float2 param = sampleCoord;
        float4 tc = sampleTex(param, _80, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr);
        if (offset < 0.0)
        {
            c = (c * (1.0 - tc.w)) + tc;
        }
        else
        {
            c = (tc * (1.0 - c.w)) + c;
        }
    }
    return c;
}

static inline __attribute__((always_inline))
float4 ystreak(constant ReferenceUniformsefc98f41c805f& _80, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr, thread float4& gl_FragCoord)
{
    float texelSize = 1.0 / _80.refScreen.y;
    float dist = _80.strength * 0.0500000007450580596923828125;
    int nSamples = int(fast::clamp(dist / texelSize, 1.0099999904632568359375, 100.01000213623046875));
    float4 c = float4(0.0);
    for (int i = 1; i < nSamples; i++)
    {
        float offset = dist * ((float(i) / float(nSamples - 1)) - 0.5);
        float2 sampleCoord = (gl_FragCoord.xy / _80.refScreen.xy) + float2(0.0, offset);
        float2 param = sampleCoord;
        float4 tc = sampleTex(param, _80, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr);
        if (offset < 0.0)
        {
            c = (c * (1.0 - tc.w)) + tc;
        }
        else
        {
            c = (tc * (1.0 - c.w)) + c;
        }
    }
    return c;
}

static inline __attribute__((always_inline))
float4 composite(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
float saturate0(thread const float& v)
{
    return fast::clamp(v, 0.0, 1.0);
}

static inline __attribute__((always_inline))
void referenceMain(thread float3x3& rgb2yuv, thread float3x3& yuv2rgb, constant ReferenceUniformsefc98f41c805f& _80, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refBuffer3, sampler refBuffer3Smplr)
{
    bool _276 = as_type<int>(_80.refComposition.z) == 1;
    bool _284;
    if (!_276)
    {
        _284 = as_type<int>(_80.refComposition.z) == 2;
    }
    else
    {
        _284 = _276;
    }
    if (_284)
    {
        float4 c1 = xstreak(_80, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr, gl_FragCoord);
        float4 c2 = ystreak(_80, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr, gl_FragCoord);
        float2 param = gl_FragCoord.xy / _80.refScreen.xy;
        float4 blur = texture2DCv(refBuffer1, refBuffer1Smplr, param);
        float4 param_1 = c1;
        float4 param_2 = c2;
        float4 param_3 = composite(param_1, param_2);
        float4 param_4 = blur;
        referenceColor = composite(param_3, param_4);
    }
    else
    {
        float2 param_5 = gl_FragCoord.xy / _80.refScreen.xy;
        float4 base = texture2DCv(refInput, refInputSmplr, param_5);
        float2 param_6 = gl_FragCoord.xy / _80.refScreen.xy;
        float4 blur_1 = texture2DCv(refBuffer1, refBuffer1Smplr, param_6);
        float2 param_7 = gl_FragCoord.xy / _80.refScreen.xy;
        float4 streak = texture2DCv(refBuffer3, refBuffer3Smplr, param_7);
        float param_8 = (1.0 - blur_1.w) * 2.0;
        float4 c = (streak * saturate0(param_8)) * base.w;
        float3 baseYUV = (base.xyz / float3(fast::max(9.9999997473787516355514526367188e-06, base.w))) * rgb2yuv;
        float3 cYUV = (c.xyz / float3(fast::max(9.9999997473787516355514526367188e-06, c.w))) * rgb2yuv;
        cYUV.x = baseYUV.x;
        c = float4(cYUV * yuv2rgb, 1.0) * c.w;
        float4 param_9 = base;
        float4 param_10 = c;
        referenceColor = composite(param_9, param_10);
    }
}

fragment refAM35_efc98f41c805f_out refAM35_efc98f41c805f(constant ReferenceUniformsefc98f41c805f& _80 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refBuffer2 [[texture(2)]], texture2d<float> refBuffer3 [[texture(3)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refBuffer2Smplr [[sampler(2)]], sampler refBuffer3Smplr [[sampler(3)]], float4 gl_FragCoord [[position]])
{
    refAM35_efc98f41c805f_out out = {};
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float4 referenceColor = float4(0.0);
    referenceMain(rgb2yuv, yuv2rgb, _80, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr, gl_FragCoord, referenceColor, refInput, refInputSmplr, refBuffer3, refBuffer3Smplr);
    bool _398 = any(isnan(referenceColor));
    bool _405;
    if (!_398)
    {
        _405 = any(isinf(referenceColor));
    }
    else
    {
        _405 = _398;
    }
    if (_405)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _418 = referenceColor;
    float3 _424 = fast::clamp(_418.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _424.x;
    referenceColor.y = _424.y;
    referenceColor.z = _424.z;
    out.finalColor = referenceColor;
    return out;
}

