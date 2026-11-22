// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_s_hotspots.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse3817a19bd21a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float threshold;
    char _m6_pad[12];
    float softness;
    char _m7_pad[12];
    float gain;
    float4 hotColor;
    float mixAmount;
};

struct refAM35_e3817a19bd21a_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float aeLuma(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse3817a19bd21a& _49, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _49.refScreen.xy;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 param_1 = src.xyz;
    float y = aeLuma(param_1);
    float m = smoothstep(_49.threshold, _49.threshold + _49.softness, y);
    float3 heat = mix(src.xyz, (_49.hotColor.xyz * fast::max(y, 0.25)) * _49.gain, float3(m * _49.hotColor.w));
    referenceColor = float4(mix(src.xyz, heat, float3(_49.mixAmount)), src.w);
}

fragment refAM35_e3817a19bd21a_out refAM35_e3817a19bd21a(constant ReferenceUniformse3817a19bd21a& _49 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e3817a19bd21a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _49, referenceColor);
    bool _124 = any(isnan(referenceColor));
    bool _131;
    if (!_124)
    {
        _131 = any(isinf(referenceColor));
    }
    else
    {
        _131 = _124;
    }
    if (_131)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _145 = referenceColor;
    float3 _151 = fast::clamp(_145.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _151.x;
    referenceColor.y = _151.y;
    referenceColor.z = _151.z;
    out.finalColor = referenceColor;
    return out;
}

