// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/glowscan.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse0136f093b8d4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float threshold;
    char _m6_pad[12];
    float radius;
    char _m7_pad[12];
    float power;
    char _m8_pad[12];
    float strength;
    float4 fillColor;
    float blend;
    char _m11_pad[12];
    float fill;
    char _m12_pad[12];
    float alpha;
};

struct refAM35_e0136f093b8d4_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse0136f093b8d4& _28, texture2d<float> refBuffer1, sampler refBuffer1Smplr, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    if (as_type<int>(_28.refComposition.z) == 0)
    {
        discard_fragment();
    }
    else
    {
        float2 param = gl_FragCoord.xy / _28.refScreen.xy;
        float4 baseColor = texture2DCv(refBuffer1, refBuffer1Smplr, param);
        float2 param_1 = gl_FragCoord.xy / _28.refScreen.xy;
        float4 mainColor = texture2DCv(refInput, refInputSmplr, param_1) * _28.fill;
        float luma = dot(baseColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        float adjThreshold = (_28.threshold * (1.0 + _28.radius)) - _28.radius;
        bool _97 = luma >= adjThreshold;
        bool _106;
        if (_97)
        {
            _106 = luma <= (adjThreshold + _28.radius);
        }
        else
        {
            _106 = _97;
        }
        if (_106)
        {
            float halfRadius = _28.radius * 0.5;
            float linearPos = abs(((luma - adjThreshold) - halfRadius) / halfRadius);
            float4 glow = powr(mix(baseColor, _28.fillColor * luma, float4(_28.blend * 0.9900000095367431640625)), float4(_28.power) * powr(linearPos, 2.0));
            mainColor = mix(mainColor, baseColor + glow, float4(_28.alpha));
        }
        referenceColor = mainColor;
    }
}

fragment refAM35_e0136f093b8d4_out refAM35_e0136f093b8d4(constant ReferenceUniformse0136f093b8d4& _28 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e0136f093b8d4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_28, refBuffer1, refBuffer1Smplr, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _164 = any(isnan(referenceColor));
    bool _171;
    if (!_164)
    {
        _171 = any(isinf(referenceColor));
    }
    else
    {
        _171 = _164;
    }
    if (_171)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _185 = referenceColor;
    float3 _191 = fast::clamp(_185.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _191.x;
    referenceColor.y = _191.y;
    referenceColor.z = _191.z;
    out.finalColor = referenceColor;
    return out;
}

