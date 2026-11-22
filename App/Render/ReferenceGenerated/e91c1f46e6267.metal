// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/VCR GLITCH.xml
// Original source comments and attribution:
// Chromatic aberration
// Additional chromatic aberration
// Contrast and saturation
// Vignette
// Noise
// Border check
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

struct ReferenceUniformse91c1f46e6267
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float glitchAmount;
    char _m6_pad[12];
    float glitchSpeed;
    char _m7_pad[12];
    float chromaticAmount;
    char _m8_pad[12];
    float chromaticOffset;
    char _m9_pad[12];
    float distortionAmount;
    char _m10_pad[12];
    float barrelAmount;
    char _m11_pad[12];
    float scanlineAmount;
    char _m12_pad[12];
    float scanlineSpeed;
    char _m13_pad[12];
    float vignetteAmount;
    char _m14_pad[12];
    float vignetteIntensity;
    char _m15_pad[12];
    float noiseAmount;
    char _m16_pad[12];
    float noiseScale;
    char _m17_pad[12];
    float saturation;
    char _m18_pad[12];
    float contrast;
};

struct refAM35_e91c1f46e6267_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 screenDistort(thread float2& uv, constant ReferenceUniformse91c1f46e6267& _54)
{
    uv = (uv - float2(0.5)) * 2.0;
    uv *= (1.10000002384185791015625 * _54.distortionAmount);
    uv.x *= (1.0 + (powr(abs(uv.y) / 5.0, 2.0) * _54.barrelAmount));
    uv.y *= (1.0 + (powr(abs(uv.x) / 4.0, 2.0) * _54.barrelAmount));
    uv = (uv / float2(2.0)) + float2(0.5);
    uv = (uv * 0.920000016689300537109375) + float2(0.039999999105930328369140625);
    return uv;
}

static inline __attribute__((always_inline))
float2 scandistort(thread const float2& uv, constant ReferenceUniformse91c1f46e6267& _54)
{
    float scan1 = fast::clamp(cos((uv.y * 2.0) + ((_54.refScreen.z * _54.glitchSpeed) * _54.scanlineSpeed)), 0.0, 1.0);
    float scan2 = fast::clamp(cos(((uv.y * 2.0) + ((_54.refScreen.z * _54.glitchSpeed) * _54.scanlineSpeed)) + 4.0) * 10.0, 0.0, 1.0);
    float amount = ((scan1 * scan2) * uv.x) * _54.scanlineAmount;
    return uv;
}

static inline __attribute__((always_inline))
float onOff(thread const float& a, thread const float& b, thread const float& c, constant ReferenceUniformse91c1f46e6267& _54)
{
    return step(c, sin((_54.refScreen.z * _54.glitchSpeed) + (a * cos((_54.refScreen.z * _54.glitchSpeed) * b))));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 getVideo(thread const float2& uv, constant ReferenceUniformse91c1f46e6267& _54, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 look = uv;
    float window = 1.0 / (1.0 + ((20.0 * (look.y - mod((_54.refScreen.z * _54.glitchSpeed) / 4.0, 1.0))) * (look.y - mod((_54.refScreen.z * _54.glitchSpeed) / 4.0, 1.0))));
    float param = 4.0;
    float param_1 = 4.0;
    float param_2 = 0.300000011920928955078125;
    look.x += (((((sin((look.y * 10.0) + (_54.refScreen.z * _54.glitchSpeed)) / 50.0) * onOff(param, param_1, param_2, _54)) * (1.0 + cos((_54.refScreen.z * _54.glitchSpeed) * 80.0))) * window) * 0.20000000298023223876953125);
    float param_3 = 2.0;
    float param_4 = 3.0;
    float param_5 = 0.89999997615814208984375;
    float vShift = (0.4000000059604644775390625 * onOff(param_3, param_4, param_5, _54)) * ((sin(_54.refScreen.z * _54.glitchSpeed) * sin((_54.refScreen.z * _54.glitchSpeed) * 20.0)) + (0.5 + ((0.100000001490116119384765625 * sin((_54.refScreen.z * _54.glitchSpeed) * 200.0)) * cos(_54.refScreen.z * _54.glitchSpeed))));
    look.y = mod(look.y + (vShift * 0.100000001490116119384765625), 1.0);
    float2 param_6 = look;
    float4 video = texture2DCv(refInput, refInputSmplr, param_6);
    return video;
}

static inline __attribute__((always_inline))
float random(thread const float2& uv, constant ReferenceUniformse91c1f46e6267& _54)
{
    return fract((sin(dot(uv, float2(15.51509952545166015625, 42.256099700927734375))) * 12341.1416015625) * sin((_54.refScreen.z * _54.glitchSpeed) * 0.02999999932944774627685546875));
}

static inline __attribute__((always_inline))
float _noise(thread const float2& uv, constant ReferenceUniformse91c1f46e6267& _54)
{
    float2 i = floor(uv);
    float2 f = fract(uv);
    float2 param = i;
    float a = random(param, _54);
    float2 param_1 = i + float2(1.0, 0.0);
    float b = random(param_1, _54);
    float2 param_2 = i + float2(0.0, 1.0);
    float c = random(param_2, _54);
    float2 param_3 = i + float2(1.0);
    float d = random(param_3, _54);
    float2 u = smoothstep(float2(0.0), float2(1.0), f);
    return (mix(a, b, u.x) + (((c - a) * u.y) * (1.0 - u.x))) + (((d - b) * u.x) * u.y);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse91c1f46e6267& _54, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _54.refScreen.xy;
    float2 param = uv;
    float2 _406 = screenDistort(param, _54);
    float2 curUV = _406;
    float2 param_1 = curUV;
    uv = scandistort(param_1, _54);
    float2 param_2 = uv;
    float4 video = getVideo(param_2, _54, refInput, refInputSmplr);
    float vigAmt = _54.vignetteIntensity + (0.300000011920928955078125 * sin((_54.refScreen.z * _54.glitchSpeed) + (5.0 * cos((_54.refScreen.z * _54.glitchSpeed) * 5.0))));
    float x = 0.0;
    float offset = _54.chromaticOffset * _54.chromaticAmount;
    float2 param_3 = float2((x + uv.x) + offset, uv.y + offset);
    video.x = getVideo(param_3, _54, refInput, refInputSmplr).x + 0.0500000007450580596923828125;
    float2 param_4 = float2((x + uv.x) + 0.0, uv.y - (offset * 2.0));
    video.y = getVideo(param_4, _54, refInput, refInputSmplr).y + 0.0500000007450580596923828125;
    float2 param_5 = float2((x + uv.x) - (offset * 2.0), uv.y + 0.0);
    video.z = getVideo(param_5, _54, refInput, refInputSmplr).z + 0.0500000007450580596923828125;
    float2 param_6 = (float2(x + 0.02500000037252902984619140625, -0.02700000070035457611083984375) * 0.75) + float2(uv.x + offset, uv.y + offset);
    video.x += (0.07999999821186065673828125 * getVideo(param_6, _54, refInput, refInputSmplr).x);
    float2 param_7 = (float2(x + (-0.02199999988079071044921875), -0.0199999995529651641845703125) * 0.75) + float2(uv.x + 0.0, uv.y - (offset * 2.0));
    video.y += (0.0500000007450580596923828125 * getVideo(param_7, _54, refInput, refInputSmplr).y);
    float2 param_8 = (float2(x + (-0.0199999995529651641845703125), -0.017999999225139617919921875) * 0.75) + float2(uv.x - (offset * 2.0), uv.y + 0.0);
    video.z += (0.07999999821186065673828125 * getVideo(param_8, _54, refInput, refInputSmplr).z);
    video = fast::clamp(((video * 0.60000002384185791015625) * _54.contrast) + ((((video * 0.4000000059604644775390625) * video) * 1.0) * _54.saturation), float4(0.0), float4(1.0));
    float vignette = (1.0 - ((vigAmt * (uv.y - 0.5)) * (uv.y - 0.5))) * (1.0 - ((vigAmt * (uv.x - 0.5)) * (uv.x - 0.5)));
    video *= (vignette * _54.vignetteAmount);
    float2 param_9 = uv * _54.noiseScale;
    video = mix(video, float4(_noise(param_9, _54)), float4(_54.noiseAmount));
    bool _632 = curUV.x < 0.0;
    bool _639;
    if (!_632)
    {
        _639 = curUV.x > 1.0;
    }
    else
    {
        _639 = _632;
    }
    bool _646;
    if (!_639)
    {
        _646 = curUV.y < 0.0;
    }
    else
    {
        _646 = _639;
    }
    bool _653;
    if (!_646)
    {
        _653 = curUV.y > 1.0;
    }
    else
    {
        _653 = _646;
    }
    if (_653)
    {
        referenceColor = float4(0.0);
    }
    else
    {
        referenceColor = video;
    }
}

fragment refAM35_e91c1f46e6267_out refAM35_e91c1f46e6267(constant ReferenceUniformse91c1f46e6267& _54 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e91c1f46e6267_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_54, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _665 = any(isnan(referenceColor));
    bool _672;
    if (!_665)
    {
        _672 = any(isinf(referenceColor));
    }
    else
    {
        _672 = _665;
    }
    if (_672)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _687 = referenceColor;
    float3 _693 = fast::clamp(_687.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _693.x;
    referenceColor.y = _693.y;
    referenceColor.z = _693.z;
    out.finalColor = referenceColor;
    return out;
}

