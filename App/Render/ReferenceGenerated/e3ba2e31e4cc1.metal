// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/channelmap.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse3ba2e31e4cc1
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int red;
    char _m6_pad[12];
    int green;
    char _m7_pad[12];
    int blue;
    char _m8_pad[12];
    int alpha;
};

struct refAM35_e3ba2e31e4cc1_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse3ba2e31e4cc1& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float luminance = dot(texColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 s = step(float2(0.0), (gl_FragCoord.xy - _36.refLayer.xy) / _36.refLayer.zw) - step(float2(1.0), (gl_FragCoord.xy - _36.refLayer.xy) / _36.refLayer.zw);
    float maskFactor = s.x * s.y;
    float4 outColor = float4(0.0);
    if (texColor.w > 0.0)
    {
        float _103 = texColor.w;
        float4 _104 = texColor;
        float3 _107 = _104.xyz / float3(_103);
        texColor.x = _107.x;
        texColor.y = _107.y;
        texColor.z = _107.z;
    }
    if (_36.red == 0)
    {
        outColor.x = texColor.x;
    }
    else
    {
        if (_36.red == 1)
        {
            outColor.x = texColor.y;
        }
        else
        {
            if (_36.red == 2)
            {
                outColor.x = texColor.z;
            }
            else
            {
                if (_36.red == 3)
                {
                    outColor.x = texColor.w;
                }
                else
                {
                    if (_36.red == 4)
                    {
                        outColor.x = luminance;
                    }
                    else
                    {
                        if (_36.red == 5)
                        {
                            outColor.x = 0.0;
                        }
                        else
                        {
                            outColor.x = 1.0;
                        }
                    }
                }
            }
        }
    }
    if (_36.green == 0)
    {
        outColor.y = texColor.x;
    }
    else
    {
        if (_36.green == 1)
        {
            outColor.y = texColor.y;
        }
        else
        {
            if (_36.green == 2)
            {
                outColor.y = texColor.z;
            }
            else
            {
                if (_36.green == 3)
                {
                    outColor.y = texColor.w;
                }
                else
                {
                    if (_36.green == 4)
                    {
                        outColor.y = luminance;
                    }
                    else
                    {
                        if (_36.green == 5)
                        {
                            outColor.y = 0.0;
                        }
                        else
                        {
                            outColor.y = 1.0;
                        }
                    }
                }
            }
        }
    }
    if (_36.blue == 0)
    {
        outColor.z = texColor.x;
    }
    else
    {
        if (_36.blue == 1)
        {
            outColor.z = texColor.y;
        }
        else
        {
            if (_36.blue == 2)
            {
                outColor.z = texColor.z;
            }
            else
            {
                if (_36.blue == 3)
                {
                    outColor.z = texColor.w;
                }
                else
                {
                    if (_36.blue == 4)
                    {
                        outColor.z = luminance;
                    }
                    else
                    {
                        if (_36.blue == 5)
                        {
                            outColor.z = 0.0;
                        }
                        else
                        {
                            outColor.z = 1.0;
                        }
                    }
                }
            }
        }
    }
    if (_36.alpha == 0)
    {
        outColor.w = texColor.x;
    }
    else
    {
        if (_36.alpha == 1)
        {
            outColor.w = texColor.y;
        }
        else
        {
            if (_36.alpha == 2)
            {
                outColor.w = texColor.z;
            }
            else
            {
                if (_36.alpha == 3)
                {
                    outColor.w = texColor.w;
                }
                else
                {
                    if (_36.alpha == 4)
                    {
                        outColor.w = luminance;
                    }
                    else
                    {
                        if (_36.alpha == 5)
                        {
                            outColor.w = 0.0;
                        }
                        else
                        {
                            outColor.w = 1.0;
                        }
                    }
                }
            }
        }
    }
    float _332 = outColor.w;
    float4 _333 = outColor;
    float3 _335 = _333.xyz * _332;
    outColor.x = _335.x;
    outColor.y = _335.y;
    outColor.z = _335.z;
    referenceColor = outColor * maskFactor;
}

fragment refAM35_e3ba2e31e4cc1_out refAM35_e3ba2e31e4cc1(constant ReferenceUniformse3ba2e31e4cc1& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e3ba2e31e4cc1_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _351 = any(isnan(referenceColor));
    bool _358;
    if (!_351)
    {
        _358 = any(isinf(referenceColor));
    }
    else
    {
        _358 = _351;
    }
    if (_358)
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

