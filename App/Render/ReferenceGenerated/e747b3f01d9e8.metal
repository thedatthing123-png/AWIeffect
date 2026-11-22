// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/squeeze.xml
// Original source comments and attribution:
//float inside = step(0.,st.x) * step(st.x,1.) * step(0.,st.y) * step(st.y,1.);
//gl_FragColor = mix(vec4(xdiv,ydiv,0.5,1.0), texture2DCv(inputImg.texture,l2s(st)), 0.5);// * inside;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse747b3f01d9e8
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
};

struct refAM35_e747b3f01d9e8_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse747b3f01d9e8& _38)
{
    return (float4(v, 0.0, 1.0) * _38.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse747b3f01d9e8& _38, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 st = (gl_FragCoord.xy - _38.refLayer.xy) / _38.refLayer.zw;
    float str = _38.strength / 2.0;
    st -= float2(0.5);
    st *= 2.0;
    float xdiv = 1.0 + ((1.0 - powr(abs(st.y), 2.0)) * (-str));
    float ydiv = 1.0 + ((1.0 - powr(abs(st.x), 2.0)) * str);
    xdiv = fast::clamp(xdiv, 0.0, 2.0);
    ydiv = fast::clamp(ydiv, 0.0, 2.0);
    st.x /= xdiv;
    st.y /= ydiv;
    st /= float2(2.0);
    st += float2(0.5);
    float2 param = st;
    float2 param_1 = l2s(param, _38);
    referenceColor = texture2DCv(refInput, refInputSmplr, param_1);
}

fragment refAM35_e747b3f01d9e8_out refAM35_e747b3f01d9e8(constant ReferenceUniformse747b3f01d9e8& _38 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e747b3f01d9e8_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_38, gl_FragCoord, referenceColor, refInput, refInputSmplr);
    bool _133 = any(isnan(referenceColor));
    bool _140;
    if (!_133)
    {
        _140 = any(isinf(referenceColor));
    }
    else
    {
        _140 = _133;
    }
    if (_140)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _155 = referenceColor;
    float3 _161 = fast::clamp(_155.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _161.x;
    referenceColor.y = _161.y;
    referenceColor.z = _161.z;
    out.finalColor = referenceColor;
    return out;
}

