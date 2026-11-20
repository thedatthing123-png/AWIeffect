// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/solidmatte.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef8c112b6b73b
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color;
    float alpha;
    char _m7_pad[12];
    uint punchout;
    char _m8_pad[12];
    uint screenSpace;
};

struct refAM35_ef8c112b6b73b_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsef8c112b6b73b& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 frontColor = texture2DCv(refInput, refInputSmplr, param);
    float4 backColor = _36.color * _36.alpha;
    if (!(_36.screenSpace != 0u))
    {
        float insideLayer = ((step(0.0, ((gl_FragCoord.xy - _36.refLayer.xy) / _36.refLayer.zw).x) * step(((gl_FragCoord.xy - _36.refLayer.xy) / _36.refLayer.zw).x, 1.0)) * step(0.0, ((gl_FragCoord.xy - _36.refLayer.xy) / _36.refLayer.zw).y)) * step(((gl_FragCoord.xy - _36.refLayer.xy) / _36.refLayer.zw).y, 1.0);
        backColor *= insideLayer;
    }
    if (_36.punchout != 0u)
    {
        referenceColor = backColor * (1.0 - frontColor.w);
    }
    else
    {
        referenceColor = (backColor * (1.0 - frontColor.w)) + frontColor;
    }
}

fragment refAM35_ef8c112b6b73b_out refAM35_ef8c112b6b73b(constant ReferenceUniformsef8c112b6b73b& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef8c112b6b73b_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _152 = any(isnan(referenceColor));
    bool _159;
    if (!_152)
    {
        _159 = any(isinf(referenceColor));
    }
    else
    {
        _159 = _152;
    }
    if (_159)
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

