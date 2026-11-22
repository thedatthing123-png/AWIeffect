// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/plasmav2.xml
// Original source comments and attribution:
// Procedural Plasma Isolines – AM official style
// - 3D value noise (hash + trilinear)
// - Fixed-iteration FBM (6 octaves)
// - No dynamic loops/arrays; only AM built-ins
// Background
// Isolines
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsedb351ee38a79
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float alpha;
};

struct refAM35_edb351ee38a79_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float rand3(thread const float3& st)
{
    return fract(sin(dot(st, float3(12.98980045318603515625, 78.233001708984375, 45.542999267578125))) * 43758.546875);
}

static inline __attribute__((always_inline))
float _noise3(thread const float3& st)
{
    float3 i = floor(st);
    float3 f = fract(st);
    float3 u = (f * f) * (float3(3.0) - (f * 2.0));
    float3 param = i;
    float a = rand3(param);
    float3 param_1 = i + float3(1.0, 0.0, 0.0);
    float b = rand3(param_1);
    float3 param_2 = i + float3(0.0, 1.0, 0.0);
    float c = rand3(param_2);
    float3 param_3 = i + float3(1.0, 1.0, 0.0);
    float d = rand3(param_3);
    float3 param_4 = i + float3(0.0, 0.0, 1.0);
    float e = rand3(param_4);
    float3 param_5 = i + float3(1.0, 0.0, 1.0);
    float f0 = rand3(param_5);
    float3 param_6 = i + float3(0.0, 1.0, 1.0);
    float g = rand3(param_6);
    float3 param_7 = i + float3(1.0);
    float h = rand3(param_7);
    float bottom = mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    float top = mix(mix(e, f0, u.x), mix(g, h, u.x), u.y);
    return mix(bottom, top, u.z);
}

static inline __attribute__((always_inline))
float fbm6(thread float3& st)
{
    float v = 0.0;
    float amp = 0.5;
    float3 param = st;
    v += (amp * _noise3(param));
    st *= 2.0;
    amp *= 0.5;
    float3 param_1 = st;
    v += (amp * _noise3(param_1));
    st *= 2.0;
    amp *= 0.5;
    float3 param_2 = st;
    v += (amp * _noise3(param_2));
    st *= 2.0;
    amp *= 0.5;
    float3 param_3 = st;
    v += (amp * _noise3(param_3));
    st *= 2.0;
    amp *= 0.5;
    float3 param_4 = st;
    v += (amp * _noise3(param_4));
    st *= 2.0;
    amp *= 0.5;
    float3 param_5 = st;
    v += (amp * _noise3(param_5));
    return v;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsedb351ee38a79& _230, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _230.refScreen.xy;
    uv.x *= (_230.refScreen.x / fast::max(_230.refScreen.y, 1.0));
    float time = _230.refScreen.z * 0.25;
    float3 param = float3(uv * 0.800000011920928955078125, time);
    float _263 = fbm6(param);
    float bgN = _263;
    float3 col = float3(0.0500000007450580596923828125, 0.100000001490116119384765625, 0.20000000298023223876953125);
    col = mix(col, float3(0.100000001490116119384765625, 0.3499999940395355224609375, 0.4000000059604644775390625), float3(smoothstep(0.4000000059604644775390625, 0.60000002384185791015625, bgN)));
    col = mix(col, float3(0.699999988079071044921875, 0.5, 0.4000000059604644775390625), float3(smoothstep(0.64999997615814208984375, 0.800000011920928955078125, bgN)));
    float3 param_1 = float3(uv * 1.39999997615814208984375, time * 1.5);
    float _297 = fbm6(param_1);
    float lineN = _297;
    float iso = fract(lineN * 5.0);
    float dline = fast::min(iso, 1.0 - iso);
    float line = smoothstep(0.02999999932944774627685546875, 0.0199999995529651641845703125, dline);
    line += (smoothstep(0.100000001490116119384765625, 0.0, dline) * 0.4000000059604644775390625);
    float3 finalRGB = col + (float3(1.0, 0.949999988079071044921875, 0.89999997615814208984375) * line);
    float2 param_2 = gl_FragCoord.xy / _230.refScreen.xy;
    float a = texture2DCv(refInput, refInputSmplr, param_2).w * _230.alpha;
    referenceColor = float4(finalRGB, 1.0) * a;
}

fragment refAM35_edb351ee38a79_out refAM35_edb351ee38a79(constant ReferenceUniformsedb351ee38a79& _230 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_edb351ee38a79_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _230, refInput, refInputSmplr, referenceColor);
    bool _357 = any(isnan(referenceColor));
    bool _364;
    if (!_357)
    {
        _364 = any(isinf(referenceColor));
    }
    else
    {
        _364 = _357;
    }
    if (_364)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _377 = referenceColor;
    float3 _383 = fast::clamp(_377.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _383.x;
    referenceColor.y = _383.y;
    referenceColor.z = _383.z;
    out.finalColor = referenceColor;
    return out;
}

