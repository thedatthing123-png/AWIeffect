// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_native_wipeChecker.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse62c9cb20d026
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

struct refAM35_e62c9cb20d026_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float aeHash(thread const float2& p)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse62c9cb20d026& _48, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _48.refScreen.xy;
    float2 p = uv - float2(0.5);
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float t = (_48.refScreen.z * 0.3499999940395355224609375) + 62.0;
    float f = 0.0;
    if (true)
    {
        float2 q = floor(uv * fast::max(3.0, _48.scale * 10.0));
        f = step(0.5, fract((q.x + q.y) + t));
    }
    else
    {
        if (true)
        {
            f = powr(fast::max(0.0, sin(((p.x * 10.0) + (sin((p.y * 7.0) + t) * 3.0)) + t)), 5.0);
        }
        else
        {
            if (true)
            {
                float2 q_1 = fract(uv * fast::max(5.0, _48.scale * 16.0)) - float2(0.5);
                float2 param_1 = floor(uv * fast::max(5.0, _48.scale * 16.0));
                f = smoothstep(0.119999997317790985107421875, 0.0199999995529651641845703125, length(q_1)) * (0.4000000059604644775390625 + (0.60000002384185791015625 * aeHash(param_1)));
            }
            else
            {
                if (true)
                {
                    float a = precise::atan2(p.y, p.x);
                    float r = length(p);
                    f = powr(fast::max(0.0, cos((a * 8.0) + (sin((r * 35.0) - t) * 2.0))), 12.0);
                }
                else
                {
                    float2 param_2 = floor((uv + float2(t * 0.0199999995529651641845703125, (-t) * 0.014999999664723873138427734375)) * fast::max(6.0, _48.scale * 14.0));
                    float n = aeHash(param_2);
                    f = smoothstep(0.37999999523162841796875, 0.920000016689300537109375, n) * (0.3499999940395355224609375 + (0.64999997615814208984375 * (1.0 - (length(p) * 1.39999997615814208984375))));
                }
            }
        }
    }
    float3 art = mix(_48.colorA.xyz, _48.colorB.xyz, float3(0.5 + (0.5 * sin((f * 6.28299999237060546875) + t))));
    float3 outc = src.xyz + ((art * f) * _48.amount);
    referenceColor = float4(outc, src.w);
}

fragment refAM35_e62c9cb20d026_out refAM35_e62c9cb20d026(constant ReferenceUniformse62c9cb20d026& _48 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e62c9cb20d026_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _48, refInput, refInputSmplr, referenceColor);
    bool _270 = any(isnan(referenceColor));
    bool _277;
    if (!_270)
    {
        _277 = any(isinf(referenceColor));
    }
    else
    {
        _277 = _270;
    }
    if (_277)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _290 = referenceColor;
    float3 _296 = fast::clamp(_290.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _296.x;
    referenceColor.y = _296.y;
    referenceColor.z = _296.z;
    out.finalColor = referenceColor;
    return out;
}

