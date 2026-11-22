// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/boxblur2.xml
// Original source comments and attribution:
//int from = -max(1,int(strength));
//int to = max(1,int(strength));
//int step;
//if( strength < 0.5 ) {
//    step = 1
//} else {
//    step = max(1,int(log2(strength))-1);
//}
//vec4 outColor = vec4(0.0);
//if( acPass==0 ) {
//    for(int i=from; i<to; i += step ) {
//        outColor += texture2DCv(inputImg.texture,vec2(acScreenNorm.s + float(i)*(1.0/1280.0),acScreenNorm.t));
//    }
//} else {
//    for(int i=from; i<to; i += step ) {
//        outColor += texture2DCv(hblur.texture,vec2(acScreenNorm.s,acScreenNorm.t + float(i)*(1.0/720.0)));
//    }
//}
//gl_FragColor = outColor/(float(to)*2.0*float(step));
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse691abb4cb767
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float iter;
};

struct refAM35_e691abb4cb767_out
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
void referenceMain(constant ReferenceUniformse691abb4cb767& _35, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    if (as_type<int>(_35.refComposition.z) == 0)
    {
        float angle = 0.0;
        float actualStrength = (_35.strength / 4.0) / _35.iter;
        float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
        float2 texelSize = float2(1.0) / getTexSize(param);
        float rad = angle * 0.01745329983532428741455078125;
        float2 velocity = float2(cos(rad) * actualStrength, (-sin(rad)) * actualStrength);
        float speed = length(velocity / texelSize);
        int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
        float2 param_1 = gl_FragCoord.xy / _35.refScreen.xy;
        float4 outColor = texture2DCv(refInput, refInputSmplr, param_1);
        for (int i = 1; i < nSamples; i++)
        {
            float2 offset = velocity * ((float(i) / float(nSamples - 1)) - 0.5);
            float2 param_2 = (gl_FragCoord.xy / _35.refScreen.xy) - offset;
            outColor += texture2DCv(refInput, refInputSmplr, param_2);
        }
        referenceColor = outColor / float4(float(nSamples));
    }
    else
    {
        float angle_1 = 90.0;
        float actualStrength_1 = (_35.strength / 4.0) / _35.iter;
        float2 param_3 = float2(int2(refInput.get_width(), refInput.get_height()));
        float2 texelSize_1 = float2(1.0) / getTexSize(param_3);
        float rad_1 = angle_1 * 0.01745329983532428741455078125;
        float2 velocity_1 = float2(cos(rad_1) * actualStrength_1, (-sin(rad_1)) * actualStrength_1);
        float speed_1 = length(velocity_1 / texelSize_1);
        int nSamples_1 = int(fast::clamp(speed_1, 1.0099999904632568359375, 100.01000213623046875));
        float2 param_4 = gl_FragCoord.xy / _35.refScreen.xy;
        float4 outColor_1 = texture2DCv(refBuffer1, refBuffer1Smplr, param_4);
        for (int i_1 = 1; i_1 < nSamples_1; i_1++)
        {
            float2 offset_1 = velocity_1 * ((float(i_1) / float(nSamples_1 - 1)) - 0.5);
            float2 param_5 = (gl_FragCoord.xy / _35.refScreen.xy) - offset_1;
            outColor_1 += texture2DCv(refBuffer1, refBuffer1Smplr, param_5);
        }
        referenceColor = outColor_1 / float4(float(nSamples_1));
    }
}

fragment refAM35_e691abb4cb767_out refAM35_e691abb4cb767(constant ReferenceUniformse691abb4cb767& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e691abb4cb767_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_35, refInput, refInputSmplr, gl_FragCoord, referenceColor, refBuffer1, refBuffer1Smplr);
    bool _251 = any(isnan(referenceColor));
    bool _258;
    if (!_251)
    {
        _258 = any(isinf(referenceColor));
    }
    else
    {
        _258 = _251;
    }
    if (_258)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _273 = referenceColor;
    float3 _279 = fast::clamp(_273.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _279.x;
    referenceColor.y = _279.y;
    referenceColor.z = _279.z;
    out.finalColor = referenceColor;
    return out;
}

