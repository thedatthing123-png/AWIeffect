// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsdotsloader.xml
// Original source comments and attribution:
//////////////////////////
//////////////////////////
/////////////////////////
// f += 0.01 / abs(length(p*0.5 + vec2(c, s)));
// resultfinal = (newLayer(texColor, factor) * hardness) * texColor.a; }
// resultfinal = min(factor, texColor) * texColor.a; }
// else if( blendMode==3 ) { factor *= hardness; 
// resultfinal = (newLayer(texColor, factor) * hardness) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse790401dd864c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 COLOR;
    float AMOUNT;
    char _m7_pad[12];
    float xxc;
    char _m8_pad[12];
    float xxb;
    char _m9_pad[12];
    float xxa;
    char _m10_pad[12];
    float xxe;
    char _m11_pad[12];
    float xxd;
    char _m12_pad[12];
    float scale;
    char _m13_pad[12];
    float angle;
    char _m14_pad[8];
    float2 position;
    char _m15_pad[8];
    float2 stretch;
    char _m16_pad[8];
    float alpha;
    char _m17_pad[12];
    float hardness;
    char _m18_pad[12];
    int blendMode;
};

struct refAM35_e790401dd864c_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse790401dd864c& _60, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_60.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _60.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_60.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _60.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_60.refScreen.x, _60.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _60.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _60.refScreen.xy).y) * _60.refScreen.xy) - float2(_60.refLayer.x + (_60.refLayer.z * 0.5), (_60.refScreen.y - _60.refLayer.y) - (_60.refLayer.w * 0.5))) / _60.refLayer.zw;
            syamjaidtz.y *= (_60.refLayer.w / _60.refLayer.z);
            syamjaidtz /= float2(_60.scale);
            float param_3 = (0.0 + _60.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _60.position.x, 0.0 + _60.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_60.scale * _60.stretch.x, _60.scale * _60.stretch.y);
            syamjaidtz /= scaleVec;
            float2 p = syamjaidtz;
            float f = 0.0;
            for (float i = 1.0; i <= _60.AMOUNT; i += 1.0)
            {
                float s = sin((0.699999988079071044921875 * _60.xxa) + ((i * 0.5) * _60.xxa)) * _60.xxd;
                float c = cos((0.20000000298023223876953125 * _60.xxb) + ((i * 0.5) * _60.xxb)) * _60.xxe;
                f += (_60.xxc / abs(length(p + float2(c, s))));
            }
            float4 fragColor = float4(_60.COLOR.xyz * f, 1.0);
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal;
            if (_60.blendMode == 0)
            {
                resultfinal = (factor * _60.hardness) * texColor.w;
            }
            else
            {
                if (_60.blendMode == 1)
                {
                    factor *= _60.hardness;
                    float4 c_1 = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c_1.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_60.blendMode == 2)
                    {
                        factor *= _60.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_60.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e790401dd864c_out refAM35_e790401dd864c(constant ReferenceUniformse790401dd864c& _60 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e790401dd864c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_60, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _406 = any(isnan(referenceColor));
    bool _413;
    if (!_406)
    {
        _413 = any(isinf(referenceColor));
    }
    else
    {
        _413 = _406;
    }
    if (_413)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _426 = referenceColor;
    float3 _432 = fast::clamp(_426.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _432.x;
    referenceColor.y = _432.y;
    referenceColor.z = _432.z;
    out.finalColor = referenceColor;
    return out;
}

