// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/boxblur3.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsed78228da4249
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
};

struct refAM35_ed78228da4249_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsed78228da4249& _35, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr)
{
    if (_35.strength <= 9.9999997473787516355514526367188e-05)
    {
        float2 param = gl_FragCoord.xy / _35.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_35.refComposition.z) == 0)
        {
            float2 param_1 = gl_FragCoord.xy / _35.refScreen.xy;
            referenceColor = texture2DCv(refInput, refInputSmplr, param_1);
        }
        else
        {
            if (as_type<int>(_35.refComposition.z) == 1)
            {
                float actualStrength = _35.strength / 10.0;
                float2 param_2 = fast::max(floor(float2(_35.refComposition.w, _35.refScreen.w) / float2(2.0)), float2(1.0));
                float2 texelSize = float2(1.0) / getTexSize(param_2);
                float2 velocity = float2(actualStrength, 0.0);
                float speed = length(velocity / texelSize);
                int nSamples = int(fast::clamp(speed, 2.0099999904632568359375, 150.0099945068359375));
                float2 param_3 = gl_FragCoord.xy / _35.refScreen.xy;
                float4 outColor = texture2DCv(refBuffer1, refBuffer1Smplr, param_3);
                for (int i = 1; i < nSamples; i++)
                {
                    float2 offset = velocity * (float(i) / float(nSamples - 1));
                    float2 param_4 = (gl_FragCoord.xy / _35.refScreen.xy) + offset;
                    outColor += texture2DCv(refBuffer1, refBuffer1Smplr, param_4);
                    float2 param_5 = (gl_FragCoord.xy / _35.refScreen.xy) - offset;
                    outColor += texture2DCv(refBuffer1, refBuffer1Smplr, param_5);
                }
                float4 result = outColor / float4(float((nSamples * 2) - 1));
                referenceColor = result;
            }
            else
            {
                float actualStrength_1 = _35.strength / 10.0;
                float2 param_6 = fast::max(floor(float2(_35.refComposition.w, _35.refScreen.w) / float2(2.0)), float2(1.0));
                float2 texelSize_1 = float2(1.0) / getTexSize(param_6);
                float2 velocity_1 = float2(0.0, actualStrength_1);
                float speed_1 = length(velocity_1 / texelSize_1);
                int nSamples_1 = int(fast::clamp(speed_1, 2.0099999904632568359375, 150.0099945068359375));
                float2 param_7 = gl_FragCoord.xy / _35.refScreen.xy;
                float4 outColor_1 = texture2DCv(refBuffer2, refBuffer2Smplr, param_7);
                for (int i_1 = 1; i_1 < nSamples_1; i_1++)
                {
                    float2 offset_1 = velocity_1 * (float(i_1) / float(nSamples_1 - 1));
                    float2 param_8 = (gl_FragCoord.xy / _35.refScreen.xy) + offset_1;
                    outColor_1 += texture2DCv(refBuffer2, refBuffer2Smplr, param_8);
                    float2 param_9 = (gl_FragCoord.xy / _35.refScreen.xy) - offset_1;
                    outColor_1 += texture2DCv(refBuffer2, refBuffer2Smplr, param_9);
                }
                float4 result_1 = outColor_1 / float4(float((nSamples_1 * 2) - 1));
                referenceColor = result_1;
            }
        }
    }
}

fragment refAM35_ed78228da4249_out refAM35_ed78228da4249(constant ReferenceUniformsed78228da4249& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refBuffer2 [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refBuffer2Smplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed78228da4249_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_35, referenceColor, refInput, refInputSmplr, gl_FragCoord, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr);
    bool _290 = any(isnan(referenceColor));
    bool _297;
    if (!_290)
    {
        _297 = any(isinf(referenceColor));
    }
    else
    {
        _297 = _290;
    }
    if (_297)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _311 = referenceColor;
    float3 _317 = fast::clamp(_311.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _317.x;
    referenceColor.y = _317.y;
    referenceColor.z = _317.z;
    out.finalColor = referenceColor;
    return out;
}

