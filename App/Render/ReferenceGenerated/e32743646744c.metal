// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/x_sharpen.xml
// Original source comments and attribution:
// Advanced Denoise + Sharpen (Bilateral + Unsharp)
// Port adapted to Alight Motion shader API
// Bilateral 5x5
// Unsharp mask using denoised as base to avoid boosting noise
// View selection
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse32743646744c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float noiseStrength;
    char _m6_pad[12];
    float sharpenStrength;
    char _m7_pad[12];
    int viewMode;
    char _m8_pad[12];
    float alpha;
};

struct refAM35_e32743646744c_out
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
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse32743646744c& _41, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _41.refScreen.xy;
    float2 param = _41.refScreen.xy;
    float2 texel = float2(1.0) / getTexSize(param);
    float2 param_1 = uv;
    float3 centerColor = texture2DCv(refInput, refInputSmplr, param_1).xyz;
    float3 accum = float3(0.0);
    float wsum = 0.0;
    for (int j = -2; j <= 2; j++)
    {
        for (int i = -2; i <= 2; i++)
        {
            float2 off = float2(float(i), float(j));
            float2 param_2 = uv + (off * texel);
            float3 nc = texture2DCv(refInput, refInputSmplr, param_2).xyz;
            float spatial = exp((-((off.x * off.x) + (off.y * off.y))) / 8.0);
            float cd = length(centerColor - nc);
            float range = exp((-(cd * cd)) / (((2.0 * _41.noiseStrength) * _41.noiseStrength) + 9.9999999747524270787835121154785e-07));
            float w = spatial * range;
            accum += (nc * w);
            wsum += w;
        }
    }
    float3 denoised = accum / float3(fast::max(wsum, 9.9999999747524270787835121154785e-07));
    float3 detail = centerColor - denoised;
    float3 finalSharpened = centerColor + (detail * _41.sharpenStrength);
    float3 outRGB = finalSharpened;
    if (_41.viewMode == 0)
    {
        outRGB = denoised;
    }
    else
    {
        if (_41.viewMode == 1)
        {
            outRGB = centerColor;
        }
    }
    float2 param_3 = uv;
    float a = texture2DCv(refInput, refInputSmplr, param_3).w * _41.alpha;
    referenceColor = float4(fast::clamp(outRGB, float3(0.0), float3(1.0)), 1.0) * a;
}

fragment refAM35_e32743646744c_out refAM35_e32743646744c(constant ReferenceUniformse32743646744c& _41 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e32743646744c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _41, refInput, refInputSmplr, referenceColor);
    bool _226 = any(isnan(referenceColor));
    bool _233;
    if (!_226)
    {
        _233 = any(isinf(referenceColor));
    }
    else
    {
        _233 = _226;
    }
    if (_233)
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

