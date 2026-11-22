// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/fillbehind.xml
// Original source comments and attribution:
//vec2 stretchToScreen = acScreenSize/acLayerSize * (1. + strength) / l2sScale;
//stretchToScreen = normalize((vec4(1., 1.,0.,0.)*acLayerToScreen).xy)/l2sScale;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse298f589ff9b7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float feather;
    char _m7_pad[12];
    float saturation;
    char _m8_pad[12];
    float brightness;
    char _m9_pad[12];
    float gamma;
    char _m10_pad[12];
    float alpha;
    char _m11_pad[12];
    float fgAlpha;
    float4 tintColor;
    float tintStrength;
    float4 edgeColor;
    float edgeStrength;
    char _m16_pad[12];
    float scanLines;
    char _m17_pad[12];
    float scanLineCount;
    char _m18_pad[8];
    float2 fgOffset;
    char _m19_pad[8];
    float fgScale;
    char _m20_pad[8];
    float2 bgOffset;
    char _m21_pad[8];
    float bgScale;
};

struct refAM35_e298f589ff9b7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float maxComponent(thread const float2& v)
{
    return fast::max(v.x, v.y);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 composite(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(thread float3x3& rgb2yuv, thread float3x3& yuv2rgb, constant ReferenceUniformse298f589ff9b7& _89, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refBuffer1, sampler refBuffer1Smplr, thread float4& referenceColor)
{
    float l2sScale = length(float4(1.0, 0.0, 0.0, 0.0) * _89.refLayerToScreen);
    float2 stretchToScreenA = float2(1.0 + _89.strength) / abs(float4(1.0, 1.0, 0.0, 0.0) * _89.refLayerToScreen).xy;
    float2 stretchToScreenB = float2(1.0 + _89.strength) / abs(float4(-1.0, -1.0, 0.0, 0.0) * _89.refLayerToScreen).xy;
    float2 stretchToScreenC = float2(1.0 + _89.strength) / abs(float4(1.0, -1.0, 0.0, 0.0) * _89.refLayerToScreen).xy;
    float2 stretchToScreenD = float2(1.0 + _89.strength) / abs(float4(-1.0, 1.0, 0.0, 0.0) * _89.refLayerToScreen).xy;
    float2 param = stretchToScreenA;
    float2 param_1 = stretchToScreenB;
    float2 param_2 = stretchToScreenC;
    float2 param_3 = stretchToScreenD;
    float fillScreenScale = fast::max(fast::max(maxComponent(param), maxComponent(param_1)), fast::max(maxComponent(param_2), maxComponent(param_3)));
    float2 stFG = ((((gl_FragCoord.xy / _89.refScreen.xy) - float2(0.5)) / float2(_89.fgScale)) + float2(0.5)) - ((_89.fgOffset / float2(500.0)) * float2(1.0, -1.0));
    float2 stBG = ((((gl_FragCoord.xy / _89.refScreen.xy) - float2(0.5)) / float2(_89.bgScale)) + float2(0.5)) - ((_89.bgOffset / float2(500.0)) * float2(1.0, -1.0));
    float insideFG = ((step(0.0, stFG.x) * step(stFG.x, 1.0)) * step(0.0, stFG.y)) * step(stFG.y, 1.0);
    float2 param_4 = stFG;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_4) * insideFG;
    float2 param_5 = stFG;
    float blurAlpha = texture2DCv(refBuffer1, refBuffer1Smplr, param_5).w;
    float2 param_6 = ((stBG - float2(0.5)) / float2(fillScreenScale)) + (float2(_89.refLayer.x + (_89.refLayer.z * 0.5), (_89.refScreen.y - _89.refLayer.y) - (_89.refLayer.w * 0.5)) / _89.refScreen.xy);
    float4 blurTexColor = texture2DCv(refBuffer1, refBuffer1Smplr, param_6);
    float3 tintYuv = _89.tintColor.xyz * rgb2yuv;
    float3 rgb = blurTexColor.xyz / float3(blurTexColor.w);
    float3 yuv = rgb * rgb2yuv;
    float3 _298 = yuv;
    float2 _304 = _298.yz * (_89.saturation + 1.0);
    yuv.y = _304.x;
    yuv.z = _304.y;
    float3 _309 = yuv;
    float2 _317 = mix(_309.yz, tintYuv.yz, float2(_89.tintStrength));
    yuv.y = _317.x;
    yuv.z = _317.y;
    rgb = yuv * yuv2rgb;
    rgb = fast::clamp(powr(rgb, float3(1.0 / _89.gamma)) + float3(_89.brightness), float3(0.0), float3(1.0));
    float4 adjBlurColor = float4(rgb, 1.0) * blurTexColor.w;
    float4 _366 = adjBlurColor;
    float3 _368 = _366.xyz * (1.0 - (_89.scanLines * cos((gl_FragCoord.xy / _89.refScreen.xy).y * _89.scanLineCount)));
    adjBlurColor.x = _368.x;
    adjBlurColor.y = _368.y;
    adjBlurColor.z = _368.z;
    float _382;
    if (_89.feather < 0.0005000000237487256526947021484375)
    {
        _382 = 1.0;
    }
    else
    {
        _382 = smoothstep(0.4999000132083892822265625, 0.5 + (fast::min(0.999000012874603271484375, _89.feather / _89.strength) * 0.5), blurAlpha);
    }
    float fa = _382;
    float4 param_7 = ((_89.edgeColor * blurAlpha) * 2.0) * _89.edgeStrength;
    float4 param_8 = texColor * fa;
    float4 param_9 = adjBlurColor * _89.alpha;
    float4 param_10 = composite(param_7, param_8) * _89.fgAlpha;
    referenceColor = composite(param_9, param_10);
}

fragment refAM35_e298f589ff9b7_out refAM35_e298f589ff9b7(constant ReferenceUniformse298f589ff9b7& _89 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e298f589ff9b7_out out = {};
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float4 referenceColor = float4(0.0);
    referenceMain(rgb2yuv, yuv2rgb, _89, gl_FragCoord, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr, referenceColor);
    bool _435 = any(isnan(referenceColor));
    bool _442;
    if (!_435)
    {
        _442 = any(isinf(referenceColor));
    }
    else
    {
        _442 = _435;
    }
    if (_442)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _455 = referenceColor;
    float3 _461 = fast::clamp(_455.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _461.x;
    referenceColor.y = _461.y;
    referenceColor.z = _461.z;
    out.finalColor = referenceColor;
    return out;
}

