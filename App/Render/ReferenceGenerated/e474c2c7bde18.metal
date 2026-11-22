// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_native_bevelLightSweep.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse474c2c7bde18
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

struct refAM35_e474c2c7bde18_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float aeLum(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float aeHash(thread const float2& p)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse474c2c7bde18& _69, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _69.refScreen.xy;
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 px = (float2(1.0) / fast::max(getTexSize(param), float2(1.0))) * fast::max(1.0, _69.radius * 0.119999997317790985107421875);
    float2 param_1 = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param_1);
    float3 param_2 = src.xyz;
    float l = aeLum(param_2);
    float2 param_3 = uv + float2(px.x, 0.0);
    float3 param_4 = texture2DCv(refInput, refInputSmplr, param_3).xyz;
    float2 param_5 = uv - float2(px.x, 0.0);
    float3 param_6 = texture2DCv(refInput, refInputSmplr, param_5).xyz;
    float lx = aeLum(param_4) - aeLum(param_6);
    float2 param_7 = uv + float2(0.0, px.y);
    float3 param_8 = texture2DCv(refInput, refInputSmplr, param_7).xyz;
    float2 param_9 = uv - float2(0.0, px.y);
    float3 param_10 = texture2DCv(refInput, refInputSmplr, param_9).xyz;
    float ly = aeLum(param_8) - aeLum(param_10);
    float edge = smoothstep(0.02500000037252902984619140625, 0.2199999988079071044921875, length(float2(lx, ly)) * _69.scale);
    float2 param_11 = float2(int2(refInput.get_width(), refInput.get_height()));
    float pat = 0.5 + (0.5 * sin((((uv.x + uv.y) * getTexSize(param_11).x) / fast::max(3.0, _69.radius)) + 18.0));
    float3 ink = mix(_69.colorA.xyz, _69.colorB.xyz, float3(fract((l * 3.0) + 1.2599999904632568359375)));
    float3 outc = src.xyz;
    if (false)
    {
        outc = mix(float3(l), ink, float3(step(pat, l)));
    }
    else
    {
        if (false)
        {
            outc = mix(src.xyz, ink, float3(edge));
        }
        else
        {
            if (true)
            {
                outc = src.xyz + ((ink * edge) * (0.449999988079071044921875 + (0.550000011920928955078125 * pat)));
            }
            else
            {
                if (true)
                {
                    outc = mix(src.xyz, ink, float3(edge * _69.amount));
                }
                else
                {
                    if (true)
                    {
                        float2 param_12 = float2(int2(refInput.get_width(), refInput.get_height()));
                        float2 cell = floor((uv * getTexSize(param_12)) / float2(fast::max(2.0, _69.radius)));
                        float2 param_13 = cell;
                        float n = aeHash(param_13);
                        outc = mix(src.xyz, ink * n, float3(_69.amount * (0.3499999940395355224609375 + (0.64999997615814208984375 * edge))));
                    }
                    else
                    {
                        if (true)
                        {
                            float ray = powr(fast::max(0.0, cos((precise::atan2(uv.y - 0.5, uv.x - 0.5) * 8.0) + _69.refScreen.z)), 18.0);
                            outc = src.xyz + ((ink * (edge + (ray * l))) * _69.amount);
                        }
                        else
                        {
                            float contour = smoothstep(0.449999988079071044921875, 0.5, fract(l * (4.0 + (_69.scale * 2.0))));
                            outc = mix(src.xyz, ink, float3(_69.amount * fast::max(edge, contour)));
                        }
                    }
                }
            }
        }
    }
    referenceColor = float4(outc, src.w);
}

fragment refAM35_e474c2c7bde18_out refAM35_e474c2c7bde18(constant ReferenceUniformse474c2c7bde18& _69 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e474c2c7bde18_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _69, refInput, refInputSmplr, referenceColor);
    bool _372 = any(isnan(referenceColor));
    bool _379;
    if (!_372)
    {
        _379 = any(isinf(referenceColor));
    }
    else
    {
        _379 = _372;
    }
    if (_379)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _392 = referenceColor;
    float3 _398 = fast::clamp(_392.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _398.x;
    referenceColor.y = _398.y;
    referenceColor.z = _398.z;
    out.finalColor = referenceColor;
    return out;
}

