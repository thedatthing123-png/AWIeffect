// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s_wipepixelate.xml
// Original source comments and attribution:
// S_WipePixelate - wipe with pixel-block dissolve edge
// --- Build wipe direction from angle ---
// --- Pixel block grid ---
// Frequency = number of blocks across; Chunky enlarges blocks.
// Per-block random value (seeded)
// --- Wipe coordinate measured at the block center ---
// Edge band: each block flips at a slightly different point,
// scattered by its random value across edgeWidth -> pixel dissolve.
// wipePercent 0 -> fully present, 1 -> fully wiped
// 1 = block removed
// Direction handling
// Wipe Off to Bg
// 1 = show source
// Wipe On from Bg
// source appears as wipe grows
// --- Show Wipe matte preview ---
// --- Composite source over chosen background ---
// Black
// None / transparent
// Premultiplied-safe blend of source vs background by reveal mask
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL radians() function
template<typename T>
inline T radians(T d)
{
    return d * T(0.01745329251);
}

struct ReferenceUniformse8e0a6f88c6f1
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int transitionDir;
    char _m6_pad[12];
    int background;
    char _m7_pad[12];
    float wipePercent;
    char _m8_pad[12];
    float edgeWidth;
    char _m9_pad[12];
    float angle;
    char _m10_pad[12];
    float pixelFrequency;
    char _m11_pad[12];
    float pixelRelWidth;
    char _m12_pad[12];
    float chunky;
    char _m13_pad[12];
    float seed;
    char _m14_pad[12];
    float showWipe;
};

struct refAM35_e8e0a6f88c6f1_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash(thread const float2& p)
{
    return fract(sin(dot(p, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse8e0a6f88c6f1& _49, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 uv = gl_FragCoord.xy / _49.refScreen.xy;
    float ang = radians(_49.angle);
    float2 dir = float2(cos(ang), sin(ang));
    float freq = _49.pixelFrequency / (1.0 + (_49.chunky * 4.0));
    float2 cells = float2(freq / fast::max(_49.pixelRelWidth, 0.001000000047497451305389404296875), freq);
    float2 block = floor(uv * cells);
    float2 blockCenter = (block + float2(0.5)) / cells;
    float2 param = block + float2(_49.seed * 1000.0);
    float rnd = hash(param);
    float coord = dot(blockCenter - float2(0.5), dir) + 0.5;
    float ew = fast::max(_49.edgeWidth, 9.9999997473787516355514526367188e-05);
    float threshold = coord + ((rnd - 0.5) * ew);
    float wiped = step(threshold, _49.wipePercent);
    float reveal;
    if (_49.transitionDir == 0)
    {
        reveal = 1.0 - wiped;
    }
    else
    {
        reveal = wiped;
    }
    if (_49.showWipe > 0.5)
    {
        referenceColor = float4(float3(reveal), 1.0);
        return;
    }
    float2 param_1 = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param_1);
    float4 bg;
    if (_49.background == 1)
    {
        bg = float4(0.0, 0.0, 0.0, 1.0);
    }
    else
    {
        bg = float4(0.0);
    }
    float4 outCol = mix(bg, src, float4(reveal));
    referenceColor = outCol;
}

fragment refAM35_e8e0a6f88c6f1_out refAM35_e8e0a6f88c6f1(constant ReferenceUniformse8e0a6f88c6f1& _49 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8e0a6f88c6f1_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _49, referenceColor, refInput, refInputSmplr);
    bool _198 = any(isnan(referenceColor));
    bool _205;
    if (!_198)
    {
        _205 = any(isinf(referenceColor));
    }
    else
    {
        _205 = _198;
    }
    if (_205)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _220 = referenceColor;
    float3 _226 = fast::clamp(_220.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _226.x;
    referenceColor.y = _226.y;
    referenceColor.z = _226.z;
    out.finalColor = referenceColor;
    return out;
}

