// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/ink_splash.xml
// Original source comments and attribution:
// Random hash function
// 2D Value Noise
// Fractal Brownian Motion (6 octaves)
// Rotation matrix to reduce grid artifacts
// cos(0.5), sin(0.5)
// --- Domain Warping ---
// Final noise value based on warped coordinates
// --- Shape Creation ---
// Combine radial with warped noise
// expansion * 0.5 replicates the iResolution based sizing
// --- Coloring ---
// Using a slightly higher minimum for bleed to prevent hard artifacts
// In Alpha mode, we treat the ink as the layer visibility
// In Color mode, we mix the Paper and Ink colors
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsedd3f3773971b
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float expansion;
    char _m6_pad[12];
    float roughness;
    char _m7_pad[12];
    float bleed;
    char _m8_pad[12];
    float speed;
    char _m9_pad[12];
    float seed;
    float4 inkColor;
    float4 paperColor;
    uint alphaMode;
};

struct refAM35_edd3f3773971b_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash(thread float2& p)
{
    p = fract(p * float2(123.339996337890625, 456.209991455078125));
    p += float2(dot(p, p + float2(45.31999969482421875)));
    return fract(p.x * p.y);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i + float2(0.0);
    float _84 = hash(param);
    float a = _84;
    float2 param_1 = i + float2(1.0, 0.0);
    float _91 = hash(param_1);
    float b = _91;
    float2 param_2 = i + float2(0.0, 1.0);
    float _97 = hash(param_2);
    float c = _97;
    float2 param_3 = i + float2(1.0);
    float _103 = hash(param_3);
    float d = _103;
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static inline __attribute__((always_inline))
float fbm(thread float2& p)
{
    float total = 0.0;
    float amp = 0.5;
    float2x2 rot = float2x2(float2(0.877582013607025146484375, 0.4794259965419769287109375), float2(-0.4794259965419769287109375, 0.877582013607025146484375));
    for (int i = 0; i < 6; i++)
    {
        float2 param = p;
        total += (_noise(param) * amp);
        p = ((rot * p) * 2.0) + float2(100.0);
        amp *= 0.5;
    }
    return total;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsedd3f3773971b& _174, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = ((gl_FragCoord.xy - _174.refLayer.xy) / _174.refLayer.zw) - float2(0.5);
    uv.x *= (_174.refLayer.z / _174.refLayer.w);
    float t = (_174.refScreen.z * _174.speed) + _174.seed;
    float2 q = float2(0.0);
    float2 param = (uv + float2(0.0)) + float2(0.0500000007450580596923828125 * t);
    float _218 = fbm(param);
    q.x = _218;
    float2 param_1 = (uv + float2(5.19999980926513671875, 1.2999999523162841796875)) + float2(0.0500000007450580596923828125 * t);
    float _230 = fbm(param_1);
    q.y = _230;
    float2 r = float2(0.0);
    float2 param_2 = ((uv + (q * 4.0)) + float2(1.7000000476837158203125, 9.19999980926513671875)) + float2(0.1500000059604644775390625 * t);
    float _248 = fbm(param_2);
    r.x = _248;
    float2 param_3 = ((uv + (q * 4.0)) + float2(8.30000019073486328125, 2.7999999523162841796875)) + float2(0.12600000202655792236328125 * t);
    float _264 = fbm(param_3);
    r.y = _264;
    float2 param_4 = uv + (r * 4.0);
    float _272 = fbm(param_4);
    float f = _272;
    float dist = length(uv);
    float inkShape = ((_174.expansion * 0.300000011920928955078125) - dist) + ((f - 0.5) * (_174.roughness * 0.20000000298023223876953125));
    float safeBleed = fast::max(_174.bleed, 0.001000000047497451305389404296875);
    float mask = smoothstep(-safeBleed, 0.0, inkShape);
    float2 param_5 = gl_FragCoord.xy / _174.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_5);
    if (_174.alphaMode != 0u)
    {
        referenceColor = float4(texColor.xyz, texColor.w * mask);
    }
    else
    {
        float3 finalCol = mix(_174.paperColor.xyz, _174.inkColor.xyz, float3(mask));
        referenceColor = float4(finalCol, 1.0);
    }
}

fragment refAM35_edd3f3773971b_out refAM35_edd3f3773971b(constant ReferenceUniformsedd3f3773971b& _174 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_edd3f3773971b_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _174, refInput, refInputSmplr, referenceColor);
    bool _358 = any(isnan(referenceColor));
    bool _365;
    if (!_358)
    {
        _365 = any(isinf(referenceColor));
    }
    else
    {
        _365 = _358;
    }
    if (_365)
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

