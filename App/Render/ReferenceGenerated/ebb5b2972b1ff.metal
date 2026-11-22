// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxdeepglow.xml
// Original source comments and attribution:
// syamjaidtz = ((vec2(acScreenNorm.x,1.0-acScreenNorm.y)*acScreenSize)-acLayerCenter)/acLayerSize;
// syamjaidtz.y*=acLayerSize.y/acLayerSize.x;
// vec2 scaleVec;
// scaleVec = vec2(1.0*stretch.x,1.0*stretch.y);
// syamjaidtz /= scaleVec;
// vec2 UV = acScreenNorm;
// vec2 center = acLayerCenterNorm-(centerPoint/1000. * vec2(-1.,1.));
// UV -= center;
// UV.x *= acScreenSize.x / acScreenSize.y;
////// OLD
// float rr = length(rrr - UV);
///SATVIB
//HUE
//
// compColorr = texture2DCv(vblur.texture, acScreenNorm.st);
// shadow = compColorr * (vec4(0.,0.,0,1.0) * higsha.y) * compColorr.a;
// vec4 dblur = vec4(compColorr.rgb / compColorr.a,1.) * (rr - 0.5);
///OLD
// vec4 resultfinalx = vec4(cross(color.rgb,blendC.rgb),1.0) * dblurr.a;
// vec4 resultfinalx = vec4(saturate(color.rgb,blendC.rgb),1.0) * dblurr.a;
// vec4 resultfinalx = vec4(color.rgb*blendC.rgb, alpc) * dblurr.a;
// vec4 resultfinal = vec4(saturate(color.rgb*blendC.rgb), progressa) * dblurr.a;
// vec4 resultfinal = vec4((dblurr.rgb/dblurr.a)*c.rgb,1.0) * dblurr.a;
// vec4 blendC = vec3(resultfinal.rgb, progressa) * dblurr.a;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsebb5b2972b1ff
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float rrr;
    char _m7_pad[8];
    float2 higsha;
    char _m8_pad[8];
    float2 satvib;
    char _m9_pad[8];
    float hue;
    char _m10_pad[8];
    float2 position;
    char _m11_pad[8];
    float oalpha;
    char _m12_pad[12];
    float calpha;
    char _m13_pad[12];
    uint sshadow;
    char _m14_pad[12];
    float power;
    char _m15_pad[12];
    float alphaa;
    char _m16_pad[12];
    uint cblend;
    float4 color;
    float alpb;
    char _m19_pad[12];
    uint thrs;
    char _m20_pad[12];
    float lowThreshold;
    char _m21_pad[12];
    float feather;
    char _m22_pad[12];
    float iter;
};

struct refAM35_ebb5b2972b1ff_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsebb5b2972b1ff& _75, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float rad = _75.hue * 0.01745329983532428741455078125;
    float3x3 huemat = float3x3(float3(1.0, 0.0, 0.0), float3(0.0, cos(rad), sin(rad)), float3(0.0, -sin(rad), cos(rad)));
    float2 param = gl_FragCoord.xy / _75.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 syamjaidtz = gl_FragCoord.xy / _75.refScreen.xy;
    syamjaidtz += ((float2(0.0 + (_75.position.x / 15.0), 0.0 + (_75.position.y / 15.0)) * float2(-1.0, 1.0)) / float2(500.0));
    float rr = length(float2(_75.rrr) - (gl_FragCoord.xy / _75.refScreen.xy));
    float2 param_1 = gl_FragCoord.xy / _75.refScreen.xy;
    float4 baseColor = texture2DCv(refInput, refInputSmplr, param_1) * _75.calpha;
    float2 param_2 = syamjaidtz;
    float4 compColorr = texture2DCv(refBuffer1, refBuffer1Smplr, param_2);
    float3 rgb = compColorr.xyz;
    float3 yuv = rgb * rgb2yuv;
    yuv *= huemat;
    float origSat = fast::min(1.0, length(yuv.yz) * 2.5);
    float2 satUV = yuv.yz * _75.satvib.y;
    float3 _196 = yuv;
    float2 _200 = mix(satUV, _196.yz, float2(origSat));
    yuv.y = _200.x;
    yuv.z = _200.y;
    float3 _206 = yuv;
    float2 _211 = _206.yz * (_75.satvib.x + 1.0);
    yuv.y = _211.x;
    yuv.z = _211.y;
    rgb = yuv * yuv2rgb;
    float4 newComp = float4(rgb, compColorr.w);
    float4 shadow = (newComp * (float4(0.0, 0.0, 0.0, 1.0) * _75.higsha.y)) * compColorr.w;
    float4 c = shadow + (float4(1.0) * (1.0 - shadow.w));
    float4 dblur = float4(newComp.xyz / float3(compColorr.w), 1.0) * (rr - 0.5);
    float4 targetLuma = dblur;
    float luma = dot(targetLuma.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float lowThresholdB = (_75.lowThreshold * (1.0 + _75.feather)) - 9.9999997473787516355514526367188e-05;
    float lowThresholdA = lowThresholdB - fast::max(_75.feather, 9.9999997473787516355514526367188e-06);
    float highThresholdA = ((1.0 * (1.0 + _75.feather)) - _75.feather) + 9.9999997473787516355514526367188e-05;
    float highThresholdB = highThresholdA + fast::max(_75.feather, 9.9999997473787516355514526367188e-06);
    float lowBlend = smoothstep(lowThresholdA, lowThresholdB, luma);
    float highBlend = 1.0 - smoothstep(highThresholdA, highThresholdB, luma);
    float lumafx = fast::min(lowBlend, highBlend);
    float4 dblurr = targetLuma;
    if (_75.thrs != 0u)
    {
        dblurr *= lumafx;
    }
    float4 blendC = float4((dblurr.xyz / float3(dblurr.w)) * c.xyz, 1.0) * dblurr.w;
    float4 resultfinalx = float4(_75.color.xyz, dblurr.w) * dblurr.w;
    float4 resultfinal = mix(blendC, resultfinalx, float4(_75.alpb)) * dblurr.w;
    float4 rrfinal = select(blendC, resultfinal, bool4(_75.cblend != 0u));
    float4 L2 = ((baseColor * _75.higsha.x) + (rrfinal * _75.oalpha)) * compColorr.w;
    L2 += baseColor;
    float2 param_3 = gl_FragCoord.xy / _75.refScreen.xy;
    float4 L1 = texture2DCv(refBuffer2, refBuffer2Smplr, param_3);
    L1 = float4(0.0, 0.0, 0.0, L1.w);
    L1 *= _75.alphaa;
    float4 _429;
    if (_75.sshadow != 0u)
    {
        float4 param_4 = L1;
        float4 param_5 = L2;
        _429 = newLayer(param_4, param_5);
    }
    else
    {
        _429 = L2;
    }
    referenceColor = _429;
}

fragment refAM35_ebb5b2972b1ff_out refAM35_ebb5b2972b1ff(constant ReferenceUniformsebb5b2972b1ff& _75 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refBuffer2 [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refBuffer2Smplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_ebb5b2972b1ff_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_75, refInput, refInputSmplr, gl_FragCoord, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr, referenceColor);
    bool _444 = any(isnan(referenceColor));
    bool _451;
    if (!_444)
    {
        _451 = any(isinf(referenceColor));
    }
    else
    {
        _451 = _444;
    }
    if (_451)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _464 = referenceColor;
    float3 _470 = fast::clamp(_464.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _470.x;
    referenceColor.y = _470.y;
    referenceColor.z = _470.z;
    out.finalColor = referenceColor;
    return out;
}

