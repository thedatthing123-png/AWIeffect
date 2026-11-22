// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/volumetric-clouds.xml
// Original source comments and attribution:
//p.y *= 1.;
//vec4 c = lightColor;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse5af76da00575
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 camera;
    float densityParam;
    char _m7_pad[12];
    float seed;
    float4 shadowColor;
    float4 lightColor;
    float fill;
};

struct refAM35_e5af76da00575_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float _noise(thread const float3& x, texture2d<float> refImage1, sampler refImage1Smplr)
{
    float3 p = floor(x);
    float3 f = fract(x);
    f = (f * f) * (float3(3.0) - (f * 2.0));
    float2 uv = (p.xy + (float2(37.0, 17.0) * p.z)) + f.xy;
    uv = (uv + float2(0.5)) / float2(256.0);
    float2 rg = refImage1.sample(refImage1Smplr, uv).yx;
    return mix(rg.x, rg.y, f.z);
}

static inline __attribute__((always_inline))
float fbm(thread const float3& p, texture2d<float> refImage1, sampler refImage1Smplr)
{
    float3 param = p;
    float3 param_1 = p * 2.0;
    float3 param_2 = p * 4.0;
    float3 param_3 = p * 8.0;
    return (((_noise(param, refImage1, refImage1Smplr) / 2.0) + (_noise(param_1, refImage1, refImage1Smplr) / 4.0)) + (_noise(param_2, refImage1, refImage1Smplr) / 8.0)) + (_noise(param_3, refImage1, refImage1Smplr) / 16.0);
}

static inline __attribute__((always_inline))
float calcDensity(thread const float3& p, texture2d<float> refImage1, sampler refImage1Smplr, constant ReferenceUniformse5af76da00575& _145)
{
    float3 param = p;
    float density = fast::max(0.0, fbm(param, refImage1, refImage1Smplr) - _145.densityParam);
    return density;
}

static inline __attribute__((always_inline))
float4 comp(thread const float4& bg, thread const float4& fg)
{
    return (bg * (1.0 - fg.w)) + fg;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refImage1, sampler refImage1Smplr, constant ReferenceUniformse5af76da00575& _145, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _145.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _145.refLayer.xy) / _145.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_145.refLayer.z / _145.refLayer.w);
    float3 ro = _145.camera / float3(100.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 dd = (rd / float3(50.0)) * 6.0;
    float4 color = float4(0.0);
    float3 light = float3(20.0, 120.0, -200.5);
    float radius = 1.4639999866485595703125;
    for (int i = 0; i < 50; i++)
    {
        float3 p = ro + (dd * float(i));
        float3 lightDir = fast::normalize(light - p);
        float t = 1.0 - (float(i) / 50.0);
        float3 param_1 = p;
        float density = calcDensity(param_1, refImage1, refImage1Smplr, _145);
        float3 param_2 = p + (lightDir * dd);
        float lightGrad = density - calcDensity(param_2, refImage1, refImage1Smplr, _145);
        float4 c = mix(_145.lightColor, _145.shadowColor, float4((lightGrad * 6.0) - _145.densityParam));
        density *= smoothstep(0.20000000298023223876953125, 0.5, t);
        float4 param_3 = c * density;
        float4 param_4 = color;
        color = comp(param_3, param_4);
    }
    float4 param_5 = texColor * _145.fill;
    float4 param_6 = color * texColor.w;
    referenceColor = comp(param_5, param_6);
}

fragment refAM35_e5af76da00575_out refAM35_e5af76da00575(constant ReferenceUniformse5af76da00575& _145 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e5af76da00575_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refImage1, refImage1Smplr, _145, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _312 = any(isnan(referenceColor));
    bool _319;
    if (!_312)
    {
        _319 = any(isinf(referenceColor));
    }
    else
    {
        _319 = _312;
    }
    if (_319)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _332 = referenceColor;
    float3 _338 = fast::clamp(_332.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _338.x;
    referenceColor.y = _338.y;
    referenceColor.z = _338.z;
    out.finalColor = referenceColor;
    return out;
}

