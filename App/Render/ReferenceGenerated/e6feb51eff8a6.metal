// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/colorize.xml
// Original source comments and attribution:
// -- Do work here in YUV space ----
// -- Back to RGB and return result ---
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse6feb51eff8a6
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 tint;
};

struct refAM35_e6feb51eff8a6_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse6feb51eff8a6& _108, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float2 param = gl_FragCoord.xy / _108.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = texColor.xyz;
    float a = texColor.w;
    float3 yuv = rgb * rgb2yuv;
    float3 param_1 = float3(_108.tint.x / 360.0, 1.0, 0.5);
    float3 tintedYUV = hsv2rgb(param_1) * rgb2yuv;
    float3 _143 = yuv;
    float2 _152 = mix(_143.yz, tintedYUV.yz, float2(_108.tint.y * a));
    yuv.y = _152.x;
    yuv.z = _152.y;
    rgb = yuv * yuv2rgb;
    referenceColor = float4(rgb, a);
}

fragment refAM35_e6feb51eff8a6_out refAM35_e6feb51eff8a6(constant ReferenceUniformse6feb51eff8a6& _108 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e6feb51eff8a6_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _108, referenceColor);
    bool _174 = any(isnan(referenceColor));
    bool _181;
    if (!_174)
    {
        _181 = any(isinf(referenceColor));
    }
    else
    {
        _181 = _174;
    }
    if (_181)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _194 = referenceColor;
    float3 _200 = fast::clamp(_194.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _200.x;
    referenceColor.y = _200.y;
    referenceColor.z = _200.z;
    out.finalColor = referenceColor;
    return out;
}

