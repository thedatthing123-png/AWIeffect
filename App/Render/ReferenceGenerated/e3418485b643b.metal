// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/Adamagedots.xml
// Original source comments and attribution:
// Procedural film damage dots
// pixel space for consistent radius
// Convert density per 1000x1000 pixels to expected cell size in px
// Grid cell in pixel space
// Random jittered dot center per cell
// Drift over time for organic motion
// Circle SDF
// Sparse flicker to emulate film dust popping
// Normal (over)
// Add
// Screen
// Multiply
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse3418485b643b
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 dotColor;
    float dotSize;
    char _m7_pad[12];
    float softness;
    char _m8_pad[12];
    float density;
    char _m9_pad[12];
    float opacity;
    char _m10_pad[12];
    float speed;
    char _m11_pad[12];
    float flicker;
    char _m12_pad[12];
    float seed;
    char _m13_pad[12];
    int blendMode;
    char _m14_pad[12];
    float mixAmount;
};

struct refAM35_e3418485b643b_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 hash22(thread const float2& p, constant ReferenceUniformse3418485b643b& _52)
{
    float n = sin(dot(p, float2(12.98980045318603515625, 78.233001708984375)) + _52.seed);
    return fract(float2(262144.0, 32768.0) * n);
}

static inline __attribute__((always_inline))
float hash12(thread const float2& p, constant ReferenceUniformse3418485b643b& _52)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125)) + _52.seed) * 43758.546875);
}

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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse3418485b643b& _52, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _52.refScreen.xy;
    float2 px = uv * _52.refScreen.xy;
    float D = fast::max(_52.density, 0.001000000047497451305389404296875);
    float area = _52.refScreen.x * _52.refScreen.y;
    float cells = D * (area / 1000000.0);
    float cellSize = sqrt(fast::max(area / fast::max(cells, 1.0), 1.0));
    float2 cell = floor(px / float2(cellSize));
    float2 cellOrigin = cell * cellSize;
    float2 param = cell;
    float2 rnd = hash22(param, _52);
    float t = _52.refScreen.z * _52.speed;
    float2 drift = (((rnd - float2(0.5)) * 0.3499999940395355224609375) * cellSize) * t;
    float2 center = (cellOrigin + (rnd * cellSize)) + drift;
    float r = fast::max(_52.dotSize, 0.0);
    float d = length(px - center);
    float feather = mix(0.001000000047497451305389404296875, 0.800000011920928955078125, fast::clamp(_52.softness, 0.0, 1.0));
    float m = 1.0 - smoothstep(r, r * (1.0 + feather), d);
    float2 param_1 = cell + float2(floor(t * 7.0));
    float f = mix(1.0, hash12(param_1, _52), _52.flicker);
    m *= f;
    float2 param_2 = uv;
    float4 base = src(param_2, refInput, refInputSmplr);
    float3 dotRGB = (_52.dotColor.xyz * _52.opacity) * m;
    int bm = _52.blendMode;
    float3 outRGB;
    if (bm == 1)
    {
        float3 mixed = mix(base.xyz, dotRGB, float3(fast::clamp(_52.mixAmount, 0.0, 1.0)));
        outRGB = mixed;
    }
    else
    {
        if (bm == 2)
        {
            outRGB = base.xyz + (dotRGB * fast::clamp(_52.mixAmount, 0.0, 1.0));
        }
        else
        {
            if (bm == 3)
            {
                float3 scr = float3(1.0) - ((float3(1.0) - base.xyz) * (float3(1.0) - fast::clamp(dotRGB, float3(0.0), float3(100.0))));
                outRGB = mix(base.xyz, scr, float3(fast::clamp(_52.mixAmount, 0.0, 1.0)));
            }
            else
            {
                float3 mul = base.xyz * (float3(1.0 - m) + dotRGB);
                outRGB = mix(base.xyz, mul, float3(fast::clamp(_52.mixAmount, 0.0, 1.0)));
            }
        }
    }
    referenceColor = float4(outRGB, base.w);
}

fragment refAM35_e3418485b643b_out refAM35_e3418485b643b(constant ReferenceUniformse3418485b643b& _52 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e3418485b643b_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _52, gl_FragCoord, referenceColor);
    bool _332 = any(isnan(referenceColor));
    bool _339;
    if (!_332)
    {
        _339 = any(isinf(referenceColor));
    }
    else
    {
        _339 = _332;
    }
    if (_339)
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

