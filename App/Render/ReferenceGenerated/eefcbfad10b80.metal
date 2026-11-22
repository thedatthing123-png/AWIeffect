// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/normal_map.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseefcbfad10b80
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float sampleRadius;
    char _m7_pad[12];
    uint invertHeight;
    char _m8_pad[12];
    int outputMode;
    char _m9_pad[12];
    float lightX;
    char _m10_pad[12];
    float lightY;
    char _m11_pad[12];
    float lightZ;
    float4 lightColor;
    float ambient;
    char _m14_pad[12];
    float mixAmount;
};

struct refAM35_eefcbfad10b80_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float lum(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformseefcbfad10b80& _49, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _49.refLayer.xy) / _49.refLayer.zw;
    float2 d = float2(_49.sampleRadius) / fast::max(_49.refLayer.zw, float2(1.0));
    float2 param = fast::clamp(uv - float2(d.x, 0.0), float2(0.0), float2(1.0));
    float3 param_1 = texture2DCv(refInput, refInputSmplr, param).xyz;
    float l = lum(param_1);
    float2 param_2 = fast::clamp(uv + float2(d.x, 0.0), float2(0.0), float2(1.0));
    float3 param_3 = texture2DCv(refInput, refInputSmplr, param_2).xyz;
    float r = lum(param_3);
    float2 param_4 = fast::clamp(uv - float2(0.0, d.y), float2(0.0), float2(1.0));
    float3 param_5 = texture2DCv(refInput, refInputSmplr, param_4).xyz;
    float u = lum(param_5);
    float2 param_6 = fast::clamp(uv + float2(0.0, d.y), float2(0.0), float2(1.0));
    float3 param_7 = texture2DCv(refInput, refInputSmplr, param_6).xyz;
    float dn = lum(param_7);
    float inv = (_49.invertHeight != 0u) ? (-1.0) : 1.0;
    float3 n = fast::normalize(float3(((l - r) * _49.strength) * inv, ((u - dn) * _49.strength) * inv, 1.0));
    float2 param_8 = uv;
    float4 s = texture2DCv(refInput, refInputSmplr, param_8);
    float3 outc = (n * 0.5) + float3(0.5);
    if (_49.outputMode == 1)
    {
        float li = fast::max(dot(n, fast::normalize(float3(_49.lightX, -_49.lightY, _49.lightZ))), 0.0);
        outc = (s.xyz * (_49.ambient + ((1.0 - _49.ambient) * li))) * _49.lightColor.xyz;
    }
    referenceColor = float4(mix(s.xyz, outc, float3(_49.mixAmount)), s.w);
}

fragment refAM35_eefcbfad10b80_out refAM35_eefcbfad10b80(constant ReferenceUniformseefcbfad10b80& _49 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eefcbfad10b80_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _49, refInput, refInputSmplr, referenceColor);
    bool _236 = any(isnan(referenceColor));
    bool _243;
    if (!_236)
    {
        _243 = any(isinf(referenceColor));
    }
    else
    {
        _243 = _236;
    }
    if (_243)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _256 = referenceColor;
    float3 _262 = fast::clamp(_256.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _262.x;
    referenceColor.y = _262.y;
    referenceColor.z = _262.z;
    out.finalColor = referenceColor;
    return out;
}

