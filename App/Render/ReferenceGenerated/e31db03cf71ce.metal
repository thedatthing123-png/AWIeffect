// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_s_hue_sat_bright.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse31db03cf71ce
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float hue;
    char _m6_pad[12];
    float saturation;
    char _m7_pad[12];
    float brightness;
    char _m8_pad[12];
    float mixAmount;
};

struct refAM35_e31db03cf71ce_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 aeRGB2HSV(thread const float3& c)
{
    float4 K = float4(0.0, -0.333333313465118408203125, 0.666666686534881591796875, -1.0);
    float4 p = mix(float4(c.zy, K.wz), float4(c.yz, K.xy), float4(step(c.z, c.y)));
    float4 q = mix(float4(p.xyw, c.x), float4(c.x, p.yzx), float4(step(p.x, c.x)));
    float d = q.x - fast::min(q.w, q.y);
    float e = 1.0000000133514319600180897396058e-10;
    return float3(abs(q.z + ((q.w - q.y) / ((6.0 * d) + e))), d / (q.x + e), q.x);
}

static inline __attribute__((always_inline))
float3 aeHSV2RGB(thread const float3& c)
{
    float3 p = abs((fract(c.xxx + float3(0.0, 0.666666686534881591796875, 0.333333313465118408203125)) * 6.0) - float3(3.0));
    return mix(float3(1.0), fast::clamp(p - float3(1.0), float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse31db03cf71ce& _172, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _172.refScreen.xy;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 param_1 = src.xyz;
    float3 hsv = aeRGB2HSV(param_1);
    hsv.x = fract(hsv.x + (_172.hue / 360.0));
    hsv.y = fast::clamp(hsv.y * _172.saturation, 0.0, 1.0);
    hsv.z = fast::max(hsv.z * _172.brightness, 0.0);
    float3 param_2 = hsv;
    float3 mapped = aeHSV2RGB(param_2);
    referenceColor = float4(mix(src.xyz, mapped, float3(_172.mixAmount)), src.w);
}

fragment refAM35_e31db03cf71ce_out refAM35_e31db03cf71ce(constant ReferenceUniformse31db03cf71ce& _172 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e31db03cf71ce_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _172, referenceColor);
    bool _240 = any(isnan(referenceColor));
    bool _247;
    if (!_240)
    {
        _247 = any(isinf(referenceColor));
    }
    else
    {
        _247 = _240;
    }
    if (_247)
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

