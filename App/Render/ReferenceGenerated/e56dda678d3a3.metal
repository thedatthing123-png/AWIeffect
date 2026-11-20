// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/brightness-contrast-2.xml
// Original source comments and attribution:
// ENABLE THE FOLLOWING TWO LINES FOR EFFECT TESTING
//float s = max(sin(acScreenNorm.x*200.),0.);
//return vec4(rgb,a*s);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse56dda678d3a3
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float brightness;
    char _m6_pad[12];
    float contrast;
};

struct refAM35_e56dda678d3a3_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse56dda678d3a3& _63, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float2 param = gl_FragCoord.xy / _63.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = texColor.xyz;
    float a = texColor.w;
    float3 yuv = rgb * rgb2yuv;
    yuv.x = (((yuv.x - (0.5 * a)) * (_63.contrast + 1.0)) + (0.5 * a)) + (_63.brightness * a);
    rgb = yuv * yuv2rgb;
    referenceColor = float4(rgb, a);
}

fragment refAM35_e56dda678d3a3_out refAM35_e56dda678d3a3(constant ReferenceUniformse56dda678d3a3& _63 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e56dda678d3a3_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _63, referenceColor);
    bool _127 = any(isnan(referenceColor));
    bool _134;
    if (!_127)
    {
        _134 = any(isinf(referenceColor));
    }
    else
    {
        _134 = _127;
    }
    if (_134)
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

