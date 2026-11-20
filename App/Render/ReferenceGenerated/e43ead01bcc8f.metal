// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxbadsignal.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
// normal
// multiply
// screen
// gl_FragColor = resultfinal;
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

struct ReferenceUniformse43ead01bcc8f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int typeX;
    char _m6_pad[12];
    uint greyscale;
    char _m7_pad[12];
    uint autop;
    char _m8_pad[12];
    uint autod;
    char _m9_pad[12];
    float progressx;
    char _m10_pad[12];
    float progressd;
    char _m11_pad[12];
    float progressb;
    char _m12_pad[12];
    float progressc;
    char _m13_pad[12];
    float alpha;
    char _m14_pad[12];
    int blendMode;
};

struct refAM35_e43ead01bcc8f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 screenDistort(thread float2& uv)
{
    uv -= float2(0.5);
    uv = (uv * 1.2000000476837158203125) * (0.833333313465118408203125 + ((((2.0 * uv.x) * uv.x) * uv.y) * uv.y));
    uv += float2(0.5);
    return uv;
}

static inline __attribute__((always_inline))
float onOff(thread const float& a, thread const float& b, thread const float& c, constant ReferenceUniformse43ead01bcc8f& _71)
{
    float _120;
    if (_71.autop != 0u)
    {
        _120 = _71.progressx + (_71.refScreen.z * 0.5);
    }
    else
    {
        _120 = _71.progressx;
    }
    float PROGO = _120;
    return step(c, sin(PROGO + (a * cos(PROGO * b))));
}

static inline __attribute__((always_inline))
float greyScale(thread const float3& col)
{
    return dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float3 getVideo(thread const float2& uv, constant ReferenceUniformse43ead01bcc8f& _71, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 look = uv;
    float _236;
    if (_71.autop != 0u)
    {
        _236 = _71.progressx + (_71.refScreen.z * 0.5);
    }
    else
    {
        _236 = _71.progressx;
    }
    float PROG = _236;
    float window = 1.0 / (1.0 + ((20.0 * (look.y - mod(PROG / 4.0, 1.0))) * (look.y - mod(PROG / 4.0, 1.0))));
    float param = 4.0;
    float param_1 = 4.0;
    float param_2 = 0.300000011920928955078125;
    look.x += ((((sin((look.y * 10.0) + PROG) / 50.0) * onOff(param, param_1, param_2, _71)) * (1.0 + cos(PROG * 80.0))) * window);
    float param_3 = 2.0;
    float param_4 = 3.0;
    float param_5 = 0.89999997615814208984375;
    float vShift = (0.4000000059604644775390625 * onOff(param_3, param_4, param_5, _71)) * ((sin(PROG) * sin(PROG * 20.0)) + (0.5 + ((0.100000001490116119384765625 * sin(PROG * 200.0)) * cos(PROG))));
    look.y = mod(look.y + vShift, 1.0);
    float2 param_6 = look;
    float3 video = float3(texture2DCv(refInput, refInputSmplr, param_6).xyz);
    if (_71.greyscale != 0u)
    {
        float3 param_7 = video;
        video = float3(greyScale(param_7));
    }
    return video;
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p, constant ReferenceUniformse43ead01bcc8f& _71, texture2d<float> refImage2, sampler refImage2Smplr, texture2d<float> refImage1, sampler refImage1Smplr)
{
    float s;
    if (_71.typeX == 0)
    {
        float2 param = float2(0.800000011920928955078125, 0.86448371410369873046875) + (p * 1.0);
        s = texture2DCv(refImage2, refImage2Smplr, param).x;
    }
    else
    {
        if (_71.typeX == 1)
        {
            float2 param_1 = float2(0.800000011920928955078125, 0.86448371410369873046875) + (p * 1.0);
            s = texture2DCv(refImage1, refImage1Smplr, param_1).x;
        }
    }
    s *= s;
    return s;
}

static inline __attribute__((always_inline))
float ramp(thread const float& y, thread const float& start, thread const float& end)
{
    float inside = step(start, y) - step(end, y);
    float fact = ((y - start) / (end - start)) * inside;
    return (1.0 - fact) * inside;
}

static inline __attribute__((always_inline))
float stripes(thread const float2& uv, constant ReferenceUniformse43ead01bcc8f& _71, texture2d<float> refImage2, sampler refImage2Smplr, texture2d<float> refImage1, sampler refImage1Smplr)
{
    float _179;
    if (_71.autod != 0u)
    {
        _179 = _71.progressd + (_71.refScreen.z * 1.25);
    }
    else
    {
        _179 = _71.progressd;
    }
    float EVO = _179;
    float2 param = (uv * float2(0.5, 1.0)) + float2(1.0, 3.0);
    float noi = _noise(param, _71, refImage2, refImage2Smplr, refImage1, refImage1Smplr);
    float param_1 = mod(((uv.y * 4.0) + (EVO / 2.0)) + sin(EVO + sin(EVO * 0.62999999523162841796875)), 1.0);
    float param_2 = 0.5;
    float param_3 = 0.60000002384185791015625;
    return ramp(param_1, param_2, param_3) * noi;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse43ead01bcc8f& _71, texture2d<float> refImage2, sampler refImage2Smplr, texture2d<float> refImage1, sampler refImage1Smplr, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _71.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 uv = gl_FragCoord.xy / _71.refScreen.xy;
    float2 param_1 = uv;
    float2 _396 = screenDistort(param_1);
    uv = _396;
    float2 param_2 = uv;
    float3 video = getVideo(param_2, _71, refInput, refInputSmplr);
    float _405;
    if (_71.autod != 0u)
    {
        _405 = _71.progressb + (_71.refScreen.z * 0.5);
    }
    else
    {
        _405 = _71.progressb;
    }
    float BLINK = _405;
    float _423;
    if (_71.autod != 0u)
    {
        _423 = _71.progressc + (_71.refScreen.z * 0.5);
    }
    else
    {
        _423 = _71.progressc;
    }
    float SLINES = _423;
    float vigAmt = 3.0 + (0.300000011920928955078125 * sin(1.0 + (5.0 * cos(BLINK * 5.0))));
    float vignette = (1.0 - ((vigAmt * (uv.y - 0.5)) * (uv.y - 0.5))) * (1.0 - ((vigAmt * (uv.x - 0.5)) * (uv.x - 0.5)));
    float2 param_3 = uv;
    video += float3(stripes(param_3, _71, refImage2, refImage2Smplr, refImage1, refImage1Smplr));
    float2 param_4 = uv * 2.0;
    video += float3(_noise(param_4, _71, refImage2, refImage2Smplr, refImage1, refImage1Smplr) / 2.0);
    video *= vignette;
    video *= ((12.0 + mod((uv.y * 30.0) + SLINES, 1.0)) / 13.0);
    float4 result = float4(video, _71.alpha);
    float4 factor = result;
    float4 resultfinal;
    if (_71.blendMode == 0)
    {
        factor *= texColor.w;
        resultfinal = factor + (texColor * (1.0 - factor.w));
    }
    else
    {
        if (_71.blendMode == 1)
        {
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_71.blendMode == 2)
            {
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(1.0)) * texColor.w;
}

fragment refAM35_e43ead01bcc8f_out refAM35_e43ead01bcc8f(constant ReferenceUniformse43ead01bcc8f& _71 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], texture2d<float> refImage2 [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], sampler refImage2Smplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_e43ead01bcc8f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_71, refImage2, refImage2Smplr, refImage1, refImage1Smplr, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _603 = any(isnan(referenceColor));
    bool _610;
    if (!_603)
    {
        _610 = any(isinf(referenceColor));
    }
    else
    {
        _610 = _603;
    }
    if (_610)
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

