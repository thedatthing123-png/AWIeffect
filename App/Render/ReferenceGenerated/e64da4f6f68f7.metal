// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxx2dtuunnell.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
// fragColor = newLayer(color3, lineT) * texColor.a;
// normal
// multiply
// screen
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse64da4f6f68f7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    uint scalex;
    char _m8_pad[12];
    float scale;
    char _m9_pad[12];
    float progressa;
    char _m10_pad[12];
    float progressb;
    char _m11_pad[12];
    float progressc;
    char _m12_pad[8];
    float2 position;
    char _m13_pad[8];
    float2 stretch;
    char _m14_pad[8];
    float bright;
    char _m15_pad[12];
    float alpha;
    char _m16_pad[12];
    float angle;
    char _m17_pad[12];
    int blendMode;
};

struct refAM35_e64da4f6f68f7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse64da4f6f68f7& _61, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _61.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _61.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _61.refScreen.xy).y) * _61.refScreen.xy) - float2(_61.refLayer.x + (_61.refLayer.z * 0.5), (_61.refScreen.y - _61.refLayer.y) - (_61.refLayer.w * 0.5))) / _61.refLayer.zw;
    syamjaidtz.y *= (_61.refLayer.w / _61.refLayer.z);
    float _139;
    if (_61.scalex != 0u)
    {
        _139 = _61.scale + 0.699999988079071044921875;
    }
    else
    {
        _139 = _61.scale - 0.819999992847442626953125;
    }
    syamjaidtz /= float2(_139);
    float param_1 = (0.0 + _61.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((float2(0.0 + _61.position.x, 0.0 + _61.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 scaleVec = float2(_61.scale * _61.stretch.x, _61.scale * _61.stretch.y);
    syamjaidtz /= scaleVec;
    float2 center = syamjaidtz;
    center.x *= (_61.refScreen.x / _61.refScreen.x);
    float a = ((1.0 / length(center)) + ((precise::atan2(center.x, center.y) / 3.141590118408203125) * _61.progressb)) + _61.progressa;
    float b = (((sin((a * 3.141590118408203125) * 8.0) * dot(center, center)) * _61.refScreen.y) / (_61.progressc + 300.0)) - 0.300000011920928955078125;
    float c = b * sin(length(center) - 0.100000001490116119384765625);
    float4 lineT = mix(_61.color1, _61.color2, float4(c));
    float4 fragColor = lineT;
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_61.blendMode == 0)
    {
        resultfinal = (factor * _61.bright) * texColor.w;
    }
    else
    {
        if (_61.blendMode == 1)
        {
            factor *= _61.bright;
            float4 c_1 = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c_1.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_61.blendMode == 2)
            {
                factor *= _61.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_61.alpha));
}

fragment refAM35_e64da4f6f68f7_out refAM35_e64da4f6f68f7(constant ReferenceUniformse64da4f6f68f7& _61 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e64da4f6f68f7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _61, referenceColor);
    bool _373 = any(isnan(referenceColor));
    bool _380;
    if (!_373)
    {
        _380 = any(isinf(referenceColor));
    }
    else
    {
        _380 = _373;
    }
    if (_380)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _393 = referenceColor;
    float3 _399 = fast::clamp(_393.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _399.x;
    referenceColor.y = _399.y;
    referenceColor.z = _399.z;
    out.finalColor = referenceColor;
    return out;
}

