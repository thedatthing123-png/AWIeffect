// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/fractalwarp4.xml
// Original source comments and attribution:
// Based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
// Four corners in 2D of a tile
// Initial values
//
// Loop of octaves
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse7efd76a1919d
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 offs;
    char _m6_pad[8];
    float2 parr;
    char _m7_pad[8];
    float mag;
    char _m8_pad[12];
    float scale;
    char _m9_pad[12];
    float intensity;
    char _m10_pad[12];
    uint screenSpace;
    char _m11_pad[12];
    float octaves;
};

struct refAM35_e7efd76a1919d_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float random(thread const float2& st)
{
    return fract(sin(dot(st, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& st)
{
    float2 i = floor(st);
    float2 f = fract(st);
    float2 param = i;
    float a = random(param);
    float2 param_1 = i + float2(1.0, 0.0);
    float b = random(param_1);
    float2 param_2 = i + float2(0.0, 1.0);
    float c = random(param_2);
    float2 param_3 = i + float2(1.0);
    float d = random(param_3);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    return (mix(a, b, u.x) + (((c - a) * u.y) * (1.0 - u.x))) + (((d - b) * u.x) * u.y);
}

static inline __attribute__((always_inline))
float fbm(thread float2& st, thread const float2& parallax, thread const int& octaveCount, thread const float& intens)
{
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 0.0;
    for (int i = 0; i < octaveCount; i++)
    {
        float2 param = st;
        value += (amplitude * _noise(param));
        st *= 2.0;
        st += parallax;
        amplitude *= intens;
    }
    return value;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse7efd76a1919d& _164, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 st;
    if (_164.screenSpace != 0u)
    {
        st = gl_FragCoord.xy / _164.refScreen.xy;
        st.x *= (_164.refScreen.x / _164.refScreen.y);
    }
    else
    {
        st = (gl_FragCoord.xy - _164.refLayer.xy) / _164.refLayer.zw;
        st.x *= (_164.refLayer.z / _164.refLayer.w);
    }
    st += ((_164.offs / float2(1000.0)) * float2(-1.0, 1.0));
    float2 parallax = (_164.parr / float2(200.0)) * float2(-1.0, 1.0);
    float2 param = (((st - float2(0.5)) * 3.0) * _164.scale) + float2(0.5);
    float2 param_1 = parallax;
    int param_2 = int(_164.octaves);
    float param_3 = _164.intensity;
    float _256 = fbm(param, param_1, param_2, param_3);
    float dx = _256;
    float2 param_4 = ((((st + float2(25.299999237060546875, 12.8999996185302734375)) - float2(0.5)) * 3.0) * _164.scale) + float2(0.5);
    float2 param_5 = parallax;
    int param_6 = int(_164.octaves);
    float param_7 = _164.intensity;
    float _279 = fbm(param_4, param_5, param_6, param_7);
    float dy = _279;
    float2 ref_sample;
    if (_164.screenSpace != 0u)
    {
        ref_sample = gl_FragCoord.xy / _164.refScreen.xy;
    }
    else
    {
        ref_sample = (gl_FragCoord.xy - _164.refLayer.xy) / _164.refLayer.zw;
    }
    ref_sample += (float2(dx - 0.5, dy - 0.5) * _164.mag);
    if (!(_164.screenSpace != 0u))
    {
        ref_sample = (float4(ref_sample, 0.0, 1.0) * _164.refLayerToScreen).xy;
    }
    float2 param_8 = ref_sample;
    referenceColor = texture2DCv(refInput, refInputSmplr, param_8);
}

fragment refAM35_e7efd76a1919d_out refAM35_e7efd76a1919d(constant ReferenceUniformse7efd76a1919d& _164 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e7efd76a1919d_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_164, gl_FragCoord, referenceColor, refInput, refInputSmplr);
    bool _341 = any(isnan(referenceColor));
    bool _348;
    if (!_341)
    {
        _348 = any(isinf(referenceColor));
    }
    else
    {
        _348 = _341;
    }
    if (_348)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _362 = referenceColor;
    float3 _368 = fast::clamp(_362.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _368.x;
    referenceColor.y = _368.y;
    referenceColor.z = _368.z;
    out.finalColor = referenceColor;
    return out;
}

