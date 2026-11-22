// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/transform.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec620fa828e95
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float scale;
    char _m6_pad[12];
    float angle;
    char _m7_pad[8];
    float2 offset;
    char _m8_pad[8];
    uint maskToLayer;
    char _m9_pad[12];
    float alpha;
    char _m10_pad[12];
    float fill;
    char _m11_pad[12];
    int ref_sample;
};

struct refAM35_ec620fa828e95_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rot2(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformsec620fa828e95& _68)
{
    return (float4(v, 0.0, 1.0) * _68.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 composite(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsec620fa828e95& _68, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st = (gl_FragCoord.xy - _68.refLayer.xy) / _68.refLayer.zw;
    st -= ((_68.offset / float2(500.0)) * float2(1.0, -1.0));
    st -= float2(0.5);
    st.x *= (_68.refLayer.z / _68.refLayer.w);
    float param = (-_68.angle) * 0.01745329983532428741455078125;
    st *= rot2(param);
    st /= float2(_68.scale);
    st.x /= (_68.refLayer.z / _68.refLayer.w);
    st += float2(0.5);
    float2 param_1 = st;
    float2 sampleCoord = l2s(param_1, _68);
    if (_68.ref_sample == 0)
    {
        sampleCoord *= _68.refScreen.xy;
        sampleCoord = floor(sampleCoord) + float2(0.5);
        sampleCoord /= _68.refScreen.xy;
    }
    float2 param_2 = sampleCoord;
    float4 scaledTexColor = texture2DCv(refInput, refInputSmplr, param_2);
    if (_68.maskToLayer != 0u)
    {
        float2 param_3 = gl_FragCoord.xy / _68.refScreen.xy;
        float4 baseColor = texture2DCv(refInput, refInputSmplr, param_3);
        float4 param_4 = baseColor * _68.fill;
        float4 param_5 = (scaledTexColor * baseColor.w) * _68.alpha;
        referenceColor = composite(param_4, param_5);
    }
    else
    {
        if (_68.fill > 9.9999997473787516355514526367188e-05)
        {
            float2 param_6 = gl_FragCoord.xy / _68.refScreen.xy;
            float4 baseColor_1 = texture2DCv(refInput, refInputSmplr, param_6);
            float4 param_7 = baseColor_1 * _68.fill;
            float4 param_8 = scaledTexColor * _68.alpha;
            referenceColor = composite(param_7, param_8);
        }
        else
        {
            referenceColor = scaledTexColor * _68.alpha;
        }
    }
}

fragment refAM35_ec620fa828e95_out refAM35_ec620fa828e95(constant ReferenceUniformsec620fa828e95& _68 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec620fa828e95_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_68, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _261 = any(isnan(referenceColor));
    bool _268;
    if (!_261)
    {
        _268 = any(isinf(referenceColor));
    }
    else
    {
        _268 = _261;
    }
    if (_268)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _282 = referenceColor;
    float3 _288 = fast::clamp(_282.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _288.x;
    referenceColor.y = _288.y;
    referenceColor.z = _288.z;
    out.finalColor = referenceColor;
    return out;
}

