// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/firey_border.xml
// Original source comments and attribution:
// --- NOISE FUNCTIONS ---
// Value Noise with Smoothstep
// Quintic
// Fractal Brownian Motion
// 1. Setup Coordinates
// 2. Generate Turbulence
// 3. Calculate Distance to Edge
// 4. Distort the Edge (Applied Settings Here)
// We use distortionScale for the noise frequency
// We use distortionStrength to determine how much it affects the border
// 5. Create the Fire Mask
// 6. Color Mapping
// Core 
// Middle 
// Tips 
// Apply manual tint override (optional, but requested implicitly)
// The original had a constant FIRE_TINT vec3(1.0, 0.5, 0.2)
// We mix towards it or multiply? Let's Multiplying it allows tinting.
// But since default colors are reddish/orange, multiplying by orange makes it very deep orange.
// Let's assume the user wants to filter the result.
// Note: The original code defined FIRE_TINT but didn't use it in the mainImage provided.
// We will leave it as an option.
// To make it neutral by default, we can't easily. 
// We'll just provide the uniform. If the user wants to use it, they can.
// Simple transparency based on heat
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse40d45d33b0da
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float borderSize;
    char _m6_pad[12];
    float fireIntensity;
    char _m7_pad[12];
    float fireSpeed;
    char _m8_pad[12];
    float flameDetail;
    float4 fireTint;
    float distortionStrength;
    char _m11_pad[12];
    float distortionScale;
};

struct refAM35_e40d45d33b0da_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash(thread float2& p)
{
    p = fract(p * float2(123.339996337890625, 456.209991455078125));
    p += float2(dot(p, p + float2(45.31999969482421875)));
    return fract(p.x * p.y);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f = ((f * f) * f) * ((f * ((f * 6.0) - float2(15.0))) + float2(10.0));
    float2 param = i;
    float _74 = hash(param);
    float a = _74;
    float2 param_1 = i + float2(1.0, 0.0);
    float _82 = hash(param_1);
    float b = _82;
    float2 param_2 = i + float2(0.0, 1.0);
    float _88 = hash(param_2);
    float c = _88;
    float2 param_3 = i + float2(1.0);
    float _94 = hash(param_3);
    float d = _94;
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static inline __attribute__((always_inline))
float fbm(thread float2& p)
{
    float f = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++)
    {
        float2 param = p;
        f += (amp * _noise(param));
        p *= 2.0;
        amp *= 0.5;
    }
    return f;
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse40d45d33b0da& _153, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _153.refScreen.xy;
    float2 noise_uv = uv;
    noise_uv.x *= (_153.refScreen.x / _153.refScreen.y);
    float t = _153.refScreen.z * _153.fireSpeed;
    float2 param = (noise_uv * _153.flameDetail) + float2(0.0, t);
    float _189 = fbm(param);
    float2 param_1 = (noise_uv * _153.flameDetail) + float2(t * 1.2999999523162841796875, 0.0);
    float _200 = fbm(param_1);
    float2 flow = float2(_189, _200);
    float dist_x = fast::min(uv.x, 1.0 - uv.x);
    float dist_y = fast::min(uv.y, 1.0 - uv.y);
    float dist_to_edge = fast::min(dist_x, dist_y);
    float2 param_2 = ((noise_uv * _153.distortionScale) - float2(t * 2.0)) + flow;
    float _233 = fbm(param_2);
    float wave = _233;
    float border_shape = dist_to_edge + (wave * _153.distortionStrength);
    float heat = 1.0 - smoothstep(0.0, _153.borderSize, border_shape);
    float3 col = float3(0.0);
    if (heat > 0.0)
    {
        col += (float3(1.0, 1.0, 0.800000011920928955078125) * powr(heat, 6.0));
        col += ((float3(1.0, 0.5, 0.0) * powr(heat, 3.0)) * 1.5);
        col += (float3(0.5, 0.0, 0.0) * heat);
    }
    col *= _153.fireIntensity;
    col *= step(0.0, heat);
    float alpha = smoothstep(0.0, 0.100000001490116119384765625, heat);
    referenceColor = float4(col, alpha);
}

fragment refAM35_e40d45d33b0da_out refAM35_e40d45d33b0da(constant ReferenceUniformse40d45d33b0da& _153 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e40d45d33b0da_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _153, referenceColor);
    bool _304 = any(isnan(referenceColor));
    bool _311;
    if (!_304)
    {
        _311 = any(isinf(referenceColor));
    }
    else
    {
        _311 = _304;
    }
    if (_311)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _325 = referenceColor;
    float3 _331 = fast::clamp(_325.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _331.x;
    referenceColor.y = _331.y;
    referenceColor.z = _331.z;
    out.finalColor = referenceColor;
    return out;
}

