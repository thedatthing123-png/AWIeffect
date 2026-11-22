// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxoldsharpen.xml
// Original source comments and attribution:
//gl_FragColor = manColor + whiteColour;
//Screen Blend Mode
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse16da2c411f51
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float brig;
    char _m7_pad[12];
    float iter;
    char _m8_pad[12];
    uint whiteonly;
    char _m9_pad[12];
    uint bluredonly;
};

struct refAM35_e16da2c411f51_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse16da2c411f51& _36, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr, texture2d<float> refBuffer3, sampler refBuffer3Smplr)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    if (_36.strength <= 0.004999999888241291046142578125)
    {
        float2 param_1 = gl_FragCoord.xy / _36.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param_1);
    }
    else
    {
        if (as_type<int>(_36.refComposition.z) == 0)
        {
            float2 param_2 = gl_FragCoord.xy / _36.refScreen.xy;
            referenceColor = texture2DCv(refInput, refInputSmplr, param_2);
        }
        else
        {
            if (as_type<int>(_36.refComposition.z) == 1)
            {
                float2 param_3 = gl_FragCoord.xy / _36.refScreen.xy;
                referenceColor = texture2DCv(refBuffer1, refBuffer1Smplr, param_3);
            }
            else
            {
                if (as_type<int>(_36.refComposition.z) == 2)
                {
                    float angle = 0.0;
                    float actualStrength = (_36.strength / 4.0) / _36.iter;
                    float2 texelSize = float2(1.0) / fast::max(floor(float2(_36.refComposition.w, _36.refScreen.w) / float2(2.0)), float2(1.0));
                    float rad = angle * 0.01745329983532428741455078125;
                    float2 velocity = float2(cos(rad) * actualStrength, (-sin(rad)) * actualStrength);
                    float speed = length(velocity / texelSize);
                    int nSamples = int(fast::clamp(speed, 2.0099999904632568359375, 100.01000213623046875));
                    float2 param_4 = gl_FragCoord.xy / _36.refScreen.xy;
                    float4 outColor = texture2DCv(refBuffer2, refBuffer2Smplr, param_4);
                    for (int i = 1; i < nSamples; i++)
                    {
                        float2 offset = velocity * (float(i) / float(nSamples - 1));
                        float2 param_5 = (gl_FragCoord.xy / _36.refScreen.xy) + offset;
                        outColor += texture2DCv(refBuffer2, refBuffer2Smplr, param_5);
                        float2 param_6 = (gl_FragCoord.xy / _36.refScreen.xy) - offset;
                        outColor += texture2DCv(refBuffer2, refBuffer2Smplr, param_6);
                    }
                    float4 result = outColor / float4(float((nSamples * 2) - 1));
                    referenceColor = result;
                }
                else
                {
                    float angle_1 = 90.0;
                    float actualStrength_1 = (_36.strength / 4.0) / _36.iter;
                    float2 texelSize_1 = float2(1.0) / fast::max(floor(float2(_36.refComposition.w, _36.refScreen.w) / float2(2.0)), float2(1.0));
                    float rad_1 = angle_1 * 0.01745329983532428741455078125;
                    float2 velocity_1 = float2(cos(rad_1) * actualStrength_1, (-sin(rad_1)) * actualStrength_1);
                    float speed_1 = length(velocity_1 / texelSize_1);
                    int nSamples_1 = int(fast::clamp(speed_1, 2.0099999904632568359375, 100.01000213623046875));
                    float2 param_7 = gl_FragCoord.xy / _36.refScreen.xy;
                    float4 outColor_1 = texture2DCv(refBuffer3, refBuffer3Smplr, param_7);
                    float2 param_8 = gl_FragCoord.xy / _36.refScreen.xy;
                    float4 manColor = texture2DCv(refInput, refInputSmplr, param_8);
                    for (int i_1 = 1; i_1 < nSamples_1; i_1++)
                    {
                        float2 offset_1 = velocity_1 * (float(i_1) / float(nSamples_1 - 1));
                        float2 param_9 = (gl_FragCoord.xy / _36.refScreen.xy) + offset_1;
                        outColor_1 += texture2DCv(refBuffer3, refBuffer3Smplr, param_9);
                        float2 param_10 = (gl_FragCoord.xy / _36.refScreen.xy) - offset_1;
                        outColor_1 += texture2DCv(refBuffer3, refBuffer3Smplr, param_10);
                    }
                    float4 result_1 = outColor_1 / float4(float((nSamples_1 * 2) - 1));
                    float4 blured = (manColor - result_1) * _36.brig;
                    float red = blured.x;
                    float green = blured.y;
                    float blue = blured.y;
                    float _all = ((red + green) + blue) / 3.0;
                    float4 whiteColour = float4(0.0);
                    if (_36.whiteonly != 0u)
                    {
                        whiteColour = float4(_all, _all, _all, 1.0) * texColor.w;
                    }
                    else
                    {
                        whiteColour = blured;
                    }
                    if (_36.bluredonly != 0u)
                    {
                        referenceColor = whiteColour;
                    }
                    else
                    {
                        referenceColor = float4(1.0) - ((float4(1.0) - manColor) * (float4(1.0) - whiteColour));
                    }
                }
            }
        }
    }
}

fragment refAM35_e16da2c411f51_out refAM35_e16da2c411f51(constant ReferenceUniformse16da2c411f51& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refBuffer2 [[texture(2)]], texture2d<float> refBuffer3 [[texture(3)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refBuffer2Smplr [[sampler(2)]], sampler refBuffer3Smplr [[sampler(3)]], float4 gl_FragCoord [[position]])
{
    refAM35_e16da2c411f51_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr, refBuffer3, refBuffer3Smplr);
    bool _404 = any(isnan(referenceColor));
    bool _411;
    if (!_404)
    {
        _411 = any(isinf(referenceColor));
    }
    else
    {
        _411 = _404;
    }
    if (_411)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _425 = referenceColor;
    float3 _431 = fast::clamp(_425.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _431.x;
    referenceColor.y = _431.y;
    referenceColor.z = _431.z;
    out.finalColor = referenceColor;
    return out;
}

