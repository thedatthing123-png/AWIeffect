// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/unsharpmask.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse381a990a1423
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float amount;
    char _m7_pad[12];
    float threshold;
    char _m8_pad[12];
    uint showMask;
};

struct refAM35_e381a990a1423_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refBuffer1, sampler refBuffer1Smplr, thread float4& gl_FragCoord, constant ReferenceUniformse381a990a1423& _36, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 blur = texture2DCv(refBuffer1, refBuffer1Smplr, param);
    float2 param_1 = gl_FragCoord.xy / _36.refScreen.xy;
    float4 base = texture2DCv(refInput, refInputSmplr, param_1);
    float blurY = dot(blur.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float baseY = dot(base.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 adjColor = (base * (1.0 + _36.amount)) - (blur * _36.amount);
    float t = step(_36.threshold, abs(blurY - baseY) * 4.0);
    t = smoothstep(_36.threshold * 0.75, (_36.threshold + 1.0099999904632568359375) / 2.0, abs(blurY - baseY) * 4.0);
    float4 _120;
    if (_36.showMask != 0u)
    {
        _120 = float4(t, 0.0, 0.0, 1.0) * base.w;
    }
    else
    {
        _120 = mix(base, adjColor, float4(t));
    }
    referenceColor = _120;
}

fragment refAM35_e381a990a1423_out refAM35_e381a990a1423(constant ReferenceUniformse381a990a1423& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e381a990a1423_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refBuffer1, refBuffer1Smplr, gl_FragCoord, _36, refInput, refInputSmplr, referenceColor);
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

