// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/Bioscanner_1.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9052edfe9633
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strandCount;
    char _m6_pad[12];
    float waveAmplitude;
    char _m7_pad[12];
    float waveFrequency;
    char _m8_pad[12];
    float waveSpeed;
    char _m9_pad[12];
    float lineThickness;
    char _m10_pad[12];
    float glowAmount;
    char _m11_pad[12];
    float intensity;
};

struct refAM35_e9052edfe9633_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse9052edfe9633& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _33.refLayer.xy) / _33.refLayer.zw;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float glow = 0.0;
    for (int i = 0; i < 16; i++)
    {
        float ref_active = 1.0 - step(_33.strandCount, float(i));
        float fi = float(i);
        float y = (fi + 0.5) / fast::max(_33.strandCount, 1.0);
        float line = y + ((sin((((uv.x * _33.waveFrequency) * 6.28299999237060546875) + (_33.refScreen.z * _33.waveSpeed)) + fi) * _33.waveAmplitude) * 0.119999997317790985107421875);
        float d = abs(uv.y - line);
        glow += (exp(((-d) * d) / fast::max((_33.lineThickness * _33.lineThickness) * 12.0, 9.9999999747524270787835121154785e-07)) * ref_active);
    }
    float3 scan = ((float3(0.119999997317790985107421875, 1.0, 0.64999997615814208984375) * glow) * _33.glowAmount) * _33.intensity;
    referenceColor = float4(src.xyz + scan, fast::max(src.w, fast::clamp(glow, 0.0, 1.0)));
}

fragment refAM35_e9052edfe9633_out refAM35_e9052edfe9633(constant ReferenceUniformse9052edfe9633& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9052edfe9633_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
    bool _182 = any(isnan(referenceColor));
    bool _189;
    if (!_182)
    {
        _189 = any(isinf(referenceColor));
    }
    else
    {
        _189 = _182;
    }
    if (_189)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _202 = referenceColor;
    float3 _208 = fast::clamp(_202.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _208.x;
    referenceColor.y = _208.y;
    referenceColor.z = _208.z;
    out.finalColor = referenceColor;
    return out;
}

