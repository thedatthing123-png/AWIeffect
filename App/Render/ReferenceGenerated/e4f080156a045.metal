// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/1block_glitch.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse4f080156a045
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int contentSrc;
    char _m6_pad[12];
    float speed;
    char _m7_pad[12];
    float blockWidthScale;
    char _m8_pad[12];
    float blockHeightScale;
    char _m9_pad[12];
    float strengthPix;
    char _m10_pad[12];
    float thresholdLevel;
    char _m11_pad[12];
    uint cropEdges;
};

struct refAM35_e4f080156a045_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float2 getResolution(texture2d<float> refReference, sampler refReferenceSmplr, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = float2(int2(refReference.get_width(), refReference.get_height()));
    float2 s = getTexSize(param);
    bool _71 = s.x <= 0.0;
    bool _79;
    if (!_71)
    {
        _79 = s.y <= 0.0;
    }
    else
    {
        _79 = _71;
    }
    if (_79)
    {
        float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
        s = getTexSize(param_1);
    }
    bool _91 = s.x <= 0.0;
    bool _98;
    if (!_91)
    {
        _98 = s.y <= 0.0;
    }
    else
    {
        _98 = _91;
    }
    if (_98)
    {
        s = float2(1920.0, 1080.0);
    }
    return s;
}

static inline __attribute__((always_inline))
float2 hash21(thread const float& p)
{
    float3 p3 = fract(float3(p) * float3(0.103100001811981201171875, 0.10300000011920928955078125, 0.097300000488758087158203125));
    p3 += float3(dot(p3, p3.yzx + float3(33.3300018310546875)));
    return fract((p3.xx + p3.yz) * p3.zy);
}

static inline __attribute__((always_inline))
float3 hash33(thread float3& p3)
{
    p3 = fract(p3 * float3(0.103100001811981201171875, 0.10300000011920928955078125, 0.097300000488758087158203125));
    p3 += float3(dot(p3, p3.yxz + float3(33.3300018310546875)));
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

static inline __attribute__((always_inline))
float fractf(thread const float& x)
{
    return fract(x);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 sampleContent(thread const float2& uv01, texture2d<float> refReference, sampler refReferenceSmplr, texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse4f080156a045& _167)
{
    if (_167.contentSrc == 1)
    {
        float2 param = uv01;
        return texture2DCv(refReference, refReferenceSmplr, param);
    }
    float2 param_1 = uv01;
    return texture2DCv(refInput, refInputSmplr, param_1);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refReference, sampler refReferenceSmplr, texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse4f080156a045& _167, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 iResolution = getResolution(refReference, refReferenceSmplr, refInput, refInputSmplr);
    float2 uv = gl_FragCoord.xy / _167.refScreen.xy;
    float t = floor(_167.refScreen.z * _167.speed);
    float param = t;
    float2 randomValues = hash21(param);
    float2 randomScale = (randomValues * 100.0) + float2(50.0);
    float2 lod = (iResolution / randomScale) * float2(_167.blockWidthScale, _167.blockHeightScale);
    float2 p = floor(uv * lod);
    float3 param_1 = float3(p, t);
    float3 _242 = hash33(param_1);
    float3 rng = _242;
    float2 offset = (rng.xy - float2(0.5)) * 2.0;
    float param_2 = _167.refScreen.z * _167.speed;
    float fade = sin(fractf(param_2) * 3.1400001049041748046875);
    float th = step(_167.thresholdLevel, rng.z);
    float2 strength = float2(_167.strengthPix) / iResolution;
    float2 glitchUV = uv + (((offset * th) * fade) * strength);
    float2 param_3 = glitchUV;
    float4 col = sampleContent(param_3, refReference, refReferenceSmplr, refInput, refInputSmplr, _167);
    if (_167.cropEdges != 0u)
    {
        float4 _314 = col;
        float3 _316 = _314.xyz * (((step(0.0, glitchUV.x) * step(glitchUV.x, 1.0)) * step(0.0, glitchUV.y)) * step(glitchUV.y, 1.0));
        col.x = _316.x;
        col.y = _316.y;
        col.z = _316.z;
    }
    referenceColor = col;
}

fragment refAM35_e4f080156a045_out refAM35_e4f080156a045(constant ReferenceUniformse4f080156a045& _167 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e4f080156a045_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refReference, refReferenceSmplr, refInput, refInputSmplr, _167, gl_FragCoord, referenceColor);
    bool _331 = any(isnan(referenceColor));
    bool _338;
    if (!_331)
    {
        _338 = any(isinf(referenceColor));
    }
    else
    {
        _338 = _331;
    }
    if (_338)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _352 = referenceColor;
    float3 _358 = fast::clamp(_352.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _358.x;
    referenceColor.y = _358.y;
    referenceColor.z = _358.z;
    out.finalColor = referenceColor;
    return out;
}

