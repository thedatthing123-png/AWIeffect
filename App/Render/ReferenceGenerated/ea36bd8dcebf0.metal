// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/bcc gradient map.xml
// Original source comments and attribution:
// Get luminance
// Gamma
// Contrast
// Brightness
// Invert
// Get gradient colors
// Reverse colors
// Duotone override
// Sample gradient
// Zone isolation
// Blend mapped with zone mask
// Apply map strength
// Blend mode
// Preserve hue
// Preserve saturation
// Preserve luminance
// Color shift
// Global mix
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea36bd8dcebf0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    float4 color3;
    float4 color4;
    float4 color5;
    float stop1;
    char _m11_pad[12];
    float stop2;
    char _m12_pad[12];
    float stop3;
    char _m13_pad[12];
    float stop4;
    char _m14_pad[12];
    float stop5;
    char _m15_pad[12];
    int lumMode;
    char _m16_pad[12];
    float gradGamma;
    char _m17_pad[12];
    float gradContrast;
    char _m18_pad[12];
    float gradBrightness;
    char _m19_pad[12];
    uint gradInvert;
    char _m20_pad[12];
    uint gradReverse;
    char _m21_pad[12];
    float mapStrength;
    char _m22_pad[12];
    int blendMode;
    char _m23_pad[12];
    float preserveLum;
    char _m24_pad[12];
    float preserveSat;
    char _m25_pad[12];
    float preserveHue;
    char _m26_pad[12];
    float hueShift;
    char _m27_pad[12];
    float satAdjust;
    char _m28_pad[12];
    float lumAdjust;
    char _m29_pad[12];
    float shadowsOnly;
    char _m30_pad[12];
    float midtonesOnly;
    char _m31_pad[12];
    float highlightsOnly;
    char _m32_pad[12];
    uint duotoneMode;
    float4 duoShadow;
    float4 duoHighlight;
    float globalMix;
};

struct refAM35_ea36bd8dcebf0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float getLum(thread const float3& c, thread const float& mode)
{
    if (mode < 1.5)
    {
        return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    }
    if (mode < 2.5)
    {
        return fast::max(c.x, fast::max(c.y, c.z));
    }
    if (mode < 3.5)
    {
        return ((c.x + c.y) + c.z) / 3.0;
    }
    if (mode < 4.5)
    {
        return powr(dot(powr(fast::max(c, float3(0.0)), float3(2.2000000476837158203125)), float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)), 0.4545454680919647216796875);
    }
    if (mode < 5.5)
    {
        return c.x;
    }
    if (mode < 6.5)
    {
        return c.y;
    }
    if (mode < 7.5)
    {
        return c.z;
    }
    float mx = fast::max(c.x, fast::max(c.y, c.z));
    float mn = fast::min(c.x, fast::min(c.y, c.z));
    return (mx + mn) * 0.5;
}

static inline __attribute__((always_inline))
float3 sampleGradient(thread const float& t, thread const float3& c1, thread const float3& c2, thread const float3& c3, thread const float3& c4, thread const float3& c5, thread const float& s1, thread const float& s2, thread const float& s3, thread const float& s4, thread const float& s5)
{
    if (t <= s1)
    {
        return c1;
    }
    if (t >= s5)
    {
        return c5;
    }
    if (t < s2)
    {
        float f = (t - s1) / fast::max(s2 - s1, 9.9999997473787516355514526367188e-06);
        f = (f * f) * (3.0 - (2.0 * f));
        return mix(c1, c2, float3(f));
    }
    if (t < s3)
    {
        float f_1 = (t - s2) / fast::max(s3 - s2, 9.9999997473787516355514526367188e-06);
        f_1 = (f_1 * f_1) * (3.0 - (2.0 * f_1));
        return mix(c2, c3, float3(f_1));
    }
    if (t < s4)
    {
        float f_2 = (t - s3) / fast::max(s4 - s3, 9.9999997473787516355514526367188e-06);
        f_2 = (f_2 * f_2) * (3.0 - (2.0 * f_2));
        return mix(c3, c4, float3(f_2));
    }
    float f_3 = (t - s4) / fast::max(s5 - s4, 9.9999997473787516355514526367188e-06);
    f_3 = (f_3 * f_3) * (3.0 - (2.0 * f_3));
    return mix(c4, c5, float3(f_3));
}

static inline __attribute__((always_inline))
float3 rgb2hsl(thread const float3& c)
{
    float mx = fast::max(c.x, fast::max(c.y, c.z));
    float mn = fast::min(c.x, fast::min(c.y, c.z));
    float l = (mx + mn) * 0.5;
    float d = mx - mn;
    float s = 0.0;
    float h = 0.0;
    if (d > 9.9999997473787516355514526367188e-06)
    {
        float _222;
        if (l > 0.5)
        {
            _222 = d / fast::max((2.0 - mx) - mn, 9.9999997473787516355514526367188e-06);
        }
        else
        {
            _222 = d / fast::max(mx + mn, 9.9999997473787516355514526367188e-06);
        }
        s = _222;
        if (mx == c.x)
        {
            h = ((c.y - c.z) / d) + ((c.y < c.z) ? 6.0 : 0.0);
        }
        else
        {
            if (mx == c.y)
            {
                h = ((c.z - c.x) / d) + 2.0;
            }
            else
            {
                h = ((c.x - c.y) / d) + 4.0;
            }
        }
        h /= 6.0;
    }
    return float3(h, s, l);
}

static inline __attribute__((always_inline))
float h2r(thread const float& p, thread const float& q, thread float& t)
{
    if (t < 0.0)
    {
        t += 1.0;
    }
    if (t > 1.0)
    {
        t -= 1.0;
    }
    if (t < 0.16666667163372039794921875)
    {
        return p + (((q - p) * 6.0) * t);
    }
    if (t < 0.5)
    {
        return q;
    }
    if (t < 0.666666686534881591796875)
    {
        return p + (((q - p) * (0.666666686534881591796875 - t)) * 6.0);
    }
    return p;
}

static inline __attribute__((always_inline))
float3 hsl2rgb(thread const float3& c)
{
    if (c.y < 9.9999997473787516355514526367188e-06)
    {
        return float3(c.z);
    }
    float _359;
    if (c.z < 0.5)
    {
        _359 = c.z * (1.0 + c.y);
    }
    else
    {
        _359 = (c.z + c.y) - (c.z * c.y);
    }
    float q = _359;
    float p = (2.0 * c.z) - q;
    float param = p;
    float param_1 = q;
    float param_2 = c.x + 0.3333333432674407958984375;
    float _396 = h2r(param, param_1, param_2);
    float param_3 = p;
    float param_4 = q;
    float param_5 = c.x;
    float _404 = h2r(param_3, param_4, param_5);
    float param_6 = p;
    float param_7 = q;
    float param_8 = c.x - 0.3333333432674407958984375;
    float _413 = h2r(param_6, param_7, param_8);
    return float3(_396, _404, _413);
}

static inline __attribute__((always_inline))
float3 blendColors(thread const float3& base, thread const float3& mapped, thread const float& mode)
{
    if (mode < 1.5)
    {
        return mapped;
    }
    if (mode < 2.5)
    {
        return base * mapped;
    }
    if (mode < 3.5)
    {
        return float3(1.0) - ((float3(1.0) - base) * (float3(1.0) - mapped));
    }
    if (mode < 4.5)
    {
        float _571;
        if (base.x < 0.5)
        {
            _571 = (2.0 * base.x) * mapped.x;
        }
        else
        {
            _571 = 1.0 - ((2.0 * (1.0 - base.x)) * (1.0 - mapped.x));
        }
        float3 r;
        r.x = _571;
        float _595;
        if (base.y < 0.5)
        {
            _595 = (2.0 * base.y) * mapped.y;
        }
        else
        {
            _595 = 1.0 - ((2.0 * (1.0 - base.y)) * (1.0 - mapped.y));
        }
        r.y = _595;
        float _619;
        if (base.z < 0.5)
        {
            _619 = (2.0 * base.z) * mapped.z;
        }
        else
        {
            _619 = 1.0 - ((2.0 * (1.0 - base.z)) * (1.0 - mapped.z));
        }
        r.z = _619;
        return r;
    }
    if (mode < 5.5)
    {
        float _650;
        if (mapped.x < 0.5)
        {
            _650 = ((2.0 * base.x) * mapped.x) + ((base.x * base.x) * (1.0 - (2.0 * mapped.x)));
        }
        else
        {
            _650 = ((2.0 * base.x) * (1.0 - mapped.x)) + (sqrt(fast::max(base.x, 0.0)) * ((2.0 * mapped.x) - 1.0));
        }
        float3 r_1;
        r_1.x = _650;
        float _693;
        if (mapped.y < 0.5)
        {
            _693 = ((2.0 * base.y) * mapped.y) + ((base.y * base.y) * (1.0 - (2.0 * mapped.y)));
        }
        else
        {
            _693 = ((2.0 * base.y) * (1.0 - mapped.y)) + (sqrt(fast::max(base.y, 0.0)) * ((2.0 * mapped.y) - 1.0));
        }
        r_1.y = _693;
        float _736;
        if (mapped.z < 0.5)
        {
            _736 = ((2.0 * base.z) * mapped.z) + ((base.z * base.z) * (1.0 - (2.0 * mapped.z)));
        }
        else
        {
            _736 = ((2.0 * base.z) * (1.0 - mapped.z)) + (sqrt(fast::max(base.z, 0.0)) * ((2.0 * mapped.z) - 1.0));
        }
        r_1.z = _736;
        return r_1;
    }
    if (mode < 6.5)
    {
        float3 param = mapped;
        float3 mappedHSL = rgb2hsl(param);
        float3 param_1 = base;
        float3 baseHSL = rgb2hsl(param_1);
        float3 param_2 = float3(mappedHSL.x, mappedHSL.y, baseHSL.z);
        return hsl2rgb(param_2);
    }
    float3 param_3 = mapped;
    float3 mappedHSL_1 = rgb2hsl(param_3);
    float3 param_4 = base;
    float3 baseHSL_1 = rgb2hsl(param_4);
    float3 param_5 = float3(baseHSL_1.x, baseHSL_1.y, mappedHSL_1.z);
    return hsl2rgb(param_5);
}

static inline __attribute__((always_inline))
float lum709(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsea36bd8dcebf0& _828, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _828.refScreen.xy;
    float2 param = uv;
    float4 original = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = fast::max(original.xyz, float3(0.0));
    float3 baseRGB = rgb;
    float lm = float(_828.lumMode);
    float3 param_1 = rgb;
    float param_2 = lm;
    float t = getLum(param_1, param_2);
    if (abs(_828.gradGamma - 1.0) > 9.9999997473787516355514526367188e-06)
    {
        t = powr(fast::max(t, 0.0), 1.0 / fast::max(_828.gradGamma, 9.9999997473787516355514526367188e-06));
    }
    if (abs(_828.gradContrast) > 0.5)
    {
        float gc = _828.gradContrast / 100.0;
        t = fast::clamp(((t - 0.5) * (1.0 + gc)) + 0.5, 0.0, 1.0);
    }
    if (abs(_828.gradBrightness) > 0.5)
    {
        t = fast::clamp(t + ((_828.gradBrightness / 100.0) * 0.300000011920928955078125), 0.0, 1.0);
    }
    if (_828.gradInvert != 0u)
    {
        t = 1.0 - t;
    }
    float3 c1 = _828.color1.xyz;
    float3 c2 = _828.color2.xyz;
    float3 c3 = _828.color3.xyz;
    float3 c4 = _828.color4.xyz;
    float3 c5 = _828.color5.xyz;
    if (_828.gradReverse != 0u)
    {
        float3 tmp = c1;
        c1 = c5;
        c5 = tmp;
        tmp = c2;
        c2 = c4;
        c4 = tmp;
    }
    if (_828.duotoneMode != 0u)
    {
        c1 = _828.duoShadow.xyz;
        c2 = mix(_828.duoShadow.xyz, _828.duoHighlight.xyz, float3(0.25));
        c3 = mix(_828.duoShadow.xyz, _828.duoHighlight.xyz, float3(0.5));
        c4 = mix(_828.duoShadow.xyz, _828.duoHighlight.xyz, float3(0.75));
        c5 = _828.duoHighlight.xyz;
    }
    float param_3 = t;
    float3 param_4 = c1;
    float3 param_5 = c2;
    float3 param_6 = c3;
    float3 param_7 = c4;
    float3 param_8 = c5;
    float param_9 = _828.stop1;
    float param_10 = _828.stop2;
    float param_11 = _828.stop3;
    float param_12 = _828.stop4;
    float param_13 = _828.stop5;
    float3 mapped = sampleGradient(param_3, param_4, param_5, param_6, param_7, param_8, param_9, param_10, param_11, param_12, param_13);
    float shadowMask = 1.0 - smoothstep(0.0, 0.4000000059604644775390625, t);
    float highlightMask = smoothstep(0.60000002384185791015625, 1.0, t);
    float midtoneMask = (1.0 - shadowMask) - highlightMask;
    midtoneMask = fast::max(midtoneMask, 0.0);
    float zoneMask = ((shadowMask * _828.shadowsOnly) + (midtoneMask * _828.midtonesOnly)) + (highlightMask * _828.highlightsOnly);
    mapped = mix(rgb, mapped, float3(zoneMask));
    mapped = mix(rgb, mapped, float3(_828.mapStrength));
    float3 param_14 = rgb;
    float3 param_15 = mapped;
    float param_16 = float(_828.blendMode);
    float3 blended = blendColors(param_14, param_15, param_16);
    if (_828.preserveHue > 9.9999997473787516355514526367188e-06)
    {
        float3 param_17 = rgb;
        float3 origHSL = rgb2hsl(param_17);
        float3 param_18 = fast::max(blended, float3(0.0));
        float3 blendHSL = rgb2hsl(param_18);
        blendHSL.x = mix(blendHSL.x, origHSL.x, _828.preserveHue);
        float3 param_19 = blendHSL;
        blended = hsl2rgb(param_19);
    }
    if (_828.preserveSat > 9.9999997473787516355514526367188e-06)
    {
        float3 param_20 = rgb;
        float3 origHSL_1 = rgb2hsl(param_20);
        float3 param_21 = fast::max(blended, float3(0.0));
        float3 blendHSL_1 = rgb2hsl(param_21);
        blendHSL_1.y = mix(blendHSL_1.y, origHSL_1.y, _828.preserveSat);
        float3 param_22 = blendHSL_1;
        blended = hsl2rgb(param_22);
    }
    if (_828.preserveLum > 9.9999997473787516355514526367188e-06)
    {
        float3 param_23 = rgb;
        float origLum = lum709(param_23);
        float3 param_24 = blended;
        float blendLum = lum709(param_24);
        if (blendLum > 9.9999997473787516355514526367188e-06)
        {
            blended *= mix(1.0, origLum / blendLum, _828.preserveLum);
        }
    }
    bool _1172 = abs(_828.hueShift) > 0.5;
    bool _1181;
    if (!_1172)
    {
        _1181 = abs(_828.satAdjust) > 0.5;
    }
    else
    {
        _1181 = _1172;
    }
    bool _1190;
    if (!_1181)
    {
        _1190 = abs(_828.lumAdjust) > 0.5;
    }
    else
    {
        _1190 = _1181;
    }
    if (_1190)
    {
        float3 param_25 = fast::max(blended, float3(0.0));
        float3 hsl = rgb2hsl(param_25);
        if (abs(_828.hueShift) > 0.5)
        {
            hsl.x = fract(hsl.x + (_828.hueShift / 360.0));
        }
        if (abs(_828.satAdjust) > 0.5)
        {
            hsl.y = fast::clamp(hsl.y * (1.0 + (_828.satAdjust / 100.0)), 0.0, 1.0);
        }
        if (abs(_828.lumAdjust) > 0.5)
        {
            hsl.z = fast::clamp(hsl.z + ((_828.lumAdjust / 100.0) * 0.300000011920928955078125), 0.0, 1.0);
        }
        float3 param_26 = hsl;
        blended = hsl2rgb(param_26);
    }
    float3 fin = mix(baseRGB, blended, float3(_828.globalMix));
    fin = fast::clamp(fin, float3(0.0), float3(1.0));
    referenceColor = float4(fin, original.w);
}

fragment refAM35_ea36bd8dcebf0_out refAM35_ea36bd8dcebf0(constant ReferenceUniformsea36bd8dcebf0& _828 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea36bd8dcebf0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _828, refInput, refInputSmplr, referenceColor);
    bool _1274 = any(isnan(referenceColor));
    bool _1281;
    if (!_1274)
    {
        _1281 = any(isinf(referenceColor));
    }
    else
    {
        _1281 = _1274;
    }
    if (_1281)
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

