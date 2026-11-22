// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/negative.xml
// Original source comments and attribution:
// --- Invert ---
// --- Luminance-weighted grayscale (perceptual) ---
// --- Sharpening via unsharp mask on grayscale ---
// --- Brightness & Contrast ---
// --- Black/White point remap ---
// --- Film grain ---
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse8d7c496ca902
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float contrast;
    char _m6_pad[12];
    float brightness;
    char _m7_pad[12];
    float blackPoint;
    char _m8_pad[12];
    float whitePoint;
    char _m9_pad[12];
    float sharpness;
    char _m10_pad[12];
    float grainAmount;
};

struct refAM35_e8d7c496ca902_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float hash(thread const float2& p)
{
    float3 p3 = fract(p.xyx * 0.103100001811981201171875);
    p3 += float3(dot(p3, p3.yzx + float3(33.3300018310546875)));
    return fract((p3.x + p3.y) * p3.z);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse8d7c496ca902& _71, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _71.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 inverted = float3(1.0) - src.xyz;
    float lum = dot(inverted, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float str = 0.00150000001303851604461669921875;
    float2 param_1 = uv + float2(-str, str);
    float lumTL = dot(float3(1.0) - texture2DCv(refInput, refInputSmplr, param_1).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_2 = uv + float2(0.0, str);
    float lumTM = dot(float3(1.0) - texture2DCv(refInput, refInputSmplr, param_2).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_3 = uv + float2(str);
    float lumTR = dot(float3(1.0) - texture2DCv(refInput, refInputSmplr, param_3).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_4 = uv + float2(-str, 0.0);
    float lumML = dot(float3(1.0) - texture2DCv(refInput, refInputSmplr, param_4).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_5 = uv + float2(str, 0.0);
    float lumMR = dot(float3(1.0) - texture2DCv(refInput, refInputSmplr, param_5).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_6 = uv + float2(-str, -str);
    float lumBL = dot(float3(1.0) - texture2DCv(refInput, refInputSmplr, param_6).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_7 = uv + float2(0.0, -str);
    float lumBM = dot(float3(1.0) - texture2DCv(refInput, refInputSmplr, param_7).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_8 = uv + float2(str, -str);
    float lumBR = dot(float3(1.0) - texture2DCv(refInput, refInputSmplr, param_8).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float blurred = (((((((lumTL + lumTM) + lumTR) + lumML) + lumMR) + lumBL) + lumBM) + lumBR) / 8.0;
    lum += ((lum - blurred) * _71.sharpness);
    lum += _71.brightness;
    lum = ((lum - 0.5) * _71.contrast) + 0.5;
    lum = (lum - _71.blackPoint) / fast::max(_71.whitePoint - _71.blackPoint, 0.001000000047497451305389404296875);
    lum = fast::clamp(lum, 0.0, 1.0);
    float2 param_9 = (uv * _71.refScreen.xy) + float2(fract(_71.refScreen.z * 100.0));
    float grain = (hash(param_9) - 0.5) * _71.grainAmount;
    lum = fast::clamp(lum + grain, 0.0, 1.0);
    referenceColor = float4(float3(lum), src.w);
}

fragment refAM35_e8d7c496ca902_out refAM35_e8d7c496ca902(constant ReferenceUniformse8d7c496ca902& _71 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8d7c496ca902_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _71, refInput, refInputSmplr, referenceColor);
    bool _288 = any(isnan(referenceColor));
    bool _295;
    if (!_288)
    {
        _295 = any(isinf(referenceColor));
    }
    else
    {
        _295 = _288;
    }
    if (_295)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _308 = referenceColor;
    float3 _314 = fast::clamp(_308.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _314.x;
    referenceColor.y = _314.y;
    referenceColor.z = _314.z;
    out.finalColor = referenceColor;
    return out;
}

