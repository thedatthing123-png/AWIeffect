// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxfencingwire.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
// if (adaptive) { 
// syamjaidtz = acScreenNorm; 
// }
// else { 
// }
// normal
// multiply
// screen
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsedd9730a273e2
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float2 stretch;
    char _m7_pad[8];
    float scale;
    char _m8_pad[12];
    float bright;
    char _m9_pad[12];
    float alpha;
    char _m10_pad[12];
    float angle;
    char _m11_pad[12];
    int blendMode;
};

struct refAM35_edd9730a273e2_out
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
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsedd9730a273e2& _76, texture2d<float> refImage1, sampler refImage1Smplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _76.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _76.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _76.refScreen.xy).y) * _76.refScreen.xy) - float2(_76.refLayer.x + (_76.refLayer.z * 0.5), (_76.refScreen.y - _76.refLayer.y) - (_76.refLayer.w * 0.5))) / _76.refLayer.zw;
    syamjaidtz.y *= (_76.refLayer.w / _76.refLayer.z);
    syamjaidtz.x = 1.0 - syamjaidtz.x;
    syamjaidtz /= float2(_76.scale);
    float param_1 = (0.0 + _76.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((float2(0.0 + _76.position.x, 0.0 + _76.position.y) * float2(-1.0, 1.0)) / float2(200.0));
    float2 scaleVec = float2(_76.scale * _76.stretch.x, _76.scale * _76.stretch.y);
    syamjaidtz /= scaleVec;
    float2 param_2 = syamjaidtz;
    float4 factor = texture2DCv(refImage1, refImage1Smplr, param_2);
    float4 resultfinal;
    if (_76.blendMode == 0)
    {
        float4 param_3 = texColor;
        float4 param_4 = factor * _76.bright;
        resultfinal = newLayer(param_3, param_4) * texColor.w;
    }
    else
    {
        if (_76.blendMode == 1)
        {
            factor *= _76.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_76.blendMode == 2)
            {
                factor *= _76.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_76.alpha)) * texColor.w;
}

fragment refAM35_edd9730a273e2_out refAM35_edd9730a273e2(constant ReferenceUniformsedd9730a273e2& _76 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_edd9730a273e2_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _76, refImage1, refImage1Smplr, referenceColor);
    bool _310 = any(isnan(referenceColor));
    bool _317;
    if (!_310)
    {
        _317 = any(isinf(referenceColor));
    }
    else
    {
        _317 = _310;
    }
    if (_317)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _330 = referenceColor;
    float3 _336 = fast::clamp(_330.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _336.x;
    referenceColor.y = _336.y;
    referenceColor.z = _336.z;
    out.finalColor = referenceColor;
    return out;
}

