// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s_warp_waves2.xml
// Original source comments and attribution:
// S_WarpWaves2 implementation for Alight Motion
// 2. Apply Z Dist (Zoom) from center
// 3. Calculate Displacement from Waves A and B
// 4. Combine Warps
// Offsets calculated in aspect-corrected space, divide X by aspect before adding to UV
// 5. Apply Wrap and Sample
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformse44c3753736ad
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float aAmplitude;
    char _m6_pad[12];
    float aFrequency;
    char _m7_pad[12];
    float aAngle;
    char _m8_pad[12];
    float aDisplaceAngle;
    char _m9_pad[12];
    float aPhaseStart;
    char _m10_pad[12];
    float aPhaseSpeed;
    char _m11_pad[12];
    float bAmplitude;
    char _m12_pad[12];
    float bFrequency;
    char _m13_pad[12];
    float bAngle;
    char _m14_pad[12];
    float bDisplaceAngle;
    char _m15_pad[12];
    float bPhaseStart;
    char _m16_pad[12];
    float bPhaseSpeed;
    char _m17_pad[12];
    float zDist;
    char _m18_pad[12];
    float wrapMode;
    char _m19_pad[12];
    uint followLayer;
    char _m20_pad[12];
    float blend;
};

struct refAM35_e44c3753736ad_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getWaveOffset(thread const float2& p, thread const float& amp, thread const float& freq, thread const float& angle, thread const float& dispAngle, thread const float& pStart, thread const float& pSpeed, thread const float& time, thread const float& aspect)
{
    float rad = angle * 0.01745329238474369049072265625;
    float dispRad = dispAngle * 0.01745329238474369049072265625;
    float2 waveDir = float2(cos(rad), sin(rad));
    float2 dispDir = float2(cos(rad + dispRad), sin(rad + dispRad));
    float2 pCorrected = p;
    pCorrected.x *= aspect;
    float phase = ((dot(pCorrected, waveDir) * freq) + pStart) + (time * pSpeed);
    return (dispDir * sin(phase)) * amp;
}

static inline __attribute__((always_inline))
float2 applyWrap(thread const float2& uv, thread const int& mode)
{
    if (mode == 1)
    {
        return fract(uv);
    }
    if (mode == 2)
    {
        return abs(mod(uv - float2(1.0), float2(2.0)) - float2(1.0));
    }
    return uv;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse44c3753736ad& _133, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 luv = (gl_FragCoord.xy - _133.refLayer.xy) / _133.refLayer.zw;
    float2 suv = gl_FragCoord.xy / _133.refScreen.xy;
    float2 uv;
    float2 aspect;
    if (_133.followLayer != 0u)
    {
        uv = luv;
        aspect = float2(_133.refLayer.z / _133.refLayer.w, 1.0);
    }
    else
    {
        uv = suv;
        aspect = float2(_133.refScreen.x / _133.refScreen.y, 1.0);
    }
    float2 p = ((uv - float2(0.5)) * _133.zDist) + float2(0.5);
    float2 param = p;
    float param_1 = _133.aAmplitude;
    float param_2 = _133.aFrequency;
    float param_3 = _133.aAngle;
    float param_4 = _133.aDisplaceAngle;
    float param_5 = _133.aPhaseStart;
    float param_6 = _133.aPhaseSpeed;
    float param_7 = _133.refScreen.z;
    float param_8 = aspect.x;
    float2 offsetA = getWaveOffset(param, param_1, param_2, param_3, param_4, param_5, param_6, param_7, param_8);
    float2 param_9 = p;
    float param_10 = _133.bAmplitude;
    float param_11 = _133.bFrequency;
    float param_12 = _133.bAngle;
    float param_13 = _133.bDisplaceAngle;
    float param_14 = _133.bPhaseStart;
    float param_15 = _133.bPhaseSpeed;
    float param_16 = _133.refScreen.z;
    float param_17 = aspect.x;
    float2 offsetB = getWaveOffset(param_9, param_10, param_11, param_12, param_13, param_14, param_15, param_16, param_17);
    float2 totalOffset = offsetA + offsetB;
    totalOffset.x /= aspect.x;
    float2 warpedUV = p + totalOffset;
    float2 param_18 = warpedUV;
    int param_19 = int(_133.wrapMode);
    warpedUV = applyWrap(param_18, param_19);
    float2 param_20 = warpedUV;
    float4 color = texture2DCv(refInput, refInputSmplr, param_20);
    float2 param_21 = suv;
    float4 base = texture2DCv(refInput, refInputSmplr, param_21);
    referenceColor = mix(base, color, float4(_133.blend));
}

fragment refAM35_e44c3753736ad_out refAM35_e44c3753736ad(constant ReferenceUniformse44c3753736ad& _133 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e44c3753736ad_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _133, refInput, refInputSmplr, referenceColor);
    bool _305 = any(isnan(referenceColor));
    bool _312;
    if (!_305)
    {
        _312 = any(isinf(referenceColor));
    }
    else
    {
        _312 = _305;
    }
    if (_312)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _326 = referenceColor;
    float3 _332 = fast::clamp(_326.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _332.x;
    referenceColor.y = _332.y;
    referenceColor.z = _332.z;
    out.finalColor = referenceColor;
    return out;
}

