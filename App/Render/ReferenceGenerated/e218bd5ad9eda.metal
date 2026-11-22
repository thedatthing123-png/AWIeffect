// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/colorista IV.xml
// Original source comments and attribution:
// ═══ TEMPERATURE + TINT ═══
// ═══ EXPOSURE ═══
// ═══ CONTRAST — S-curve around pivot ═══
// ═══ COLOR WHEELS — Real hue-disc Lift/Gamma/Gain/Offset ═══
// Zone weights with adjustable ranges
// Build color vectors from wheels
// Apply chroma per zone
// Apply luminance bias per zone
// Back to RGB
// ═══ 7-POINT CURVES ═══
// ═══ SPLIT TONE ═══
// ═══ PRINTER LIGHTS ═══
// ═══ HDR ═══
// ═══ RECOVERY ═══
// ═══ FILM ═══
// ═══ SECONDARY ═══
// ═══ COLOR MATCH ═══
// ═══ SATURATION ═══
// ═══ VIBRANCE ═══
// ═══ PRESERVE LUMINANCE ═══
// ═══ SKIN PROTECTION ═══
// ═══ GLOBAL MIX ═══
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse218bd5ad9eda
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float exposure;
    char _m6_pad[12];
    float contrast;
    char _m7_pad[12];
    float pivot;
    char _m8_pad[12];
    float saturation;
    char _m9_pad[12];
    float vibrance;
    char _m10_pad[12];
    float temperature;
    char _m11_pad[12];
    float tint;
    float3 lift;
    float liftRange;
    float3 gamma;
    float gammaRange;
    float3 gain;
    float gainRange;
    float3 offset;
    float curveBlacks;
    char _m20_pad[12];
    float curveShadows;
    char _m21_pad[12];
    float curveLowMids;
    char _m22_pad[12];
    float curveMidtones;
    char _m23_pad[12];
    float curveHighMids;
    char _m24_pad[12];
    float curveHighlights;
    char _m25_pad[12];
    float curveWhites;
    float4 splitShadow;
    float splitShadowStr;
    float4 splitMidtone;
    float splitMidtoneStr;
    float4 splitHighlight;
    float splitHighlightStr;
    char _m32_pad[12];
    float splitBalance;
    char _m33_pad[12];
    float printerR;
    char _m34_pad[12];
    float printerG;
    char _m35_pad[12];
    float printerB;
    char _m36_pad[12];
    float hdrHlRolloff;
    char _m37_pad[12];
    float hdrShRolloff;
    char _m38_pad[12];
    float hdrWhitePoint;
    char _m39_pad[12];
    float hdrBlackPoint;
    char _m40_pad[12];
    float filmDensity;
    char _m41_pad[12];
    float filmFade;
    char _m42_pad[12];
    float filmBleach;
    char _m43_pad[12];
    float filmCrossProcess;
    char _m44_pad[12];
    float hlRecovery;
    char _m45_pad[12];
    float shRecovery;
    char _m46_pad[12];
    uint secActive;
    float4 secTarget;
    float secRange;
    char _m49_pad[12];
    float secSoftness;
    char _m50_pad[12];
    float secHueShift;
    char _m51_pad[12];
    float secSaturation;
    char _m52_pad[12];
    float secLuminance;
    char _m53_pad[12];
    float skinProtect;
    char _m54_pad[12];
    float skinHue;
    char _m55_pad[12];
    float skinRange;
    float4 matchTarget;
    float matchStr;
    char _m58_pad[12];
    uint preserveLum;
    char _m59_pad[12];
    float globalMix;
};

struct refAM35_e218bd5ad9eda_out
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
        float _140;
        if (l > 0.5)
        {
            _140 = d / fast::max((2.0 - mx) - mn, 9.9999997473787516355514526367188e-06);
        }
        else
        {
            _140 = d / fast::max(mx + mn, 9.9999997473787516355514526367188e-06);
        }
        s = _140;
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
float getSkinMask(thread const float3& rgb, constant ReferenceUniformse218bd5ad9eda& _334)
{
    if (_334.skinProtect < 9.9999997473787516355514526367188e-06)
    {
        return 0.0;
    }
    float3 param = rgb;
    float3 hsl = rgb2hsl(param);
    float hueDist = abs(hsl.x - _334.skinHue);
    hueDist = fast::min(hueDist, 1.0 - hueDist);
    float mask = smoothstep(_334.skinRange, _334.skinRange * 0.300000011920928955078125, hueDist);
    mask *= smoothstep(0.1500000059604644775390625, 0.3499999940395355224609375, hsl.y);
    mask *= (smoothstep(0.100000001490116119384765625, 0.300000011920928955078125, hsl.z) * (1.0 - smoothstep(0.800000011920928955078125, 0.949999988079071044921875, hsl.z)));
    return mask * _334.skinProtect;
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
float hueToRgb(thread const float& p, thread const float& q, thread float& t)
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
    float _274;
    if (c.z < 0.5)
    {
        _274 = c.z * (1.0 + c.y);
    }
    else
    {
        _274 = (c.z + c.y) - (c.z * c.y);
    }
    float q = _274;
    float p = (2.0 * c.z) - q;
    float param = p;
    float param_1 = q;
    float param_2 = c.x + 0.3333333432674407958984375;
    float _310 = hueToRgb(param, param_1, param_2);
    float param_3 = p;
    float param_4 = q;
    float param_5 = c.x;
    float _318 = hueToRgb(param_3, param_4, param_5);
    float param_6 = p;
    float param_7 = q;
    float param_8 = c.x - 0.3333333432674407958984375;
    float _327 = hueToRgb(param_6, param_7, param_8);
    return float3(_310, _318, _327);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse218bd5ad9eda& _334, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float2 uv = gl_FragCoord.xy / _334.refScreen.xy;
    float2 param = uv;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = texColor.xyz;
    float3 baseRGB = rgb;
    float a = texColor.w;
    float3 param_1 = rgb;
    float origLum = lum(param_1);
    float3 param_2 = rgb;
    float skinMask = getSkinMask(param_2, _334);
    float3 preSkin = rgb;
    if (abs(_334.temperature) > 0.5)
    {
        float t = (_334.temperature / 100.0) * 0.07999999821186065673828125;
        rgb.x += t;
        rgb.z -= t;
        rgb.y += (t * 0.1500000059604644775390625);
    }
    if (abs(_334.tint) > 0.5)
    {
        float t_1 = (_334.tint / 100.0) * 0.07999999821186065673828125;
        rgb.y += t_1;
        rgb.x -= (t_1 * 0.300000011920928955078125);
        rgb.z -= (t_1 * 0.300000011920928955078125);
    }
    if (abs(_334.exposure) > 9.9999997473787516355514526367188e-06)
    {
        rgb *= powr(2.0, _334.exposure);
    }
    if (abs(_334.contrast) > 0.5)
    {
        float c = _334.contrast / 100.0;
        rgb = ((rgb - float3(_334.pivot)) * (1.0 + c)) + float3(_334.pivot);
        if (c > 0.0)
        {
            rgb += (((rgb - float3(0.5)) * (c * 0.300000011920928955078125)) * (float3(1.0) - (abs(rgb - float3(0.5)) * 2.0)));
        }
    }
    float3 yuv = rgb * rgb2yuv;
    float origY = yuv.x;
    float y = yuv.x;
    float shadowWeight = powr(fast::max(1.0 - (y / fast::max(_334.liftRange, 0.001000000047497451305389404296875)), 0.0), 2.0);
    float highlightWeight = powr(fast::max((y - (1.0 - _334.gainRange)) / fast::max(_334.gainRange, 0.001000000047497451305389404296875), 0.0), 2.0);
    float gammaWeight = powr(abs((y - 0.5) * 2.0), 2.0) * _334.gammaRange;
    float3 param_3 = float3(_334.lift.x / 360.0, 1.0, 0.5);
    float3 liftYUV = (hsv2rgb(param_3) * rgb2yuv) * _334.lift.y;
    float3 param_4 = float3(_334.gamma.x / 360.0, 1.0, 0.5);
    float3 gammaYUV = (hsv2rgb(param_4) * rgb2yuv) * _334.gamma.y;
    float3 param_5 = float3(_334.gain.x / 360.0, 1.0, 0.5);
    float3 gainYUV = (hsv2rgb(param_5) * rgb2yuv) * _334.gain.y;
    float3 param_6 = float3(_334.offset.x / 360.0, 1.0, 0.5);
    float3 offsetYUV = (hsv2rgb(param_6) * rgb2yuv) * _334.offset.y;
    float3 _674 = yuv;
    float2 _676 = _674.yz + ((liftYUV.yz * shadowWeight) * a);
    yuv.y = _676.x;
    yuv.z = _676.y;
    float3 _687 = yuv;
    float2 _689 = _687.yz + ((gammaYUV.yz * gammaWeight) * a);
    yuv.y = _689.x;
    yuv.z = _689.y;
    float3 _700 = yuv;
    float2 _702 = _700.yz + ((gainYUV.yz * highlightWeight) * a);
    yuv.y = _702.x;
    yuv.z = _702.y;
    float3 _711 = yuv;
    float2 _713 = _711.yz + (offsetYUV.yz * a);
    yuv.y = _713.x;
    yuv.z = _713.y;
    yuv.x += ((_334.lift.z * shadowWeight) * a);
    yuv.x += ((_334.gamma.z * gammaWeight) * a);
    yuv.x += ((_334.gain.z * highlightWeight) * a);
    yuv.x += (_334.offset.z * a);
    rgb = yuv * yuv2rgb;
    float3 param_7 = rgb;
    float l = lum(param_7);
    float oL = fast::max(l, 9.9999997473787516355514526367188e-06);
    float adj = 0.0;
    adj += (((_334.curveBlacks / 100.0) * 0.300000011920928955078125) * smoothstep(0.100000001490116119384765625, 0.0, l));
    adj += ((((_334.curveShadows / 100.0) * 0.300000011920928955078125) * smoothstep(0.0, 0.100000001490116119384765625, l)) * smoothstep(0.300000011920928955078125, 0.1500000059604644775390625, l));
    adj += ((((_334.curveLowMids / 100.0) * 0.300000011920928955078125) * smoothstep(0.100000001490116119384765625, 0.25, l)) * smoothstep(0.5, 0.3499999940395355224609375, l));
    adj += ((((_334.curveMidtones / 100.0) * 0.300000011920928955078125) * smoothstep(0.25, 0.4000000059604644775390625, l)) * smoothstep(0.75, 0.60000002384185791015625, l));
    adj += ((((_334.curveHighMids / 100.0) * 0.300000011920928955078125) * smoothstep(0.5, 0.64999997615814208984375, l)) * smoothstep(0.85000002384185791015625, 0.75, l));
    adj += ((((_334.curveHighlights / 100.0) * 0.300000011920928955078125) * smoothstep(0.699999988079071044921875, 0.85000002384185791015625, l)) * smoothstep(1.0, 0.89999997615814208984375, l));
    adj += (((_334.curveWhites / 100.0) * 0.300000011920928955078125) * smoothstep(0.87999999523162841796875, 1.0, l));
    rgb *= (fast::max(l + adj, 0.0) / oL);
    float3 param_8 = rgb;
    float splitL = lum(param_8);
    float balOff = (_334.splitBalance / 100.0) * 0.300000011920928955078125;
    if (_334.splitShadowStr > 0.5)
    {
        float shMask = 1.0 - smoothstep(0.0, 0.3300000131130218505859375 + balOff, splitL);
        float3 shTint = (_334.splitShadow.xyz - float3(0.5)) * 2.0;
        float3 param_9 = rgb;
        float tL = lum(param_9);
        rgb += ((((shTint * _334.splitShadowStr) / float3(100.0)) * shMask) * 0.20000000298023223876953125);
        float3 param_10 = rgb;
        float nL = lum(param_10);
        if (nL > 9.9999997473787516355514526367188e-06)
        {
            rgb *= mix(1.0, tL / nL, 0.699999988079071044921875);
        }
    }
    if (_334.splitMidtoneStr > 0.5)
    {
        float midMask = smoothstep(0.0, 0.3300000131130218505859375, splitL) * smoothstep(1.0, 0.670000016689300537109375, splitL);
        float3 midTint = (_334.splitMidtone.xyz - float3(0.5)) * 2.0;
        float3 param_11 = rgb;
        float tL_1 = lum(param_11);
        rgb += ((((midTint * _334.splitMidtoneStr) / float3(100.0)) * midMask) * 0.20000000298023223876953125);
        float3 param_12 = rgb;
        float nL_1 = lum(param_12);
        if (nL_1 > 9.9999997473787516355514526367188e-06)
        {
            rgb *= mix(1.0, tL_1 / nL_1, 0.699999988079071044921875);
        }
    }
    if (_334.splitHighlightStr > 0.5)
    {
        float hlMask = smoothstep(0.670000016689300537109375 - balOff, 1.0, splitL);
        float3 hlTint = (_334.splitHighlight.xyz - float3(0.5)) * 2.0;
        float3 param_13 = rgb;
        float tL_2 = lum(param_13);
        rgb += ((((hlTint * _334.splitHighlightStr) / float3(100.0)) * hlMask) * 0.20000000298023223876953125);
        float3 param_14 = rgb;
        float nL_2 = lum(param_14);
        if (nL_2 > 9.9999997473787516355514526367188e-06)
        {
            rgb *= mix(1.0, tL_2 / nL_2, 0.699999988079071044921875);
        }
    }
    float pBase = 25.0;
    bool _1036 = abs(_334.printerR - pBase) > 0.5;
    bool _1047;
    if (!_1036)
    {
        _1047 = abs(_334.printerG - pBase) > 0.5;
    }
    else
    {
        _1047 = _1036;
    }
    bool _1058;
    if (!_1047)
    {
        _1058 = abs(_334.printerB - pBase) > 0.5;
    }
    else
    {
        _1058 = _1047;
    }
    if (_1058)
    {
        rgb.x *= powr(2.0, ((_334.printerR - pBase) / 25.0) * 0.5);
        rgb.y *= powr(2.0, ((_334.printerG - pBase) / 25.0) * 0.5);
        rgb.z *= powr(2.0, ((_334.printerB - pBase) / 25.0) * 0.5);
    }
    if (_334.hdrHlRolloff > 0.5)
    {
        float hr = _334.hdrHlRolloff / 100.0;
        float3 shouldered = float3(1.0) - powr(fast::max(float3(1.0) - rgb, float3(0.0)), float3(1.0 + (hr * 3.0)));
        rgb = mix(rgb, shouldered, float3(hr));
    }
    if (_334.hdrShRolloff > 0.5)
    {
        float sr = _334.hdrShRolloff / 100.0;
        rgb = powr(fast::max(rgb, float3(0.0)), float3(1.0 + (sr * 0.5)));
    }
    if (abs(_334.hdrWhitePoint - 1.0) > 9.9999997473787516355514526367188e-06)
    {
        rgb = fast::min(rgb, float3(_334.hdrWhitePoint));
    }
    if (_334.hdrBlackPoint > 9.9999997473787516355514526367188e-06)
    {
        rgb = fast::max(rgb - float3(_334.hdrBlackPoint), float3(0.0)) / float3(fast::max(1.0 - _334.hdrBlackPoint, 9.9999997473787516355514526367188e-06));
    }
    if (_334.hlRecovery > 0.5)
    {
        float hr_1 = _334.hlRecovery / 100.0;
        float maxC = fast::max(rgb.x, fast::max(rgb.y, rgb.z));
        if (maxC > 1.0)
        {
            rgb = mix(rgb, rgb / float3(fast::max(maxC, 9.9999997473787516355514526367188e-06)), float3(hr_1));
        }
    }
    if (_334.shRecovery > 0.5)
    {
        float sr_1 = _334.shRecovery / 100.0;
        float3 param_15 = rgb;
        float sM = 1.0 - smoothstep(0.0, 0.20000000298023223876953125, lum(param_15));
        rgb += float3((sr_1 * 0.1500000059604644775390625) * sM);
    }
    if (abs(_334.filmDensity) > 0.5)
    {
        rgb = powr(fast::max(rgb, float3(0.0)), float3(1.0 + (_334.filmDensity / 100.0)));
    }
    if (_334.filmBleach > 0.5)
    {
        float ba = _334.filmBleach / 100.0;
        float3 param_16 = rgb;
        float bl = lum(param_16);
        float3 ds = float3(bl);
        float _1263;
        if (bl < 0.5)
        {
            _1263 = (2.0 * rgb.x) * ds.x;
        }
        else
        {
            _1263 = 1.0 - ((2.0 * (1.0 - rgb.x)) * (1.0 - ds.x));
        }
        float3 r;
        r.x = _1263;
        float _1286;
        if (bl < 0.5)
        {
            _1286 = (2.0 * rgb.y) * ds.y;
        }
        else
        {
            _1286 = 1.0 - ((2.0 * (1.0 - rgb.y)) * (1.0 - ds.y));
        }
        r.y = _1286;
        float _1309;
        if (bl < 0.5)
        {
            _1309 = (2.0 * rgb.z) * ds.z;
        }
        else
        {
            _1309 = 1.0 - ((2.0 * (1.0 - rgb.z)) * (1.0 - ds.z));
        }
        r.z = _1309;
        rgb = mix(rgb, r, float3(ba));
    }
    if (_334.filmCrossProcess > 0.5)
    {
        float ca = _334.filmCrossProcess / 100.0;
        float3 cp;
        cp.x = powr(fast::max(rgb.x, 0.0), 0.800000011920928955078125 + (ca * 0.300000011920928955078125));
        cp.y = powr(fast::max(rgb.y, 0.0), 1.0 - (ca * 0.1500000059604644775390625));
        cp.z = powr(fast::max(rgb.z, 0.0), 1.2000000476837158203125 - (ca * 0.100000001490116119384765625));
        cp.x += (ca * 0.039999999105930328369140625);
        cp.z -= (ca * 0.0199999995529651641845703125);
        rgb = mix(rgb, cp, float3(ca));
    }
    if (_334.filmFade > 0.5)
    {
        float f = _334.filmFade / 100.0;
        rgb = (rgb * (1.0 - (f * 0.1500000059604644775390625))) + float3(f * 0.100000001490116119384765625);
        float3 param_17 = rgb;
        float fl = lum(param_17);
        rgb = mix(rgb, float3(fl), float3(f * 0.20000000298023223876953125));
    }
    if (_334.secActive != 0u)
    {
        float3 param_18 = _334.secTarget.xyz;
        float3 tgtHSL = rgb2hsl(param_18);
        float3 param_19 = fast::max(rgb, float3(0.0));
        float3 curHSL = rgb2hsl(param_19);
        float hueDist = abs(curHSL.x - tgtHSL.x);
        hueDist = fast::min(hueDist, 1.0 - hueDist);
        float hueRange = _334.secRange / 360.0;
        float hueSoft = _334.secSoftness / 360.0;
        float secMask = 1.0 - smoothstep(hueRange - hueSoft, hueRange + hueSoft, hueDist);
        if (secMask > 9.9999997473787516355514526367188e-06)
        {
            float3 secHSL = curHSL;
            secHSL.x = fract(secHSL.x + (_334.secHueShift / 360.0));
            secHSL.y = fast::clamp(secHSL.y + (_334.secSaturation / 100.0), 0.0, 1.0);
            secHSL.z = fast::clamp(secHSL.z + ((_334.secLuminance / 100.0) * 0.300000011920928955078125), 0.0, 1.0);
            float3 param_20 = secHSL;
            rgb = mix(rgb, hsl2rgb(param_20), float3(secMask));
        }
    }
    if (_334.matchStr > 9.9999997473787516355514526367188e-06)
    {
        float3 param_21 = rgb;
        float avgLum = lum(param_21);
        float3 matched = rgb * (_334.matchTarget.xyz / float3(0.5));
        float3 param_22 = matched;
        float mLum = lum(param_22);
        if (mLum > 9.9999997473787516355514526367188e-06)
        {
            matched *= (avgLum / mLum);
        }
        rgb = mix(rgb, matched, float3(_334.matchStr));
    }
    if (abs(_334.saturation - 1.0) > 0.001000000047497451305389404296875)
    {
        float3 param_23 = rgb;
        float ll = lum(param_23);
        rgb = mix(float3(ll), rgb, float3(_334.saturation));
    }
    if (abs(_334.vibrance) > 0.001000000047497451305389404296875)
    {
        float3 param_24 = rgb;
        float ll_1 = lum(param_24);
        float sat = length(rgb - float3(ll_1));
        float w = 1.0 - fast::clamp(sat * 3.0, 0.0, 1.0);
        rgb = mix(float3(ll_1), rgb, float3(1.0 + (_334.vibrance * w)));
    }
    if (_334.preserveLum != 0u)
    {
        float3 param_25 = rgb;
        float newLum = lum(param_25);
        if (newLum > 9.9999997473787516355514526367188e-06)
        {
            rgb *= (origLum / newLum);
        }
    }
    if (skinMask > 9.9999997473787516355514526367188e-06)
    {
        float3 skinG = preSkin;
        if (abs(_334.exposure) > 9.9999997473787516355514526367188e-06)
        {
            skinG *= powr(2.0, _334.exposure);
        }
        if (abs(_334.temperature) > 0.5)
        {
            float t_2 = (_334.temperature / 100.0) * 0.07999999821186065673828125;
            skinG.x += t_2;
            skinG.z -= t_2;
        }
        rgb = mix(rgb, skinG, float3(skinMask));
    }
    rgb = mix(baseRGB, rgb, float3(_334.globalMix));
    rgb = fast::clamp(rgb, float3(0.0), float3(1.0));
    referenceColor = float4(rgb, a);
}

fragment refAM35_e218bd5ad9eda_out refAM35_e218bd5ad9eda(constant ReferenceUniformse218bd5ad9eda& _334 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e218bd5ad9eda_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_334, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1687 = any(isnan(referenceColor));
    bool _1694;
    if (!_1687)
    {
        _1694 = any(isinf(referenceColor));
    }
    else
    {
        _1694 = _1687;
    }
    if (_1694)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1707 = referenceColor;
    float3 _1713 = fast::clamp(_1707.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1713.x;
    referenceColor.y = _1713.y;
    referenceColor.z = _1713.z;
    out.finalColor = referenceColor;
    return out;
}

