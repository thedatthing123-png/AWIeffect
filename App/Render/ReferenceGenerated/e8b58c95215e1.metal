// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/unsharp_gauss_v_wide.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse8b58c95215e1
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float wideRadius;
    char _m6_pad[12];
    int quality;
};

struct refAM35_e8b58c95215e1_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 s(thread const float2& uv, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = uv;
    return texture2DCv(refInput, refInputSmplr, param);
}

static inline __attribute__((always_inline))
float w(thread const float& x, thread const float& sigma)
{
    return exp((-(x * x)) / ((2.0 * sigma) * sigma));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse8b58c95215e1& _70, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _70.refScreen.xy;
    float2 param = _70.refScreen.xy;
    float2 texel = float2(1.0) / getTexSize(param);
    float r = _70.wideRadius;
    if (r <= 0.0)
    {
        float2 param_1 = uv;
        referenceColor = s(param_1, refInput, refInputSmplr);
        return;
    }
    float _111;
    if (_70.quality == 0)
    {
        _111 = 2.0;
    }
    else
    {
        _111 = (_70.quality == 1) ? 3.0 : 4.0;
    }
    int taps = int(r * _111);
    float sigma = fast::max(9.9999997473787516355514526367188e-05, r * 0.60000002384185791015625);
    float4 acc = float4(0.0);
    float wsum = 0.0;
    for (int i = -2048; i <= 2048; i++)
    {
        if (i < (-taps))
        {
            continue;
        }
        if (i > taps)
        {
            break;
        }
        float param_2 = float(i);
        float param_3 = sigma;
        float wi = w(param_2, param_3);
        float2 param_4 = uv + float2(0.0, float(i) * texel.y);
        acc += (s(param_4, refInput, refInputSmplr) * wi);
        wsum += wi;
    }
    referenceColor = acc / float4(fast::max(9.9999997473787516355514526367188e-05, wsum));
}

fragment refAM35_e8b58c95215e1_out refAM35_e8b58c95215e1(constant ReferenceUniformse8b58c95215e1& _70 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8b58c95215e1_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _70, referenceColor);
    bool _195 = any(isnan(referenceColor));
    bool _202;
    if (!_195)
    {
        _202 = any(isinf(referenceColor));
    }
    else
    {
        _202 = _195;
    }
    if (_202)
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

