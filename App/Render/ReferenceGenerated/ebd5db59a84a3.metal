// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/rgb-mixer.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsebd5db59a84a3
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 rmix;
    float4 gmix;
    float4 bmix;
    float gamma;
    char _m9_pad[12];
    float offset;
};

struct refAM35_ebd5db59a84a3_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 saturate0(thread const float3& v)
{
    return fast::clamp(v, float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsebd5db59a84a3& _49, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _49.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = texColor.xyz / float3(fast::max(texColor.w, 9.9999997473787516355514526367188e-06));
    float4 result = ((_49.rmix * rgb.x) + (_49.gmix * rgb.y)) + (_49.bmix * rgb.z);
    float4 _95 = result;
    float3 _103 = powr(_95.xyz, float3(1.0 / _49.gamma));
    result.x = _103.x;
    result.y = _103.y;
    result.z = _103.z;
    float4 _113 = result;
    float3 _116 = _113.xyz + float3(_49.offset);
    result.x = _116.x;
    result.y = _116.y;
    result.z = _116.z;
    float3 param_1 = result.xyz;
    referenceColor = float4(saturate0(param_1), 1.0) * texColor.w;
}

fragment refAM35_ebd5db59a84a3_out refAM35_ebd5db59a84a3(constant ReferenceUniformsebd5db59a84a3& _49 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ebd5db59a84a3_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _49, referenceColor);
    bool _142 = any(isnan(referenceColor));
    bool _149;
    if (!_142)
    {
        _149 = any(isinf(referenceColor));
    }
    else
    {
        _149 = _142;
    }
    if (_149)
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

