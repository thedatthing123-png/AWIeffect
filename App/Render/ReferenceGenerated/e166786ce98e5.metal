// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/softglow.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse166786ce98e5
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float brightness;
    char _m7_pad[12];
    float contrast;
    char _m8_pad[12];
    float highlights;
    float4 color;
    float blend;
    char _m11_pad[12];
    float alpha;
    char _m12_pad[12];
    float outsideAlpha;
};

struct refAM35_e166786ce98e5_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 saturate0(thread const float4& v)
{
    return fast::clamp(v, float4(0.0), float4(1.0));
}

static inline __attribute__((always_inline))
float4 composite(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse166786ce98e5& _64, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _64.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = gl_FragCoord.xy / _64.refScreen.xy;
    float4 blurTexColor = texture2DCv(refBuffer1, refBuffer1Smplr, param_1);
    float4 adjBlur = blurTexColor;
    float4 _87 = adjBlur;
    float3 _95 = fast::min(_87.xyz * _64.brightness, float3(1.0));
    adjBlur.x = _95.x;
    adjBlur.y = _95.y;
    adjBlur.z = _95.z;
    float luminance = fast::min(1.0, dot(adjBlur.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)) * _64.brightness);
    float4 blendColor = mix(adjBlur, _64.color * luminance, float4(_64.blend));
    float4 _129 = blendColor;
    float3 _139 = mix(_129.xyz, float3(luminance), float3(luminance * _64.highlights));
    blendColor.x = _139.x;
    blendColor.y = _139.y;
    blendColor.z = _139.z;
    float4 _146 = blendColor;
    float4 _148 = blendColor;
    float3 _155 = _146.xyz * mix(float3(1.0), _148.xyz, float3(_64.contrast));
    blendColor.x = _155.x;
    blendColor.y = _155.y;
    blendColor.z = _155.z;
    float4 blendInside = blendColor * _64.alpha;
    float4 param_2 = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - blendInside.xyz)), 1.0) * texColor.w;
    float4 result = saturate0(param_2);
    if (_64.outsideAlpha > 0.0)
    {
        float2 param_3 = gl_FragCoord.xy / _64.refScreen.xy;
        float4 compColor = texture2DCv(refReference, refReferenceSmplr, param_3);
        float lum = dot(blurTexColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        float4 blendOutside = mix(blurTexColor, _64.color * lum, float4(_64.blend));
        float4 oc = float4(float3(1.0) - ((float3(1.0) - (compColor.xyz / float3(fast::max(9.9999999747524270787835121154785e-07, compColor.w)))) * (float3(1.0) - (blendOutside.xyz / float3(fast::max(9.9999999747524270787835121154785e-07, blendOutside.w))))), 1.0) * compColor.w;
        float4 param_4 = mix(result, oc, float4(_64.outsideAlpha * (blurTexColor.w * 2.0)));
        float4 param_5 = result;
        result = composite(param_4, param_5);
    }
    referenceColor = result;
}

fragment refAM35_e166786ce98e5_out refAM35_e166786ce98e5(constant ReferenceUniformse166786ce98e5& _64 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refReference [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refReferenceSmplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_e166786ce98e5_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _64, refBuffer1, refBuffer1Smplr, refReference, refReferenceSmplr, referenceColor);
    bool _277 = any(isnan(referenceColor));
    bool _284;
    if (!_277)
    {
        _284 = any(isinf(referenceColor));
    }
    else
    {
        _284 = _277;
    }
    if (_284)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _297 = referenceColor;
    float3 _303 = fast::clamp(_297.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _303.x;
    referenceColor.y = _303.y;
    referenceColor.z = _303.z;
    out.finalColor = referenceColor;
    return out;
}

