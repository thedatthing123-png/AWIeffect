// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/offset.xml
// Original source comments and attribution:
//vec2 pixel = vec2(1.,1.)/getTexSize(inputImg.size);
//vec2 layerPixel = vec2(1.,1.)/acLayerSize;
//sampleCoord += pixel/2.;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformse6c55023d327b
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 offset;
    char _m6_pad[8];
    float feather;
    char _m7_pad[12];
    uint mask;
};

struct refAM35_e6c55023d327b_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse6c55023d327b& _34, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 sampleCoord = mod(((gl_FragCoord.xy - _34.refLayer.xy) / _34.refLayer.zw) + ((_34.offset * float2(-1.0, 1.0)) / float2(1000.0)), float2(1.0));
    float2 featherDist = ((float2(0.5) - abs(mod(_34.offset / float2(1000.0), float2(1.0)) - float2(0.5))) * 2.0) * _34.feather;
    float2 _86;
    if (_34.feather < 9.9999997473787516355514526367188e-05)
    {
        _86 = float2(1.0);
    }
    else
    {
        _86 = smoothstep(float2(0.0), featherDist, fast::min(sampleCoord, float2(1.0) - sampleCoord));
    }
    float2 featherAmount = _86;
    sampleCoord = (float4(sampleCoord, 0.0, 1.0) * _34.refLayerToScreen).xy;
    float2 param = gl_FragCoord.xy / _34.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float maskFactor;
    if (_34.mask != 0u)
    {
        maskFactor = texColor.w;
    }
    else
    {
        float2 s = step(float2(0.0), (gl_FragCoord.xy - _34.refLayer.xy) / _34.refLayer.zw) - step(float2(1.0), (gl_FragCoord.xy - _34.refLayer.xy) / _34.refLayer.zw);
        maskFactor = s.x * s.y;
    }
    float4 overColor = texColor * (1.0 - (featherAmount.x * featherAmount.y));
    float2 param_1 = sampleCoord;
    referenceColor = overColor + ((texture2DCv(refInput, refInputSmplr, param_1) * maskFactor) * (1.0 - overColor.w));
}

fragment refAM35_e6c55023d327b_out refAM35_e6c55023d327b(constant ReferenceUniformse6c55023d327b& _34 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e6c55023d327b_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _34, refInput, refInputSmplr, referenceColor);
    bool _193 = any(isnan(referenceColor));
    bool _200;
    if (!_193)
    {
        _200 = any(isinf(referenceColor));
    }
    else
    {
        _200 = _193;
    }
    if (_200)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _214 = referenceColor;
    float3 _220 = fast::clamp(_214.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _220.x;
    referenceColor.y = _220.y;
    referenceColor.z = _220.z;
    out.finalColor = referenceColor;
    return out;
}

