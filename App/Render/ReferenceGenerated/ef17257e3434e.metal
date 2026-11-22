// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/crossfade_noise_wipe.xml
// Original source comments and attribution:
// Crossfade Noise Wipe (manual progress, no auto time)
// Procedural version: single input and procedural noise
// Progress with crossfade window
// Optionally invert
// Mask along X
// Procedural value noise (cheap hash-based)
// Input and background color
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef17257e3434e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progress;
    char _m6_pad[12];
    float crossfadeLength;
    char _m7_pad[12];
    float textureZoom;
    char _m8_pad[12];
    uint invert;
    float4 bgColor;
    float bgStrength;
};

struct refAM35_ef17257e3434e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsef17257e3434e& _30, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 res = _30.refScreen.xy;
    float2 fragCoord = (gl_FragCoord.xy / _30.refScreen.xy) * res;
    float2 uv = fragCoord / res;
    float pr = (_30.progress * (1.0 + _30.crossfadeLength)) - _30.crossfadeLength;
    if (_30.invert != 0u)
    {
        pr = 1.0 - ((_30.progress * (1.0 + _30.crossfadeLength)) - _30.crossfadeLength);
    }
    float mask = smoothstep(uv.x - _30.crossfadeLength, uv.x, pr);
    float n = fract(sin(dot(floor((uv * _30.textureZoom) * 1024.0), float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
    float m = fast::clamp((n * mask) + mask, 0.0, 1.0);
    float2 param = uv;
    float3 a = texture2DCv(refInput, refInputSmplr, param).xyz;
    float3 b = _30.bgColor.xyz;
    float3 col = mix(a, b, float3(m * _30.bgStrength));
    referenceColor = float4(col, 1.0);
}

fragment refAM35_ef17257e3434e_out refAM35_ef17257e3434e(constant ReferenceUniformsef17257e3434e& _30 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef17257e3434e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_30, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _156 = any(isnan(referenceColor));
    bool _163;
    if (!_156)
    {
        _163 = any(isinf(referenceColor));
    }
    else
    {
        _163 = _156;
    }
    if (_163)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _177 = referenceColor;
    float3 _183 = fast::clamp(_177.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _183.x;
    referenceColor.y = _183.y;
    referenceColor.z = _183.z;
    out.finalColor = referenceColor;
    return out;
}

