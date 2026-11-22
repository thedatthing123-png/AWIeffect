// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/unmult.xml
// Original source comments and attribution:
// Utility
// Sample helpers
// 5-tap cross blur for performance
// dilate
// erode
// map softness to a reasonable ramp width
// Base alpha from max RGB with threshold + softness
// Feathering
// Matte cleanup (choke/spread). Blend with feathered alpha based on magnitude.
// Respect original alpha channel; output straight alpha
// Unmult color to preserve luminance under reduced alpha (classic Unmult behavior)
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseeb953c7a62af
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float blackLevel;
    char _m6_pad[12];
    float softness;
    char _m7_pad[12];
    float featherPx;
    char _m8_pad[12];
    float cleanupPx;
    char _m9_pad[12];
    float edgeGamma;
    char _m10_pad[12];
    uint preserveLuma;
    char _m11_pad[12];
    uint previewMatte;
    char _m12_pad[12];
    float quality;
};

struct refAM35_eeb953c7a62af_out
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
float4 sampleImg(texture2d<float> img, sampler imgSmplr, thread const float2& uv)
{
    float2 param = uv;
    return texture2DCv(img, imgSmplr, param);
}

static inline __attribute__((always_inline))
float max3(thread const float3& v)
{
    return fast::max(v.x, fast::max(v.y, v.z));
}

static inline __attribute__((always_inline))
float getBaseAlpha(thread const float3& srgb, thread const float& thr, thread const float& soft, thread const float& gamma)
{
    float3 param = srgb;
    float m = max3(param);
    float a = smoothstep(thr, thr + soft, m);
    a = powr(fast::clamp(a, 0.0, 1.0), gamma);
    return a;
}

static inline __attribute__((always_inline))
float featherAlpha(texture2d<float> img, sampler imgSmplr, thread const float2& uv, thread const float& baseA, thread const float2& px, thread const float& feather)
{
    if (feather <= 9.9999997473787516355514526367188e-05)
    {
        return baseA;
    }
    float f = fast::clamp(feather, 0.0, 10.0);
    float2 off = px * f;
    float2 param = uv;
    float3 cC = sampleImg(img, imgSmplr, param).xyz;
    float2 param_1 = uv - float2(off.x, 0.0);
    float3 cL = sampleImg(img, imgSmplr, param_1).xyz;
    float2 param_2 = uv + float2(off.x, 0.0);
    float3 cR = sampleImg(img, imgSmplr, param_2).xyz;
    float2 param_3 = uv - float2(0.0, off.y);
    float3 cT = sampleImg(img, imgSmplr, param_3).xyz;
    float2 param_4 = uv + float2(0.0, off.y);
    float3 cB = sampleImg(img, imgSmplr, param_4).xyz;
    float3 param_5 = cC;
    float aC = max3(param_5);
    float3 param_6 = cL;
    float aL = max3(param_6);
    float3 param_7 = cR;
    float aR = max3(param_7);
    float3 param_8 = cT;
    float aT = max3(param_8);
    float3 param_9 = cB;
    float aB = max3(param_9);
    float avg = (aC * 0.4000000059604644775390625) + ((((aL + aR) + aT) + aB) * 0.1500000059604644775390625);
    return mix(baseA, avg, 0.75);
}

static inline __attribute__((always_inline))
float cleanupAlpha(texture2d<float> img, sampler imgSmplr, thread const float2& uv, thread const float2& px, thread const float& pixels)
{
    float p = abs(pixels);
    if (p < 0.001000000047497451305389404296875)
    {
        float2 param = uv;
        float3 param_1 = sampleImg(img, imgSmplr, param).xyz;
        return max3(param_1);
    }
    float2 off = px * p;
    float2 param_2 = uv;
    float3 param_3 = sampleImg(img, imgSmplr, param_2).xyz;
    float aC = max3(param_3);
    float2 param_4 = uv - float2(off.x, 0.0);
    float3 param_5 = sampleImg(img, imgSmplr, param_4).xyz;
    float aL = max3(param_5);
    float2 param_6 = uv + float2(off.x, 0.0);
    float3 param_7 = sampleImg(img, imgSmplr, param_6).xyz;
    float aR = max3(param_7);
    float2 param_8 = uv - float2(0.0, off.y);
    float3 param_9 = sampleImg(img, imgSmplr, param_8).xyz;
    float aT = max3(param_9);
    float2 param_10 = uv + float2(0.0, off.y);
    float3 param_11 = sampleImg(img, imgSmplr, param_10).xyz;
    float aB = max3(param_11);
    float spread = fast::max(aC, fast::max(fast::max(aL, aR), fast::max(aT, aB)));
    float choke = fast::min(aC, fast::min(fast::min(aL, aR), fast::min(aT, aB)));
    return (pixels >= 0.0) ? spread : choke;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseeb953c7a62af& _327, thread float4& referenceColor)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param);
    float2 px = float2(1.0) / fast::max(float2(image_size.x, image_size.y), float2(1.0));
    float2 uv = gl_FragCoord.xy / _327.refScreen.xy;
    float2 param_1 = uv;
    float4 col = sampleImg(refInput, refInputSmplr, param_1);
    float thr = fast::clamp(_327.blackLevel / 255.0, 0.0, 1.0);
    float soft = fast::max(_327.softness, 0.0) * 0.25;
    float gamma = _327.edgeGamma;
    float3 param_2 = col.xyz;
    float param_3 = thr;
    float param_4 = soft;
    float param_5 = gamma;
    float aBase = getBaseAlpha(param_2, param_3, param_4, param_5);
    float2 param_6 = uv;
    float param_7 = aBase;
    float2 param_8 = px;
    float param_9 = _327.featherPx;
    float aFeather = featherAlpha(refInput, refInputSmplr, param_6, param_7, param_8, param_9);
    float2 param_10 = uv;
    float2 param_11 = px;
    float param_12 = _327.cleanupPx;
    float aClean = cleanupAlpha(refInput, refInputSmplr, param_10, param_11, param_12);
    float mAmt = fast::clamp(abs(_327.cleanupPx) / 10.0, 0.0, 1.0);
    float aMatte = mix(aFeather, aClean, mAmt);
    float aOut = aMatte * col.w;
    float3 _413;
    if (_327.preserveLuma != 0u)
    {
        _413 = col.xyz / float3(fast::max(aMatte, 9.9999997473787516355514526367188e-05));
    }
    else
    {
        _413 = col.xyz;
    }
    float3 unmultRGB = _413;
    unmultRGB = fast::clamp(unmultRGB, float3(0.0), float3(1.0));
    if (_327.previewMatte != 0u)
    {
        referenceColor = float4(float3(aOut), aOut);
    }
    else
    {
        referenceColor = float4(unmultRGB, aOut);
    }
}

fragment refAM35_eeb953c7a62af_out refAM35_eeb953c7a62af(constant ReferenceUniformseeb953c7a62af& _327 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eeb953c7a62af_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _327, referenceColor);
    bool _457 = any(isnan(referenceColor));
    bool _464;
    if (!_457)
    {
        _464 = any(isinf(referenceColor));
    }
    else
    {
        _464 = _457;
    }
    if (_464)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _477 = referenceColor;
    float3 _483 = fast::clamp(_477.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _483.x;
    referenceColor.y = _483.y;
    referenceColor.z = _483.z;
    out.finalColor = referenceColor;
    return out;
}

