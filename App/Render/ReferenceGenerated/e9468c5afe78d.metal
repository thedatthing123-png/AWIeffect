// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/InsaneSignal.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9468c5afe78d
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float intensity;
    char _m6_pad[12];
    float speed;
    char _m7_pad[12];
    float randomSeed;
    char _m8_pad[12];
    float noiseIntensity;
    char _m9_pad[12];
    float chromaGain;
};

struct refAM35_e9468c5afe78d_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float h(thread const float& n, constant ReferenceUniformse9468c5afe78d& _36)
{
    return fract(sin((n * 127.09999847412109375) + _36.randomSeed) * 43758.546875);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse9468c5afe78d& _36, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _36.refLayer.xy) / _36.refLayer.zw;
    float row = floor(uv.y * 120.0);
    float frame = floor((_36.refScreen.z * _36.speed) * 12.0);
    float param = row + (frame * 17.0);
    float gate = step(0.7799999713897705078125, h(param, _36));
    float param_1 = (row * 3.0) + frame;
    float off = (((h(param_1, _36) - 0.5) * 0.07999999821186065673828125) * _36.intensity) * gate;
    float wave = (sin((uv.y * 700.0) + ((_36.refScreen.z * 35.0) * _36.speed)) * 0.00179999996908009052276611328125) * _36.intensity;
    float2 p = float2(fast::clamp((uv.x + off) + wave, 0.0, 1.0), uv.y);
    float ca = (0.0030000000260770320892333984375 * _36.intensity) * _36.chromaGain;
    float2 param_2 = p;
    float4 c = texture2DCv(refInput, refInputSmplr, param_2);
    float2 param_3 = fast::clamp(p + float2(ca, 0.0), float2(0.0), float2(1.0));
    c.x = texture2DCv(refInput, refInputSmplr, param_3).x;
    float2 param_4 = fast::clamp(p - float2(ca, 0.0), float2(0.0), float2(1.0));
    c.z = texture2DCv(refInput, refInputSmplr, param_4).z;
    float param_5 = dot(floor(uv * _36.refLayer.zw), float2(1.0, 57.0)) + frame;
    float grain = (h(param_5, _36) - 0.5) * _36.noiseIntensity;
    float4 _203 = c;
    float3 _206 = _203.xyz + float3(grain);
    c.x = _206.x;
    c.y = _206.y;
    c.z = _206.z;
    float scan = 0.930000007152557373046875 + (0.070000000298023223876953125 * sin((uv.y * _36.refLayer.w) * 3.141590118408203125));
    referenceColor = float4(c.xyz * scan, c.w);
}

fragment refAM35_e9468c5afe78d_out refAM35_e9468c5afe78d(constant ReferenceUniformse9468c5afe78d& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9468c5afe78d_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_36, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _245 = any(isnan(referenceColor));
    bool _252;
    if (!_245)
    {
        _252 = any(isinf(referenceColor));
    }
    else
    {
        _252 = _245;
    }
    if (_252)
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

