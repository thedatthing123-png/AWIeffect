// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/cosuv.xml
// Original source comments and attribution:
// Shadertoy uv mapping
// Fixed 9 iterations like original (1..9)
// Composite over input layer
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse4390d04fc4d7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float speed;
    char _m6_pad[12];
    float amount;
    char _m7_pad[12];
    float freqX;
    char _m8_pad[12];
    float freqY;
    char _m9_pad[12];
    float base;
    char _m10_pad[12];
    float opacity;
};

struct refAM35_e4390d04fc4d7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse4390d04fc4d7& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 fragCoord = (gl_FragCoord.xy / _33.refScreen.xy) * _33.refScreen.xy;
    float2 iResolution = _33.refScreen.xy;
    float iTime = _33.refScreen.z * _33.speed;
    float2 uv = ((fragCoord * 2.0) - iResolution) / float2(fast::max(iResolution.x, iResolution.y));
    for (float i = 1.0; i < 10.0; i += 1.0)
    {
        uv.x += ((_33.amount / i) * cos(((i * _33.freqX) * uv.y) + iTime));
        uv.y += ((_33.amount / i) * cos(((i * _33.freqY) * uv.x) + iTime));
    }
    float3 col = float3(_33.base) / float3(fast::max(abs(sin((iTime - uv.y) - uv.x)), 9.9999997473787516355514526367188e-05));
    float4 gen = float4(col, 1.0);
    float2 param = gl_FragCoord.xy / _33.refScreen.xy;
    float4 baseCol = texture2DCv(refInput, refInputSmplr, param);
    float4 outC = gen * _33.opacity;
    outC = (baseCol * (1.0 - outC.w)) + outC;
    referenceColor = outC;
}

fragment refAM35_e4390d04fc4d7_out refAM35_e4390d04fc4d7(constant ReferenceUniformse4390d04fc4d7& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e4390d04fc4d7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
    bool _189 = any(isnan(referenceColor));
    bool _196;
    if (!_189)
    {
        _196 = any(isinf(referenceColor));
    }
    else
    {
        _196 = _189;
    }
    if (_196)
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

