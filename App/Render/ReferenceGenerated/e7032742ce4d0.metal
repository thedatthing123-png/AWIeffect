// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxfourcolorgradientnew.xml
// Original source comments and attribution:
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse7032742ce4d0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float2 offset1;
    float4 color2;
    float2 offset2;
    float4 color3;
    float2 offset3;
    float4 color4;
    float2 offset4;
    char _m13_pad[8];
    float blend;
    char _m14_pad[12];
    float alpha;
    char _m15_pad[12];
    float bright;
    char _m16_pad[12];
    int blendMode;
    char _m17_pad[12];
    float alphab;
};

struct refAM35_e7032742ce4d0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float gradientNoise(thread const float2& uv)
{
    return fract(52.98291778564453125 * fract(dot(uv, float2(0.067110560834407806396484375, 0.005837149918079376220703125))));
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
void referenceMain(thread float3x3& rgb2yuv, thread float3x3& yuv2rgb, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse7032742ce4d0& _219, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _219.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _219.refLayer.xy) / _219.refLayer.zw;
    float2 pos = (_219.offset1 * float2(1.0, -1.0)) / float2(500.0);
    float t1 = length(st - pos);
    pos = (_219.offset2 * float2(1.0, -1.0)) / float2(500.0);
    float t2 = length(st - pos);
    pos = (_219.offset3 * float2(1.0, -1.0)) / float2(500.0);
    float t3 = length(st - pos);
    pos = (_219.offset4 * float2(1.0, -1.0)) / float2(500.0);
    float t4 = length(st - pos);
    float4 color = float4(0.0);
    float sw_t1 = smoothstep(0.0, 1.0, fast::clamp(1.0 - t1, 0.0, 1.0));
    float sw_t2 = smoothstep(0.0, 1.0, fast::clamp(1.0 - t2, 0.0, 1.0));
    float sw_t3 = smoothstep(0.0, 1.0, fast::clamp(1.0 - t3, 0.0, 1.0));
    float sw_t4 = smoothstep(0.0, 1.0, fast::clamp(1.0 - t4, 0.0, 1.0));
    color += (_219.color1 * powr(sw_t1, 1.0 / _219.blend));
    color += (_219.color2 * powr(sw_t2, 1.0 / _219.blend));
    color += (_219.color3 * powr(sw_t3, 1.0 / _219.blend));
    color += (_219.color4 * powr(sw_t4, 1.0 / _219.blend));
    color /= float4(((sw_t1 + sw_t2) + sw_t3) + sw_t4);
    color.w = 1.0;
    float2 param_1 = st;
    color += float4((0.0039215688593685626983642578125 * gradientNoise(param_1)) - 0.00196078442968428134918212890625);
    float4 result;
    if (_219.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(texColor.w)) * color.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_219.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - color.xyz)), 1.0) * texColor.w;
        }
        else
        {
            result = float4(color.xyz, 1.0) * texColor.w;
        }
    }
    float4 fragColor = mix(texColor, result, float4(_219.alpha));
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_219.blendMode == 0)
    {
        resultfinal = (factor * _219.bright) * texColor.w;
    }
    else
    {
        if (_219.blendMode == 1)
        {
            factor *= _219.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_219.blendMode == 2)
            {
                factor *= _219.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
            else
            {
                if (_219.blendMode == 3)
                {
                    factor *= _219.bright;
                    float3 t = smoothstep(float3(0.5), float3(0.5), texColor.xyz);
                    float3 result_1 = (t * (float3(1.0) - ((float3(1.0) - ((texColor.xyz - float3(0.5)) * 2.0)) * (float3(1.0) - factor.xyz)))) + ((float3(1.0) - t) * ((texColor.xyz * 2.0) * factor.xyz));
                    resultfinal = float4(result_1, texColor.w) * texColor.w;
                }
                else
                {
                    if (_219.blendMode == 4)
                    {
                        float3 colorBlend = float3((texColor.xyz * rgb2yuv).x, (factor.xyz * rgb2yuv).yz) * yuv2rgb;
                        resultfinal = float4(colorBlend, texColor.w) * texColor.w;
                    }
                    else
                    {
                        if (_219.blendMode == 5)
                        {
                            factor *= _219.bright;
                            resultfinal = fast::max(factor, texColor) * texColor.w;
                        }
                        else
                        {
                            if (_219.blendMode == 6)
                            {
                                factor *= _219.bright;
                                resultfinal = (texColor / (float4(1.0) - factor)) * texColor.w;
                            }
                            else
                            {
                                if (_219.blendMode == 7)
                                {
                                    factor *= _219.bright;
                                    resultfinal = (float4(1.0) - ((float4(1.0) - texColor) / factor)) * texColor.w;
                                }
                                else
                                {
                                    if (_219.blendMode == 8)
                                    {
                                        factor *= _219.bright;
                                        resultfinal = (texColor + factor) * texColor.w;
                                    }
                                    else
                                    {
                                        if (_219.blendMode == 9)
                                        {
                                            factor *= _219.bright;
                                            resultfinal = ((texColor + factor) - float4(1.0)) * texColor.w;
                                        }
                                        else
                                        {
                                            if (_219.blendMode == 10)
                                            {
                                                float3 t_1 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                float3 linearLight = (t_1 * (texColor.xyz + ((factor.xyz - float3(0.5)) * 2.0))) + ((float3(1.0) - t_1) * ((texColor.xyz + (factor.xyz * 2.0)) - float3(1.0)));
                                                resultfinal = float4(linearLight, texColor.w) * texColor.w;
                                            }
                                            else
                                            {
                                                if (_219.blendMode == 11)
                                                {
                                                    factor *= _219.bright;
                                                    resultfinal = fast::min(factor, texColor) * texColor.w;
                                                }
                                                else
                                                {
                                                    if (_219.blendMode == 12)
                                                    {
                                                        factor *= _219.bright;
                                                        float3 _803;
                                                        if (length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * factor.xyz) > length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * texColor.xyz))
                                                        {
                                                            _803 = texColor.xyz;
                                                        }
                                                        else
                                                        {
                                                            _803 = factor.xyz;
                                                        }
                                                        float3 darkenColor = _803;
                                                        resultfinal = float4(darkenColor, texColor.w) * texColor.w;
                                                    }
                                                    else
                                                    {
                                                        if (_219.blendMode == 13)
                                                        {
                                                            factor *= _219.bright;
                                                            float3 _842;
                                                            if (length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * factor.xyz) > length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * texColor.xyz))
                                                            {
                                                                _842 = factor.xyz;
                                                            }
                                                            else
                                                            {
                                                                _842 = texColor.xyz;
                                                            }
                                                            float3 lightenColor = _842;
                                                            resultfinal = float4(lightenColor, texColor.w) * texColor.w;
                                                        }
                                                        else
                                                        {
                                                            if (_219.blendMode == 14)
                                                            {
                                                                factor *= _219.bright;
                                                                float3 t_2 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                float3 softLight = (t_2 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - (factor.xyz - float3(0.5)))))) + ((float3(1.0) - t_2) * (texColor.xyz * (factor.xyz + float3(0.5))));
                                                                resultfinal = float4(softLight, texColor.w) * texColor.w;
                                                            }
                                                            else
                                                            {
                                                                if (_219.blendMode == 15)
                                                                {
                                                                    factor *= _219.bright;
                                                                    float3 t_3 = smoothstep(float3(0.5), float3(0.5), texColor.xyz);
                                                                    float3 softOver = (t_3 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - (factor.xyz - float3(0.5)))))) + ((float3(1.0) - t_3) * (texColor.xyz * (factor.xyz + float3(0.5))));
                                                                    resultfinal = float4(softOver, texColor.w) * texColor.w;
                                                                }
                                                                else
                                                                {
                                                                    if (_219.blendMode == 16)
                                                                    {
                                                                        factor *= _219.bright;
                                                                        float3 t_4 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                        float3 hardLight = (t_4 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - ((factor.xyz - float3(0.5)) * 2.0))))) + ((float3(1.0) - t_4) * (texColor.xyz * (factor.xyz * 2.0)));
                                                                        resultfinal = float4(hardLight, texColor.w) * texColor.w;
                                                                    }
                                                                    else
                                                                    {
                                                                        if (_219.blendMode == 17)
                                                                        {
                                                                            factor *= _219.bright;
                                                                            float3 param_2 = factor.xyz;
                                                                            float3 param_3 = texColor.xyz;
                                                                            float3 param_4 = float3(rgb2hsv(param_2).x, rgb2hsv(param_3).yz);
                                                                            float3 hueB = hsv2rgb(param_4);
                                                                            resultfinal = float4(hueB, texColor.w) * texColor.w;
                                                                        }
                                                                        else
                                                                        {
                                                                            if (_219.blendMode == 18)
                                                                            {
                                                                                factor *= _219.bright;
                                                                                resultfinal = float4(abs((texColor.xyz * texColor.w) - factor.xyz), texColor.w);
                                                                            }
                                                                            else
                                                                            {
                                                                                if (_219.blendMode == 19)
                                                                                {
                                                                                    factor *= _219.bright;
                                                                                    float3 lumin = float3((factor.xyz * rgb2yuv).x, (texColor.xyz * rgb2yuv).yz) * yuv2rgb;
                                                                                    resultfinal = float4(lumin, texColor.w) * texColor.w;
                                                                                }
                                                                                else
                                                                                {
                                                                                    if (_219.blendMode == 20)
                                                                                    {
                                                                                        factor *= _219.bright;
                                                                                        float3 param_5 = texColor.xyz;
                                                                                        float3 bot_hsv = rgb2hsv(param_5);
                                                                                        float3 param_6 = factor.xyz;
                                                                                        float3 param_7 = float3(bot_hsv.x, rgb2hsv(param_6).y, bot_hsv.z);
                                                                                        float3 satBlend = hsv2rgb(param_7);
                                                                                        resultfinal = float4(satBlend, texColor.w) * texColor.w;
                                                                                    }
                                                                                    else
                                                                                    {
                                                                                        if (_219.blendMode == 21)
                                                                                        {
                                                                                            factor *= _219.bright;
                                                                                            float3 t_5 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                                            float3 vividLight = (t_5 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * ((factor.xyz - float3(0.5)) * 2.0)))) + ((float3(1.0) - t_5) * (texColor.xyz * (float3(1.0) - (factor.xyz * 2.0))));
                                                                                            resultfinal = float4(vividLight, texColor.w) * texColor.w;
                                                                                        }
                                                                                        else
                                                                                        {
                                                                                            if (_219.blendMode == 22)
                                                                                            {
                                                                                                factor *= _219.bright;
                                                                                                float3 t_6 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                                                float3 pinLight = (t_6 * fast::max(texColor.xyz, (factor.xyz - float3(0.5)) * 2.0)) + ((float3(1.0) - t_6) * fast::min(texColor.xyz, factor.xyz * 2.0));
                                                                                                resultfinal = float4(pinLight, texColor.w) * texColor.w;
                                                                                            }
                                                                                            else
                                                                                            {
                                                                                                if (_219.blendMode == 23)
                                                                                                {
                                                                                                    factor *= _219.bright;
                                                                                                    resultfinal = (texColor / factor) * texColor.w;
                                                                                                }
                                                                                                else
                                                                                                {
                                                                                                    if (_219.blendMode == 24)
                                                                                                    {
                                                                                                        factor *= _219.bright;
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
    referenceColor = mix(fragColor, resultfinal, float4(_219.alphab)) * texColor.w;
}

fragment refAM35_e7032742ce4d0_out refAM35_e7032742ce4d0(constant ReferenceUniformse7032742ce4d0& _219 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e7032742ce4d0_out out = {};
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float4 referenceColor = float4(0.0);
    referenceMain(rgb2yuv, yuv2rgb, refInput, refInputSmplr, gl_FragCoord, _219, referenceColor);
    bool _1315 = any(isnan(referenceColor));
    bool _1322;
    if (!_1315)
    {
        _1322 = any(isinf(referenceColor));
    }
    else
    {
        _1322 = _1315;
    }
    if (_1322)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1335 = referenceColor;
    float3 _1341 = fast::clamp(_1335.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1341.x;
    referenceColor.y = _1341.y;
    referenceColor.z = _1341.z;
    out.finalColor = referenceColor;
    return out;
}

