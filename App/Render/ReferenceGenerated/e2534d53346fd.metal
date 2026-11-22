// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/lumastamper.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse2534d53346fd
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color;
    float clipLow;
    char _m7_pad[12];
    float clipHigh;
    char _m8_pad[12];
    float gamma;
    char _m9_pad[12];
    uint invert;
};

struct refAM35_e2534d53346fd_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float saturate0(thread const float& v)
{
    return fast::clamp(v, 0.0, 1.0);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse2534d53346fd& _47, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _47.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float luminance = dot(texColor.xyz / float3(fast::max(9.9999999747524270787835121154785e-07, texColor.w)), float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float param_1 = (luminance - _47.clipLow) / (fast::max(1.0 - _47.clipHigh, _47.clipLow + 9.9999997473787516355514526367188e-05) - _47.clipLow);
    float p = saturate0(param_1);
    p = powr(p, 1.0 / _47.gamma);
    if (_47.invert != 0u)
    {
        p = 1.0 - p;
    }
    p *= texColor.w;
    referenceColor = _47.color * p;
}

fragment refAM35_e2534d53346fd_out refAM35_e2534d53346fd(constant ReferenceUniformse2534d53346fd& _47 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e2534d53346fd_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _47, referenceColor);
    bool _128 = any(isnan(referenceColor));
    bool _135;
    if (!_128)
    {
        _135 = any(isinf(referenceColor));
    }
    else
    {
        _135 = _128;
    }
    if (_135)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _148 = referenceColor;
    float3 _154 = fast::clamp(_148.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _154.x;
    referenceColor.y = _154.y;
    referenceColor.z = _154.z;
    out.finalColor = referenceColor;
    return out;
}

