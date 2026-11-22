// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxisoline.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
// vec4 factor = mix(texColorX,fragColor,alpha);
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformseac60c37101a4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float progressa;
    char _m7_pad[12];
    float progressb;
    char _m8_pad[12];
    float progressc;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    float bright;
    char _m11_pad[12];
    float alpha;
    char _m12_pad[12];
    float angle;
    float4 color1;
    float4 color2;
    int blendMode;
};

struct refAM35_eac60c37101a4_out
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
float wave(thread const float& x, thread const float& y)
{
    return (((((((sin((10.0 * x) + (10.0 * y)) / 5.0) + (sin((20.0 * x) + (15.0 * y)) / 3.0)) + (sin((4.0 * x) + (10.0 * y)) / (-4.0))) + (sin(y) / 2.0)) + sin(((x * x) * y) * 20.0)) + (sin((x * 20.0) + 4.0) / 5.0)) + (sin(y * 30.0) / 5.0)) + (sin(x) / 4.0);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseac60c37101a4& _126, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _126.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _126.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _126.refScreen.xy).y) * _126.refScreen.xy) - float2(_126.refLayer.x + (_126.refLayer.z * 0.5), (_126.refScreen.y - _126.refLayer.y) - (_126.refLayer.w * 0.5))) / _126.refLayer.zw;
    syamjaidtz.y *= (_126.refLayer.w / _126.refLayer.z);
    syamjaidtz /= float2(_126.scale);
    float param_1 = ((-180.0) + _126.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((float2(0.0 + _126.position.x, 0.0 + _126.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 uv = syamjaidtz;
    float param_2 = uv.x;
    float param_3 = uv.y;
    float z = wave(param_2, param_3) + 2.0;
    z *= (_126.progressc * sin(1.57000005245208740234375 + (_126.progressa / 5.0)));
    float d = fract(z);
    if (mod(z, 2.0) > 1.0)
    {
        d = 1.0 - d;
    }
    d /= (_126.progressb * z);
    float4 fragColor = float4(1.0) + ((float4(1.0) - float4(d)) + float4(1.0));
    float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 gradmap = mix(_126.color1, _126.color2, float4(luminance)) * fragColor.w;
    float4 factor = mix(texColorX, gradmap, float4(1.0));
    float4 resultfinal;
    if (_126.blendMode == 0)
    {
        resultfinal = (factor * _126.bright) * texColor.w;
    }
    else
    {
        if (_126.blendMode == 1)
        {
            factor *= _126.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_126.blendMode == 2)
            {
                factor *= _126.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_126.alpha));
}

fragment refAM35_eac60c37101a4_out refAM35_eac60c37101a4(constant ReferenceUniformseac60c37101a4& _126 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eac60c37101a4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _126, referenceColor);
    bool _405 = any(isnan(referenceColor));
    bool _412;
    if (!_405)
    {
        _412 = any(isinf(referenceColor));
    }
    else
    {
        _412 = _405;
    }
    if (_412)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _425 = referenceColor;
    float3 _431 = fast::clamp(_425.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _431.x;
    referenceColor.y = _431.y;
    referenceColor.z = _431.z;
    out.finalColor = referenceColor;
    return out;
}

