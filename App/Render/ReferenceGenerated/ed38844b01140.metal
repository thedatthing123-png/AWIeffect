// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxxfibersglow.xml
// Original source comments and attribution:
//////////////////////////
//////////////////////////
// syamjaidtz = acScreenNorm; 
/////////////////////////
// vec3 color = vec3(1.0, 0.3, 0.3);
// vec4 xbuffer = texture2DCv(buff1.texture, acScreenNorm.st);
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsed38844b01140
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 COLORS;
    float4 COLORS2;
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
    char _m17_pad[12];
    uint GRADMAP;
    float4 color1;
    float4 color2;
};

struct refAM35_ed38844b01140_out
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
float wave(thread const float2& p, thread float3& tangent, thread const float& t, thread const float& ang, thread const float& ampl, thread const float& wl, thread const float& spd)
{
    float k = 6.28318023681640625 / wl;
    float f = ((dot(float2(cos(ang), sin(ang)), p) - spd) - t) * k;
    tangent += fast::normalize(float3(1.0, (k * ampl) * cos(f), 0.0));
    return ampl * sin(f);
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsed38844b01140& _123, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_123.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _123.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_123.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _123.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_123.refScreen.x, _123.refScreen.y);
            float2 iMouse = float2(0.5);
            float _196;
            if (_123.autop != 0u)
            {
                _196 = _123.PROGRESS + (_123.refScreen.z * _123.SPEED);
            }
            else
            {
                _196 = _123.PROGRESS;
            }
            float iTime = _196;
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _123.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _123.refScreen.xy).y) * _123.refScreen.xy) - float2(_123.refLayer.x + (_123.refLayer.z * 0.5), (_123.refScreen.y - _123.refLayer.y) - (_123.refLayer.w * 0.5))) / _123.refLayer.zw;
            syamjaidtz.y *= (_123.refLayer.w / _123.refLayer.z);
            syamjaidtz /= float2(_123.scale);
            float param_3 = (0.0 + _123.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _123.position.x, 0.0 + _123.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_123.scale * _123.stretch.x, _123.scale * _123.stretch.y);
            syamjaidtz /= scaleVec;
            float3 color = _123.COLORS.xyz;
            float zoom = 0.60000002384185791015625;
            float t = ((iTime * 0.5) * zoom) / 2.0;
            float2 uv = syamjaidtz;
            uv = (uv * 2.0) - float2(1.0);
            float3 tangent = float3(0.0);
            float2 param_4 = uv;
            float3 param_5 = tangent;
            float param_6 = -t;
            float param_7 = (sin(t) * 0.100000001490116119384765625) + t;
            float param_8 = 0.300000011920928955078125;
            float param_9 = 1.0 * zoom;
            float param_10 = 0.100000001490116119384765625;
            float _355 = wave(param_4, param_5, param_6, param_7, param_8, param_9, param_10);
            tangent = param_5;
            float2 param_11 = uv;
            float3 param_12 = tangent;
            float param_13 = t;
            float param_14 = (sin(t) * 0.20000000298023223876953125) + t;
            float param_15 = 0.4000000059604644775390625;
            float param_16 = 0.4000000059604644775390625 * zoom;
            float param_17 = 10.0;
            float _377 = wave(param_11, param_12, param_13, param_14, param_15, param_16, param_17);
            tangent = param_12;
            float2 param_18 = uv;
            float3 param_19 = tangent;
            float param_20 = t;
            float param_21 = (sin(t) * 0.0500000007450580596923828125) + t;
            float param_22 = 0.800000011920928955078125;
            float param_23 = 0.699999988079071044921875 * zoom;
            float param_24 = 2.0;
            float _400 = wave(param_18, param_19, param_20, param_21, param_22, param_23, param_24);
            tangent = param_19;
            float2 param_25 = uv;
            float3 param_26 = tangent;
            float param_27 = -t;
            float param_28 = (sin(t) * 0.300000011920928955078125) + t;
            float param_29 = 1.0;
            float param_30 = 2.0 * zoom;
            float param_31 = 7.0;
            float _422 = wave(param_25, param_26, param_27, param_28, param_29, param_30, param_31);
            tangent = param_26;
            float h = ((_355 + _377) + _400) + _422;
            float3 n = float3(-tangent.y, tangent.x, 0.0);
            float3 p = float3(uv.x, h, uv.y);
            float3 lpos = float3(cos(t) * 1.0, 2.0, sin(t) * 1.0);
            float lam = smoothstep(0.0, 2.0, dot(n, fast::normalize(lpos - p)));
            float3 water = float3(lam) * color;
            float3 shiny = ((float3(smoothstep(0.89999997615814208984375, 1.0, lam)) * float3(1.0)) * 0.100000001490116119384765625) + ((float3(smoothstep(0.999998986721038818359375, 1.0, lam)) * float3(1.0)) * 0.20000000298023223876953125);
            float4 fragColor = float4(mix(_123.COLORS2.xyz, water + shiny, float3(n.y - 0.300000011920928955078125)), 1.0);
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float4 gradmap = mix(_123.color1, _123.color2, float4(luminance)) * fragColor.w;
            if (_123.GRADMAP != 0u)
            {
                factor = mix(texColorX, gradmap, float4(1.0));
            }
            float4 resultfinal;
            if (_123.blendMode == 0)
            {
                resultfinal = (factor * _123.hardness) * texColor.w;
            }
            else
            {
                if (_123.blendMode == 1)
                {
                    factor *= _123.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_123.blendMode == 2)
                    {
                        factor *= _123.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_123.blendMode == 3)
                        {
                            factor *= _123.hardness;
                            float4 param_32 = texColor;
                            float4 param_33 = factor;
                            resultfinal = (newLayer(param_32, param_33) * _123.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_123.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_ed38844b01140_out refAM35_ed38844b01140(constant ReferenceUniformsed38844b01140& _123 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed38844b01140_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_123, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _647 = any(isnan(referenceColor));
    bool _654;
    if (!_647)
    {
        _654 = any(isinf(referenceColor));
    }
    else
    {
        _654 = _647;
    }
    if (_654)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _667 = referenceColor;
    float3 _673 = fast::clamp(_667.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _673.x;
    referenceColor.y = _673.y;
    referenceColor.z = _673.z;
    out.finalColor = referenceColor;
    return out;
}

