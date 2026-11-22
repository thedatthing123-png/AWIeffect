// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxpaperburn.xml
// Original source comments and attribution:
/////////////////////////
// vec4 glow = texture2DCv(edge.texture, acScreenNorm);
/////////////////////////
// burn
//float noiseBurn = noise(uv + noise(uv * 2. +  fbm(uv * 40.)));
//noiseBurn *= noiseControl;
// gl_FragColor = mix(resultfinal,chromakey,1.0) * texColor.a;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsee491c4fae043
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color;
    float progressa;
    char _m7_pad[12];
    float feather;
    char _m8_pad[12];
    float alpha;
};

struct refAM35_ee491c4fae043_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float Hash(thread const float2& p)
{
    float3 p2 = float3(p, 1.0);
    return fract(sin(dot(p2, float3(37.09999847412109375, 61.700000762939453125, 12.3999996185302734375))) * 3758.54541015625);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f *= (f * (float2(3.0) - (f * 2.0)));
    float2 param = i + float2(0.0);
    float2 param_1 = i + float2(1.0, 0.0);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 param_3 = i + float2(1.0);
    return mix(mix(Hash(param), Hash(param_1), f.x), mix(Hash(param_2), Hash(param_3), f.x), f.y);
}

static inline __attribute__((always_inline))
float fbm(thread const float2& p)
{
    float v = 0.0;
    float2 param = p * 1.0;
    v += (_noise(param) * 0.5);
    float2 param_1 = p * 2.0;
    v += (_noise(param_1) * 0.25);
    float2 param_2 = p * 4.0;
    v += (_noise(param_2) * 0.125);
    float2 param_3 = p * 8.0;
    v += (_noise(param_3) * 0.0625);
    float2 param_4 = p * 16.0;
    v += (_noise(param_4) * 0.03125);
    return v;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsee491c4fae043& _164, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _164.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 uv = gl_FragCoord.xy / _164.refScreen.xy;
    float2 uvDisplace = uv;
    bool apply = true;
    float factor = 1.0 - (0.14000000059604644775390625 + _164.progressa);
    if (!apply)
    {
        factor = 0.0;
    }
    float factorInv = 1.0 - factor;
    float2 p = uv * 10.0;
    float2 param_1 = (uv * 3.0) + float2(2.5);
    float noiseControl = _noise(param_1) * 1.2999999523162841796875;
    float2 param_2 = uv * 15.0;
    float noiseBurn = fbm(param_2);
    float burn = noiseBurn + factor;
    if (apply)
    {
        burn = powr(burn, _164.feather);
    }
    burn = fast::clamp(burn, 0.0, 1.0);
    float displace = -mix(0.0, burn * 0.02999999932944774627685546875, factor);
    uvDisplace += float2(displace);
    float3 src = _164.color.xyz;
    float2 param_3 = uv;
    float3 tgt = texture2DCv(refInput, refInputSmplr, param_3).xyz;
    float3 col = src;
    col = float3(burn);
    if (apply)
    {
        col = mix(src, tgt, float3(burn));
    }
    float4 result = float4(col, 1.0);
    float4 factorx = result * _164.alpha;
    factorx *= texColor.w;
    float4 resultfinal = factorx + (texColor * (1.0 - factorx.w));
    referenceColor = resultfinal;
}

fragment refAM35_ee491c4fae043_out refAM35_ee491c4fae043(constant ReferenceUniformsee491c4fae043& _164 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ee491c4fae043_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _164, referenceColor);
    bool _302 = any(isnan(referenceColor));
    bool _309;
    if (!_302)
    {
        _309 = any(isinf(referenceColor));
    }
    else
    {
        _309 = _302;
    }
    if (_309)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _322 = referenceColor;
    float3 _328 = fast::clamp(_322.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _328.x;
    referenceColor.y = _328.y;
    referenceColor.z = _328.z;
    out.finalColor = referenceColor;
    return out;
}

