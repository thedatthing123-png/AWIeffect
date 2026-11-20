// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/eye_split_bend.xml
// Original source comments and attribution:
// Eye Split Bend
// Port of the provided ShaderToy with AM coordinate + param mapping
// - Uses Point A/B to define the split axis
// - Split (px) sets the height manually (keyframe as needed)
// Helper: perpendicular
// Points in pixels -> normalize to UV
// midpoint in UV
// axis unit in UV
// normal unit in UV
// half-length in UV units
// Local coordinates relative to the AB frame
// along AB
// across AB
// normalize so A/B map to -1..+1 along 2*range
// Split height in UV units (based on screen height to be pixel-consistent)
// Manual control: keyframe 'split' as needed; no time-based animation here.
// Superellipse-like longitudinal profile with sharper tips
// base runs 0..1 across x, with tip shaping and global sharpness
// Asymmetric upper / lower lobe scales
// Vertical bend profile along x
// Inside if within the piecewise top/bottom boundaries around the bent centerline
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseaf4b83be09ed
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 pointA;
    char _m6_pad[8];
    float2 pointB;
    char _m7_pad[8];
    float split;
    char _m8_pad[12];
    float sharpness;
    char _m9_pad[12];
    float bendFactor;
    char _m10_pad[12];
    float tipSharpness;
    char _m11_pad[12];
    float lobePower;
    char _m12_pad[12];
    float upperScale;
    char _m13_pad[12];
    float lowerScale;
    char _m14_pad[12];
    uint invertInside;
    char _m15_pad[12];
    float alpha;
};

struct refAM35_eaf4b83be09ed_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 perp(thread const float2& v)
{
    return float2(-v.y, v.x);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformseaf4b83be09ed& _49, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _49.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float2 Auv = _49.pointA / _49.refScreen.xy;
    float2 Buv = _49.pointB / _49.refScreen.xy;
    float2 Muv = (Auv + Buv) * 0.5;
    float2 dir = fast::normalize(Buv - Auv);
    float2 param_1 = dir;
    float2 nrm = perp(param_1);
    float halfLen = fast::max(length(Buv - Auv) * 0.5, 9.9999999747524270787835121154785e-07);
    float2 p = uv - Muv;
    float x = dot(p, dir);
    float y = dot(p, nrm);
    float xN = x / halfLen;
    float splitUV = _49.split / fast::max(_49.refScreen.y, 1.0);
    float xAbs = abs(xN);
    float base = powr(fast::max(0.0, 1.0 - powr(xAbs, _49.tipSharpness)), _49.sharpness);
    base = powr(base, _49.lobePower);
    float topBoundary = (splitUV * _49.upperScale) * base;
    float bottomBoundary = (splitUV * _49.lowerScale) * base;
    float vertical_bend = _49.bendFactor * (0.25 - (xN * xN));
    float yRel = y - vertical_bend;
    bool _185 = yRel <= topBoundary;
    bool _192;
    if (_185)
    {
        _192 = yRel >= (-bottomBoundary);
    }
    else
    {
        _192 = _185;
    }
    bool inside = _192;
    float4 transparent = float4(0.0);
    float4 _201;
    if (_49.invertInside != 0u)
    {
        _201 = select(transparent, src, bool4(inside));
    }
    else
    {
        _201 = select(src, transparent, bool4(inside));
    }
    float4 outCol = _201;
    float aSrc = src.w * _49.alpha;
    referenceColor = outCol * aSrc;
}

fragment refAM35_eaf4b83be09ed_out refAM35_eaf4b83be09ed(constant ReferenceUniformseaf4b83be09ed& _49 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eaf4b83be09ed_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _49, refInput, refInputSmplr, referenceColor);
    bool _233 = any(isnan(referenceColor));
    bool _240;
    if (!_233)
    {
        _240 = any(isinf(referenceColor));
    }
    else
    {
        _240 = _233;
    }
    if (_240)
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

