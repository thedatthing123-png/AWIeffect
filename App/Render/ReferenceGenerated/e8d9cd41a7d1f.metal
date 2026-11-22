// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxgradientdisplace.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse8d9cd41a7d1f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float smoothing;
};

struct refAM35_e8d9cd41a7d1f_out
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
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse8d9cd41a7d1f& _40, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float2 st = gl_FragCoord.xy / _40.refScreen.xy;
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 fragSize = (float2(1.0) / getTexSize(param)) * (_40.smoothing * 24.0);
    float2 param_1 = float2((gl_FragCoord.xy / _40.refScreen.xy).x - fragSize.x, (gl_FragCoord.xy / _40.refScreen.xy).y);
    float4 leftColor = texture2DCv(refInput, refInputSmplr, param_1);
    float2 param_2 = float2((gl_FragCoord.xy / _40.refScreen.xy).x + fragSize.x, (gl_FragCoord.xy / _40.refScreen.xy).y);
    float4 rightColor = texture2DCv(refInput, refInputSmplr, param_2);
    float2 param_3 = float2((gl_FragCoord.xy / _40.refScreen.xy).x, (gl_FragCoord.xy / _40.refScreen.xy).y + fragSize.y);
    float4 topColor = texture2DCv(refInput, refInputSmplr, param_3);
    float2 param_4 = float2((gl_FragCoord.xy / _40.refScreen.xy).x, (gl_FragCoord.xy / _40.refScreen.xy).y - fragSize.y);
    float4 bottomColor = texture2DCv(refInput, refInputSmplr, param_4);
    float left = length(leftColor.xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float right = length(rightColor.xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float top = length(topColor.xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float bottom = length(bottomColor.xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 gradient = fast::normalize(float2((right - left) / (2.0 * fragSize.x), (top - bottom) / (2.0 * fragSize.y)));
    float alpha = 1.0;
    alpha = fast::min(alpha, leftColor.w);
    alpha = fast::min(alpha, rightColor.w);
    alpha = fast::min(alpha, topColor.w);
    alpha = fast::min(alpha, bottomColor.w);
    float2 param_5 = st + (gradient * _40.strength);
    referenceColor = texture2DCv(refReference, refReferenceSmplr, param_5) * alpha;
}

fragment refAM35_e8d9cd41a7d1f_out refAM35_e8d9cd41a7d1f(constant ReferenceUniformse8d9cd41a7d1f& _40 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8d9cd41a7d1f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _40, refInput, refInputSmplr, referenceColor, refReference, refReferenceSmplr);
    bool _238 = any(isnan(referenceColor));
    bool _245;
    if (!_238)
    {
        _245 = any(isinf(referenceColor));
    }
    else
    {
        _245 = _238;
    }
    if (_245)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _258 = referenceColor;
    float3 _264 = fast::clamp(_258.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _264.x;
    referenceColor.y = _264.y;
    referenceColor.z = _264.z;
    out.finalColor = referenceColor;
    return out;
}

