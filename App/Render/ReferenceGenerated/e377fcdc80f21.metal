// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/vibrance-saturation.xml
// Original source comments and attribution:
//float hue = 0.0;
//float rad = hue * 0.0174533;
//highp mat3 huemat = mat3(
//    1.0,  0.0,       0.0,
//    0.0,  cos(rad),  sin(rad),
//    0.0,  -sin(rad), cos(rad)
//);
//-- Vibrance 1 --
//
//--------------
//-- Vibrance 2 --
//float origSat = min(1.0,length(yuv.yz)*2.5); //
//vec2 satUV = yuv.yz * pow(origSat+1.0,vib);
//yuv.yz = mix(satUV,yuv.yz,origSat);
//--------------
//yuv = yuv * huemat;
//yuv.x = (yuv.x-0.5*a) * (contrast+1.0) + 0.5*a + brightness*a;
//rgb = (rgb - 0.5) * (contrast+1.0) + 0.5 + brightness;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse377fcdc80f21
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float saturation;
    char _m6_pad[12];
    float vib;
};

struct refAM35_e377fcdc80f21_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse377fcdc80f21& _63, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float2 param = gl_FragCoord.xy / _63.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = texColor.xyz;
    float a = texColor.w;
    float3 yuv = rgb * rgb2yuv;
    float origSat = fast::min(1.0, length(yuv.yz) * 2.5);
    float2 satUV = yuv.yz * _63.vib;
    float3 _103 = yuv;
    float2 _107 = mix(satUV, _103.yz, float2(origSat));
    yuv.y = _107.x;
    yuv.z = _107.y;
    float3 _114 = yuv;
    float2 _120 = _114.yz * (_63.saturation + 1.0);
    yuv.y = _120.x;
    yuv.z = _120.y;
    rgb = yuv * yuv2rgb;
    referenceColor = float4(rgb, a);
}

fragment refAM35_e377fcdc80f21_out refAM35_e377fcdc80f21(constant ReferenceUniformse377fcdc80f21& _63 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e377fcdc80f21_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _63, referenceColor);
    bool _142 = any(isnan(referenceColor));
    bool _149;
    if (!_142)
    {
        _149 = any(isinf(referenceColor));
    }
    else
    {
        _149 = _142;
    }
    if (_149)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _162 = referenceColor;
    float3 _168 = fast::clamp(_162.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _168.x;
    referenceColor.y = _168.y;
    referenceColor.z = _168.z;
    out.finalColor = referenceColor;
    return out;
}

