// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxoldfastadjusting.xml
// Original source comments and attribution:
// vec4 source = texture2DCv(inputImg.texture,acScreenNorm);
// vec4 texColor = texture2DCv(inputImg.texture,acScreenNorm);
// yuv.x = (yuv.x-0.5*a) * (contrast+1.0) + 0.5*a + brightness*a;
//
// yuv = yuv * huemat;
//////////////////////////
// gl_FragColor = mix(texColor, huecolor, alphax) * texColor.a; }
// gl_FragColor = huecolor;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse83f3250e5723
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint mode;
    char _m6_pad[12];
    float exposure;
    char _m7_pad[12];
    float gamma;
    char _m8_pad[12];
    float brightness;
    char _m9_pad[12];
    float contrast;
    char _m10_pad[12];
    float highlights;
    char _m11_pad[12];
    float shadows;
    char _m12_pad[12];
    float offset;
    char _m13_pad[12];
    float saturation;
    char _m14_pad[12];
    float vib;
    char _m15_pad[12];
    float hue;
    char _m16_pad[12];
    float temperature;
    char _m17_pad[12];
    float redGamma;
    char _m18_pad[12];
    float greenGamma;
    char _m19_pad[12];
    float blueGamma;
    char _m20_pad[12];
    int red;
    char _m21_pad[12];
    int green;
    char _m22_pad[12];
    int blue;
    char _m23_pad[12];
    int alphay;
    char _m24_pad[12];
    float alphax;
};

struct refAM35_e83f3250e5723_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 colorTemperatureToRGB(float temperature)
{
    float3x3 _36;
    if (temperature <= 6500.0)
    {
        _36 = float3x3(float3(0.0, -2902.195556640625, -8257.7998046875), float3(0.0, 1669.580322265625, 2575.28271484375), float3(1.0, 1.330267429351806640625, 1.899375438690185546875));
    }
    else
    {
        _36 = float3x3(float3(1745.04248046875, 1216.6168212890625, -8257.7998046875), float3(-2666.347412109375, -2173.101318359375, 2575.28271484375), float3(0.559953868389129638671875, 0.70381200313568115234375, 1.899375438690185546875));
    }
    float3x3 m = _36;
    return mix(fast::clamp((m[0] / (float3(fast::clamp(temperature, 1000.0, 40000.0)) + m[1])) + m[2], float3(0.0), float3(1.0)), float3(1.0), float3(smoothstep(1000.0, 0.0, temperature)));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse83f3250e5723& _93, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, texture2d<float> refReference, sampler refReferenceSmplr)
{
    if (as_type<int>(_93.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _93.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_93.refComposition.z) == 1)
        {
            float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
            float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
            float rad = _93.hue * 0.01745329983532428741455078125;
            float3x3 huemat = float3x3(float3(1.0, 0.0, 0.0), float3(0.0, cos(rad), sin(rad)), float3(0.0, -sin(rad), cos(rad)));
            float2 param_1 = gl_FragCoord.xy / _93.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float2 param_2 = gl_FragCoord.xy / _93.refScreen.xy;
            float4 lift = mix(texture2DCv(refReference, refReferenceSmplr, param_2) * texColor.w, texColor, float4(0.0));
            float4 realTexture = select(texColor, lift, bool4(_93.mode != 0u));
            float luminanceX = dot(realTexture.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float2 s = step(float2(0.0), (gl_FragCoord.xy - _93.refLayer.xy) / _93.refLayer.zw) - step(float2(1.0), (gl_FragCoord.xy - _93.refLayer.xy) / _93.refLayer.zw);
            float maskFactor = s.x * s.y;
            float4 outColor = float4(0.0);
            if (realTexture.w > 0.0)
            {
                float _255 = realTexture.w;
                float4 _256 = realTexture;
                float3 _259 = _256.xyz / float3(_255);
                realTexture.x = _259.x;
                realTexture.y = _259.y;
                realTexture.z = _259.z;
            }
            if (_93.red == 0)
            {
                outColor.x = realTexture.x;
            }
            else
            {
                if (_93.red == 1)
                {
                    outColor.x = realTexture.y;
                }
                else
                {
                    if (_93.red == 2)
                    {
                        outColor.x = realTexture.z;
                    }
                    else
                    {
                        if (_93.red == 3)
                        {
                            outColor.x = realTexture.w;
                        }
                        else
                        {
                            if (_93.red == 4)
                            {
                                outColor.x = luminanceX;
                            }
                            else
                            {
                                if (_93.red == 5)
                                {
                                    outColor.x = 0.0;
                                }
                                else
                                {
                                    outColor.x = 1.0;
                                }
                            }
                        }
                    }
                }
            }
            if (_93.green == 0)
            {
                outColor.y = realTexture.x;
            }
            else
            {
                if (_93.green == 1)
                {
                    outColor.y = realTexture.y;
                }
                else
                {
                    if (_93.green == 2)
                    {
                        outColor.y = realTexture.z;
                    }
                    else
                    {
                        if (_93.green == 3)
                        {
                            outColor.y = realTexture.w;
                        }
                        else
                        {
                            if (_93.green == 4)
                            {
                                outColor.y = luminanceX;
                            }
                            else
                            {
                                if (_93.green == 5)
                                {
                                    outColor.y = 0.0;
                                }
                                else
                                {
                                    outColor.y = 1.0;
                                }
                            }
                        }
                    }
                }
            }
            if (_93.blue == 0)
            {
                outColor.z = realTexture.x;
            }
            else
            {
                if (_93.blue == 1)
                {
                    outColor.z = realTexture.y;
                }
                else
                {
                    if (_93.blue == 2)
                    {
                        outColor.z = realTexture.z;
                    }
                    else
                    {
                        if (_93.blue == 3)
                        {
                            outColor.z = realTexture.w;
                        }
                        else
                        {
                            if (_93.blue == 4)
                            {
                                outColor.z = luminanceX;
                            }
                            else
                            {
                                if (_93.blue == 5)
                                {
                                    outColor.z = 0.0;
                                }
                                else
                                {
                                    outColor.z = 1.0;
                                }
                            }
                        }
                    }
                }
            }
            if (_93.alphay == 0)
            {
                outColor.w = realTexture.x;
            }
            else
            {
                if (_93.alphay == 1)
                {
                    outColor.w = realTexture.y;
                }
                else
                {
                    if (_93.alphay == 2)
                    {
                        outColor.w = realTexture.z;
                    }
                    else
                    {
                        if (_93.alphay == 3)
                        {
                            outColor.w = realTexture.w;
                        }
                        else
                        {
                            if (_93.alphay == 4)
                            {
                                outColor.w = luminanceX;
                            }
                            else
                            {
                                if (_93.alphay == 5)
                                {
                                    outColor.w = 0.0;
                                }
                                else
                                {
                                    outColor.w = 1.0;
                                }
                            }
                        }
                    }
                }
            }
            float _482 = outColor.w;
            float4 _483 = outColor;
            float3 _485 = _483.xyz * _482;
            outColor.x = _485.x;
            outColor.y = _485.y;
            outColor.z = _485.z;
            float4 channel = outColor * maskFactor;
            float luminance = dot(channel.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float clampedShadows = fast::clamp(_93.shadows, 1.0, 2.0);
            float shadow = fast::clamp((powr(luminance, 1.0 / clampedShadows) + ((-0.7599999904632568359375) * powr(luminance, 2.0 / clampedShadows))) - luminance, 0.0, 1.0);
            float highlight = fast::clamp((1.0 - (powr(1.0 - luminance, 1.0 / (2.0 - _93.highlights)) + ((-0.800000011920928955078125) * powr(1.0 - luminance, 2.0 / (2.0 - _93.highlights))))) - luminance, -1.0, 0.0);
            float3 result = float3(0.0) + (((channel.xyz - float3(0.0)) / float3(luminance - 0.0)) * (((luminance + shadow) + highlight) - 0.0));
            float contrastedLuminance = ((luminance - 0.5) * 1.5) + 0.5;
            float whiteInterp = (contrastedLuminance * contrastedLuminance) * contrastedLuminance;
            float whiteTarget = fast::clamp(_93.highlights, 1.0, 2.0) - 1.0;
            result = mix(result, float3(1.0), float3(whiteInterp * whiteTarget));
            float invContrastedLuminance = 1.0 - contrastedLuminance;
            float blackInterp = (invContrastedLuminance * invContrastedLuminance) * invContrastedLuminance;
            float blackTarget = 1.0 - fast::clamp(_93.shadows, 0.0, 1.0);
            result = mix(result, float3(0.0), float3(blackInterp * blackTarget));
            float4 highshadow = float4(result, channel.w);
            float4 afterHs = mix(channel, highshadow, float4(1.0)) * channel.w;
            float4 _621 = afterHs;
            float3 _636 = powr(_621.xyz, float3(1.0 / _93.redGamma, 1.0 / _93.greenGamma, 1.0 / _93.blueGamma));
            afterHs.x = _636.x;
            afterHs.y = _636.y;
            afterHs.z = _636.z;
            float3 rgb = afterHs.xyz;
            float a = afterHs.w;
            float3 yuv = rgb * rgb2yuv;
            float origSat = fast::min(1.0, length(yuv.yz) * 2.5);
            float2 satUV = yuv.yz * _93.vib;
            float3 _668 = yuv;
            float2 _672 = mix(satUV, _668.yz, float2(origSat));
            yuv.y = _672.x;
            yuv.z = _672.y;
            float3 _677 = yuv;
            float2 _683 = _677.yz * (_93.saturation + 1.0);
            yuv.y = _683.x;
            yuv.z = _683.y;
            rgb = yuv * yuv2rgb;
            rgb += (float3(_93.offset) * a);
            rgb = powr(rgb, float3(1.0 / _93.gamma));
            rgb *= powr(2.0, _93.exposure);
            rgb = mix(rgb, rgb * colorTemperatureToRGB(_93.temperature * 1000.0), float3(0.800000011920928955078125));
            float4 exsat = float4(rgb, a);
            float3 rgbx = exsat.xyz;
            float ax = exsat.w;
            float3 yuvbc = rgbx * rgb2yuv;
            yuvbc.x = (((yuvbc.x - (0.5 * ax)) * (_93.contrast + 1.0)) + (0.5 * ax)) + (_93.brightness * ax);
            rgbx = yuvbc * yuv2rgb;
            float4 bright = float4(rgbx, a);
            float3 rgbxx = bright.xyz;
            float axx = bright.w;
            float3 yuvhue = rgbxx * rgb2yuv;
            yuvhue *= huemat;
            rgbxx = yuvhue * yuv2rgb;
            float4 huecolor = float4(rgbxx, a);
            referenceColor = huecolor;
        }
    }
}

fragment refAM35_e83f3250e5723_out refAM35_e83f3250e5723(constant ReferenceUniformse83f3250e5723& _93 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_e83f3250e5723_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_93, referenceColor, refInput, refInputSmplr, gl_FragCoord, refReference, refReferenceSmplr);
    bool _797 = any(isnan(referenceColor));
    bool _804;
    if (!_797)
    {
        _804 = any(isinf(referenceColor));
    }
    else
    {
        _804 = _797;
    }
    if (_804)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _817 = referenceColor;
    float3 _823 = fast::clamp(_817.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _823.x;
    referenceColor.y = _823.y;
    referenceColor.z = _823.z;
    out.finalColor = referenceColor;
    return out;
}

