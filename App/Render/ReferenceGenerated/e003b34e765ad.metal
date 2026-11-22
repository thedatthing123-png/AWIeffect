// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/pro_lens_flare.xml
// Original source comments and attribution:
// Utility: Rotate Hue of a color
// Utility: Noise for pseudo-randomness
// Procedural Lens Flare
// Base Palette
// Determine Active Features based on Type
// Type 0: Clean Glow
// Type 1: Anamorphic
// Type 2: Starburst
// Type 3: Sci-Fi / Complex
// Combine with manual sliders
// 1. SOFT CORE GLOW
// 2. STARBURST
// 3. ANAMORPHIC STREAK
// 4. LENS GHOSTS
// Center UVs
// Light position
// Background
// Add Flare
// Tone Mapping (ACES-like)
// Gamma
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse003b34e765ad
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float posX;
    char _m6_pad[12];
    float posY;
    char _m7_pad[12];
    float intensity;
    char _m8_pad[12];
    float flareHue;
    char _m9_pad[12];
    float flareType;
    char _m10_pad[12];
    float glowSize;
    char _m11_pad[12];
    float ghostStr;
    char _m12_pad[12];
    float streakStr;
    char _m13_pad[12];
    float starburstStr;
};

struct refAM35_e003b34e765ad_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 hueShift(thread float3& col, thread const float& shift)
{
    float3 P = float3(0.557349979877471923828125) * dot(float3(0.557349979877471923828125), col);
    float3 U = col - P;
    float3 V = cross(float3(0.557349979877471923828125), U);
    col = ((U * cos(shift * 6.283199787139892578125)) + (V * sin(shift * 6.283199787139892578125))) + P;
    return fast::max(float3(0.0), col);
}

static inline __attribute__((always_inline))
float hash(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

static inline __attribute__((always_inline))
float3 lensFlare(thread const float2& uv, thread const float2& pos, constant ReferenceUniformse003b34e765ad& _107)
{
    float2 main = uv - pos;
    float dist = length(main);
    float ang = precise::atan2(main.y, main.x);
    float3 f = float3(0.0);
    float3 param = float3(1.0, 0.89999997615814208984375, 0.800000011920928955078125);
    float param_1 = _107.flareHue;
    float3 _115 = hueShift(param, param_1);
    float3 colCore = _115;
    float3 param_2 = float3(0.800000011920928955078125, 0.5, 0.20000000298023223876953125);
    float param_3 = _107.flareHue;
    float3 _124 = hueShift(param_2, param_3);
    float3 colStreak = _124;
    float3 param_4 = float3(0.89999997615814208984375, 0.800000011920928955078125, 1.0);
    float param_5 = _107.flareHue;
    float3 _131 = hueShift(param_4, param_5);
    float3 colGhost = _131;
    int type = int(floor(_107.flareType + 0.5));
    float activeStreak = 0.0;
    float activeStar = 0.0;
    float activeGhosts = 0.0;
    if (type == 0)
    {
        activeStreak = 0.0;
        activeStar = 0.0;
        activeGhosts = 0.0;
    }
    else
    {
        if (type == 1)
        {
            activeStreak = 1.0;
            activeStar = 0.0;
            activeGhosts = 0.20000000298023223876953125;
        }
        else
        {
            if (type == 2)
            {
                activeStreak = 0.0;
                activeStar = 1.0;
                activeGhosts = 0.100000001490116119384765625;
            }
            else
            {
                activeStreak = 0.300000011920928955078125;
                activeStar = 0.20000000298023223876953125;
                activeGhosts = 1.0;
            }
        }
    }
    float sStr = _107.streakStr * activeStreak;
    float stStr = _107.starburstStr * activeStar;
    float gStr = _107.ghostStr * activeGhosts;
    float core = 1.0 / ((dist * (20.0 / _107.glowSize)) + 0.5);
    core = powr(core, 2.0);
    f += ((colCore * core) * 2.0);
    if (stStr > 0.00999999977648258209228515625)
    {
        float rays = (abs(cos(ang * 3.0)) * 0.5) + (abs(cos(ang * 12.0)) * 0.20000000298023223876953125);
        rays += (smoothstep(0.0, 1.0, abs(sin(ang * 100.0))) * 0.100000001490116119384765625);
        rays *= (0.20000000298023223876953125 / (dist + 0.100000001490116119384765625));
        f += ((colCore * rays) * stStr);
    }
    if (sStr > 0.00999999977648258209228515625)
    {
        float vDist = abs(main.y);
        float streak = exp((-vDist) * 40.0);
        streak *= smoothstep(1.5, 0.100000001490116119384765625, abs(main.x));
        f += ((colStreak * streak) * sStr);
    }
    if (gStr > 0.00999999977648258209228515625)
    {
        float2 ghostVec = (-pos) * 0.5;
        for (float i = 0.0; i < 5.0; i += 1.0)
        {
            float t = fract((i * 0.3499999940395355224609375) + 0.300000011920928955078125);
            float2 gPos = pos + (ghostVec * (t * 4.0));
            float param_6 = i * 12.30000019073486328125;
            float size = 0.0500000007450580596923828125 + (0.1500000059604644775390625 * hash(param_6));
            float chr = 0.0199999995529651641845703125 * dist;
            float3 ghostCol = float3(0.0);
            float d = length(uv - gPos);
            ghostCol.x = smoothstep(size + chr, (size - 0.00999999977648258209228515625) + chr, d);
            ghostCol.y = smoothstep(size, size - 0.00999999977648258209228515625, d);
            ghostCol.z = smoothstep(size - chr, (size - 0.00999999977648258209228515625) - chr, d);
            float hollow = smoothstep(0.0, size * 0.800000011920928955078125, d);
            ghostCol *= (0.5 + (0.5 * hollow));
            float alpha = (0.100000001490116119384765625 * gStr) * (1.0 - (t * 0.5));
            f += ((ghostCol * alpha) * colGhost);
        }
    }
    return f * _107.intensity;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse003b34e765ad& _107, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _107.refScreen.xy;
    float2 aspectVec = float2(_107.refLayer.z / _107.refLayer.w, 1.0);
    float2 cUV = (uv - float2(0.5)) * aspectVec;
    float2 lightPos = (float2(_107.posX, 1.0 - _107.posY) - float2(0.5)) * aspectVec;
    float2 param = uv;
    float3 col = texture2DCv(refInput, refInputSmplr, param).xyz;
    float2 param_1 = cUV;
    float2 param_2 = lightPos;
    float3 flare = lensFlare(param_1, param_2, _107);
    col += flare;
    col *= 0.800000011920928955078125;
    col = fast::clamp((col * ((col * 2.5099999904632568359375) + float3(0.02999999932944774627685546875))) / ((col * ((col * 2.4300000667572021484375) + float3(0.589999973773956298828125))) + float3(0.14000000059604644775390625)), float3(0.0), float3(1.0));
    col = powr(col, float3(0.4545454680919647216796875));
    referenceColor = float4(col, 1.0);
}

fragment refAM35_e003b34e765ad_out refAM35_e003b34e765ad(constant ReferenceUniformse003b34e765ad& _107 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e003b34e765ad_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_107, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _473 = any(isnan(referenceColor));
    bool _480;
    if (!_473)
    {
        _480 = any(isinf(referenceColor));
    }
    else
    {
        _480 = _473;
    }
    if (_480)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _493 = referenceColor;
    float3 _499 = fast::clamp(_493.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _499.x;
    referenceColor.y = _499.y;
    referenceColor.z = _499.z;
    out.finalColor = referenceColor;
    return out;
}

