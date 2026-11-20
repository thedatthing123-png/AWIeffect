// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/luma_color.xml
// Original source comments and attribution:
// Color-Luma Key (official AM style)
// - Only AM builtins
// - No dynamic loops/derivatives
// Simple YUV-like chroma for distance that's less sensitive to brightness
// Key color chroma and luma
// 0..~1
// 0..1
// Combined distance (scaled by lumaWeight)
// Soft thresholding to build matte
// 1 where color matches key
// Despill: reduce contribution of keyed color on remaining pixels
// Simple projection toward neutral luma
// 1 near key
// Compose: attenuate alpha where key matched
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse1ab9310206cc
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 keyColor;
    float tolerance;
    char _m7_pad[12];
    float softness;
    char _m8_pad[12];
    float lumaWeight;
    char _m9_pad[12];
    uint invertKey;
    char _m10_pad[12];
    float despill;
    char _m11_pad[12];
    float alpha;
};

struct refAM35_e1ab9310206cc_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 chroma(thread const float3& c)
{
    float y = dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    return float2(c.z - y, c.x - y);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse1ab9310206cc& _61, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _61.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 c = src.xyz;
    float3 k = _61.keyColor.xyz;
    float y = dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float yk = dot(k, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float3 param_1 = c;
    float2 cc = chroma(param_1);
    float3 param_2 = k;
    float2 ck = chroma(param_2);
    float chromaDist = length(cc - ck);
    float lumaDist = abs(y - yk);
    float d = chromaDist + (_61.lumaWeight * lumaDist);
    float t = _61.tolerance;
    float s = fast::max(_61.softness, 9.9999997473787516355514526367188e-06);
    float matte = 1.0 - smoothstep(t - s, t + s, d);
    if (_61.invertKey != 0u)
    {
        matte = 1.0 - matte;
    }
    float match = matte;
    float3 neutral = float3(y);
    float3 cDespill = mix(c, mix(c, neutral, float3(0.60000002384185791015625)), float3(_61.despill * match));
    float aOut = (src.w * (1.0 - matte)) * _61.alpha;
    referenceColor = float4(cDespill, 1.0) * aOut;
}

fragment refAM35_e1ab9310206cc_out refAM35_e1ab9310206cc(constant ReferenceUniformse1ab9310206cc& _61 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e1ab9310206cc_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _61, refInput, refInputSmplr, referenceColor);
    bool _192 = any(isnan(referenceColor));
    bool _199;
    if (!_192)
    {
        _199 = any(isinf(referenceColor));
    }
    else
    {
        _199 = _192;
    }
    if (_199)
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

