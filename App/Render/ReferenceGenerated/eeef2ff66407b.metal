// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/colorbalance.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseeef2ff66407b
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float crLow;
    char _m6_pad[12];
    float mgLow;
    char _m7_pad[12];
    float ybLow;
    char _m8_pad[12];
    float crMid;
    char _m9_pad[12];
    float mgMid;
    char _m10_pad[12];
    float ybMid;
    char _m11_pad[12];
    float crHigh;
    char _m12_pad[12];
    float mgHigh;
    char _m13_pad[12];
    float ybHigh;
    char _m14_pad[12];
    uint fixLum;
};

struct refAM35_eeef2ff66407b_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseeef2ff66407b& _64, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float2 param = gl_FragCoord.xy / _64.refScreen.xy;
    float4 baseColor = texture2DCv(refInput, refInputSmplr, param);
    float3 yuv = baseColor.xyz * rgb2yuv;
    float low = 1.0 - smoothstep(0.22200000286102294921875, 0.4440000057220458984375, yuv.x);
    float midLow = smoothstep(0.22200000286102294921875, 0.4440000057220458984375, yuv.x) * step(yuv.x, 0.555000007152557373046875);
    float midHigh = ((1.0 - smoothstep(0.555000007152557373046875, 0.777000010013580322265625, yuv.x)) * step(0.555000007152557373046875, yuv.x)) * step(yuv.x, 0.777000010013580322265625);
    float high = smoothstep(0.555000007152557373046875, 0.777000010013580322265625, yuv.x);
    float3 ref_filter = ((float3(_64.crLow, _64.mgLow, _64.ybLow) * low) + (float3(_64.crMid, _64.mgMid, _64.ybMid) * (midLow + midHigh))) + (float3(_64.crHigh, _64.mgHigh, _64.ybHigh) * high);
    ref_filter = fast::max(fast::min(ref_filter, float3(100.0)), float3(-100.0));
    float3 conv = (ref_filter + float3(100.0)) / float3(100.0);
    float3 converted = baseColor.xyz * conv;
    float3 convYuv = converted * rgb2yuv;
    if (_64.fixLum != 0u)
    {
        convYuv.x = yuv.x;
    }
    float4 outColor = float4(convYuv * yuv2rgb, baseColor.w);
    referenceColor = outColor;
}

fragment refAM35_eeef2ff66407b_out refAM35_eeef2ff66407b(constant ReferenceUniformseeef2ff66407b& _64 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eeef2ff66407b_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _64, referenceColor);
    bool _210 = any(isnan(referenceColor));
    bool _217;
    if (!_210)
    {
        _217 = any(isinf(referenceColor));
    }
    else
    {
        _217 = _210;
    }
    if (_217)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _230 = referenceColor;
    float3 _236 = fast::clamp(_230.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _236.x;
    referenceColor.y = _236.y;
    referenceColor.z = _236.z;
    out.finalColor = referenceColor;
    return out;
}

