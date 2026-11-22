// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/warp_styles.xml
// Original source comments and attribution:
// Multi-Style Warp Implementation for Alight Motion
// Repeat
// Mirror
// Clamp
// Transparent/Default
// 1. Normalize UVs to [-1, 1] for math
// 2. Apply Horizontal and Vertical Distortion (Tapering)
// 3. Axis Swap for Vertical Mode
// 4. Warp Logic
// Arc
// Arc Lower
// Arc Upper
// Arch
// Bulge
// Shell Lower
// Shell Upper
// Flag
// Wave
// Fish
// Rise
// FishEye
// Inflate
// Twist
// Squeeze
// 5. Inverse Axis Swap
// 6. Map back to [0, 1]
// 7. Apply Tiling
// 8. Clamp and Sample
// Alpha mask only if transparent mode is selected
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

struct ReferenceUniformse4fafe3d586d7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int warpStyle;
    char _m6_pad[12];
    uint warpVertical;
    char _m7_pad[12];
    float bend;
    char _m8_pad[12];
    float hDistortion;
    char _m9_pad[12];
    float vDistortion;
    char _m10_pad[12];
    uint followLayer;
    char _m11_pad[12];
    float blend;
    char _m12_pad[12];
    int tileMode;
};

struct refAM35_e4fafe3d586d7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 applyTile(thread const float2& uv, thread const int& mode)
{
    if (mode == 1)
    {
        return fract(uv);
    }
    else
    {
        if (mode == 2)
        {
            float2 m = mod(uv, float2(2.0));
            return mix(m, float2(2.0) - m, step(float2(1.0), m));
        }
        else
        {
            if (mode == 3)
            {
                return fast::clamp(uv, float2(0.0), float2(1.0));
            }
        }
    }
    return uv;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse4fafe3d586d7& _86, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 luv = (gl_FragCoord.xy - _86.refLayer.xy) / _86.refLayer.zw;
    float2 suv = gl_FragCoord.xy / _86.refScreen.xy;
    float2 uv;
    float2 aspect;
    if (_86.followLayer != 0u)
    {
        uv = luv;
        aspect = float2(_86.refLayer.z / _86.refLayer.w, 1.0);
    }
    else
    {
        uv = suv;
        aspect = float2(_86.refScreen.x / _86.refScreen.y, 1.0);
    }
    float2 p = (uv * 2.0) - float2(1.0);
    float hDist = _86.hDistortion * 0.00999999977648258209228515625;
    float vDist = _86.vDistortion * 0.00999999977648258209228515625;
    p.x *= (1.0 - (vDist * p.y));
    p.y *= (1.0 - (hDist * p.x));
    if (_86.warpVertical != 0u)
    {
        p = p.yx;
    }
    float b = _86.bend * 0.00999999977648258209228515625;
    float2 warped = p;
    int style = _86.warpStyle;
    int tMode = _86.tileMode;
    float curve = 1.0 - (p.x * p.x);
    if (style == 0)
    {
        warped.y += (b * curve);
    }
    else
    {
        if (style == 1)
        {
            if (p.y < 0.0)
            {
                warped.y += ((b * curve) * abs(p.y));
            }
        }
        else
        {
            if (style == 2)
            {
                if (p.y > 0.0)
                {
                    warped.y += ((b * curve) * p.y);
                }
            }
            else
            {
                if (style == 3)
                {
                    warped.y += (b * curve);
                    warped.x *= (1.0 - ((b * 0.5) * (1.0 + p.y)));
                }
                else
                {
                    if (style == 4)
                    {
                        float bulge = (b * (1.0 - abs(p.x))) * (1.0 - abs(p.y));
                        warped *= (1.0 - bulge);
                    }
                    else
                    {
                        if (style == 5)
                        {
                            warped.y += (b * curve);
                            warped.x *= (1.0 + ((b * 0.5) * (1.0 - p.y)));
                        }
                        else
                        {
                            if (style == 6)
                            {
                                warped.y += (b * curve);
                                warped.x *= (1.0 + ((b * 0.5) * (1.0 + p.y)));
                            }
                            else
                            {
                                if (style == 7)
                                {
                                    warped.y += (b * sin((p.x * 3.1415927410125732421875) + 0.0));
                                }
                                else
                                {
                                    if (style == 8)
                                    {
                                        warped.y += (b * sin((p.x * 3.1415927410125732421875) * 2.0));
                                    }
                                    else
                                    {
                                        if (style == 9)
                                        {
                                            warped.y *= (1.0 + (b * p.x));
                                            warped.x += ((b * 0.20000000298023223876953125) * (1.0 - (p.y * p.y)));
                                        }
                                        else
                                        {
                                            if (style == 10)
                                            {
                                                warped.y += (b * sin((p.x * 3.1415927410125732421875) * 0.5));
                                            }
                                            else
                                            {
                                                if (style == 11)
                                                {
                                                    float d = length(p);
                                                    warped = p * (1.0 + (b * d));
                                                }
                                                else
                                                {
                                                    if (style == 12)
                                                    {
                                                        float d_1 = length(p);
                                                        warped = p / float2(1.0 + (b * (1.0 - d_1)));
                                                    }
                                                    else
                                                    {
                                                        if (style == 13)
                                                        {
                                                            float d_2 = length(p);
                                                            float angle = (b * 3.1415927410125732421875) * (1.0 - d_2);
                                                            float s = sin(angle);
                                                            float c = cos(angle);
                                                            warped = float2((p.x * c) - (p.y * s), (p.x * s) + (p.y * c));
                                                        }
                                                        else
                                                        {
                                                            if (style == 14)
                                                            {
                                                                warped.x *= (1.0 + (b * (1.0 - abs(p.y))));
                                                                warped.y *= (1.0 + (b * (1.0 - abs(p.x))));
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (_86.warpVertical != 0u)
    {
        warped = warped.yx;
    }
    float2 finalUV = (warped + float2(1.0)) * 0.5;
    float2 param = finalUV;
    int param_1 = tMode;
    float2 tiledUV = applyTile(param, param_1);
    float2 param_2 = tiledUV;
    float4 color = texture2DCv(refInput, refInputSmplr, param_2);
    if (tMode == 0)
    {
        bool _549 = finalUV.x < 0.0;
        bool _556;
        if (!_549)
        {
            _556 = finalUV.x > 1.0;
        }
        else
        {
            _556 = _549;
        }
        bool _563;
        if (!_556)
        {
            _563 = finalUV.y < 0.0;
        }
        else
        {
            _563 = _556;
        }
        bool _570;
        if (!_563)
        {
            _570 = finalUV.y > 1.0;
        }
        else
        {
            _570 = _563;
        }
        if (_570)
        {
            color = float4(0.0);
        }
    }
    float2 param_3 = suv;
    float4 base = texture2DCv(refInput, refInputSmplr, param_3);
    referenceColor = mix(base, color, float4(_86.blend));
}

fragment refAM35_e4fafe3d586d7_out refAM35_e4fafe3d586d7(constant ReferenceUniformse4fafe3d586d7& _86 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e4fafe3d586d7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _86, refInput, refInputSmplr, referenceColor);
    bool _590 = any(isnan(referenceColor));
    bool _597;
    if (!_590)
    {
        _597 = any(isinf(referenceColor));
    }
    else
    {
        _597 = _590;
    }
    if (_597)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _611 = referenceColor;
    float3 _617 = fast::clamp(_611.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _617.x;
    referenceColor.y = _617.y;
    referenceColor.z = _617.z;
    out.finalColor = referenceColor;
    return out;
}

