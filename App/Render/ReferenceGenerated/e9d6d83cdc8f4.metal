// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_native_fractalZoomTrails.xml
// Original source comments and attribution:

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

struct ReferenceUniformse9d6d83cdc8f4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amount;
    char _m6_pad[12];
    float radius;
    char _m7_pad[12];
    float scale;
    float4 colorA;
    float4 colorB;
};

struct refAM35_e9d6d83cdc8f4_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float aeHash(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 aeMirror(thread const float2& p)
{
    return abs((fract((p * 0.5) + float2(0.5)) * 2.0) - float2(1.0));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse9d6d83cdc8f4& _63, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _63.refScreen.xy;
    float2 p = uv - float2(0.5);
    float r = length(p);
    float a = precise::atan2(p.y, p.x);
    float m = 4.0;
    float t = _63.refScreen.z * 1.190000057220458984375;
    float k = _63.amount * 0.119999997317790985107421875;
    if (m < 0.5)
    {
        p *= (1.0 + ((k * ((r * r) - 0.20000000298023223876953125)) * 3.0));
    }
    else
    {
        if (m < 1.5)
        {
            p.x += ((p.y * k) * 0.95637595653533935546875);
        }
        else
        {
            if (m < 2.5)
            {
                float param = floor(t * 12.0) + 27.0;
                float param_1 = (floor(t * 12.0) + 27.0) + 9.0;
                p += (float2(aeHash(param) - 0.5, aeHash(param_1) - 0.5) * k);
            }
            else
            {
                if (m < 3.5)
                {
                    p *= (1.0 - ((k * (1.0 - r)) * 2.0));
                }
                else
                {
                    if (m < 4.5)
                    {
                        float z = 1.0 + (k * sin((log(fast::max(r, 0.00200000009499490261077880859375)) * 18.0) - (t * 4.0)));
                        p = (float2(cos(a), sin(a)) * r) * z;
                    }
                    else
                    {
                        if (m < 6.5)
                        {
                            p += ((fast::normalize(p + float2(0.001000000047497451305389404296875)) * sin((r * 42.0) - (t * 5.0))) * k);
                        }
                        else
                        {
                            if (m < 8.5)
                            {
                                p += (float2(sin((p.y * 22.0) + t), cos((p.x * 19.0) - t)) * k);
                            }
                            else
                            {
                                if (m < 10.5)
                                {
                                    p += (float2(sin(((p.y + p.x) * 18.0) + t), sin(((p.y - p.x) * 21.0) - t)) * k);
                                }
                                else
                                {
                                    if (m < 13.5)
                                    {
                                        float2 q = p * fast::max(2.0, _63.scale * 4.0);
                                        q.x += (mod(floor(q.y), 2.0) * 0.5);
                                        q = floor(q) + float2(0.5);
                                        p = q / float2(fast::max(2.0, _63.scale * 4.0));
                                        p = float2x2(float2(cos(k), -sin(k)), float2(sin(k), cos(k))) * p;
                                    }
                                    else
                                    {
                                        if (m < 16.5)
                                        {
                                            p += ((float2(sin(((p.y * _63.scale) * 25.0) + t), sin(((p.x * _63.scale) * 23.0) - t)) * k) * (0.4000000059604644775390625 + r));
                                        }
                                        else
                                        {
                                            if (m < 17.5)
                                            {
                                                float cells = fast::max(3.0, _63.scale * 9.0);
                                                p = floor(p * cells) / float2(cells);
                                            }
                                            else
                                            {
                                                if (m < 18.5)
                                                {
                                                    a += ((sin(((r * _63.scale) * 22.0) - t) * k) * 8.0);
                                                    p = float2(cos(a), sin(a)) * r;
                                                }
                                                else
                                                {
                                                    if (m < 19.5)
                                                    {
                                                        p += ((fast::normalize(p + float2(0.001000000047497451305389404296875)) * sin((r * 65.0) - (t * 5.0))) * k);
                                                    }
                                                    else
                                                    {
                                                        p.x += (sin(((p.y * _63.scale) * 18.0) + t) * k);
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
    float2 param_2 = p + float2(0.5);
    float2 suv = aeMirror(param_2);
    float2 param_3 = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param_3);
    float2 param_4 = suv;
    float4 warped = texture2DCv(refInput, refInputSmplr, param_4);
    referenceColor = mix(src, warped, float4(fast::clamp(_63.amount, 0.0, 1.0)));
    referenceColor.w = src.w;
}

fragment refAM35_e9d6d83cdc8f4_out refAM35_e9d6d83cdc8f4(constant ReferenceUniformse9d6d83cdc8f4& _63 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9d6d83cdc8f4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _63, refInput, refInputSmplr, referenceColor);
    bool _488 = any(isnan(referenceColor));
    bool _495;
    if (!_488)
    {
        _495 = any(isinf(referenceColor));
    }
    else
    {
        _495 = _488;
    }
    if (_495)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _508 = referenceColor;
    float3 _514 = fast::clamp(_508.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _514.x;
    referenceColor.y = _514.y;
    referenceColor.z = _514.z;
    out.finalColor = referenceColor;
    return out;
}

