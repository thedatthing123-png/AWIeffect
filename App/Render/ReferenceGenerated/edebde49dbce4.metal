// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxboxblurplus.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsedebde49dbce4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint mode;
    char _m6_pad[12];
    float strength;
    char _m7_pad[12];
    float fill;
};

struct refAM35_edebde49dbce4_out
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
void referenceMain(constant ReferenceUniformsedebde49dbce4& _36, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr)
{
    if (_36.strength <= 9.9999997473787516355514526367188e-05)
    {
        float2 param = gl_FragCoord.xy / _36.refScreen.xy;
        float4 texColor = texture2DCv(refInput, refInputSmplr, param);
        float2 param_1 = gl_FragCoord.xy / _36.refScreen.xy;
        float4 lift = mix(texture2DCv(refReference, refReferenceSmplr, param_1) * texColor.w, texColor, float4(_36.fill));
        float4 _91;
        if (_36.mode != 0u)
        {
            _91 = lift;
        }
        else
        {
            float2 param_2 = gl_FragCoord.xy / _36.refScreen.xy;
            _91 = texture2DCv(refInput, refInputSmplr, param_2);
        }
        referenceColor = _91;
    }
    else
    {
        if (as_type<int>(_36.refComposition.z) == 0)
        {
            float2 param_3 = gl_FragCoord.xy / _36.refScreen.xy;
            float4 texColor_1 = texture2DCv(refInput, refInputSmplr, param_3);
            float2 param_4 = gl_FragCoord.xy / _36.refScreen.xy;
            float4 lift_1 = mix(texture2DCv(refReference, refReferenceSmplr, param_4) * texColor_1.w, texColor_1, float4(_36.fill));
            float4 _143;
            if (_36.mode != 0u)
            {
                _143 = lift_1;
            }
            else
            {
                float2 param_5 = gl_FragCoord.xy / _36.refScreen.xy;
                _143 = texture2DCv(refInput, refInputSmplr, param_5);
            }
            referenceColor = _143;
        }
        else
        {
            if (as_type<int>(_36.refComposition.z) == 1)
            {
                float actualStrength = _36.strength / 10.0;
                float2 param_6 = fast::max(floor(float2(_36.refComposition.w, _36.refScreen.w) / float2(2.0)), float2(1.0));
                float2 texelSize = float2(1.0) / getTexSize(param_6);
                float2 velocity = float2(actualStrength, 0.0);
                float speed = length(velocity / texelSize);
                int nSamples = int(fast::clamp(speed, 2.0099999904632568359375, 150.0099945068359375));
                float2 param_7 = gl_FragCoord.xy / _36.refScreen.xy;
                float4 outColor = texture2DCv(refBuffer1, refBuffer1Smplr, param_7);
                for (int i = 1; i < nSamples; i++)
                {
                    float2 offset = velocity * (float(i) / float(nSamples - 1));
                    float2 param_8 = (gl_FragCoord.xy / _36.refScreen.xy) + offset;
                    outColor += texture2DCv(refBuffer1, refBuffer1Smplr, param_8);
                    float2 param_9 = (gl_FragCoord.xy / _36.refScreen.xy) - offset;
                    outColor += texture2DCv(refBuffer1, refBuffer1Smplr, param_9);
                }
                float4 result = outColor / float4(float((nSamples * 2) - 1));
                referenceColor = result;
            }
            else
            {
                float actualStrength_1 = _36.strength / 10.0;
                float2 param_10 = fast::max(floor(float2(_36.refComposition.w, _36.refScreen.w) / float2(2.0)), float2(1.0));
                float2 texelSize_1 = float2(1.0) / getTexSize(param_10);
                float2 velocity_1 = float2(0.0, actualStrength_1);
                float speed_1 = length(velocity_1 / texelSize_1);
                int nSamples_1 = int(fast::clamp(speed_1, 2.0099999904632568359375, 150.0099945068359375));
                float2 param_11 = gl_FragCoord.xy / _36.refScreen.xy;
                float4 outColor_1 = texture2DCv(refBuffer2, refBuffer2Smplr, param_11);
                for (int i_1 = 1; i_1 < nSamples_1; i_1++)
                {
                    float2 offset_1 = velocity_1 * (float(i_1) / float(nSamples_1 - 1));
                    float2 param_12 = (gl_FragCoord.xy / _36.refScreen.xy) + offset_1;
                    outColor_1 += texture2DCv(refBuffer2, refBuffer2Smplr, param_12);
                    float2 param_13 = (gl_FragCoord.xy / _36.refScreen.xy) - offset_1;
                    outColor_1 += texture2DCv(refBuffer2, refBuffer2Smplr, param_13);
                }
                float4 result_1 = outColor_1 / float4(float((nSamples_1 * 2) - 1));
                referenceColor = result_1;
            }
        }
    }
}

fragment refAM35_edebde49dbce4_out refAM35_edebde49dbce4(constant ReferenceUniformsedebde49dbce4& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refBuffer2 [[texture(2)]], texture2d<float> refReference [[texture(3)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refBuffer2Smplr [[sampler(2)]], sampler refReferenceSmplr [[sampler(3)]], float4 gl_FragCoord [[position]])
{
    refAM35_edebde49dbce4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_36, refInput, refInputSmplr, gl_FragCoord, refReference, refReferenceSmplr, referenceColor, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr);
    bool _365 = any(isnan(referenceColor));
    bool _372;
    if (!_365)
    {
        _372 = any(isinf(referenceColor));
    }
    else
    {
        _372 = _365;
    }
    if (_372)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _386 = referenceColor;
    float3 _392 = fast::clamp(_386.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _392.x;
    referenceColor.y = _392.y;
    referenceColor.z = _392.z;
    out.finalColor = referenceColor;
    return out;
}

