// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/DeepGlow Enhanced.xml
// Original source comments and attribution:
/// GLOW UV
/////// CHROMATIC FX
// vec4 colorMid = texture2DCv(vblur.texture,acScreenNorm);
// texture2DCv(blurBuf.texture, umefx);
//////////////////////////
///GAMMA CORRECTION
///SATVIB
// highp vec3 rgb = compColorr.rgb;
//HUE
//
// vec4 satComp = vec4(rgb, compColorr.a);
///////
// if (thrs) { dblurr *= lumafx; }
/// GLOW BLENDCOLOR
///
/// SHADOW
// vec4 shadowComp= texture2DCv(hblur.texture, acScreenNorm.st);
// shadowComp = vec4(vec3(0.0, 0.0, 0.0), shadowComp.a);
// shadowComp *= SDA;
/////// BLEND SECTION
// finalGlow = vec4( 1.-((1.-(baseColor.rgb/baseColor.a))*(1.-blendComp.rgb)),1.0);
// finalGlow *= blendComp.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse3ff064ef7353
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int bmode;
    char _m6_pad[12];
    uint overd;
    char _m7_pad[12];
    float strength;
    char _m8_pad[12];
    float oalpha;
    char _m9_pad[12];
    float lowThreshold;
    char _m10_pad[12];
    float highThreshold;
    char _m11_pad[12];
    float feather;
    char _m12_pad[8];
    float2 position;
    char _m13_pad[8];
    float2 stretch;
    char _m14_pad[8];
    float2 satvib;
    char _m15_pad[8];
    float hue;
    char _m16_pad[12];
    float calpha;
    char _m17_pad[12];
    uint GCE;
    char _m18_pad[12];
    uint CHROM;
    char _m19_pad[12];
    float strengthhh;
    char _m20_pad[12];
    float angleee;
    char _m21_pad[8];
    float2 OFT;
    char _m22_pad[8];
    int centerChannel;
    char _m23_pad[12];
    uint cblend;
    char _m24_pad[12];
    int cmode;
    float4 colblend;
    float alpb;
    char _m27_pad[12];
    float iter;
};

struct refAM35_e3ff064ef7353_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float blendScreen(thread const float& base, thread const float& blend)
{
    return 1.0 - ((1.0 - base) * (1.0 - blend));
}

static inline __attribute__((always_inline))
float3 blendScreen(thread const float3& base, thread const float3& blend)
{
    float param = base.x;
    float param_1 = blend.x;
    float param_2 = base.y;
    float param_3 = blend.y;
    float param_4 = base.z;
    float param_5 = blend.z;
    return float3(blendScreen(param, param_1), blendScreen(param_2, param_3), blendScreen(param_4, param_5));
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse3ff064ef7353& _122, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, texture2d<float> refBuffer1, sampler refBuffer1Smplr, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float rad = _122.hue * 0.01745329983532428741455078125;
    float3x3 huemat = float3x3(float3(1.0, 0.0, 0.0), float3(0.0, cos(rad), sin(rad)), float3(0.0, -sin(rad), cos(rad)));
    float2 param = gl_FragCoord.xy / _122.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 umefx = gl_FragCoord.xy / _122.refScreen.xy;
    umefx += ((float2(0.0 + _122.position.x, 0.0 + _122.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    umefx.y -= (((umefx.y - 0.5) * 0.699999988079071044921875) * fract(_122.stretch.y * 0.5));
    umefx.x -= (((umefx.x - 0.5) * 0.699999988079071044921875) * fract(_122.stretch.x * 0.5));
    float2 param_1 = gl_FragCoord.xy / _122.refScreen.xy;
    float4 baseColor = texture2DCv(refInput, refInputSmplr, param_1) * _122.calpha;
    float2 param_2 = gl_FragCoord.xy / _122.refScreen.xy;
    float4 vColor = texture2DCv(refBuffer1, refBuffer1Smplr, param_2);
    float raddd = _122.angleee * 0.01745329983532428741455078125;
    float adjStrength = _122.strengthhh / 8.0;
    float2 offset = float2(cos(raddd) * adjStrength, (-sin(raddd)) * adjStrength);
    offset += ((float2(0.0 + _122.OFT.x, 0.0 + _122.OFT.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 sampleLow = (float4(((gl_FragCoord.xy - _122.refLayer.xy) / _122.refLayer.zw) - offset, 0.0, 1.0) * _122.refLayerToScreen).xy;
    float2 sampleHigh = (float4(((gl_FragCoord.xy - _122.refLayer.xy) / _122.refLayer.zw) + offset, 0.0, 1.0) * _122.refLayerToScreen).xy;
    float2 param_3 = sampleLow;
    float4 colorLow = texture2DCv(refBuffer1, refBuffer1Smplr, param_3);
    float2 param_4 = sampleHigh;
    float4 colorHigh = texture2DCv(refBuffer1, refBuffer1Smplr, param_4);
    float2 param_5 = umefx;
    float4 colorMid = texture2DCv(refBuffer1, refBuffer1Smplr, param_5);
    float4 outColor;
    if (_122.centerChannel == 0)
    {
        outColor = float4(colorMid.x, colorLow.y, colorHigh.z, 1.0);
    }
    else
    {
        if (_122.centerChannel == 1)
        {
            outColor = float4(colorLow.x, colorMid.y, colorHigh.z, 1.0);
        }
        else
        {
            outColor = float4(colorLow.x, colorHigh.y, colorMid.z, 1.0);
        }
    }
    float4 _365;
    if (_122.CHROM != 0u)
    {
        _365 = float4(outColor.xyz, colorMid.w);
    }
    else
    {
        float2 param_6 = umefx;
        _365 = texture2DCv(refBuffer1, refBuffer1Smplr, param_6);
    }
    float4 compColorr = _365;
    float3 normCol = compColorr.xyz;
    float3 gamcor = powr(normCol, float3(0.4545454680919647216796875));
    float4 gamcorComp = float4(gamcor, compColorr.w);
    float4 _402;
    if (_122.GCE != 0u)
    {
        _402 = gamcorComp * compColorr.w;
    }
    else
    {
        _402 = compColorr;
    }
    float4 gammaComp = _402;
    float3 rgb = gammaComp.xyz;
    float3 yuv = rgb * rgb2yuv;
    yuv *= huemat;
    float origSat = fast::min(1.0, length(yuv.yz) * 2.5);
    float2 satUV = yuv.yz * _122.satvib.y;
    float3 _437 = yuv;
    float2 _441 = mix(satUV, _437.yz, float2(origSat));
    yuv.y = _441.x;
    yuv.z = _441.y;
    float3 _446 = yuv;
    float2 _451 = _446.yz * (_122.satvib.x + 1.0);
    yuv.y = _451.x;
    yuv.z = _451.y;
    rgb = yuv * yuv2rgb;
    float4 satComp = float4(rgb, gammaComp.w);
    float4 dblur = float4(satComp.xyz / float3(satComp.w), 1.0);
    float4 targetLuma = dblur;
    float luma = dot(targetLuma.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float lowThresholdB = (_122.lowThreshold * (1.0 + _122.feather)) - 9.9999997473787516355514526367188e-05;
    float lowThresholdA = lowThresholdB - fast::max(_122.feather, 9.9999997473787516355514526367188e-06);
    float highThresholdA = ((_122.highThreshold * (1.0 + _122.feather)) - _122.feather) + 9.9999997473787516355514526367188e-05;
    float highThresholdB = highThresholdA + fast::max(_122.feather, 9.9999997473787516355514526367188e-06);
    float lowBlend = smoothstep(lowThresholdA, lowThresholdB, luma);
    float highBlend = 1.0 - smoothstep(highThresholdA, highThresholdB, luma);
    float lumafx = fast::min(lowBlend, highBlend);
    float4 dblurr = targetLuma;
    bool _544 = _122.lowThreshold > 0.001000000047497451305389404296875;
    bool _551;
    if (!_544)
    {
        _551 = _122.highThreshold < 0.001000000047497451305389404296875;
    }
    else
    {
        _551 = _544;
    }
    if (_551)
    {
        dblurr *= lumafx;
    }
    dblurr *= satComp.w;
    dblurr *= _122.oalpha;
    float3 blendGlow;
    if (_122.cmode == 0)
    {
        blendGlow = dblurr.xyz + _122.colblend.xyz;
    }
    else
    {
        if (_122.cmode == 1)
        {
            blendGlow = _122.colblend.xyz;
        }
    }
    float4 mixcblend = mix(dblurr, float4(blendGlow, dblurr.w), float4(_122.alpb));
    float4 _608;
    if (_122.cblend != 0u)
    {
        _608 = mixcblend * dblurr.w;
    }
    else
    {
        _608 = dblurr;
    }
    float4 blendComp = _608;
    float4 finalGlow;
    if (_122.bmode == 0)
    {
        float3 param_7 = baseColor.xyz;
        float3 param_8 = blendComp.xyz;
        float3 colorScreen = blendScreen(param_7, param_8);
        float4 param_9 = baseColor;
        float4 param_10 = float4(colorScreen, blendComp.w);
        finalGlow = newLayer(param_9, param_10);
    }
    else
    {
        if (_122.bmode == 1)
        {
            finalGlow = baseColor / (float4(1.0) - blendComp);
        }
        else
        {
            if (_122.bmode == 2)
            {
                finalGlow = baseColor + blendComp;
            }
            else
            {
                if (_122.bmode == 3)
                {
                    float4 param_11 = baseColor;
                    float4 param_12 = blendComp;
                    finalGlow = newLayer(param_11, param_12);
                }
            }
        }
    }
    referenceColor = select(texColor, finalGlow, bool4(_122.strength > 9.9999997473787516355514526367188e-06));
    if (_122.overd != 0u)
    {
        referenceColor *= texColor.w;
    }
}

fragment refAM35_e3ff064ef7353_out refAM35_e3ff064ef7353(constant ReferenceUniformse3ff064ef7353& _122 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e3ff064ef7353_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_122, refInput, refInputSmplr, gl_FragCoord, refBuffer1, refBuffer1Smplr, referenceColor);
    bool _701 = any(isnan(referenceColor));
    bool _708;
    if (!_701)
    {
        _708 = any(isinf(referenceColor));
    }
    else
    {
        _708 = _701;
    }
    if (_708)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _721 = referenceColor;
    float3 _727 = fast::clamp(_721.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _727.x;
    referenceColor.y = _727.y;
    referenceColor.z = _727.z;
    out.finalColor = referenceColor;
    return out;
}

