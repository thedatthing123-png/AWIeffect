// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/edgeglow.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseadb757aa8f44
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float smoothing;
    char _m6_pad[12];
    float threshold;
    char _m7_pad[12];
    uint invert;
    char _m8_pad[12];
    float strength;
    char _m9_pad[12];
    float spread;
    float4 fillColor;
    float blend;
    char _m12_pad[12];
    float gamma;
    char _m13_pad[12];
    float brightness;
    float4 tintColor;
    float tint;
};

struct refAM35_eadb757aa8f44_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 saturate0(thread const float3& v)
{
    return fast::clamp(v, float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
float saturate0(thread const float& v)
{
    return fast::clamp(v, 0.0, 1.0);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refBuffer2, sampler refBuffer2Smplr, thread float4& gl_FragCoord, constant ReferenceUniformseadb757aa8f44& _84, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float2 param = gl_FragCoord.xy / _84.refScreen.xy;
    float4 glow = texture2DCv(refBuffer2, refBuffer2Smplr, param);
    float2 param_1 = gl_FragCoord.xy / _84.refScreen.xy;
    float4 base = texture2DCv(refInput, refInputSmplr, param_1);
    float _106 = glow.w;
    float4 _107 = glow;
    float3 _110 = _107.xyz / float3(_106);
    glow.x = _110.x;
    glow.y = _110.y;
    glow.z = _110.z;
    float _121 = base.w;
    float4 _122 = base;
    float3 _125 = _122.xyz / float3(_121);
    base.x = _125.x;
    base.y = _125.y;
    base.z = _125.z;
    float4 _132 = glow;
    float3 _143 = powr(_132.xyz, float3(fast::max(9.9999997473787516355514526367188e-05, 3.0 - _84.spread)));
    glow.x = _143.x;
    glow.y = _143.y;
    glow.z = _143.z;
    float4 _150 = base;
    float3 _157 = powr(_150.xyz, float3(1.0 / _84.gamma));
    base.x = _157.x;
    base.y = _157.y;
    base.z = _157.z;
    float4 _164 = base;
    float3 _174 = ((_164.xyz * rgb2yuv) + float3(_84.brightness, 0.0, 0.0)) * yuv2rgb;
    base.x = _174.x;
    base.y = _174.y;
    base.z = _174.z;
    float3 param_2 = base.xyz;
    float3 _184 = saturate0(param_2);
    base.x = _184.x;
    base.y = _184.y;
    base.z = _184.z;
    float lum = dot(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875), glow.xyz);
    float fill = 1.0;
    float _201 = glow.w;
    float4 _202 = glow;
    float3 _204 = _202.xyz * _201;
    glow.x = _204.x;
    glow.y = _204.y;
    glow.z = _204.z;
    float _212 = base.w;
    float4 _213 = base;
    float3 _215 = _213.xyz * _212;
    base.x = _215.x;
    base.y = _215.y;
    base.z = _215.z;
    float param_3 = _84.blend;
    referenceColor = (mix(base, base * _84.tintColor, float4(_84.tint)) * fill) + mix(glow * mix(lum, 1.0, fill), _84.fillColor * lum, float4(fast::max(saturate0(param_3) * (1.0 - lum), _84.blend - 1.0)));
}

fragment refAM35_eadb757aa8f44_out refAM35_eadb757aa8f44(constant ReferenceUniformseadb757aa8f44& _84 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer2 [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer2Smplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_eadb757aa8f44_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refBuffer2, refBuffer2Smplr, gl_FragCoord, _84, refInput, refInputSmplr, referenceColor);
    bool _268 = any(isnan(referenceColor));
    bool _275;
    if (!_268)
    {
        _275 = any(isinf(referenceColor));
    }
    else
    {
        _275 = _268;
    }
    if (_275)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _288 = referenceColor;
    float3 _294 = fast::clamp(_288.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _294.x;
    referenceColor.y = _294.y;
    referenceColor.z = _294.z;
    out.finalColor = referenceColor;
    return out;
}

