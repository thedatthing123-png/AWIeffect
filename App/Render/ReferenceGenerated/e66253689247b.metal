// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxeclipse.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse66253689247b
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    uint autop;
    char _m8_pad[12];
    float PROGRESS;
    char _m9_pad[12];
    float SPEED;
    char _m10_pad[12];
    float scale;
    char _m11_pad[12];
    float angle;
    char _m12_pad[8];
    float2 position;
    char _m13_pad[8];
    float2 stretch;
    char _m14_pad[8];
    float alpha;
    char _m15_pad[12];
    float hardness;
    char _m16_pad[12];
    int blendMode;
};

struct refAM35_e66253689247b_out
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
float circle(thread const float2& uv, thread const float& blur)
{
    return smoothstep(0.0, blur, 1.0 - length(uv));
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse66253689247b& _95, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float2 param = gl_FragCoord.xy / _95.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param_1);
    float2 iResolution = float2(_95.refScreen.x, _95.refScreen.y);
    float2 iMouse = float2(0.5);
    float _136;
    if (_95.autop != 0u)
    {
        _136 = _95.PROGRESS + (_95.refScreen.z * _95.SPEED);
    }
    else
    {
        _136 = _95.PROGRESS;
    }
    float iTime = _136;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _95.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _95.refScreen.xy).y) * _95.refScreen.xy) - float2(_95.refLayer.x + (_95.refLayer.z * 0.5), (_95.refScreen.y - _95.refLayer.y) - (_95.refLayer.w * 0.5))) / _95.refLayer.zw;
    syamjaidtz.y *= (_95.refLayer.w / _95.refLayer.z);
    syamjaidtz /= float2(_95.scale);
    float param_2 = (0.0 + _95.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_2);
    syamjaidtz += ((float2(0.0 + _95.position.x, 0.0 + _95.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 scaleVec = float2(_95.scale * _95.stretch.x, _95.scale * _95.stretch.y);
    syamjaidtz /= scaleVec;
    float2 uv = syamjaidtz;
    if (as_type<int>(_95.refComposition.z) == 0)
    {
        float2 param_3 = uv * 2.4500000476837158203125;
        float param_4 = 1.0;
        float circleWhite = circle(param_3, param_4);
        float2 param_5 = uv * 2.8599998950958251953125;
        float param_6 = 0.699999988079071044921875;
        float circleBlack = circle(param_5, param_6);
        float c = circleWhite - circleBlack;
        c *= 6.0;
        float t = iTime * 5.0;
        float2 param_7 = float2(uv.x - (sin(t) * 0.85000002384185791015625), (1.7999999523162841796875 * uv.y) - (cos(t) * 0.64999997615814208984375)) * 0.800000011920928955078125;
        float param_8 = 1.0;
        c -= circle(param_7, param_8);
        float3 col = float3(c) * float3(1.0, 0.0, 0.5);
        col += (float3(smoothstep(0.20000000298023223876953125, 0.699999988079071044921875, c)) * float3(1.0, 1.0, 0.0));
        col += float3(smoothstep(0.4000000059604644775390625, 0.550000011920928955078125, c));
        referenceColor = float4(col, 1.0);
    }
    else
    {
        float2 param_9 = gl_FragCoord.xy / _95.refScreen.xy;
        float4 xbuffer = texture2DCv(refBuffer1, refBuffer1Smplr, param_9);
        float luminance = dot(xbuffer.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        float4 gradmap = mix(_95.color1, _95.color2, float4(luminance)) * xbuffer.w;
        float4 factor = mix(texColorX, gradmap, float4(1.0));
        float4 resultfinal;
        if (_95.blendMode == 0)
        {
            resultfinal = (factor * _95.hardness) * texColor.w;
        }
        else
        {
            if (_95.blendMode == 1)
            {
                factor *= _95.hardness;
                float4 c_1 = factor + (float4(1.0) * (1.0 - factor.w));
                resultfinal = float4((texColor.xyz / float3(texColor.w)) * c_1.xyz, 1.0) * texColor.w;
            }
            else
            {
                if (_95.blendMode == 2)
                {
                    factor *= _95.hardness;
                    resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                }
                else
                {
                    if (_95.blendMode == 3)
                    {
                        factor *= _95.hardness;
                        float4 param_10 = texColor;
                        float4 param_11 = factor;
                        resultfinal = (newLayer(param_10, param_11) * _95.hardness) * texColor.w;
                    }
                }
            }
        }
        referenceColor = mix(texColor, resultfinal, float4(_95.alpha)) * texColor.w;
    }
}

fragment refAM35_e66253689247b_out refAM35_e66253689247b(constant ReferenceUniformse66253689247b& _95 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e66253689247b_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _95, referenceColor, refBuffer1, refBuffer1Smplr);
    bool _498 = any(isnan(referenceColor));
    bool _505;
    if (!_498)
    {
        _505 = any(isinf(referenceColor));
    }
    else
    {
        _505 = _498;
    }
    if (_505)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _518 = referenceColor;
    float3 _524 = fast::clamp(_518.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _524.x;
    referenceColor.y = _524.y;
    referenceColor.z = _524.z;
    out.finalColor = referenceColor;
    return out;
}

