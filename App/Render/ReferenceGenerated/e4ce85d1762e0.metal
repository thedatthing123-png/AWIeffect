// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/3colorgrad.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse4ce85d1762e0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    float4 color3;
    float angle;
    char _m9_pad[12];
    float offset;
    char _m10_pad[12];
    float scale;
    char _m11_pad[12];
    float midpoint;
    char _m12_pad[12];
    float opacity;
};

struct refAM35_e4ce85d1762e0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse4ce85d1762e0& _35, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float2 p = (gl_FragCoord.xy / _35.refScreen.xy) - float2(0.5);
    float rad = _35.angle * 0.01745329238474369049072265625;
    float2 dir = float2(cos(rad), sin(rad));
    float t = ((dot(p, dir) / fast::max(_35.scale, 0.001000000047497451305389404296875)) + 0.5) + (_35.offset * 0.5);
    t = fast::clamp(t, 0.0, 1.0);
    float m = fast::clamp(_35.midpoint, 0.100000001490116119384765625, 0.89999997615814208984375);
    float3 grad;
    if (t < m)
    {
        grad = mix(_35.color1.xyz, _35.color2.xyz, float3(t / m));
    }
    else
    {
        grad = mix(_35.color2.xyz, _35.color3.xyz, float3((t - m) / (1.0 - m)));
    }
    referenceColor = float4(mix(src.xyz, grad, float3(_35.opacity)), src.w);
}

fragment refAM35_e4ce85d1762e0_out refAM35_e4ce85d1762e0(constant ReferenceUniformse4ce85d1762e0& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e4ce85d1762e0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, referenceColor);
    bool _157 = any(isnan(referenceColor));
    bool _164;
    if (!_157)
    {
        _164 = any(isinf(referenceColor));
    }
    else
    {
        _164 = _157;
    }
    if (_164)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _177 = referenceColor;
    float3 _183 = fast::clamp(_177.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _183.x;
    referenceColor.y = _183.y;
    referenceColor.z = _183.z;
    out.finalColor = referenceColor;
    return out;
}

