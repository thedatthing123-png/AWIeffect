// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s_glow_aura.xml
// Original source comments and attribution:
// S_GlowAura implementation for Alight Motion
// Base cycling colors
// Sharp interference bands
// 2. Generate Distance Influence
// Sampling offset corrected by aspect to keep it circular
// 3. Twist & Phase Calculation
// 4. Color Generation
// Fade aura based on distance
// 5. Composite (Screen Blend)
// Keep text interior bright
// Mixing based on blend parameter
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse18058eae046e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float brightness;
    char _m6_pad[12];
    float threshold;
    char _m7_pad[12];
    float glowWidth;
    char _m8_pad[12];
    float frequency;
    char _m9_pad[12];
    float phaseSpeed;
    char _m10_pad[12];
    float twist;
    char _m11_pad[12];
    uint followLayer;
    char _m12_pad[12];
    float blend;
};

struct refAM35_e18058eae046e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float getLuma(thread const float3& rgb)
{
    return dot(rgb, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float3 auraPalette(thread const float& t)
{
    float3 col = float3(0.5) + (cos((float3(t) + float3(0.0, 0.3300000131130218505859375, 0.670000016689300537109375)) * 6.28318023681640625) * 0.5);
    float bands = sin(t * 15.0);
    col *= (0.800000011920928955078125 + (0.4000000059604644775390625 * smoothstep(-0.20000000298023223876953125, 0.20000000298023223876953125, bands)));
    return col;
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse18058eae046e& _86, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 luv = (gl_FragCoord.xy - _86.refLayer.xy) / _86.refLayer.zw;
    float2 suv = gl_FragCoord.xy / _86.refScreen.xy;
    float2 uv;
    float2 aspect;
    if (_86.followLayer != 0u)
    {
        uv = luv;
        aspect = float2(_86.refLayer.z / _86.refLayer.w, 1.0);
    }
    else
    {
        uv = suv;
        aspect = float2(_86.refScreen.x / _86.refScreen.y, 1.0);
    }
    float2 p = (uv - float2(0.5)) * aspect;
    float2 param = uv;
    float4 source = texture2DCv(refInput, refInputSmplr, param);
    float dist = 0.0;
    for (int i = 0; i < 16; i++)
    {
        float sampleAngle = float(i) * 0.3926990926265716552734375;
        float2 sampleDir = float2(cos(sampleAngle), sin(sampleAngle));
        float2 offset = (sampleDir * _86.glowWidth) * 0.100000001490116119384765625;
        offset.x /= aspect.x;
        float2 sampleUV = uv + offset;
        float2 param_1 = sampleUV;
        float3 param_2 = texture2DCv(refInput, refInputSmplr, param_1).xyz;
        float sampleLuma = getLuma(param_2);
        dist += smoothstep(_86.threshold, 1.0, sampleLuma);
    }
    dist /= 16.0;
    float angle = precise::atan2(p.y, p.x);
    float timePhase = _86.refScreen.z * _86.phaseSpeed;
    float auraMap = ((dist * _86.frequency) + ((angle / 3.1415927410125732421875) * _86.twist)) + timePhase;
    float param_3 = auraMap + 0.20000000298023223876953125;
    float param_4 = auraMap + 0.100000001490116119384765625;
    float param_5 = auraMap + 0.0;
    float3 auraCol = float3(auraPalette(param_3).x, auraPalette(param_4).y, auraPalette(param_5).z);
    float mask = smoothstep(0.0, 0.5, dist) * (1.0 - smoothstep(0.5, 1.2000000476837158203125, dist));
    auraCol *= (mask * _86.brightness);
    float3 result = float3(1.0) - ((float3(1.0) - source.xyz) * (float3(1.0) - auraCol));
    float3 param_6 = source.xyz;
    if (getLuma(param_6) > 0.800000011920928955078125)
    {
        result = source.xyz;
    }
    float4 finalColor = float4(result, source.w);
    referenceColor = mix(source, finalColor, float4(_86.blend));
}

fragment refAM35_e18058eae046e_out refAM35_e18058eae046e(constant ReferenceUniformse18058eae046e& _86 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e18058eae046e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _86, refInput, refInputSmplr, referenceColor);
    bool _311 = any(isnan(referenceColor));
    bool _318;
    if (!_311)
    {
        _318 = any(isinf(referenceColor));
    }
    else
    {
        _318 = _311;
    }
    if (_318)
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

