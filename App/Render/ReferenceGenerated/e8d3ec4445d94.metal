// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/sanchezae_cc.xml
// Original source comments and attribution:
// sanchezae_cc: Cinematic color correction
// Clarity
// Contrast
// Tint
// Bloom
// Vignette
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse8d3ec4445d94
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float contrast;
    char _m6_pad[12];
    float bloom;
    char _m7_pad[12];
    float clarity;
    char _m8_pad[12];
    float vignette;
    float4 highlightTint;
    float4 shadowTint;
    float tintStrength;
};

struct refAM35_e8d3ec4445d94_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 clarityPass(texture2d<float> tex, sampler texSmplr, thread const float2& uv, thread const float& strength)
{
    float2 param = uv;
    float3 orig = texture2DCv(tex, texSmplr, param).xyz;
    float2 param_1 = uv + float2(0.00200000009499490261077880859375, 0.0);
    float2 param_2 = uv - float2(0.00200000009499490261077880859375, 0.0);
    float2 param_3 = uv + float2(0.0, 0.00200000009499490261077880859375);
    float2 param_4 = uv - float2(0.0, 0.00200000009499490261077880859375);
    float3 sharp = (orig * 2.0) - ((((texture2DCv(tex, texSmplr, param_1).xyz + texture2DCv(tex, texSmplr, param_2).xyz) + texture2DCv(tex, texSmplr, param_3).xyz) + texture2DCv(tex, texSmplr, param_4).xyz) * 0.25);
    return mix(orig, sharp, float3(strength));
}

static inline __attribute__((always_inline))
float3 applyTint(thread const float3& color, thread const float3& shadows, thread const float3& highlights, thread const float& strength)
{
    float lum = dot(color, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float3 tint = mix(shadows, highlights, float3(smoothstep(0.20000000298023223876953125, 0.800000011920928955078125, lum)));
    return mix(color, tint, float3(strength));
}

static inline __attribute__((always_inline))
float3 bloomPass(texture2d<float> tex, sampler texSmplr, thread const float2& uv, thread const float& strength)
{
    float3 sum = float3(0.0);
    float w = 0.0;
    for (int x = -2; x <= 2; x++)
    {
        for (int y = -2; y <= 2; y++)
        {
            float k = exp((-float((x * x) + (y * y))) / 4.0);
            float2 param = uv + (float2(float(x), float(y)) * 0.0030000000260770320892333984375);
            sum += (texture2DCv(tex, texSmplr, param).xyz * k);
            w += k;
        }
    }
    return mix(float3(0.0), sum / float3(w), float3(strength));
}

static inline __attribute__((always_inline))
float vignetteMask(thread const float2& uv, thread const float& strength)
{
    float d = distance(uv, float2(0.5));
    return 1.0 - smoothstep(0.5 - (strength * 0.5), 0.75 - (strength * 0.5), d);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse8d3ec4445d94& _216, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _216.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = uv;
    float param_2 = _216.clarity;
    float3 color = clarityPass(refInput, refInputSmplr, param_1, param_2);
    color = ((color - float3(0.5)) * _216.contrast) + float3(0.5);
    float3 param_3 = color;
    float3 param_4 = _216.shadowTint.xyz;
    float3 param_5 = _216.highlightTint.xyz;
    float param_6 = _216.tintStrength;
    color = applyTint(param_3, param_4, param_5, param_6);
    float2 param_7 = uv;
    float param_8 = _216.bloom;
    color += bloomPass(refInput, refInputSmplr, param_7, param_8);
    float2 param_9 = uv;
    float param_10 = _216.vignette;
    float vign = vignetteMask(param_9, param_10);
    color *= vign;
    referenceColor = float4(color, src.w);
}

fragment refAM35_e8d3ec4445d94_out refAM35_e8d3ec4445d94(constant ReferenceUniformse8d3ec4445d94& _216 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8d3ec4445d94_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _216, refInput, refInputSmplr, referenceColor);
    bool _300 = any(isnan(referenceColor));
    bool _307;
    if (!_300)
    {
        _307 = any(isinf(referenceColor));
    }
    else
    {
        _307 = _300;
    }
    if (_307)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _320 = referenceColor;
    float3 _326 = fast::clamp(_320.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _326.x;
    referenceColor.y = _326.y;
    referenceColor.z = _326.z;
    out.finalColor = referenceColor;
    return out;
}

