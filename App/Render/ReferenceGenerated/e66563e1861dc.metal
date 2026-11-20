// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_s_glow_noise.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse66563e1861dc
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float threshold;
    char _m6_pad[12];
    float radius;
    char _m7_pad[12];
    float noiseScale;
    char _m8_pad[12];
    float evolution;
    char _m9_pad[12];
    float noiseAmount;
    char _m10_pad[12];
    float intensity;
    float4 glowColor;
};

struct refAM35_e66563e1861dc_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 aePx(constant ReferenceUniformse66563e1861dc& _43)
{
    return float2(1.0) / fast::max(_43.refScreen.xy, float2(1.0));
}

static inline __attribute__((always_inline))
float aeLuma(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float aeHash(thread const float2& p)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse66563e1861dc& _43, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _43.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float2 p = aePx(_43) * _43.radius;
    float blur = 0.0;
    float2 param_1 = uv + float2(p.x, 0.0);
    float3 param_2 = texture2DCv(refInput, refInputSmplr, param_1).xyz;
    blur += aeLuma(param_2);
    float2 param_3 = uv + float2(-p.x, 0.0);
    float3 param_4 = texture2DCv(refInput, refInputSmplr, param_3).xyz;
    blur += aeLuma(param_4);
    float2 param_5 = uv + float2(0.0, p.y);
    float3 param_6 = texture2DCv(refInput, refInputSmplr, param_5).xyz;
    blur += aeLuma(param_6);
    float2 param_7 = uv + float2(0.0, -p.y);
    float3 param_8 = texture2DCv(refInput, refInputSmplr, param_7).xyz;
    blur += aeLuma(param_8);
    float2 param_9 = uv + p;
    float3 param_10 = texture2DCv(refInput, refInputSmplr, param_9).xyz;
    blur += aeLuma(param_10);
    float2 param_11 = uv - p;
    float3 param_12 = texture2DCv(refInput, refInputSmplr, param_11).xyz;
    blur += aeLuma(param_12);
    blur *= 0.16666670143604278564453125;
    float mask = smoothstep(_43.threshold, fast::min(_43.threshold + 0.20000000298023223876953125, 1.0), blur);
    float2 param_13 = floor(uv * _43.noiseScale) + float2(_43.evolution + (_43.refScreen.z * 0.25));
    float n = aeHash(param_13);
    mask *= mix(1.0, n, _43.noiseAmount);
    float3 result = src.xyz + (((_43.glowColor.xyz * _43.glowColor.w) * mask) * _43.intensity);
    referenceColor = float4(result, src.w);
}

fragment refAM35_e66563e1861dc_out refAM35_e66563e1861dc(constant ReferenceUniformse66563e1861dc& _43 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e66563e1861dc_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_43, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _245 = any(isnan(referenceColor));
    bool _252;
    if (!_245)
    {
        _252 = any(isinf(referenceColor));
    }
    else
    {
        _252 = _245;
    }
    if (_252)
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

