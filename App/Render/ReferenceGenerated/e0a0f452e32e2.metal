// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/aemotion_native_maskBlur.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse0a0f452e32e2
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

struct refAM35_e0a0f452e32e2_out
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
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse0a0f452e32e2& _54, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _54.refScreen.xy;
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 px = float2(1.0) / fast::max(getTexSize(param), float2(1.0));
    float a = 0.95504415035247802734375;
    float2 d = (float2(cos(a), sin(a)) * px) * fast::max(1.0, _54.radius * 0.319999992847442626953125);
    float2 param_1 = uv;
    float4 c0 = texture2DCv(refInput, refInputSmplr, param_1);
    float4 sum = c0 * 0.2199999988079071044921875;
    float2 param_2 = uv + d;
    float2 param_3 = uv - d;
    sum += ((texture2DCv(refInput, refInputSmplr, param_2) + texture2DCv(refInput, refInputSmplr, param_3)) * 0.1599999964237213134765625);
    float2 param_4 = uv + (d * 2.0);
    float2 param_5 = uv - (d * 2.0);
    sum += ((texture2DCv(refInput, refInputSmplr, param_4) + texture2DCv(refInput, refInputSmplr, param_5)) * 0.100000001490116119384765625);
    float2 param_6 = uv + float2(-d.y, d.x);
    float2 param_7 = uv - float2(-d.y, d.x);
    sum += ((texture2DCv(refInput, refInputSmplr, param_6) + texture2DCv(refInput, refInputSmplr, param_7)) * 0.07999999821186065673828125);
    float2 param_8 = uv + (float2(-d.y, d.x) * 2.0);
    float2 param_9 = uv - (float2(-d.y, d.x) * 2.0);
    sum += ((texture2DCv(refInput, refInputSmplr, param_8) + texture2DCv(refInput, refInputSmplr, param_9)) * 0.0500000007450580596923828125);
    float4 outc = sum;
    if (false)
    {
        outc = mix(sum, c0, float4((1.0 - _54.amount) * 0.3499999940395355224609375));
    }
    else
    {
        if (false)
        {
            float2 param_10 = uv + d;
            float2 param_11 = uv - d;
            float4 hi = fast::max(fast::max(texture2DCv(refInput, refInputSmplr, param_10), texture2DCv(refInput, refInputSmplr, param_11)), c0);
            float2 param_12 = uv + d;
            float2 param_13 = uv - d;
            float4 lo = fast::min(fast::min(texture2DCv(refInput, refInputSmplr, param_12), texture2DCv(refInput, refInputSmplr, param_13)), c0);
            outc = mix(lo, hi, float4(_54.amount));
        }
        else
        {
            if (true)
            {
                float3 param_14 = sum.xyz;
                float b = smoothstep(0.449999988079071044921875, 1.0, aeLum(param_14));
                outc = mix(sum, float4(sum.xyz + ((_54.colorA.xyz * b) * 0.449999988079071044921875), sum.w), float4(_54.amount));
            }
            else
            {
                if (false)
                {
                    float3 param_15 = sum.xyz;
                    float b_1 = smoothstep(0.550000011920928955078125, 1.0, aeLum(param_15));
                    outc = float4(sum.xyz + ((_54.colorA.xyz * b_1) * 0.60000002384185791015625), sum.w);
                }
                else
                {
                    if (false)
                    {
                        float2 param_16 = uv + (d * 1.60000002384185791015625);
                        float4 r = texture2DCv(refInput, refInputSmplr, param_16);
                        float2 param_17 = uv - (d * 1.60000002384185791015625);
                        float4 b_2 = texture2DCv(refInput, refInputSmplr, param_17);
                        outc = float4(r.x, sum.y, b_2.z, c0.w);
                    }
                }
            }
        }
    }
    referenceColor = mix(c0, outc, float4(fast::clamp(_54.amount, 0.0, 1.0)));
    referenceColor.w = c0.w;
}

fragment refAM35_e0a0f452e32e2_out refAM35_e0a0f452e32e2(constant ReferenceUniformse0a0f452e32e2& _54 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e0a0f452e32e2_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _54, refInput, refInputSmplr, referenceColor);
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
    float4 _370 = referenceColor;
    float3 _376 = fast::clamp(_370.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _376.x;
    referenceColor.y = _376.y;
    referenceColor.z = _376.z;
    out.finalColor = referenceColor;
    return out;
}

