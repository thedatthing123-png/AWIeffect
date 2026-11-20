// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxcolorbalanceold.xml
// Original source comments and attribution:
/////////////////////////
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse26dde3c2724a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float redValue;
    char _m6_pad[12];
    float greenValue;
    char _m7_pad[12];
    float blueValue;
    char _m8_pad[12];
    float alpha;
    char _m9_pad[12];
    float bright;
    char _m10_pad[12];
    int blendMode;
    char _m11_pad[12];
    float alphab;
};

struct refAM35_e26dde3c2724a_out
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
float3 rgb2hsv(thread const float3& c)
{
    float4 K = float4(0.0, -0.3333333432674407958984375, 0.666666686534881591796875, -1.0);
    float4 p = mix(float4(c.zy, K.wz), float4(c.yz, K.xy), float4(step(c.z, c.y)));
    float4 q = mix(float4(p.xyw, c.x), float4(c.x, p.yzx), float4(step(p.x, c.x)));
    float d = q.x - fast::min(q.w, q.y);
    float e = 1.0000000133514319600180897396058e-10;
    return float3(abs(q.z + ((q.w - q.y) / ((6.0 * d) + e))), d / (q.x + e), q.x);
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(thread float3x3& rgb2yuv, thread float3x3& yuv2rgb, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse26dde3c2724a& _225, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _225.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = _225.refScreen.xy;
    float2 image_size = getTexSize(param_1);
    float2 iResolution = float2(_225.refScreen.x, _225.refScreen.y);
    float2 iMouse = float2(0.5);
    float fr = (_225.redValue * _225.redValue) * sign(_225.redValue);
    float dr = (-fr) / 2.0;
    float fg = (_225.greenValue * _225.greenValue) * sign(_225.greenValue);
    float dg = (-fg) / 2.0;
    float fb = (_225.blueValue * _225.blueValue) * sign(_225.blueValue);
    float db = (-fb) / 2.0;
    float4x4 myMatrix;
    myMatrix[0].x = 1.0 + fr;
    myMatrix[0].y = dg;
    myMatrix[0].z = db;
    myMatrix[0].w = 0.0;
    myMatrix[1].x = dr;
    myMatrix[1].y = 1.0 + fg;
    myMatrix[1].z = db;
    myMatrix[1].w = 0.0;
    myMatrix[2].x = dr;
    myMatrix[2].y = dg;
    myMatrix[2].z = 1.0 + fb;
    myMatrix[2].w = 0.0;
    myMatrix[3].x = 0.0;
    myMatrix[3].y = 0.0;
    myMatrix[3].z = 0.0;
    myMatrix[3].w = 1.0;
    float2 param_2 = gl_FragCoord.xy / _225.refScreen.xy;
    float4 inputColor = texture2DCv(refInput, refInputSmplr, param_2);
    inputColor *= myMatrix;
    float3 _352 = fast::min(inputColor.xyz, float3(inputColor.w));
    float4 dst;
    dst.x = _352.x;
    dst.y = _352.y;
    dst.z = _352.z;
    dst.w = inputColor.w;
    float4 fragColor = dst;
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_225.blendMode == 0)
    {
        resultfinal = (factor * _225.bright) * texColor.w;
    }
    else
    {
        if (_225.blendMode == 1)
        {
            factor *= _225.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_225.blendMode == 2)
            {
                factor *= _225.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
            else
            {
                if (_225.blendMode == 3)
                {
                    factor *= _225.bright;
                    float3 t = smoothstep(float3(0.5), float3(0.5), texColor.xyz);
                    float3 result = (t * (float3(1.0) - ((float3(1.0) - ((texColor.xyz - float3(0.5)) * 2.0)) * (float3(1.0) - factor.xyz)))) + ((float3(1.0) - t) * ((texColor.xyz * 2.0) * factor.xyz));
                    resultfinal = float4(result, texColor.w) * texColor.w;
                }
                else
                {
                    if (_225.blendMode == 4)
                    {
                        float3 colorBlend = float3((texColor.xyz * rgb2yuv).x, (factor.xyz * rgb2yuv).yz) * yuv2rgb;
                        resultfinal = float4(colorBlend, texColor.w) * texColor.w;
                    }
                    else
                    {
                        if (_225.blendMode == 5)
                        {
                            factor *= _225.bright;
                            resultfinal = fast::max(factor, texColor) * texColor.w;
                        }
                        else
                        {
                            if (_225.blendMode == 6)
                            {
                                factor *= _225.bright;
                                resultfinal = (texColor / (float4(1.0) - factor)) * texColor.w;
                            }
                            else
                            {
                                if (_225.blendMode == 7)
                                {
                                    factor *= _225.bright;
                                    resultfinal = (float4(1.0) - ((float4(1.0) - texColor) / factor)) * texColor.w;
                                }
                                else
                                {
                                    if (_225.blendMode == 8)
                                    {
                                        factor *= _225.bright;
                                        resultfinal = (texColor + factor) * texColor.w;
                                    }
                                    else
                                    {
                                        if (_225.blendMode == 9)
                                        {
                                            factor *= _225.bright;
                                            resultfinal = ((texColor + factor) - float4(1.0)) * texColor.w;
                                        }
                                        else
                                        {
                                            if (_225.blendMode == 10)
                                            {
                                                float3 t_1 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                float3 linearLight = (t_1 * (texColor.xyz + ((factor.xyz - float3(0.5)) * 2.0))) + ((float3(1.0) - t_1) * ((texColor.xyz + (factor.xyz * 2.0)) - float3(1.0)));
                                                resultfinal = float4(linearLight, texColor.w) * texColor.w;
                                            }
                                            else
                                            {
                                                if (_225.blendMode == 11)
                                                {
                                                    factor *= _225.bright;
                                                    resultfinal = fast::min(factor, texColor) * texColor.w;
                                                }
                                                else
                                                {
                                                    if (_225.blendMode == 12)
                                                    {
                                                        factor *= _225.bright;
                                                        float3 _716;
                                                        if (length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * factor.xyz) > length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * texColor.xyz))
                                                        {
                                                            _716 = texColor.xyz;
                                                        }
                                                        else
                                                        {
                                                            _716 = factor.xyz;
                                                        }
                                                        float3 darkenColor = _716;
                                                        resultfinal = float4(darkenColor, texColor.w) * texColor.w;
                                                    }
                                                    else
                                                    {
                                                        if (_225.blendMode == 13)
                                                        {
                                                            factor *= _225.bright;
                                                            float3 _756;
                                                            if (length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * factor.xyz) > length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * texColor.xyz))
                                                            {
                                                                _756 = factor.xyz;
                                                            }
                                                            else
                                                            {
                                                                _756 = texColor.xyz;
                                                            }
                                                            float3 lightenColor = _756;
                                                            resultfinal = float4(lightenColor, texColor.w) * texColor.w;
                                                        }
                                                        else
                                                        {
                                                            if (_225.blendMode == 14)
                                                            {
                                                                factor *= _225.bright;
                                                                float3 t_2 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                float3 softLight = (t_2 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - (factor.xyz - float3(0.5)))))) + ((float3(1.0) - t_2) * (texColor.xyz * (factor.xyz + float3(0.5))));
                                                                resultfinal = float4(softLight, texColor.w) * texColor.w;
                                                            }
                                                            else
                                                            {
                                                                if (_225.blendMode == 15)
                                                                {
                                                                    factor *= _225.bright;
                                                                    float3 t_3 = smoothstep(float3(0.5), float3(0.5), texColor.xyz);
                                                                    float3 softOver = (t_3 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - (factor.xyz - float3(0.5)))))) + ((float3(1.0) - t_3) * (texColor.xyz * (factor.xyz + float3(0.5))));
                                                                    resultfinal = float4(softOver, texColor.w) * texColor.w;
                                                                }
                                                                else
                                                                {
                                                                    if (_225.blendMode == 16)
                                                                    {
                                                                        factor *= _225.bright;
                                                                        float3 t_4 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                        float3 hardLight = (t_4 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - ((factor.xyz - float3(0.5)) * 2.0))))) + ((float3(1.0) - t_4) * (texColor.xyz * (factor.xyz * 2.0)));
                                                                        resultfinal = float4(hardLight, texColor.w) * texColor.w;
                                                                    }
                                                                    else
                                                                    {
                                                                        if (_225.blendMode == 17)
                                                                        {
                                                                            factor *= _225.bright;
                                                                            float3 param_3 = factor.xyz;
                                                                            float3 param_4 = texColor.xyz;
                                                                            float3 param_5 = float3(rgb2hsv(param_3).x, rgb2hsv(param_4).yz);
                                                                            float3 hueB = hsv2rgb(param_5);
                                                                            resultfinal = float4(hueB, texColor.w) * texColor.w;
                                                                        }
                                                                        else
                                                                        {
                                                                            if (_225.blendMode == 18)
                                                                            {
                                                                                factor *= _225.bright;
                                                                                resultfinal = float4(abs((texColor.xyz * texColor.w) - factor.xyz), texColor.w);
                                                                            }
                                                                            else
                                                                            {
                                                                                if (_225.blendMode == 19)
                                                                                {
                                                                                    factor *= _225.bright;
                                                                                    float3 lumin = float3((factor.xyz * rgb2yuv).x, (texColor.xyz * rgb2yuv).yz) * yuv2rgb;
                                                                                    resultfinal = float4(lumin, texColor.w) * texColor.w;
                                                                                }
                                                                                else
                                                                                {
                                                                                    if (_225.blendMode == 20)
                                                                                    {
                                                                                        factor *= _225.bright;
                                                                                        float3 param_6 = texColor.xyz;
                                                                                        float3 bot_hsv = rgb2hsv(param_6);
                                                                                        float3 param_7 = factor.xyz;
                                                                                        float3 param_8 = float3(bot_hsv.x, rgb2hsv(param_7).y, bot_hsv.z);
                                                                                        float3 satBlend = hsv2rgb(param_8);
                                                                                        resultfinal = float4(satBlend, texColor.w) * texColor.w;
                                                                                    }
                                                                                    else
                                                                                    {
                                                                                        if (_225.blendMode == 21)
                                                                                        {
                                                                                            factor *= _225.bright;
                                                                                            float3 t_5 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                                            float3 vividLight = (t_5 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * ((factor.xyz - float3(0.5)) * 2.0)))) + ((float3(1.0) - t_5) * (texColor.xyz * (float3(1.0) - (factor.xyz * 2.0))));
                                                                                            resultfinal = float4(vividLight, texColor.w) * texColor.w;
                                                                                        }
                                                                                        else
                                                                                        {
                                                                                            if (_225.blendMode == 22)
                                                                                            {
                                                                                                factor *= _225.bright;
                                                                                                float3 t_6 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                                                float3 pinLight = (t_6 * fast::max(texColor.xyz, (factor.xyz - float3(0.5)) * 2.0)) + ((float3(1.0) - t_6) * fast::min(texColor.xyz, factor.xyz * 2.0));
                                                                                                resultfinal = float4(pinLight, texColor.w) * texColor.w;
                                                                                            }
                                                                                            else
                                                                                            {
                                                                                                if (_225.blendMode == 23)
                                                                                                {
                                                                                                    factor *= _225.bright;
                                                                                                    resultfinal = (texColor / factor) * texColor.w;
                                                                                                }
                                                                                                else
                                                                                                {
                                                                                                    if (_225.blendMode == 24)
                                                                                                    {
                                                                                                        factor *= _225.bright;
                                                                                                        resultfinal = (texColor - factor) * texColor.w;
                                                                                                    }
                                                                                                    else
                                                                                                    {
                                                                                                        if (_225.blendMode == 25)
                                                                                                        {
                                                                                                            factor *= _225.bright;
                                                                                                            float4 param_9 = texColor;
                                                                                                            float4 param_10 = factor;
                                                                                                            resultfinal = newLayer(param_9, param_10) * texColor.w;
                                                                                                        }
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                    }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    float4 satriyhaidfx = mix(factor, resultfinal, float4(_225.alphab));
    referenceColor = mix(texColor, satriyhaidfx, float4(_225.alpha)) * texColor.w;
}

fragment refAM35_e26dde3c2724a_out refAM35_e26dde3c2724a(constant ReferenceUniformse26dde3c2724a& _225 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e26dde3c2724a_out out = {};
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float4 referenceColor = float4(0.0);
    referenceMain(rgb2yuv, yuv2rgb, refInput, refInputSmplr, gl_FragCoord, _225, referenceColor);
    bool _1259 = any(isnan(referenceColor));
    bool _1266;
    if (!_1259)
    {
        _1266 = any(isinf(referenceColor));
    }
    else
    {
        _1266 = _1259;
    }
    if (_1266)
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

