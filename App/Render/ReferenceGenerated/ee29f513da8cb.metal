// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/fisheye.xml
// Original source comments and attribution:
// Fisheye / Anti‑Fisheye
// Ported from the Shadertoy snippet provided by the user and adapted for Alight Motion
// Inspired by: https://stackoverflow.com/questions/6030814
// Notes:
// - power > 0 : fisheye (barrel)
// - power < 0 : anti‑fisheye (pincushion)
// - aspectMode!=0 applies aspect correction so the effect remains circular on non‑square frames
// 0..1
// working UVs (may be aspect-adjusted)
// aspect ratio (width/height)
// Aspect-corrected center
// Aspect-corrected working coordinates for circular behavior
// vector from center
// distance from center
// Map UI power [-1..1] to a usable curvature scale (radians-like)
// Using PI scaling provides a useful range similar to the original mouse mapping
// Compute bind radius according to original logic
// stick to corners for fisheye
// borders when anti‑fisheye
// not used when k == 0
// fisheye
// anti‑fisheye (scaled by 10 like the reference)
// no effect
// Undo aspect correction for sampling
// Sample with clamping at edges
// Preserve original alpha and allow overall alpha control
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsee29f513da8cb
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float power;
    char _m6_pad[12];
    float centerX;
    char _m7_pad[12];
    float centerY;
    char _m8_pad[12];
    int aspectMode;
    char _m9_pad[12];
    float alpha;
};

struct refAM35_ee29f513da8cb_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsee29f513da8cb& _34, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _34.refScreen.xy;
    float2 uvWork = uv;
    float prop = _34.refScreen.x / _34.refScreen.y;
    float _64;
    if (_34.aspectMode != 0)
    {
        _64 = _34.centerY / prop;
    }
    else
    {
        _64 = _34.centerY;
    }
    float2 m = float2(_34.centerX, _64);
    if (_34.aspectMode != 0)
    {
        uvWork = float2(uv.x, uv.y / prop);
    }
    float2 d = uvWork - m;
    float r = length(d);
    float k = _34.power * 3.1415927410125732421875;
    float bind;
    if (k > 0.0)
    {
        bind = length(m);
    }
    else
    {
        if (k < 0.0)
        {
            float _118;
            if (prop < 1.0)
            {
                _118 = m.x;
            }
            else
            {
                _118 = m.y;
            }
            bind = _118;
        }
        else
        {
            bind = 1.0;
        }
    }
    float2 uv2;
    if (k > 0.0)
    {
        uv2 = m + (((fast::normalize(d) * tan(r * k)) * bind) / float2(tan(bind * k)));
    }
    else
    {
        if (k < 0.0)
        {
            float kk = (-k) * 10.0;
            uv2 = m + (((fast::normalize(d) * atan(r * kk)) * bind) / float2(atan(kk * bind)));
        }
        else
        {
            uv2 = uvWork;
        }
    }
    if (_34.aspectMode != 0)
    {
        uv2 = float2(uv2.x, uv2.y * prop);
    }
    float2 param = fast::clamp(uv2, float2(0.0), float2(1.0));
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float a = src.w * _34.alpha;
    referenceColor = float4(src.xyz, 1.0) * a;
}

fragment refAM35_ee29f513da8cb_out refAM35_ee29f513da8cb(constant ReferenceUniformsee29f513da8cb& _34 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ee29f513da8cb_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _34, refInput, refInputSmplr, referenceColor);
    bool _224 = any(isnan(referenceColor));
    bool _231;
    if (!_224)
    {
        _231 = any(isinf(referenceColor));
    }
    else
    {
        _231 = _224;
    }
    if (_231)
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

