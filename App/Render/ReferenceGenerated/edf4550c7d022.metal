// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxmultigradmap.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsedf4550c7d022
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    float4 color3;
    float4 color4;
    float progressa;
    char _m10_pad[12];
    float alpha;
    char _m11_pad[12];
    float bright;
    char _m12_pad[12];
    int blendMode;
    char _m13_pad[12];
    float alphab;
};

struct refAM35_edf4550c7d022_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
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
void referenceMain(thread float3x3& rgb2yuv, thread float3x3& yuv2rgb, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsedf4550c7d022& _204, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _204.refScreen.xy;
    float4 col = texture2DCv(refInput, refInputSmplr, param);
    float4 texColor = col;
    float value1 = sign(fast::max(-_204.progressa, 0.0));
    float value2 = step(0.0, _204.progressa);
    float lum = ((0.2989999949932098388671875 * col.x) + (0.58700001239776611328125 * col.y)) + (0.114000000059604644775390625 * col.z);
    lum = (powr(lum, 1.0 - _204.progressa) * value1) + (powr(lum, 1.0 / (1.0 + _204.progressa)) * value2);
    lum *= 3.0;
    value1 = smoothstep(2.0, 3.0, lum);
    value2 = smoothstep(1.0, 2.0, lum);
    float weight4 = value1;
    float weight3 = value2 - value1;
    value1 = smoothstep(0.0, 1.0, lum);
    float weight2 = value1 - value2;
    float weight1 = 1.0 - value1;
    float4 dst = col;
    dst = (((_204.color1 * weight1) + (_204.color2 * weight2)) + (_204.color3 * weight3)) + (_204.color4 * weight4);
    float4 fragColor = mix(col, dst, float4(_204.alpha)) * col.w;
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_204.blendMode == 0)
    {
        resultfinal = (factor * _204.bright) * texColor.w;
    }
    else
    {
        if (_204.blendMode == 1)
        {
            factor *= _204.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_204.blendMode == 2)
            {
                factor *= _204.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
            else
            {
                if (_204.blendMode == 3)
                {
                    factor *= _204.bright;
                    float3 t = smoothstep(float3(0.5), float3(0.5), texColor.xyz);
                    float3 result = (t * (float3(1.0) - ((float3(1.0) - ((texColor.xyz - float3(0.5)) * 2.0)) * (float3(1.0) - factor.xyz)))) + ((float3(1.0) - t) * ((texColor.xyz * 2.0) * factor.xyz));
                    resultfinal = float4(result, texColor.w) * texColor.w;
                }
                else
                {
                    if (_204.blendMode == 4)
                    {
                        float3 colorBlend = float3((texColor.xyz * rgb2yuv).x, (factor.xyz * rgb2yuv).yz) * yuv2rgb;
                        resultfinal = float4(colorBlend, texColor.w) * texColor.w;
                    }
                    else
                    {
                        if (_204.blendMode == 5)
                        {
                            factor *= _204.bright;
                            resultfinal = fast::max(factor, texColor) * texColor.w;
                        }
                        else
                        {
                            if (_204.blendMode == 6)
                            {
                                factor *= _204.bright;
                                resultfinal = (texColor / (float4(1.0) - factor)) * texColor.w;
                            }
                            else
                            {
                                if (_204.blendMode == 7)
                                {
                                    factor *= _204.bright;
                                    resultfinal = (float4(1.0) - ((float4(1.0) - texColor) / factor)) * texColor.w;
                                }
                                else
                                {
                                    if (_204.blendMode == 8)
                                    {
                                        factor *= _204.bright;
                                        resultfinal = (texColor + factor) * texColor.w;
                                    }
                                    else
                                    {
                                        if (_204.blendMode == 9)
                                        {
                                            factor *= _204.bright;
                                            resultfinal = ((texColor + factor) - float4(1.0)) * texColor.w;
                                        }
                                        else
                                        {
                                            if (_204.blendMode == 10)
                                            {
                                                float3 t_1 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                float3 linearLight = (t_1 * (texColor.xyz + ((factor.xyz - float3(0.5)) * 2.0))) + ((float3(1.0) - t_1) * ((texColor.xyz + (factor.xyz * 2.0)) - float3(1.0)));
                                                resultfinal = float4(linearLight, texColor.w) * texColor.w;
                                            }
                                            else
                                            {
                                                if (_204.blendMode == 11)
                                                {
                                                    factor *= _204.bright;
                                                    resultfinal = fast::min(factor, texColor) * texColor.w;
                                                }
                                                else
                                                {
                                                    if (_204.blendMode == 12)
                                                    {
                                                        factor *= _204.bright;
                                                        float3 _671;
                                                        if (length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * factor.xyz) > length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * texColor.xyz))
                                                        {
                                                            _671 = texColor.xyz;
                                                        }
                                                        else
                                                        {
                                                            _671 = factor.xyz;
                                                        }
                                                        float3 darkenColor = _671;
                                                        resultfinal = float4(darkenColor, texColor.w) * texColor.w;
                                                    }
                                                    else
                                                    {
                                                        if (_204.blendMode == 13)
                                                        {
                                                            factor *= _204.bright;
                                                            float3 _711;
                                                            if (length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * factor.xyz) > length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * texColor.xyz))
                                                            {
                                                                _711 = factor.xyz;
                                                            }
                                                            else
                                                            {
                                                                _711 = texColor.xyz;
                                                            }
                                                            float3 lightenColor = _711;
                                                            resultfinal = float4(lightenColor, texColor.w) * texColor.w;
                                                        }
                                                        else
                                                        {
                                                            if (_204.blendMode == 14)
                                                            {
                                                                factor *= _204.bright;
                                                                float3 t_2 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                float3 softLight = (t_2 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - (factor.xyz - float3(0.5)))))) + ((float3(1.0) - t_2) * (texColor.xyz * (factor.xyz + float3(0.5))));
                                                                resultfinal = float4(softLight, texColor.w) * texColor.w;
                                                            }
                                                            else
                                                            {
                                                                if (_204.blendMode == 15)
                                                                {
                                                                    factor *= _204.bright;
                                                                    float3 t_3 = smoothstep(float3(0.5), float3(0.5), texColor.xyz);
                                                                    float3 softOver = (t_3 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - (factor.xyz - float3(0.5)))))) + ((float3(1.0) - t_3) * (texColor.xyz * (factor.xyz + float3(0.5))));
                                                                    resultfinal = float4(softOver, texColor.w) * texColor.w;
                                                                }
                                                                else
                                                                {
                                                                    if (_204.blendMode == 16)
                                                                    {
                                                                        factor *= _204.bright;
                                                                        float3 t_4 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                        float3 hardLight = (t_4 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - ((factor.xyz - float3(0.5)) * 2.0))))) + ((float3(1.0) - t_4) * (texColor.xyz * (factor.xyz * 2.0)));
                                                                        resultfinal = float4(hardLight, texColor.w) * texColor.w;
                                                                    }
                                                                    else
                                                                    {
                                                                        if (_204.blendMode == 17)
                                                                        {
                                                                            factor *= _204.bright;
                                                                            float3 param_1 = factor.xyz;
                                                                            float3 param_2 = texColor.xyz;
                                                                            float3 param_3 = float3(rgb2hsv(param_1).x, rgb2hsv(param_2).yz);
                                                                            float3 hueB = hsv2rgb(param_3);
                                                                            resultfinal = float4(hueB, texColor.w) * texColor.w;
                                                                        }
                                                                        else
                                                                        {
                                                                            if (_204.blendMode == 18)
                                                                            {
                                                                                factor *= _204.bright;
                                                                                resultfinal = float4(abs((texColor.xyz * texColor.w) - factor.xyz), texColor.w);
                                                                            }
                                                                            else
                                                                            {
                                                                                if (_204.blendMode == 19)
                                                                                {
                                                                                    factor *= _204.bright;
                                                                                    float3 lumin = float3((factor.xyz * rgb2yuv).x, (texColor.xyz * rgb2yuv).yz) * yuv2rgb;
                                                                                    resultfinal = float4(lumin, texColor.w) * texColor.w;
                                                                                }
                                                                                else
                                                                                {
                                                                                    if (_204.blendMode == 20)
                                                                                    {
                                                                                        factor *= _204.bright;
                                                                                        float3 param_4 = texColor.xyz;
                                                                                        float3 bot_hsv = rgb2hsv(param_4);
                                                                                        float3 param_5 = factor.xyz;
                                                                                        float3 param_6 = float3(bot_hsv.x, rgb2hsv(param_5).y, bot_hsv.z);
                                                                                        float3 satBlend = hsv2rgb(param_6);
                                                                                        resultfinal = float4(satBlend, texColor.w) * texColor.w;
                                                                                    }
                                                                                    else
                                                                                    {
                                                                                        if (_204.blendMode == 21)
                                                                                        {
                                                                                            factor *= _204.bright;
                                                                                            float3 t_5 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                                            float3 vividLight = (t_5 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * ((factor.xyz - float3(0.5)) * 2.0)))) + ((float3(1.0) - t_5) * (texColor.xyz * (float3(1.0) - (factor.xyz * 2.0))));
                                                                                            resultfinal = float4(vividLight, texColor.w) * texColor.w;
                                                                                        }
                                                                                        else
                                                                                        {
                                                                                            if (_204.blendMode == 22)
                                                                                            {
                                                                                                factor *= _204.bright;
                                                                                                float3 t_6 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                                                float3 pinLight = (t_6 * fast::max(texColor.xyz, (factor.xyz - float3(0.5)) * 2.0)) + ((float3(1.0) - t_6) * fast::min(texColor.xyz, factor.xyz * 2.0));
                                                                                                resultfinal = float4(pinLight, texColor.w) * texColor.w;
                                                                                            }
                                                                                            else
                                                                                            {
                                                                                                if (_204.blendMode == 23)
                                                                                                {
                                                                                                    factor *= _204.bright;
                                                                                                    resultfinal = (texColor / factor) * texColor.w;
                                                                                                }
                                                                                                else
                                                                                                {
                                                                                                    if (_204.blendMode == 24)
                                                                                                    {
                                                                                                        factor *= _204.bright;
                                                                                                        resultfinal = (texColor - factor) * texColor.w;
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
    referenceColor = mix(fragColor, resultfinal, float4(_204.alphab)) * texColor.w;
}

fragment refAM35_edf4550c7d022_out refAM35_edf4550c7d022(constant ReferenceUniformsedf4550c7d022& _204 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_edf4550c7d022_out out = {};
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float4 referenceColor = float4(0.0);
    referenceMain(rgb2yuv, yuv2rgb, refInput, refInputSmplr, gl_FragCoord, _204, referenceColor);
    bool _1188 = any(isnan(referenceColor));
    bool _1195;
    if (!_1188)
    {
        _1195 = any(isinf(referenceColor));
    }
    else
    {
        _1195 = _1188;
    }
    if (_1195)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1208 = referenceColor;
    float3 _1214 = fast::clamp(_1208.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1214.x;
    referenceColor.y = _1214.y;
    referenceColor.z = _1214.z;
    out.finalColor = referenceColor;
    return out;
}

