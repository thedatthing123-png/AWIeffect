// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/hueshift.xml
// Original source comments and attribution:
//yuv.yz = yuv.yz * (saturation+1.0);
//rgb = (rgb - 0.5) * (contrast+1.0) + 0.5 + brightness;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse77c18bb5f153
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float hue;
};

struct refAM35_e77c18bb5f153_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse77c18bb5f153& _58, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float rad = _58.hue * 0.01745329983532428741455078125;
    float3x3 huemat = float3x3(float3(1.0, 0.0, 0.0), float3(0.0, cos(rad), sin(rad)), float3(0.0, -sin(rad), cos(rad)));
    float2 param = gl_FragCoord.xy / _58.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = texColor.xyz;
    float a = texColor.w;
    float3 yuv = rgb * rgb2yuv;
    yuv *= huemat;
    rgb = yuv * yuv2rgb;
    referenceColor = float4(rgb, a);
}

fragment refAM35_e77c18bb5f153_out refAM35_e77c18bb5f153(constant ReferenceUniformse77c18bb5f153& _58 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e77c18bb5f153_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_58, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _128 = any(isnan(referenceColor));
    bool _135;
    if (!_128)
    {
        _135 = any(isinf(referenceColor));
    }
    else
    {
        _135 = _128;
    }
    if (_135)
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

