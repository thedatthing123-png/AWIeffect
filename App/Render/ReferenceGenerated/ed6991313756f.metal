// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s_warp_magnify.xml
// Original source comments and attribution:
// S_WarpMagnify implementation for Alight Motion
// Tile
// Reflect
// No wrap
// 1. Calculate relative position from center
// Correct for aspect ratio
// 2. Apply Lens Rotation
// 3. Apply Ellipse Scaling
// 4. Calculate Distance and Magnification
// 5. Warp the UVs
// 6. Inverse Transform
// 7. Apply Wrap and Sample
// 8. Edge Darkening
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformsed6991313756f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 center;
    char _m6_pad[8];
    float magnifyAmount;
    char _m7_pad[8];
    float2 magnifyRel;
    char _m8_pad[8];
    float lensRadius;
    char _m9_pad[12];
    float lensEdgeWidth;
    char _m10_pad[12];
    float lensRelWidth;
    char _m11_pad[12];
    float lensRelHeight;
    char _m12_pad[12];
    float lensRotate;
    char _m13_pad[12];
    float lensEdgeShape;
    char _m14_pad[12];
    float wrapMode;
    char _m15_pad[12];
    uint followLayer;
    char _m16_pad[12];
    float blend;
};

struct refAM35_ed6991313756f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 rotate(thread const float2& v, thread const float& angle)
{
    float s = sin(angle);
    float c = cos(angle);
    return float2((v.x * c) - (v.y * s), (v.x * s) + (v.y * c));
}

static inline __attribute__((always_inline))
float2 applyWrap(thread const float2& uv, thread const int& mode)
{
    if (mode == 1)
    {
        return fract(uv);
    }
    if (mode == 2)
    {
        return abs(mod(uv - float2(1.0), float2(2.0)) - float2(1.0));
    }
    return uv;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsed6991313756f& _104, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 luv = (gl_FragCoord.xy - _104.refLayer.xy) / _104.refLayer.zw;
    float2 suv = gl_FragCoord.xy / _104.refScreen.xy;
    float2 uv;
    float2 aspect;
    if (_104.followLayer != 0u)
    {
        uv = luv;
        aspect = float2(_104.refLayer.z / _104.refLayer.w, 1.0);
    }
    else
    {
        uv = suv;
        aspect = float2(_104.refScreen.x / _104.refScreen.y, 1.0);
    }
    float2 p = uv - _104.center;
    p.x *= aspect.x;
    float rad = _104.lensRotate * 0.01745329238474369049072265625;
    float2 param = p;
    float param_1 = rad;
    p = rotate(param, param_1);
    p.x /= fast::max(0.00999999977648258209228515625, _104.lensRelWidth);
    p.y /= fast::max(0.00999999977648258209228515625, _104.lensRelHeight);
    float d = length(p);
    float edgeSize = _104.lensRadius * _104.lensEdgeWidth;
    float magFactor = 1.0;
    if (d < _104.lensRadius)
    {
        magFactor = _104.magnifyAmount;
    }
    else
    {
        if (d < (_104.lensRadius + edgeSize))
        {
            float t = (d - _104.lensRadius) / edgeSize;
            float curve = mix(t, smoothstep(0.0, 1.0, t), _104.lensEdgeShape);
            magFactor = mix(_104.magnifyAmount, 1.0, curve);
        }
    }
    float2 warpedP = p;
    warpedP /= (_104.magnifyRel * magFactor);
    warpedP.x *= _104.lensRelWidth;
    warpedP.y *= _104.lensRelHeight;
    float2 param_2 = warpedP;
    float param_3 = -rad;
    warpedP = rotate(param_2, param_3);
    warpedP.x /= aspect.x;
    float2 finalUV = _104.center + warpedP;
    float2 param_4 = finalUV;
    int param_5 = int(_104.wrapMode);
    finalUV = applyWrap(param_4, param_5);
    float2 param_6 = finalUV;
    float4 color = texture2DCv(refInput, refInputSmplr, param_6);
    bool _295 = d > _104.lensRadius;
    bool _304;
    if (_295)
    {
        _304 = d < (_104.lensRadius + edgeSize);
    }
    else
    {
        _304 = _295;
    }
    if (_304)
    {
        float4 _316 = color;
        float3 _318 = _316.xyz * mix(0.949999988079071044921875, 1.0, (d - _104.lensRadius) / edgeSize);
        color.x = _318.x;
        color.y = _318.y;
        color.z = _318.z;
    }
    float2 param_7 = suv;
    float4 base = texture2DCv(refInput, refInputSmplr, param_7);
    referenceColor = mix(base, color, float4(_104.blend));
}

fragment refAM35_ed6991313756f_out refAM35_ed6991313756f(constant ReferenceUniformsed6991313756f& _104 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed6991313756f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _104, refInput, refInputSmplr, referenceColor);
    bool _343 = any(isnan(referenceColor));
    bool _350;
    if (!_343)
    {
        _350 = any(isinf(referenceColor));
    }
    else
    {
        _350 = _343;
    }
    if (_350)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _363 = referenceColor;
    float3 _369 = fast::clamp(_363.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _369.x;
    referenceColor.y = _369.y;
    referenceColor.z = _369.z;
    out.finalColor = referenceColor;
    return out;
}

