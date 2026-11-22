// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxswaterwave.xml
// Original source comments and attribution:
//////////////////////////
//////////////////////////
/////////////////////////
//3D effect
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse85891f96edbc
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 water_color;
    uint autop;
    char _m7_pad[12];
    float PROGRESS;
    char _m8_pad[12];
    float SPEED;
    char _m9_pad[12];
    float HEI;
    char _m10_pad[12];
    float STR;
    char _m11_pad[12];
    float FREQ;
    char _m12_pad[12];
    float TRP;
    char _m13_pad[12];
    float ANG;
    char _m14_pad[12];
    float alpha;
};

struct refAM35_e85891f96edbc_out
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
void referenceMain(constant ReferenceUniformse85891f96edbc& _36, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_36.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _36.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_36.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _36.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_36.refScreen.x, _36.refScreen.y);
            float2 iMouse = float2(0.5);
            float _115;
            if (_36.autop != 0u)
            {
                _115 = _36.PROGRESS + (_36.refScreen.z * _36.SPEED);
            }
            else
            {
                _115 = _36.PROGRESS;
            }
            float iTime = _115;
            float2 syamjaidtz = gl_FragCoord.xy / _36.refScreen.xy;
            float2 uv = syamjaidtz;
            float height = _36.HEI;
            float wave_strength = _36.STR;
            float wave_frequency = _36.FREQ;
            float transparency = _36.TRP;
            float angle = _36.ANG;
            angle *= ((uv.y / height) + (angle / 1.5));
            wave_strength /= 1000.0;
            float wave = sin(((10.0 * uv.y) + (10.0 * uv.x)) + (wave_frequency * iTime)) * wave_strength;
            wave += ((sin(((20.0 * (-uv.y)) + (20.0 * uv.x)) + ((wave_frequency * 1.0) * iTime)) * wave_strength) * 0.5);
            wave += ((sin(((15.0 * (-uv.y)) + (15.0 * (-uv.x))) + ((wave_frequency * 0.60000002384185791015625) * iTime)) * wave_strength) * 1.2999999523162841796875);
            wave += ((sin(((3.0 * (-uv.y)) + (3.0 * (-uv.x))) + ((wave_frequency * 0.300000011920928955078125) * iTime)) * wave_strength) * 10.0);
            float2 param_3 = float2(uv.x, uv.y);
            float4 fragColor = texture2DCv(refInput, refInputSmplr, param_3);
            if ((uv.y - wave) <= height)
            {
                float2 param_4 = float2(uv.x, (((1.0 + angle) * (height + wave)) - (angle * uv.y)) + wave);
                float2 param_5 = float2(uv.x + wave, uv.y - wave);
                fragColor = mix(mix(texture2DCv(refInput, refInputSmplr, param_4), _36.water_color, float4(0.60000002384185791015625 - (0.300000011920928955078125 - ((0.300000011920928955078125 * uv.y) / height)))), texture2DCv(refInput, refInputSmplr, param_5), float4(transparency - ((transparency * uv.y) / height)));
            }
            referenceColor = mix(texColor, fragColor, float4(_36.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e85891f96edbc_out refAM35_e85891f96edbc(constant ReferenceUniformse85891f96edbc& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e85891f96edbc_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_36, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _337 = any(isnan(referenceColor));
    bool _344;
    if (!_337)
    {
        _344 = any(isinf(referenceColor));
    }
    else
    {
        _344 = _337;
    }
    if (_344)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _358 = referenceColor;
    float3 _364 = fast::clamp(_358.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _364.x;
    referenceColor.y = _364.y;
    referenceColor.z = _364.z;
    out.finalColor = referenceColor;
    return out;
}

