// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsrainyfalls.xml
// Original source comments and attribution:
//////////////////////////
//////////////////////////
/////////////////////////
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse8d03cb65185e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint autop;
    char _m6_pad[12];
    float PROGRESS;
    char _m7_pad[12];
    float SPEED;
    char _m8_pad[12];
    float xscale;
    char _m9_pad[12];
    float yscale;
    char _m10_pad[12];
    float xdistort;
    char _m11_pad[12];
    float ydistort;
    char _m12_pad[12];
    float alpha;
};

struct refAM35_e8d03cb65185e_out
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
void referenceMain(constant ReferenceUniformse8d03cb65185e& _36, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, texture2d<float> refImage1, sampler refImage1Smplr)
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
            float speed = 0.07999999821186065673828125;
            float2 param_1 = gl_FragCoord.xy / _36.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_36.refScreen.x, _36.refScreen.y);
            float2 iMouse = float2(0.5);
            float _117;
            if (_36.autop != 0u)
            {
                _117 = _36.PROGRESS + (_36.refScreen.z * _36.SPEED);
            }
            else
            {
                _117 = _36.PROGRESS;
            }
            float iTime = _117;
            float2 syamjaidtz = gl_FragCoord.xy / _36.refScreen.xy;
            float2 uv = syamjaidtz;
            float2 uv_warp = float2(uv.x / fast::max(abs(_36.xscale), 9.9999997473787516355514526367188e-05), (uv.y / fast::max(abs(_36.yscale), 9.9999997473787516355514526367188e-05)) + (iTime * speed));
            float2 param_3 = uv_warp;
            float2 param_4 = float2(uv_warp.x, uv_warp.y + speed);
            float2 uv_samp = float2(texture2DCv(refImage1, refImage1Smplr, param_3).x, texture2DCv(refImage1, refImage1Smplr, param_4).x);
            float2 param_5 = float2(uv.x + ((uv_samp.x - uv_samp.y) * _36.xdistort), uv.y + (uv_samp.y * _36.ydistort));
            float4 fragColor = texture2DCv(refInput, refInputSmplr, param_5);
            referenceColor = mix(texColor, fragColor, float4(_36.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e8d03cb65185e_out refAM35_e8d03cb65185e(constant ReferenceUniformse8d03cb65185e& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8d03cb65185e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_36, referenceColor, refInput, refInputSmplr, gl_FragCoord, refImage1, refImage1Smplr);
    bool _223 = any(isnan(referenceColor));
    bool _230;
    if (!_223)
    {
        _230 = any(isinf(referenceColor));
    }
    else
    {
        _230 = _223;
    }
    if (_230)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _244 = referenceColor;
    float3 _250 = fast::clamp(_244.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _250.x;
    referenceColor.y = _250.y;
    referenceColor.z = _250.z;
    out.finalColor = referenceColor;
    return out;
}

