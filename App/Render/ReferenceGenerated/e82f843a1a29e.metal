// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/color balance hsl 2.xml
// Original source comments and attribution:
// True CMY-RGB color balance
// This works on complementary color axes
// Cyan-Red: moving toward red adds red, removes cyan (green+blue)
// Magenta-Green: moving toward green adds green, removes magenta (red+blue)
// Yellow-Blue: moving toward blue adds blue, removes yellow (red+green)
// Scale by zone mask so balance only applies where it should
// Proper complementary axis math
// Cyan-Red axis
// Positive = more red = +R -G -B
// Negative = more cyan = -R +G +B
// Magenta-Green axis
// Positive = more green = -R +G -B
// Negative = more magenta = +R -G +B
// Yellow-Blue axis
// Positive = more blue = -R -G +B
// Negative = more yellow = +R +G -B
// Per-zone saturation adjustment
// Works in RGB space to avoid HSL artifacts
// Per-zone brightness adjustment
// Preserves color ratios
// ═══ ZONE MASKS ═══
// Smooth overlapping zones — no harsh transitions
// Each zone fades smoothly into the next
// Shadow zone — strongest at black, fades to zero at boundary
// Highlight zone — zero below boundary, strongest at white
// Midtone zone — what's left between shadow and highlight
// Peaks at center, zero at extremes
// Normalize so zones always sum to 1.0
// ═══ SHADOW COLOR BALANCE ═══
// ═══ MIDTONE COLOR BALANCE ═══
// ═══ HIGHLIGHT COLOR BALANCE ═══
// ═══ COMBINE ZONES ═══
// ═══ MASTER SATURATION ═══
// ═══ MASTER BRIGHTNESS ═══
// ═══ PRESERVE LUMINANCE ═══
// ═══ GLOBAL MIX ═══
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse82f843a1a29e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float shCyanRed;
    char _m6_pad[12];
    float shMagGreen;
    char _m7_pad[12];
    float shYelBlue;
    char _m8_pad[12];
    float midCyanRed;
    char _m9_pad[12];
    float midMagGreen;
    char _m10_pad[12];
    float midYelBlue;
    char _m11_pad[12];
    float hlCyanRed;
    char _m12_pad[12];
    float hlMagGreen;
    char _m13_pad[12];
    float hlYelBlue;
    char _m14_pad[12];
    float shSatAdjust;
    char _m15_pad[12];
    float shLumAdjust;
    char _m16_pad[12];
    float midSatAdjust;
    char _m17_pad[12];
    float midLumAdjust;
    char _m18_pad[12];
    float hlSatAdjust;
    char _m19_pad[12];
    float hlLumAdjust;
    char _m20_pad[12];
    float masterSaturation;
    char _m21_pad[12];
    float masterBrightness;
    char _m22_pad[12];
    float shBoundary;
    char _m23_pad[12];
    float hlBoundary;
    char _m24_pad[12];
    uint preserveLuminance;
    char _m25_pad[12];
    float globalMix;
};

struct refAM35_e82f843a1a29e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float lum(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float3 balanceCMYRGB(thread float3& rgb, thread const float& cr, thread const float& mg, thread const float& yb, thread const float& zoneMask)
{
    bool _63 = abs(cr) < 0.5;
    bool _69;
    if (_63)
    {
        _69 = abs(mg) < 0.5;
    }
    else
    {
        _69 = _63;
    }
    bool _75;
    if (_69)
    {
        _75 = abs(yb) < 0.5;
    }
    else
    {
        _75 = _69;
    }
    if (_75)
    {
        return rgb;
    }
    float crN = cr / 100.0;
    float mgN = mg / 100.0;
    float ybN = yb / 100.0;
    crN *= zoneMask;
    mgN *= zoneMask;
    ybN *= zoneMask;
    float rShift = crN * 0.100000001490116119384765625;
    float gShift = (-crN) * 0.0500000007450580596923828125;
    float bShift = (-crN) * 0.0500000007450580596923828125;
    gShift += (mgN * 0.100000001490116119384765625);
    rShift -= (mgN * 0.0500000007450580596923828125);
    bShift -= (mgN * 0.02999999932944774627685546875);
    bShift += (ybN * 0.100000001490116119384765625);
    rShift -= (ybN * 0.02999999932944774627685546875);
    gShift -= (ybN * 0.0500000007450580596923828125);
    rgb.x += rShift;
    rgb.y += gShift;
    rgb.z += bShift;
    return rgb;
}

static inline __attribute__((always_inline))
float3 adjustSaturation(thread const float3& rgb, thread const float& amount, thread const float& zoneMask)
{
    if (abs(amount) < 0.5)
    {
        return rgb;
    }
    float a = (amount / 100.0) * zoneMask;
    float3 param = rgb;
    float l = lum(param);
    return mix(float3(l), rgb, float3(1.0 + a));
}

static inline __attribute__((always_inline))
float3 adjustBrightness(thread const float3& rgb, thread const float& amount, thread const float& zoneMask)
{
    if (abs(amount) < 0.5)
    {
        return rgb;
    }
    float a = ((amount / 100.0) * 0.300000011920928955078125) * zoneMask;
    float3 param = rgb;
    float l = lum(param);
    float origL = fast::max(l, 9.9999997473787516355514526367188e-06);
    float newL = fast::max(l + a, 0.0);
    return rgb * (newL / origL);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse82f843a1a29e& _228, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _228.refScreen.xy;
    float2 param = uv;
    float4 original = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = fast::max(original.xyz, float3(0.0));
    float3 baseRGB = rgb;
    float3 param_1 = rgb;
    float l = lum(param_1);
    float origLum = l;
    float shMask = 1.0 - smoothstep(fast::max(_228.shBoundary - 0.1500000059604644775390625, 0.0), _228.shBoundary + 0.0500000007450580596923828125, l);
    float hlMask = smoothstep(_228.hlBoundary - 0.0500000007450580596923828125, fast::min(_228.hlBoundary + 0.1500000059604644775390625, 1.0), l);
    float midMask = (1.0 - shMask) - hlMask;
    midMask = fast::max(midMask, 0.0);
    float totalMask = (shMask + midMask) + hlMask;
    if (totalMask > 9.9999997473787516355514526367188e-06)
    {
        shMask /= totalMask;
        midMask /= totalMask;
        hlMask /= totalMask;
    }
    float3 param_2 = rgb;
    float param_3 = _228.shCyanRed;
    float param_4 = _228.shMagGreen;
    float param_5 = _228.shYelBlue;
    float param_6 = 1.0;
    float3 _322 = balanceCMYRGB(param_2, param_3, param_4, param_5, param_6);
    float3 shResult = _322;
    float3 param_7 = shResult;
    float param_8 = _228.shSatAdjust;
    float param_9 = 1.0;
    shResult = adjustSaturation(param_7, param_8, param_9);
    float3 param_10 = shResult;
    float param_11 = _228.shLumAdjust;
    float param_12 = 1.0;
    shResult = adjustBrightness(param_10, param_11, param_12);
    float3 param_13 = rgb;
    float param_14 = _228.midCyanRed;
    float param_15 = _228.midMagGreen;
    float param_16 = _228.midYelBlue;
    float param_17 = 1.0;
    float3 _355 = balanceCMYRGB(param_13, param_14, param_15, param_16, param_17);
    float3 midResult = _355;
    float3 param_18 = midResult;
    float param_19 = _228.midSatAdjust;
    float param_20 = 1.0;
    midResult = adjustSaturation(param_18, param_19, param_20);
    float3 param_21 = midResult;
    float param_22 = _228.midLumAdjust;
    float param_23 = 1.0;
    midResult = adjustBrightness(param_21, param_22, param_23);
    float3 param_24 = rgb;
    float param_25 = _228.hlCyanRed;
    float param_26 = _228.hlMagGreen;
    float param_27 = _228.hlYelBlue;
    float param_28 = 1.0;
    float3 _388 = balanceCMYRGB(param_24, param_25, param_26, param_27, param_28);
    float3 hlResult = _388;
    float3 param_29 = hlResult;
    float param_30 = _228.hlSatAdjust;
    float param_31 = 1.0;
    hlResult = adjustSaturation(param_29, param_30, param_31);
    float3 param_32 = hlResult;
    float param_33 = _228.hlLumAdjust;
    float param_34 = 1.0;
    hlResult = adjustBrightness(param_32, param_33, param_34);
    float3 result = ((shResult * shMask) + (midResult * midMask)) + (hlResult * hlMask);
    if (abs(_228.masterSaturation - 100.0) > 0.5)
    {
        float3 param_35 = result;
        float ml = lum(param_35);
        result = mix(float3(ml), result, float3(_228.masterSaturation / 100.0));
    }
    if (abs(_228.masterBrightness) > 0.5)
    {
        float mb = (_228.masterBrightness / 100.0) * 0.300000011920928955078125;
        float3 param_36 = result;
        float rl = lum(param_36);
        float origRL = fast::max(rl, 9.9999997473787516355514526367188e-06);
        float newRL = fast::max(rl + mb, 0.0);
        result *= (newRL / origRL);
    }
    if (_228.preserveLuminance != 0u)
    {
        float3 param_37 = result;
        float newLum = lum(param_37);
        if (newLum > 9.9999997473787516355514526367188e-06)
        {
            result *= (origLum / newLum);
        }
    }
    result = mix(baseRGB, result, float3(_228.globalMix));
    result = fast::clamp(result, float3(0.0), float3(1.0));
    referenceColor = float4(result, original.w);
}

fragment refAM35_e82f843a1a29e_out refAM35_e82f843a1a29e(constant ReferenceUniformse82f843a1a29e& _228 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e82f843a1a29e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _228, refInput, refInputSmplr, referenceColor);
    bool _512 = any(isnan(referenceColor));
    bool _519;
    if (!_512)
    {
        _519 = any(isinf(referenceColor));
    }
    else
    {
        _519 = _512;
    }
    if (_519)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _532 = referenceColor;
    float3 _538 = fast::clamp(_532.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _538.x;
    referenceColor.y = _538.y;
    referenceColor.z = _538.z;
    out.finalColor = referenceColor;
    return out;
}

