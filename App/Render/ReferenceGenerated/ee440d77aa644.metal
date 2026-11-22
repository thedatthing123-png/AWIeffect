// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/burning_texture_fade2.xml
// Original source comments and attribution:
// Burning Texture Fade (ShaderToy port with controls)
// Original by Krzysztof Kondrak @k_kondrak; this port exposes progress and feather.
// Hash random
// Smoothed interpolation noise
// Smokey/Hellish background using optional bgTex, animated by time parameters
// Map ShaderToy iTime*0.01 to controllable time/bgSpeed
// ShaderToy used uv = p/iResolution.xx; replicate largest-axis normalization
// Use aspect-correct screen-normalized UVs to avoid stretching
// Map progress [0,1] to original t range [0,1.2]
// Fade to black using noisy threshold with controllable feather and scale
// Original used smoothstep(t+0.1, t-0.1, val) (note reversed edges)
// Burning on edges where alpha got low
// Background under holes (alpha very small)
// Plain burn-to-black
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

struct ReferenceUniformsee440d77aa644
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progress;
    char _m6_pad[12];
    float feather;
    char _m7_pad[12];
    float noiseScale;
    float4 heatColor;
    float burnIntensity;
    char _m10_pad[12];
    uint useBackground;
    char _m11_pad[12];
    float bgScale;
    char _m12_pad[12];
    float time;
    char _m13_pad[12];
    float bgSpeed;
};

struct refAM35_ee440d77aa644_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float r(thread const float2& p)
{
    return fract(cos((p.x * 42.979999542236328125) + (p.y * 43.229999542236328125)) * 1127.530029296875);
}

static inline __attribute__((always_inline))
float n(thread const float2& p)
{
    float2 fn = floor(p);
    float2 sn = smoothstep(float2(0.0), float2(1.0), fract(p));
    float2 param = fn;
    float2 param_1 = fn + float2(1.0, 0.0);
    float h1 = mix(r(param), r(param_1), sn.x);
    float2 param_2 = fn + float2(0.0, 1.0);
    float2 param_3 = fn + float2(1.0);
    float h2 = mix(r(param_2), r(param_3), sn.x);
    return mix(h1, h2, sn.y);
}

static inline __attribute__((always_inline))
float noiseFBM(thread const float2& p)
{
    float2 param = p / float2(32.0);
    float2 param_1 = p / float2(16.0);
    float2 param_2 = p / float2(8.0);
    float2 param_3 = p / float2(4.0);
    float2 param_4 = p / float2(2.0);
    float2 param_5 = p;
    return (((((n(param) * 0.579999983310699462890625) + (n(param_1) * 0.20000000298023223876953125)) + (n(param_2) * 0.100000001490116119384765625)) + (n(param_3) * 0.0500000007450580596923828125)) + (n(param_4) * 0.0199999995529651641845703125)) + (n(param_5) * 0.012500000186264514923095703125);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 backgroundTex(thread const float2& pos, constant ReferenceUniformsee440d77aa644& _158, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 offset = float2(0.0, _158.bgSpeed * _158.time);
    float3 color = float3(1.0);
    for (int i = 0; i < 3; i++)
    {
        float w = abs(mod(float(i) * 0.66600000858306884765625, 2.0) - 1.0);
        float2 param = (pos - (offset * 0.25)) + float2(0.5);
        float3 a = texture2DCv(refInput, refInputSmplr, param).xyz;
        float2 param_1 = pos - offset;
        float3 b = texture2DCv(refInput, refInputSmplr, param_1).xyz;
        color += ((mix(a, b, float3(w)) * color) * color);
    }
    return color * float3(0.066600002348423004150390625, 0.0265999995172023773193359375, 0.00332999997772276401519775390625);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsee440d77aa644& _158, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 res = _158.refScreen.xy;
    float2 fragCoord = (gl_FragCoord.xy / _158.refScreen.xy) * res;
    float2 uv = gl_FragCoord.xy / _158.refScreen.xy;
    float t = _158.progress * 1.2000000476837158203125;
    float2 param = fragCoord * _158.noiseScale;
    float val = noiseFBM(param);
    float m = smoothstep(t + _158.feather, t - _158.feather, val);
    float2 param_1 = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param_1);
    float4 c = mix(src, float4(0.0), float4(m));
    float edge = step(c.w, 0.100000001490116119384765625);
    float2 param_2 = uv * 2000.0;
    float3 heat = _158.heatColor.xyz * (_158.burnIntensity * noiseFBM(param_2));
    float4 _314 = c;
    float3 _322 = fast::clamp(_314.xyz + (heat * edge), float3(0.0), float3(1.0));
    c.x = _322.x;
    c.y = _322.y;
    c.z = _322.z;
    if (_158.useBackground != 0u)
    {
        float2 param_3 = uv * _158.bgScale;
        float3 bg = backgroundTex(param_3, _158, refInput, refInputSmplr);
        float4 _345 = c;
        float _349 = c.w;
        float _354 = c.w;
        float3 _357 = (_345.xyz * step(0.00999999977648258209228515625, _349)) + (bg * step(_354, 0.00999999977648258209228515625));
        c.x = _357.x;
        c.y = _357.y;
        c.z = _357.z;
    }
    else
    {
        float _366 = c.w;
        float4 _368 = c;
        float3 _370 = _368.xyz * step(0.00999999977648258209228515625, _366);
        c.x = _370.x;
        c.y = _370.y;
        c.z = _370.z;
    }
    referenceColor = c;
}

fragment refAM35_ee440d77aa644_out refAM35_ee440d77aa644(constant ReferenceUniformsee440d77aa644& _158 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ee440d77aa644_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_158, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _384 = any(isnan(referenceColor));
    bool _391;
    if (!_384)
    {
        _391 = any(isinf(referenceColor));
    }
    else
    {
        _391 = _384;
    }
    if (_391)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _404 = referenceColor;
    float3 _410 = fast::clamp(_404.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _410.x;
    referenceColor.y = _410.y;
    referenceColor.z = _410.z;
    out.finalColor = referenceColor;
    return out;
}

