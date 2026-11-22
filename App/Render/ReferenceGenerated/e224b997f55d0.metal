// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/displacemap3.xml
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

struct ReferenceUniformse224b997f55d0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 offs;
    char _m6_pad[8];
    int typex;
    char _m7_pad[12];
    int typey;
    char _m8_pad[12];
    int edges;
    char _m9_pad[12];
    uint fromctr;
    char _m10_pad[12];
    uint invert;
};

struct refAM35_e224b997f55d0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse224b997f55d0& _31, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float2 adjOffs = _31.offs / float2(1000.0);
    adjOffs.x *= ((_31.refLayer.z / _31.refLayer.w) * (-1.0));
    float2 param = gl_FragCoord.xy / _31.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float luminance = dot(texColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float px;
    if (_31.typex == 0)
    {
        px = luminance;
    }
    else
    {
        if (_31.typex == 1)
        {
            px = texColor.x;
        }
        else
        {
            if (_31.typex == 2)
            {
                px = texColor.y;
            }
            else
            {
                if (_31.typex == 3)
                {
                    px = texColor.z;
                }
                else
                {
                    adjOffs *= 0.0;
                }
            }
        }
    }
    float py;
    if (_31.typey == 0)
    {
        py = luminance;
    }
    else
    {
        if (_31.typey == 1)
        {
            py = texColor.x;
        }
        else
        {
            if (_31.typey == 2)
            {
                py = texColor.y;
            }
            else
            {
                if (_31.typey == 3)
                {
                    py = texColor.z;
                }
                else
                {
                    adjOffs *= 0.0;
                }
            }
        }
    }
    if (_31.fromctr != 0u)
    {
        px = (px - 0.5) * 2.0;
        py = (py - 0.5) * 2.0;
    }
    if (_31.invert != 0u)
    {
        px = 1.0 - px;
        py = 1.0 - py;
    }
    float2 p = float2(px, py);
    adjOffs *= (p * texColor.w);
    float2 ref_sample = (gl_FragCoord.xy / _31.refScreen.xy) + adjOffs;
    if (_31.edges == 0)
    {
        float2 param_1 = ref_sample;
        referenceColor = texture2DCv(refReference, refReferenceSmplr, param_1);
    }
    else
    {
        if (_31.edges == 1)
        {
            ref_sample = float2(1.0) - abs(mod(ref_sample, float2(2.0)) - float2(1.0));
            float2 param_2 = ref_sample;
            referenceColor = texture2DCv(refReference, refReferenceSmplr, param_2) * texColor.w;
        }
        else
        {
            if (_31.edges == 2)
            {
                bool _240 = ref_sample.x < 0.0;
                bool _247;
                if (!_240)
                {
                    _247 = ref_sample.x > 1.0;
                }
                else
                {
                    _247 = _240;
                }
                bool _254;
                if (!_247)
                {
                    _254 = ref_sample.y < 0.0;
                }
                else
                {
                    _254 = _247;
                }
                bool _261;
                if (!_254)
                {
                    _261 = ref_sample.y > 1.0;
                }
                else
                {
                    _261 = _254;
                }
                if (_261)
                {
                    referenceColor = float4(0.0);
                }
                else
                {
                    float2 param_3 = ref_sample;
                    referenceColor = texture2DCv(refReference, refReferenceSmplr, param_3) * texColor.w;
                }
            }
            else
            {
                if (_31.edges == 3)
                {
                    ref_sample = mod(ref_sample, float2(1.0));
                    float2 param_4 = ref_sample;
                    referenceColor = texture2DCv(refReference, refReferenceSmplr, param_4) * texColor.w;
                }
                else
                {
                    float2 param_5 = ref_sample;
                    referenceColor = texture2DCv(refReference, refReferenceSmplr, param_5) * texColor.w;
                }
            }
        }
    }
}

fragment refAM35_e224b997f55d0_out refAM35_e224b997f55d0(constant ReferenceUniformse224b997f55d0& _31 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e224b997f55d0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_31, refInput, refInputSmplr, gl_FragCoord, referenceColor, refReference, refReferenceSmplr);
    bool _297 = any(isnan(referenceColor));
    bool _304;
    if (!_297)
    {
        _304 = any(isinf(referenceColor));
    }
    else
    {
        _304 = _297;
    }
    if (_304)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _317 = referenceColor;
    float3 _323 = fast::clamp(_317.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _323.x;
    referenceColor.y = _323.y;
    referenceColor.z = _323.z;
    out.finalColor = referenceColor;
    return out;
}

