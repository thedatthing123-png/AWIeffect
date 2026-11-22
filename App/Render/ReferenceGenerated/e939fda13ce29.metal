// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/new-lensflare-shadertoy.xml
// Original source comments and attribution:
// Shadertoy lens flare port adapted to AM. Uses same control IDs as skexnxxnewlensflare.
// NORMAL
// MULTIPLY
// SCREEN
// Position mapping: interpret position.x/y as percentage (0..100) of screen
// Orient controls slightly skew the mouse
// Two variants of anamorphic flare; choose richer one similar to non-cheap path
// reflection strength scaler
// luminance scaler
// global intensity
// gamma-like tone on flare
// Float-based selection to avoid int/float mismatch across platforms
// NORMAL
// MULTIPLY
// SCREEN
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse939fda13ce29
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 position;
    float progressc;
    char _m7_pad[12];
    float progressd;
    char _m8_pad[12];
    float progresse;
    char _m9_pad[12];
    float progressa;
    char _m10_pad[12];
    float progressb;
    char _m11_pad[12];
    float alpha;
    float4 color1;
    float4 color3;
    float4 color4;
    int blendMode;
};

struct refAM35_e939fda13ce29_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float3 lensflares(thread const float2& uv, thread const float2& pos, thread float3& sunflare, thread float3& lensflare)
{
    float2 main = uv - pos;
    float2 uvd = uv * length(uv);
    float ang = precise::atan2(main.y, main.x);
    float dist = length(main);
    dist = powr(dist, 0.100000001490116119384765625);
    float f0 = 1.0 / ((length(uv - pos) * 25.0) + 1.0);
    f0 = powr(f0, 2.0);
    f0 += (f0 * (((sin((ang + 0.0555555559694766998291015625) * 12.0) * 0.100000001490116119384765625) + (dist * 0.100000001490116119384765625)) + 0.800000011920928955078125));
    float f2 = fast::max(1.0 / (1.0 + (32.0 * powr(length(uvd + (pos * 0.800000011920928955078125)), 2.0))), 0.0) * 0.25;
    float f22 = fast::max(1.0 / (1.0 + (32.0 * powr(length(uvd + (pos * 0.85000002384185791015625)), 2.0))), 0.0) * 0.23000000417232513427734375;
    float f23 = fast::max(1.0 / (1.0 + (32.0 * powr(length(uvd + (pos * 0.89999997615814208984375)), 2.0))), 0.0) * 0.20999999344348907470703125;
    float2 uvx = mix(uv, uvd, float2(-0.5));
    float f4 = fast::max(0.00999999977648258209228515625 - powr(length(uvx + (pos * 0.4000000059604644775390625)), 2.400000095367431640625), 0.0) * 6.0;
    float f42 = fast::max(0.00999999977648258209228515625 - powr(length(uvx + (pos * 0.449999988079071044921875)), 2.400000095367431640625), 0.0) * 5.0;
    float f43 = fast::max(0.00999999977648258209228515625 - powr(length(uvx + (pos * 0.5)), 2.400000095367431640625), 0.0) * 3.0;
    uvx = mix(uv, uvd, float2(-0.4000000059604644775390625));
    float f5 = fast::max(0.00999999977648258209228515625 - powr(length(uvx + (pos * 0.20000000298023223876953125)), 5.5), 0.0) * 2.0;
    float f52 = fast::max(0.00999999977648258209228515625 - powr(length(uvx + (pos * 0.4000000059604644775390625)), 5.5), 0.0) * 2.0;
    float f53 = fast::max(0.00999999977648258209228515625 - powr(length(uvx + (pos * 0.60000002384185791015625)), 5.5), 0.0) * 2.0;
    uvx = mix(uv, uvd, float2(-0.5));
    float f6 = fast::max(0.00999999977648258209228515625 - powr(length(uvx - (pos * 0.300000011920928955078125)), 1.60000002384185791015625), 0.0) * 6.0;
    float f62 = fast::max(0.00999999977648258209228515625 - powr(length(uvx - (pos * 0.324999988079071044921875)), 1.60000002384185791015625), 0.0) * 3.0;
    float f63 = fast::max(0.00999999977648258209228515625 - powr(length(uvx - (pos * 0.3499999940395355224609375)), 1.60000002384185791015625), 0.0) * 5.0;
    sunflare = float3(f0);
    lensflare = float3(((f2 + f4) + f5) + f6, ((f22 + f42) + f52) + f62, ((f23 + f43) + f53) + f63);
    return sunflare + lensflare;
}

static inline __attribute__((always_inline))
float getSun(thread const float2& uv)
{
    return float(length(uv) < 0.0089999996125698089599609375);
}

static inline __attribute__((always_inline))
float3 anflares2(thread const float2& uv, thread float& threshold, thread const float& intensity, thread const float& stretch, thread const float& brightness)
{
    threshold = 1.0 - threshold;
    float2 param = uv;
    float3 hdr = float3(getSun(param));
    hdr = float3(floor(threshold + powr(hdr.x, 1.0)));
    float d = fast::max(intensity, 0.001000000047497451305389404296875);
    float c = fast::max(intensity * stretch, 0.0);
    float _363;
    for (int k = 0; k <= 64; k++)
    {
        float i = float(k) * (c / 64.0);
        float2 param_1 = uv + float2(i / d, 0.0);
        float texL = getSun(param_1);
        float2 param_2 = uv - float2(i / d, 0.0);
        float texR = getSun(param_2);
        if (c > 0.0)
        {
            _363 = 1.0 - (i / c);
        }
        else
        {
            _363 = 0.0;
        }
        float w = _363;
        hdr += float3(floor(threshold + powr(fast::max(texL, texR), 4.0)) * fast::max(w, 0.0));
    }
    return hdr * brightness;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse939fda13ce29& _398, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 R = _398.refScreen.xy;
    float2 uv = (gl_FragCoord.xy / _398.refScreen.xy) - float2(0.5);
    uv.x *= (R.x / fast::max(R.y, 1.0));
    float2 pos01 = fast::clamp(float2(_398.position.x, _398.position.y) / float2(100.0), float2(0.0), float2(1.0));
    float2 mouse = pos01 - float2(0.5);
    mouse.x *= (R.x / fast::max(R.y, 1.0));
    mouse += float2(_398.progressc * 0.0500000007450580596923828125, _398.progressd * 0.0500000007450580596923828125);
    float3 col = float3(0.0);
    float2 param = uv * 1.5;
    float2 param_1 = mouse * 1.5;
    float3 param_2;
    float3 param_3;
    float3 _478 = lensflares(param, param_1, param_2, param_3);
    float3 sunflare = param_2;
    float3 lensflare = param_3;
    float3 flare = _478;
    float2 param_4 = uv - mouse;
    float param_5 = 0.5;
    float param_6 = 400.0;
    float param_7 = 0.89999997615814208984375;
    float param_8 = 0.100000001490116119384765625;
    float3 _491 = anflares2(param_4, param_5, param_6, param_7, param_8);
    float3 anflare = powr(_491, float3(4.0));
    float3 tint1 = _398.color1.xyz;
    float3 tintBase = _398.color3.xyz;
    float3 tintSec = _398.color4.xyz;
    float refl = _398.progressa;
    float lumin = _398.progressb;
    float Strength = _398.progresse;
    float3 flareCol = ((flare + anflare) * float3(0.64300000667572021484375, 0.4939999878406524658203125, 0.86699998378753662109375)) * 2.0;
    flareCol *= lumin;
    flareCol = mix(flareCol, flareCol * tint1, float3(0.60000002384185791015625));
    flareCol += ((sunflare * tintBase) * 0.5);
    flareCol += (((lensflare * tintSec) * 0.25) * refl);
    float2 param_9 = gl_FragCoord.xy / _398.refScreen.xy;
    float3 src = texture2DCv(refInput, refInputSmplr, param_9).xyz;
    flareCol = powr(fast::max(flareCol, float3(0.0)), float3(0.4545454680919647216796875));
    float a = fast::clamp(_398.alpha * Strength, 0.0, 1.0);
    float bmode = float(_398.blendMode);
    float wN = 1.0 - step(0.5, abs(bmode - 0.0));
    float wM = 1.0 - step(0.5, abs(bmode - 1.0));
    float wS = 1.0 - step(0.5, abs(bmode - 2.0));
    float3 colNormal = mix(src, flareCol, float3(a));
    float3 colMultiply = mix(src, src * flareCol, float3(a));
    float3 screenMix = float3(1.0) - ((float3(1.0) - src) * (float3(1.0) - flareCol));
    float3 colScreen = mix(src, screenMix, float3(a));
    float3 outc = ((colNormal * wN) + (colMultiply * wM)) + (colScreen * wS);
    referenceColor = float4(outc, 1.0);
}

fragment refAM35_e939fda13ce29_out refAM35_e939fda13ce29(constant ReferenceUniformse939fda13ce29& _398 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e939fda13ce29_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_398, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _656 = any(isnan(referenceColor));
    bool _663;
    if (!_656)
    {
        _663 = any(isinf(referenceColor));
    }
    else
    {
        _663 = _656;
    }
    if (_663)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _677 = referenceColor;
    float3 _683 = fast::clamp(_677.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _683.x;
    referenceColor.y = _683.y;
    referenceColor.z = _683.z;
    out.finalColor = referenceColor;
    return out;
}

