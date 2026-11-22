// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/bloodsplash.xml
// Original source comments and attribution:
// Render multiple 3D spheres with lighting, animation, and blending
// Random position and depth, animated
// Parallax for depth
// 3D sphere shading
// Lighting
// Blend with source image if enabled (no inputImg.enabled in AfterMotion)
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse00491689d6e9
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float sphereCount;
    float4 sphereColor;
    float sphereSize;
    char _m8_pad[12];
    float spread;
    char _m9_pad[12];
    float depth;
    char _m10_pad[12];
    float gloss;
    char _m11_pad[12];
    float anim;
    char _m12_pad[12];
    uint blendSource;
};

struct refAM35_e00491689d6e9_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float rand(thread const float2& co)
{
    return fract(sin(dot(co, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse00491689d6e9& _49, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _49.refScreen.xy;
    float4 outColor = float4(0.0);
    float maxAlpha = 0.0;
    for (int i = 0; i < 32; i++)
    {
        if (i >= int(_49.sphereCount))
        {
            break;
        }
        float fi = float(i);
        float2 param = float2(fi, 1.230000019073486328125);
        float angle = rand(param) * 6.283100128173828125;
        float2 param_1 = float2(fi, 2.46000003814697265625);
        float radius = _49.spread * (0.4000000059604644775390625 + (rand(param_1) * 0.60000002384185791015625));
        float2 param_2 = float2(fi, 3.1400001049041748046875);
        float z = _49.depth * (rand(param_2) - 0.5);
        float animT = _49.anim;
        float2 param_3 = float2(fi, 7.769999980926513671875);
        float explode = animT * (0.699999988079071044921875 + (rand(param_3) * 0.800000011920928955078125));
        float2 center = float2(0.5) + ((float2(cos(angle), sin(angle)) * radius) * (1.0 + explode));
        center += (((uv - float2(0.5)) * z) * 0.20000000298023223876953125);
        float2 param_4 = float2(fi, 5.55000019073486328125);
        float size = (_49.sphereSize * (0.699999988079071044921875 + (rand(param_4) * 0.60000002384185791015625))) * (1.0 - (z * 0.300000011920928955078125));
        float2 rel = (uv - center) / float2(size);
        float d = length(rel);
        if (d > 1.0)
        {
            continue;
        }
        float dz = sqrt(1.0 - (d * d));
        float3 n = fast::normalize(float3(rel, dz));
        float3 lightDir = float3(-0.3790490329265594482421875, 0.53066861629486083984375, 0.758098065853118896484375);
        float diff = fast::max(dot(n, lightDir), 0.0);
        float spec = powr(fast::max(dot(reflect(-lightDir, n), float3(0.0, 0.0, 1.0)), 0.0), 24.0 + (_49.gloss * 80.0));
        float ambient = 0.1599999964237213134765625;
        float3 base = mix(_49.sphereColor.xyz, float3(1.0), float3(0.0500000007450580596923828125 + (0.300000011920928955078125 * _49.gloss)));
        float3 color = (base * (ambient + (diff * 0.85000002384185791015625))) + ((float3(1.0) * spec) * _49.gloss);
        float alpha = smoothstep(1.0, 0.800000011920928955078125, d) * _49.sphereColor.w;
        float4 _269 = outColor;
        float3 _274 = mix(_269.xyz, color, float3(alpha));
        outColor.x = _274.x;
        outColor.y = _274.y;
        outColor.z = _274.z;
        maxAlpha = fast::max(maxAlpha, alpha);
    }
    outColor.w = maxAlpha;
    if (_49.blendSource != 0u)
    {
        float2 param_5 = uv;
        float4 src = texture2DCv(refInput, refInputSmplr, param_5);
        outColor += (src * (1.0 - outColor.w));
    }
    referenceColor = outColor;
}

fragment refAM35_e00491689d6e9_out refAM35_e00491689d6e9(constant ReferenceUniformse00491689d6e9& _49 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e00491689d6e9_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _49, refInput, refInputSmplr, referenceColor);
    bool _318 = any(isnan(referenceColor));
    bool _325;
    if (!_318)
    {
        _325 = any(isinf(referenceColor));
    }
    else
    {
        _325 = _318;
    }
    if (_325)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _338 = referenceColor;
    float3 _344 = fast::clamp(_338.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _344.x;
    referenceColor.y = _344.y;
    referenceColor.z = _344.z;
    out.finalColor = referenceColor;
    return out;
}

