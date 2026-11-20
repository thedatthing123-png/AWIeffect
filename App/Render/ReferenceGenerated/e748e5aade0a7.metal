// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/1mojo.xml
// Original source comments and attribution:
// Mojo Cinematic Color Grading Effect
// Professional blockbuster look with enhanced skin tones
// Utility functions
// Skin tone detection
// Already in 0-1 range
// Skin tone hue range (orange-red to yellow-orange) - normalized to 0-1
// Expanded range to catch more skin tones
// 7-58 degrees normalized
// More forgiving saturation range
// More forgiving brightness range
// Mojo color transformation
// Apply exposure (always applied, not dependent on mojo strength)
// Apply cool/warm temperature shift
// Apply green/magenta tint
// Apply punch (contrast enhancement)
// Apply bleach bypass effect
// Apply fade
// Apply blue squeeze (cooler shadows)
// Cooler shadows and midtones
// Apply skin tone squeeze
// Enhance skin tone saturation
// Adjust skin tone hue towards warmer tones
// Too red
// Too yellow
// Apply skin yellow/pink adjustment
// Yellow (lower hue) vs Pink (higher hue)
// Apply overall tint
// Highlight protection
// Apply mojo transformation with all parameters
// Protect highlights
// Apply final blend with mojo strength
// Ensure we don't exceed valid color ranges
// Preserve original alpha
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse748e5aade0a7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float mojo;
    char _m6_pad[12];
    float tint;
    char _m7_pad[12];
    float punch;
    char _m8_pad[12];
    float bleach;
    char _m9_pad[12];
    float fade;
    char _m10_pad[12];
    float blueSqueeze;
    char _m11_pad[12];
    float skinSqueeze;
    char _m12_pad[12];
    float exposure;
    char _m13_pad[12];
    float coolWarm;
    char _m14_pad[12];
    float greenMagenta;
    char _m15_pad[12];
    float skinYellowPink;
    char _m16_pad[12];
    uint preserveHighlights;
    char _m17_pad[12];
    uint protectSkinTones;
};

struct refAM35_e748e5aade0a7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 rgb2hsv(thread const float3& c)
{
    float4 K = float4(0.0, -0.3333333432674407958984375, 0.666666686534881591796875, -1.0);
    float4 p = mix(float4(c.zy, K.wz), float4(c.yz, K.xy), float4(step(c.z, c.y)));
    float4 q = mix(float4(p.xyw, c.x), float4(c.x, p.yzx), float4(step(p.x, c.x)));
    float d = q.x - fast::min(q.w, q.y);
    float e = 1.0000000133514319600180897396058e-10;
    return float3(abs(q.z + ((q.w - q.y) / ((6.0 * d) + e))), d / (q.x + e), q.x);
}

static inline __attribute__((always_inline))
bool isSkinTone(thread const float3& rgb)
{
    float3 param = rgb;
    float3 hsv = rgb2hsv(param);
    float h = hsv.x;
    float s = hsv.y;
    float v = hsv.z;
    bool hueRange = (h > 0.0199999995529651641845703125) && (h < 0.1599999964237213134765625);
    bool satRange = (s > 0.100000001490116119384765625) && (s < 0.85000002384185791015625);
    bool valRange = (v > 0.1500000059604644775390625) && (v < 0.949999988079071044921875);
    return (hueRange && satRange) && valRange;
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
float3 applyMojo(thread float3& rgb, constant ReferenceUniformse748e5aade0a7& _229)
{
    float mojoStrength = _229.mojo * 0.00999999977648258209228515625;
    rgb *= powr(2.0, _229.exposure);
    if (_229.coolWarm != 0.0)
    {
        float temp = (_229.coolWarm * 0.00999999977648258209228515625) * mojoStrength;
        rgb.x += (temp * 0.1500000059604644775390625);
        rgb.z -= (temp * 0.1500000059604644775390625);
        rgb = fast::clamp(rgb, float3(0.0), float3(1.0));
    }
    if (_229.greenMagenta != 0.0)
    {
        float tint = (_229.greenMagenta * 0.00999999977648258209228515625) * mojoStrength;
        rgb.y += (tint * 0.1500000059604644775390625);
        rgb = fast::clamp(rgb, float3(0.0), float3(1.0));
    }
    if (_229.punch != 0.0)
    {
        float punchStrength = (_229.punch * 0.00999999977648258209228515625) * mojoStrength;
        float3 contrast = mix(float3(0.5), rgb, float3(1.0 + (punchStrength * 0.5)));
        rgb = contrast;
        rgb = fast::clamp(rgb, float3(0.0), float3(1.0));
    }
    if (_229.bleach != 0.0)
    {
        float bleachStrength = (_229.bleach * 0.00999999977648258209228515625) * mojoStrength;
        float luminance = dot(rgb, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
        float3 bleachColor = mix(rgb, float3(luminance), float3(0.5 * bleachStrength));
        rgb = mix(rgb, bleachColor, float3(mojoStrength));
        rgb = fast::clamp(rgb, float3(0.0), float3(1.0));
    }
    if (_229.fade != 0.0)
    {
        float fadeStrength = (_229.fade * 0.00999999977648258209228515625) * mojoStrength;
        float3 fadeColor = mix(rgb, float3(0.5), float3(fadeStrength));
        rgb = fadeColor;
        rgb = fast::clamp(rgb, float3(0.0), float3(1.0));
    }
    if (_229.blueSqueeze != 0.0)
    {
        float luminance_1 = dot(rgb, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
        float blueSqueezeStrength = (_229.blueSqueeze * 0.00999999977648258209228515625) * mojoStrength;
        if (luminance_1 < 0.699999988079071044921875)
        {
            float shadowFactor = (0.699999988079071044921875 - luminance_1) / 0.699999988079071044921875;
            rgb.z += ((blueSqueezeStrength * shadowFactor) * 0.20000000298023223876953125);
            rgb.x -= ((blueSqueezeStrength * shadowFactor) * 0.100000001490116119384765625);
            rgb = fast::clamp(rgb, float3(0.0), float3(1.0));
        }
    }
    if (_229.skinSqueeze != 0.0)
    {
        float3 param = rgb;
        if (isSkinTone(param))
        {
            float skinSqueezeStrength = (_229.skinSqueeze * 0.00999999977648258209228515625) * mojoStrength;
            float3 param_1 = rgb;
            float3 hsv = rgb2hsv(param_1);
            hsv.y = mix(hsv.y, fast::min(hsv.y * 1.2999999523162841796875, 1.0), skinSqueezeStrength);
            if (hsv.x < 0.039999999105930328369140625)
            {
                hsv.x = mix(hsv.x, 0.07999999821186065673828125, skinSqueezeStrength * 0.300000011920928955078125);
            }
            else
            {
                if (hsv.x > 0.12999999523162841796875)
                {
                    hsv.x = mix(hsv.x, 0.100000001490116119384765625, skinSqueezeStrength * 0.300000011920928955078125);
                }
            }
            float3 param_2 = hsv;
            rgb = hsv2rgb(param_2);
            rgb = fast::clamp(rgb, float3(0.0), float3(1.0));
        }
    }
    if (_229.skinYellowPink != 0.0)
    {
        float3 param_3 = rgb;
        if (isSkinTone(param_3))
        {
            float skinAdjust = (_229.skinYellowPink * 0.00999999977648258209228515625) * mojoStrength;
            float3 param_4 = rgb;
            float3 hsv_1 = rgb2hsv(param_4);
            hsv_1.x = fast::clamp(hsv_1.x + (skinAdjust * 0.07999999821186065673828125), 0.02999999932944774627685546875, 0.14000000059604644775390625);
            float3 param_5 = hsv_1;
            rgb = hsv2rgb(param_5);
            rgb = fast::clamp(rgb, float3(0.0), float3(1.0));
        }
    }
    if (_229.tint != 0.0)
    {
        float tintStrength = (_229.tint * 0.00999999977648258209228515625) * mojoStrength;
        float3 tintColor = float3(1.0 + (tintStrength * 0.20000000298023223876953125), 1.0, 1.0 - (tintStrength * 0.20000000298023223876953125));
        rgb *= tintColor;
        rgb = fast::clamp(rgb, float3(0.0), float3(1.0));
    }
    return rgb;
}

static inline __attribute__((always_inline))
float3 protectHighlights(thread float3& rgb, constant ReferenceUniformse748e5aade0a7& _229)
{
    if (_229.preserveHighlights != 0u)
    {
        float maxChannel = fast::max(fast::max(rgb.x, rgb.y), rgb.z);
        if (maxChannel > 0.949999988079071044921875)
        {
            float highlightReduction = (maxChannel - 0.949999988079071044921875) / 0.0500000007450580596923828125;
            rgb = mix(rgb, fast::clamp(rgb, float3(0.0), float3(0.949999988079071044921875)), float3(highlightReduction * 0.5));
        }
    }
    return rgb;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse748e5aade0a7& _229, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _229.refScreen.xy;
    float2 param = uv;
    float4 original = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = original.xyz;
    float3 param_1 = rgb;
    float3 _614 = applyMojo(param_1, _229);
    float3 mojoColor = _614;
    float3 param_2 = mojoColor;
    float3 _617 = protectHighlights(param_2, _229);
    mojoColor = _617;
    float3 finalColor = mix(rgb, mojoColor, float3(_229.mojo * 0.00999999977648258209228515625));
    finalColor = fast::clamp(finalColor, float3(0.0), float3(1.0));
    referenceColor = float4(finalColor, original.w);
}

fragment refAM35_e748e5aade0a7_out refAM35_e748e5aade0a7(constant ReferenceUniformse748e5aade0a7& _229 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e748e5aade0a7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_229, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _644 = any(isnan(referenceColor));
    bool _651;
    if (!_644)
    {
        _651 = any(isinf(referenceColor));
    }
    else
    {
        _651 = _644;
    }
    if (_651)
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

