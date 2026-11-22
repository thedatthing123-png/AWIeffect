// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/ Aflare.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse089fe308a7e7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float level0;
    char _m6_pad[12];
    float iterations;
    char _m7_pad[12];
    float radiusScale;
    char _m8_pad[12];
    float basePower;
    char _m9_pad[12];
    float peakPower;
    char _m10_pad[12];
    float falloffExp;
    char _m11_pad[12];
    float strength;
    char _m12_pad[12];
    float gamma;
    float4 tintColor;
    float bloomThreshold;
    char _m15_pad[12];
    float bloomRadius;
    char _m16_pad[12];
    float bloomStrength;
    char _m17_pad[12];
    int blendMode;
    char _m18_pad[12];
    float mixAmount;
};

struct refAM35_e089fe308a7e7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 src(thread const float2& uv, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = uv;
    return texture2DCv(refInput, refInputSmplr, param);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse089fe308a7e7& _44, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _44.refScreen.xy;
    float2 param = uv;
    float4 srcCol = src(param, refInput, refInputSmplr);
    float3 hdr = srcCol.xyz;
    float3 accum = float3(floor(_44.level0 + powr(hdr.x, _44.basePower)));
    float c = fast::max(_44.iterations, 1.0);
    float2 r = _44.refScreen.xy * fast::max(_44.radiusScale, 0.001000000047497451305389404296875);
    int samples = int(_44.iterations);
    for (int i = 0; i < 2048; i++)
    {
        if (i >= samples)
        {
            break;
        }
        float it = float(i);
        float w = 1.0 - (it / c);
        float2 param_1 = uv + float2(it / r.x, 0.0);
        float texL = src(param_1, refInput, refInputSmplr).x;
        float2 param_2 = uv - float2(it / r.x, 0.0);
        float texR = src(param_2, refInput, refInputSmplr).x;
        accum += float3(floor(_44.level0 + powr(fast::max(texL, texR), _44.peakPower)) * w);
        float2 param_3 = uv + float2(0.0, it / r.y);
        float texU = src(param_3, refInput, refInputSmplr).x;
        float2 param_4 = uv - float2(0.0, it / r.y);
        float texD = src(param_4, refInput, refInputSmplr).x;
        accum += float3(floor(_44.level0 + powr(fast::max(texU, texD), _44.peakPower)) * w);
        float ring = smoothstep(0.5, 0.75, length(float2(it / r.x, it / r.y))) / c;
        accum += float3(powr(ring, 1.0 / fast::max(_44.falloffExp, 0.001000000047497451305389404296875)));
    }
    float3 effectRGB = powr(accum * _44.strength, float3(1.0 / fast::max(_44.gamma, 9.9999999747524270787835121154785e-07)));
    effectRGB *= _44.tintColor.xyz;
    float3 luma = float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625);
    float lum = dot(srcCol.xyz, luma);
    float gate = smoothstep(_44.bloomThreshold, 1.0, lum);
    float3 b0 = srcCol.xyz * gate;
    float2 texel = float2(_44.bloomRadius) / fast::max(_44.refScreen.xy, float2(1.0));
    float3 b = b0;
    float2 param_5 = uv + (texel * float2(1.0, 0.0));
    float3 s1 = src(param_5, refInput, refInputSmplr).xyz;
    b += (s1 * smoothstep(_44.bloomThreshold, 1.0, dot(s1, luma)));
    float2 param_6 = uv + (texel * float2(-1.0, 0.0));
    float3 s2 = src(param_6, refInput, refInputSmplr).xyz;
    b += (s2 * smoothstep(_44.bloomThreshold, 1.0, dot(s2, luma)));
    float2 param_7 = uv + (texel * float2(0.0, 1.0));
    float3 s3 = src(param_7, refInput, refInputSmplr).xyz;
    b += (s3 * smoothstep(_44.bloomThreshold, 1.0, dot(s3, luma)));
    float2 param_8 = uv + (texel * float2(0.0, -1.0));
    float3 s4 = src(param_8, refInput, refInputSmplr).xyz;
    b += (s4 * smoothstep(_44.bloomThreshold, 1.0, dot(s4, luma)));
    float2 param_9 = uv + (texel * float2(1.0));
    float3 s5 = src(param_9, refInput, refInputSmplr).xyz;
    b += (s5 * smoothstep(_44.bloomThreshold, 1.0, dot(s5, luma)));
    float2 param_10 = uv + (texel * float2(-1.0, 1.0));
    float3 s6 = src(param_10, refInput, refInputSmplr).xyz;
    b += (s6 * smoothstep(_44.bloomThreshold, 1.0, dot(s6, luma)));
    float2 param_11 = uv + (texel * float2(1.0, -1.0));
    float3 s7 = src(param_11, refInput, refInputSmplr).xyz;
    b += (s7 * smoothstep(_44.bloomThreshold, 1.0, dot(s7, luma)));
    float2 param_12 = uv + (texel * float2(-1.0));
    float3 s8 = src(param_12, refInput, refInputSmplr).xyz;
    b += (s8 * smoothstep(_44.bloomThreshold, 1.0, dot(s8, luma)));
    b *= 0.111111111938953399658203125;
    float3 bloom = b * _44.bloomStrength;
    int bm = _44.blendMode;
    float3 outRGB;
    if (bm == 1)
    {
        outRGB = effectRGB;
    }
    else
    {
        if (bm == 2)
        {
            outRGB = srcCol.xyz + effectRGB;
        }
        else
        {
            if (bm == 3)
            {
                outRGB = float3(1.0) - ((float3(1.0) - srcCol.xyz) * (float3(1.0) - effectRGB));
            }
            else
            {
                outRGB = mix(effectRGB, srcCol.xyz, float3(srcCol.w));
            }
        }
    }
    outRGB += bloom;
    float3 mixed = mix(srcCol.xyz, outRGB, float3(fast::clamp(_44.mixAmount, 0.0, 1.0)));
    referenceColor = float4(mixed, srcCol.w);
}

fragment refAM35_e089fe308a7e7_out refAM35_e089fe308a7e7(constant ReferenceUniformse089fe308a7e7& _44 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e089fe308a7e7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _44, referenceColor);
    bool _517 = any(isnan(referenceColor));
    bool _524;
    if (!_517)
    {
        _524 = any(isinf(referenceColor));
    }
    else
    {
        _524 = _517;
    }
    if (_524)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _537 = referenceColor;
    float3 _543 = fast::clamp(_537.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _543.x;
    referenceColor.y = _543.y;
    referenceColor.z = _543.z;
    out.finalColor = referenceColor;
    return out;
}

