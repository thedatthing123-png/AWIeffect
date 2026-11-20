// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxwarpdist.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef0dd00935b91
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float warpx;
    char _m6_pad[12];
    float warpy;
    char _m7_pad[12];
    float intensity;
    char _m8_pad[12];
    float amp;
    char _m9_pad[12];
    float speed;
    char _m10_pad[8];
    float2 position;
    char _m11_pad[8];
    float2 stretch;
};

struct refAM35_ef0dd00935b91_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 distortUV(thread float2& uv, thread float2& nUV, constant ReferenceUniformsef0dd00935b91& _33, texture2d<float> refImage1, sampler refImage1Smplr)
{
    nUV.x += (_33.warpx * _33.speed);
    nUV.y += (_33.warpy * _33.speed);
    float2 param = nUV * _33.amp;
    float2 _noise = texture2DCv(refImage1, refImage1Smplr, param).xy;
    uv += ((float2(-1.0) + (_noise * 2.0)) * _33.intensity);
    return uv;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsef0dd00935b91& _33, texture2d<float> refImage1, sampler refImage1Smplr, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _33.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 syamjaidtz = gl_FragCoord.xy / _33.refScreen.xy;
    syamjaidtz /= float2(1.0);
    syamjaidtz += ((float2(0.0 + _33.position.x, 0.0 + _33.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 scaleVec = float2(1.0 * _33.stretch.x, 1.0 * _33.stretch.y);
    syamjaidtz /= scaleVec;
    float2 uv = syamjaidtz;
    float2 nUV = uv;
    float2 param_1 = uv;
    float2 param_2 = float2(nUV.x, nUV.y);
    float2 _152 = distortUV(param_1, param_2, _33, refImage1, refImage1Smplr);
    uv = _152;
    float2 param_3 = uv;
    float4 color = texture2DCv(refInput, refInputSmplr, param_3);
    referenceColor = color;
}

fragment refAM35_ef0dd00935b91_out refAM35_ef0dd00935b91(constant ReferenceUniformsef0dd00935b91& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef0dd00935b91_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_33, refImage1, refImage1Smplr, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _166 = any(isnan(referenceColor));
    bool _173;
    if (!_166)
    {
        _173 = any(isinf(referenceColor));
    }
    else
    {
        _173 = _166;
    }
    if (_173)
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

