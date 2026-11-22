// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxgradshadow.xml
// Original source comments and attribution:
/////////////////////////
// highp mat3 rgb2yuv = mat3(
// 0.299,     0.587,    0.114,
// -0.14713,  -0.28886,  0.436,
// 0.615,    -0.51499, -0.10001
// );
// highp mat3 yuv2rgb = mat3(
// 1.0,  0.0,      1.13983,
// 1.0, -0.39465, -0.58060,
// 1.0,  2.03211,  0.0
// );
// float radius = hue * 0.0174533;
// highp mat3 huemat = mat3(
// 1.0,  0.0,       0.0,
// 0.0,  cos(radius),  sin(radius),
// 0.0,  -sin(radius), cos(radius)
// );
// syamjaidtz *= rot2m(angle*0.0174533);
// syamjaidtz += position*vec2(-1.,1.)/500.;
/////////////////////////
//vec2 v = (vec4(normalize(vec2(cos(rad),-sin(rad))),0.0,1.0) * acLayerToScreen).xy;
//float p = length(projectAndClamp(acLayerNorm.st-vec2(0.5,0.5), v))/length(v)+0.5;
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse227d3c4d2f74
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color;
    float start;
    char _m7_pad[12];
    float angle;
    char _m8_pad[12];
    float alphb;
    char _m9_pad[12];
    float feather;
    char _m10_pad[12];
    float end;
    char _m11_pad[12];
    float bright;
    char _m12_pad[12];
    int blendMode;
    char _m13_pad[12];
    float alphab;
};

struct refAM35_e227d3c4d2f74_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float smoothstepRev(thread const float& edge0, thread const float& edge1, thread const float& x)
{
    if (edge0 == edge1)
    {
        return step(edge0, x);
    }
    else
    {
        return smoothstep(edge0, edge1, x);
    }
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
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
void referenceMain(thread float3x3& rgb2yuv, thread float3x3& yuv2rgb, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse227d3c4d2f74& _241, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _241.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 syamjaidtz = (gl_FragCoord.xy - _241.refLayer.xy) / _241.refLayer.zw;
    syamjaidtz -= float2(0.5);
    syamjaidtz += float2(0.5);
    syamjaidtz.x *= (_241.refLayer.z / _241.refLayer.w);
    syamjaidtz.x /= (_241.refLayer.z / _241.refLayer.w);
    syamjaidtz /= float2(1.0);
    float adjStart = _241.start;
    float adjEnd = _241.end;
    float adjFeather = _241.feather / 100.0;
    float rad = _241.angle * 0.01745329983532428741455078125;
    float2 v = fast::normalize(float2(cos(rad), -sin(rad)));
    float p = dot(((gl_FragCoord.xy - _241.refLayer.xy) / _241.refLayer.zw) - float2(0.5), v) + 0.5;
    float param_1 = adjStart - adjFeather;
    float param_2 = adjStart;
    float param_3 = p;
    float p0 = smoothstepRev(param_1, param_2, param_3);
    float param_4 = adjEnd;
    float param_5 = adjEnd + adjFeather;
    float param_6 = p;
    float p1 = 1.0 - smoothstepRev(param_4, param_5, param_6);
    float2 param_7 = gl_FragCoord.xy / _241.refScreen.xy;
    float4 result = (texture2DCv(refInput, refInputSmplr, param_7) * p0) * p1;
    float4 rs = (((float4(1.0) * p0) * p1) * texColor.w) * _241.alphb;
    float4 fragColor = rs * _241.color;
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_241.blendMode == 0)
    {
        float4 param_8 = texColor;
        float4 param_9 = factor * _241.bright;
        resultfinal = newLayer(param_8, param_9) * texColor.w;
    }
    else
    {
        if (_241.blendMode == 1)
        {
            factor *= _241.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_241.blendMode == 2)
            {
                factor *= _241.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
            else
            {
                if (_241.blendMode == 3)
                {
                    factor *= _241.bright;
                    float3 t = smoothstep(float3(0.5), float3(0.5), texColor.xyz);
                    float3 result_1 = (t * (float3(1.0) - ((float3(1.0) - ((texColor.xyz - float3(0.5)) * 2.0)) * (float3(1.0) - factor.xyz)))) + ((float3(1.0) - t) * ((texColor.xyz * 2.0) * factor.xyz));
                    resultfinal = float4(result_1, texColor.w) * texColor.w;
                }
                else
                {
                    if (_241.blendMode == 4)
                    {
                        float3 colorBlend = float3((texColor.xyz * rgb2yuv).x, (factor.xyz * rgb2yuv).yz) * yuv2rgb;
                        resultfinal = float4(colorBlend, texColor.w) * texColor.w;
                    }
                    else
                    {
                        if (_241.blendMode == 5)
                        {
                            factor *= _241.bright;
                            resultfinal = fast::max(factor, texColor) * texColor.w;
                        }
                        else
                        {
                            if (_241.blendMode == 6)
                            {
                                factor *= _241.bright;
                                resultfinal = (texColor / (float4(1.0) - factor)) * texColor.w;
                            }
                            else
                            {
                                if (_241.blendMode == 7)
                                {
                                    factor *= _241.bright;
                                    resultfinal = (float4(1.0) - ((float4(1.0) - texColor) / factor)) * texColor.w;
                                }
                                else
                                {
                                    if (_241.blendMode == 8)
                                    {
                                        factor *= _241.bright;
                                        resultfinal = (texColor + factor) * texColor.w;
                                    }
                                    else
                                    {
                                        if (_241.blendMode == 9)
                                        {
                                            factor *= _241.bright;
                                            resultfinal = ((texColor + factor) - float4(1.0)) * texColor.w;
                                        }
                                        else
                                        {
                                            if (_241.blendMode == 10)
                                            {
                                                float3 t_1 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                float3 linearLight = (t_1 * (texColor.xyz + ((factor.xyz - float3(0.5)) * 2.0))) + ((float3(1.0) - t_1) * ((texColor.xyz + (factor.xyz * 2.0)) - float3(1.0)));
                                                resultfinal = float4(linearLight, texColor.w) * texColor.w;
                                            }
                                            else
                                            {
                                                if (_241.blendMode == 11)
                                                {
                                                    factor *= _241.bright;
                                                    resultfinal = fast::min(factor, texColor) * texColor.w;
                                                }
                                                else
                                                {
                                                    if (_241.blendMode == 12)
                                                    {
                                                        factor *= _241.bright;
                                                        float3 _747;
                                                        if (length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * factor.xyz) > length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * texColor.xyz))
                                                        {
                                                            _747 = texColor.xyz;
                                                        }
                                                        else
                                                        {
                                                            _747 = factor.xyz;
                                                        }
                                                        float3 darkenColor = _747;
                                                        resultfinal = float4(darkenColor, texColor.w) * texColor.w;
                                                    }
                                                    else
                                                    {
                                                        if (_241.blendMode == 13)
                                                        {
                                                            factor *= _241.bright;
                                                            float3 _787;
                                                            if (length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * factor.xyz) > length(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * texColor.xyz))
                                                            {
                                                                _787 = factor.xyz;
                                                            }
                                                            else
                                                            {
                                                                _787 = texColor.xyz;
                                                            }
                                                            float3 lightenColor = _787;
                                                            resultfinal = float4(lightenColor, texColor.w) * texColor.w;
                                                        }
                                                        else
                                                        {
                                                            if (_241.blendMode == 14)
                                                            {
                                                                factor *= _241.bright;
                                                                float3 t_2 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                float3 softLight = (t_2 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - (factor.xyz - float3(0.5)))))) + ((float3(1.0) - t_2) * (texColor.xyz * (factor.xyz + float3(0.5))));
                                                                resultfinal = float4(softLight, texColor.w) * texColor.w;
                                                            }
                                                            else
                                                            {
                                                                if (_241.blendMode == 15)
                                                                {
                                                                    factor *= _241.bright;
                                                                    float3 t_3 = smoothstep(float3(0.5), float3(0.5), texColor.xyz);
                                                                    float3 softOver = (t_3 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - (factor.xyz - float3(0.5)))))) + ((float3(1.0) - t_3) * (texColor.xyz * (factor.xyz + float3(0.5))));
                                                                    resultfinal = float4(softOver, texColor.w) * texColor.w;
                                                                }
                                                                else
                                                                {
                                                                    if (_241.blendMode == 16)
                                                                    {
                                                                        factor *= _241.bright;
                                                                        float3 t_4 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                        float3 hardLight = (t_4 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * (float3(1.0) - ((factor.xyz - float3(0.5)) * 2.0))))) + ((float3(1.0) - t_4) * (texColor.xyz * (factor.xyz * 2.0)));
                                                                        resultfinal = float4(hardLight, texColor.w) * texColor.w;
                                                                    }
                                                                    else
                                                                    {
                                                                        if (_241.blendMode == 17)
                                                                        {
                                                                            factor *= _241.bright;
                                                                            float3 param_10 = factor.xyz;
                                                                            float3 param_11 = texColor.xyz;
                                                                            float3 param_12 = float3(rgb2hsv(param_10).x, rgb2hsv(param_11).yz);
                                                                            float3 hueB = hsv2rgb(param_12);
                                                                            resultfinal = float4(hueB, texColor.w) * texColor.w;
                                                                        }
                                                                        else
                                                                        {
                                                                            if (_241.blendMode == 18)
                                                                            {
                                                                                factor *= _241.bright;
                                                                                resultfinal = float4(abs((texColor.xyz * texColor.w) - factor.xyz), texColor.w);
                                                                            }
                                                                            else
                                                                            {
                                                                                if (_241.blendMode == 19)
                                                                                {
                                                                                    factor *= _241.bright;
                                                                                    float3 lumin = float3((factor.xyz * rgb2yuv).x, (texColor.xyz * rgb2yuv).yz) * yuv2rgb;
                                                                                    resultfinal = float4(lumin, texColor.w) * texColor.w;
                                                                                }
                                                                                else
                                                                                {
                                                                                    if (_241.blendMode == 20)
                                                                                    {
                                                                                        factor *= _241.bright;
                                                                                        float3 param_13 = texColor.xyz;
                                                                                        float3 bot_hsv = rgb2hsv(param_13);
                                                                                        float3 param_14 = factor.xyz;
                                                                                        float3 param_15 = float3(bot_hsv.x, rgb2hsv(param_14).y, bot_hsv.z);
                                                                                        float3 satBlend = hsv2rgb(param_15);
                                                                                        resultfinal = float4(satBlend, texColor.w) * texColor.w;
                                                                                    }
                                                                                    else
                                                                                    {
                                                                                        if (_241.blendMode == 21)
                                                                                        {
                                                                                            factor *= _241.bright;
                                                                                            float3 t_5 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                                            float3 vividLight = (t_5 * (float3(1.0) - ((float3(1.0) - texColor.xyz) * ((factor.xyz - float3(0.5)) * 2.0)))) + ((float3(1.0) - t_5) * (texColor.xyz * (float3(1.0) - (factor.xyz * 2.0))));
                                                                                            resultfinal = float4(vividLight, texColor.w) * texColor.w;
                                                                                        }
                                                                                        else
                                                                                        {
                                                                                            if (_241.blendMode == 22)
                                                                                            {
                                                                                                factor *= _241.bright;
                                                                                                float3 t_6 = smoothstep(float3(0.5), float3(0.5), factor.xyz);
                                                                                                float3 pinLight = (t_6 * fast::max(texColor.xyz, (factor.xyz - float3(0.5)) * 2.0)) + ((float3(1.0) - t_6) * fast::min(texColor.xyz, factor.xyz * 2.0));
                                                                                                resultfinal = float4(pinLight, texColor.w) * texColor.w;
                                                                                            }
                                                                                            else
                                                                                            {
                                                                                                if (_241.blendMode == 23)
                                                                                                {
                                                                                                    factor *= _241.bright;
                                                                                                    resultfinal = (texColor / factor) * texColor.w;
                                                                                                }
                                                                                                else
                                                                                                {
                                                                                                    if (_241.blendMode == 24)
                                                                                                    {
                                                                                                        factor *= _241.bright;
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
    referenceColor = mix(fragColor, resultfinal, float4(_241.alphab)) * texColor.w;
}

fragment refAM35_e227d3c4d2f74_out refAM35_e227d3c4d2f74(constant ReferenceUniformse227d3c4d2f74& _241 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e227d3c4d2f74_out out = {};
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float4 referenceColor = float4(0.0);
    referenceMain(rgb2yuv, yuv2rgb, refInput, refInputSmplr, gl_FragCoord, _241, referenceColor);
    bool _1264 = any(isnan(referenceColor));
    bool _1271;
    if (!_1264)
    {
        _1271 = any(isinf(referenceColor));
    }
    else
    {
        _1271 = _1264;
    }
    if (_1271)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1284 = referenceColor;
    float3 _1290 = fast::clamp(_1284.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1290.x;
    referenceColor.y = _1290.y;
    referenceColor.z = _1290.z;
    out.finalColor = referenceColor;
    return out;
}

