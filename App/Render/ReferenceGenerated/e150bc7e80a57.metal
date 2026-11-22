// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/streakstrips.xml
// Original source comments and attribution:
//st = mod(st + 1000., 1.);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse150bc7e80a57
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amount;
    char _m6_pad[12];
    float angle;
    char _m7_pad[12];
    float phase;
    char _m8_pad[12];
    uint maskToLayer;
    char _m9_pad[12];
    float alpha;
};

struct refAM35_e150bc7e80a57_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rot2d(thread const float& a)
{
    return float2x2(float2(cos(a), -sin(a)), float2(sin(a), cos(a)));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse150bc7e80a57& _45)
{
    return (float4(v, 0.0, 1.0) * _45.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse150bc7e80a57& _45, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st = (gl_FragCoord.xy - _45.refLayer.xy) / _45.refLayer.zw;
    float a = _45.angle * 0.01745329983532428741455078125;
    st -= float2(0.5);
    float param = a;
    st *= rot2d(param);
    st += float2(0.5);
    st.y = (floor((st.y + (_45.phase / 10.0)) * _45.amount) / _45.amount) - (_45.phase / 10.0);
    st -= float2(0.5);
    float param_1 = -a;
    st *= rot2d(param_1);
    st += float2(0.5);
    float2 param_2 = gl_FragCoord.xy / _45.refScreen.xy;
    float4 baseColor = texture2DCv(refInput, refInputSmplr, param_2);
    float2 param_3 = st;
    float2 param_4 = l2s(param_3, _45);
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_4);
    float4 c = mix(baseColor, texColor, float4(_45.alpha));
    if (_45.maskToLayer != 0u)
    {
        c *= baseColor.w;
        referenceColor = (baseColor * (1.0 - c.w)) + c;
    }
    else
    {
        referenceColor = c;
    }
}

fragment refAM35_e150bc7e80a57_out refAM35_e150bc7e80a57(constant ReferenceUniformse150bc7e80a57& _45 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e150bc7e80a57_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_45, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _193 = any(isnan(referenceColor));
    bool _200;
    if (!_193)
    {
        _200 = any(isinf(referenceColor));
    }
    else
    {
        _200 = _193;
    }
    if (_200)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _214 = referenceColor;
    float3 _220 = fast::clamp(_214.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _220.x;
    referenceColor.y = _220.y;
    referenceColor.z = _220.z;
    out.finalColor = referenceColor;
    return out;
}

