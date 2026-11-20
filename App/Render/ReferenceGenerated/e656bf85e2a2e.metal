// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/rounded_edge_mask.xml
// Original source comments and attribution:
// Signed distance function for a rounded rectangle
// b = half-extents, r = corner radius
// acLayerNorm is 0..1 within the layer, centered on the layer
// This makes the mask follow the layer exactly as it moves/scales/rotates
// Remap to -0.5 .. 0.5, then apply user offset
// Apply aspect-correct scale
// acLayerSize gives the layer pixel size so we can correct aspect
// Half extents of the box (aspect corrected)
// Corner radius in same space
// SDF distance — negative = inside, positive = outside
// Feather: transition band in layer-space units
// mask = 1 inside, 0 outside, smooth transition
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse656bf85e2a2e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float radius;
    char _m6_pad[12];
    float feather;
    char _m7_pad[12];
    float scaleX;
    char _m8_pad[12];
    float scaleY;
    char _m9_pad[12];
    float offsetX;
    char _m10_pad[12];
    float offsetY;
    char _m11_pad[12];
    uint invert;
    char _m12_pad[12];
    float opacity;
};

struct refAM35_e656bf85e2a2e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float sdRoundedBox(thread const float2& p, thread const float2& b, thread const float& r)
{
    float2 q = (abs(p) - b) + float2(r);
    return (length(fast::max(q, float2(0.0))) + fast::min(fast::max(q.x, q.y), 0.0)) - r;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse656bf85e2a2e& _67, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _67.refLayer.xy) / _67.refLayer.zw;
    float2 p = (uv - float2(0.5)) - (float2(_67.offsetX, _67.offsetY) * 0.5);
    float aspect = _67.refLayer.z / _67.refLayer.w;
    p.x *= aspect;
    float2 halfExtents = float2((0.5 * _67.scaleX) * aspect, 0.5 * _67.scaleY);
    float r = _67.radius * fast::min(halfExtents.x, halfExtents.y);
    float2 param = p;
    float2 param_1 = halfExtents - float2(r);
    float param_2 = r;
    float dist = sdRoundedBox(param, param_1, param_2);
    float featherSize = (_67.feather * fast::min(halfExtents.x, halfExtents.y)) * 0.5;
    featherSize = fast::max(featherSize, 9.9999997473787516355514526367188e-05);
    float mask = 1.0 - smoothstep(-featherSize, featherSize, dist);
    if (_67.invert != 0u)
    {
        mask = 1.0 - mask;
    }
    mask *= _67.opacity;
    float2 param_3 = gl_FragCoord.xy / _67.refScreen.xy;
    float4 col = texture2DCv(refInput, refInputSmplr, param_3);
    referenceColor = float4(col.xyz * mask, col.w * mask);
}

fragment refAM35_e656bf85e2a2e_out refAM35_e656bf85e2a2e(constant ReferenceUniformse656bf85e2a2e& _67 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e656bf85e2a2e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _67, refInput, refInputSmplr, referenceColor);
    bool _209 = any(isnan(referenceColor));
    bool _216;
    if (!_209)
    {
        _216 = any(isinf(referenceColor));
    }
    else
    {
        _216 = _209;
    }
    if (_216)
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

