// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxnewoffsetglitch.xml
// Original source comments and attribution:
/*
            vec2 offset = vec2(cos(rad)*adjStrength,-sin(rad)*adjStrength);
            vec2 sampleLow = (vec4(acLayerNorm - offset,0.0,1.0) * acLayerToScreen).xy;
            vec2 sampleHigh = (vec4(acLayerNorm + offset,0.0,1.0) * acLayerToScreen).xy;
            vec4 colorLow = texture2DCv(inputImg.texture,sampleLow);
            vec4 colorHigh = texture2DCv(inputImg.texture,sampleHigh);
            vec4 colorMid = texture2DCv(inputImg.texture,acScreenNorm);
            vec4 outColor;
            
                vec4 r = vec4(outColor.r, 0.0, 0.0, outColor.r);
                vec4 g = vec4(0.0, outColor.g, 0.0, outColor.g);
                vec4 b = vec4(0.0, 0.0, outColor.b, outColor.b);
                vec4 m = (r + g + b) / 3.;
                vec4 c = vec4(0.0,0.0,0.0,0.0);
                vec4 l = vec4(dot(luminanceWeighting * colorMid.rgb, vec3(1.0)));
                c = m + (c*(1.0-m.a));
                c = l + (c*(1.0-l.a));
                
            highp mat3 rgb2yuv = mat3(
                 0.299,     0.587,    0.114,
                -0.14713,  -0.28886,  0.436,
                 0.615,    -0.51499, -0.10001
            );
            highp mat3 yuv2rgb = mat3(
                1.0,  0.0,      1.13983,
                1.0, -0.39465, -0.58060,
                1.0,  2.03211,  0.0
            );
            float adjStrength = strength / 8.0;
            vec2 offset = vec2(cos(rad)*adjStrength,-sin(rad)*adjStrength);
            vec2 sampleLow = (vec4(acLayerNorm - offset,0.0,1.0) * acLayerToScreen).xy;
            vec2 sampleHigh = (vec4(acLayerNorm + offset,0.0,1.0) * acLayerToScreen).xy;
            float rad = angle * 0.0174533;
            float adjStrength = strength / 8.0;
            vec2 offset = vec2(cos(rad)*adjStrength,-sin(rad)*adjStrength);
            vec2 sampleLow = (vec4(acLayerNorm - offset,0.0,1.0) * acLayerToScreen).xy;
            vec2 sampleHigh = (vec4(acLayerNorm + offset,0.0,1.0) * acLayerToScreen).xy;
            vec4 colorLow = texture2DCv(inputImg.texture,sampleLow); vec4 colorHigh = texture2DCv(inputImg.texture,sampleHigh); vec4 colorMid = texture2DCv(inputImg.texture,acScreenNorm);*/
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb54b9b7ba7f0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint autop;
    char _m6_pad[12];
    uint OFFSIDE;
    char _m7_pad[12];
    float PROGRESS;
    char _m8_pad[12];
    float SPEED;
    char _m9_pad[12];
    float glitchAmplitude;
    char _m10_pad[12];
    float AMOUNT;
    char _m11_pad[12];
    float scale;
    char _m12_pad[8];
    float2 stretch;
    char _m13_pad[8];
    float DISTORT;
    char _m14_pad[12];
    float STEP;
    char _m15_pad[12];
    float glitchNarrowness;
    char _m16_pad[12];
    float glitchBlockiness;
    char _m17_pad[12];
    float glitchMinimizer;
    char _m18_pad[12];
    float alpha;
    char _m19_pad[12];
    uint rcolor;
    char _m20_pad[12];
    uint gcolor;
    char _m21_pad[12];
    uint bcolor;
};

struct refAM35_eb54b9b7ba7f0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refBuffer1, sampler refBuffer1Smplr, thread float4& gl_FragCoord, constant ReferenceUniformseb54b9b7ba7f0& _48, thread float4& referenceColor)
{
    float phiQuarter = 1.570796966552734375;
    float enchantDecryption = 8.0;
    float keyDecryptSyamjaiDtz = 0.943778336048126220703125;
    float keyDecryptSec = 0.63558638095855712890625;
    float keyDecryptThird = 0.7377994060516357421875;
    keyDecryptSyamjaiDtz = 1.0;
    float2 param = gl_FragCoord.xy / _48.refScreen.xy;
    float4 DecodingFX = texture2DCv(refBuffer1, refBuffer1Smplr, param) * keyDecryptSyamjaiDtz;
    referenceColor = DecodingFX;
}

fragment refAM35_eb54b9b7ba7f0_out refAM35_eb54b9b7ba7f0(constant ReferenceUniformseb54b9b7ba7f0& _48 [[buffer(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb54b9b7ba7f0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refBuffer1, refBuffer1Smplr, gl_FragCoord, _48, referenceColor);
    bool _70 = any(isnan(referenceColor));
    bool _77;
    if (!_70)
    {
        _77 = any(isinf(referenceColor));
    }
    else
    {
        _77 = _70;
    }
    if (_77)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _92 = referenceColor;
    float3 _98 = fast::clamp(_92.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _98.x;
    referenceColor.y = _98.y;
    referenceColor.z = _98.z;
    out.finalColor = referenceColor;
    return out;
}

