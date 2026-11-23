// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/fbm_time_displace_fade.xml
// Original source comments and attribution:
// Port of provided ShaderToy-style effect (manual time control)
// Original concepts: fbm noise, displacement, time-based fade
// 0..1
// Time mapping from params (no auto acTime)
// Secondary time scale (iTime/3. in source) kept for parity if needed
// not used directly but preserved for parity
// FBM-based displacements
// Fade mask (procedural, similar structure to source)
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsecef0c8a880bd
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float time;
    char _m6_pad[12];
    float timeDiv;
    char _m7_pad[12];
    float timeScale;
    char _m8_pad[12];
    float fbmScale;
    char _m9_pad[12];
    float dispClamp;
    char _m10_pad[12];
    float fadeBias;
};

struct refAM35_ecef0c8a880bd_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float workingPow3(thread const float& x)
{
    return (x * x) * x;
}

static inline __attribute__((always_inline))
float random(thread const float2& _st)
{
    return fract(sin(dot(_st, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float noise2d(thread const float2& _st)
{
    float2 i = floor(_st);
    float2 f = fract(_st);
    float2 param = i;
    float a = random(param);
    float2 param_1 = i + float2(1.0, 0.0);
    float b = random(param_1);
    float2 param_2 = i + float2(0.0, 1.0);
    float c = random(param_2);
    float2 param_3 = i + float2(1.0);
    float d = random(param_3);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    return (mix(a, b, u.x) + (((c - a) * u.y) * (1.0 - u.x))) + (((d - b) * u.x) * u.y);
}

static inline __attribute__((always_inline))
float fbm(thread float2& _st)
{
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0);
    float2x2 rot = float2x2(float2(0.877582550048828125, 0.47942554950714111328125), float2(-0.47942554950714111328125, 0.877582550048828125));
    for (int i = 0; i < 5; i++)
    {
        float2 param = _st;
        v += (a * noise2d(param));
        _st = ((rot * _st) * 2.0) + shift;
        a *= 0.5;
    }
    return v;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsecef0c8a880bd& _183, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 res = _183.refScreen.xy;
    float2 fragCoord = (gl_FragCoord.xy / _183.refScreen.xy) * res;
    float2 uv = fragCoord / res;
    float param = fract(_183.time / fast::max(_183.timeDiv, 9.9999997473787516355514526367188e-05)) - 0.5;
    float modifiedTime = workingPow3(param) * 4.0;
    float timeB = _183.time / fast::max(_183.timeScale, 9.9999997473787516355514526367188e-05);
    float2 param_1 = fragCoord / float2(_183.fbmScale);
    float _235 = fbm(param_1);
    float verticalDisp = fast::clamp(_235 * modifiedTime, -1.0, 1.0) / fast::max(_183.dispClamp, 9.9999997473787516355514526367188e-05);
    float2 param_2 = fragCoord.yx / float2(_183.fbmScale);
    float _253 = fbm(param_2);
    float horizontalDisp = fast::clamp(_253 * modifiedTime, -1.0, 1.0) / fast::max(_183.dispClamp, 9.9999997473787516355514526367188e-05);
    float2 offsetCoords = uv - float2(horizontalDisp, verticalDisp);
    float2 param_3 = offsetCoords;
    float4 tex = texture2DCv(refInput, refInputSmplr, param_3);
    float2 param_4 = uv * 3.0;
    float _280 = fbm(param_4);
    float mask = fast::clamp((1.0 - ((abs(modifiedTime) * 2.0) + _280)) * _183.fadeBias, 0.0, 1.0);
    float3 outRGB = mix(float3(0.0), tex.xyz, float3(mask));
    referenceColor = tex * mask;
}

fragment refAM35_ecef0c8a880bd_out refAM35_ecef0c8a880bd(constant ReferenceUniformsecef0c8a880bd& _183 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ecef0c8a880bd_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_183, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _307 = any(isnan(referenceColor));
    bool _314;
    if (!_307)
    {
        _314 = any(isinf(referenceColor));
    }
    else
    {
        _314 = _307;
    }
    if (_314)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _328 = referenceColor;
    float3 _334 = fast::clamp(_328.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _334.x;
    referenceColor.y = _334.y;
    referenceColor.z = _334.z;
    out.finalColor = referenceColor;
    return out;
}

