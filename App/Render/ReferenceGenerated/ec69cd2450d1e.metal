// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/organic_particles_up.xml
// Original source comments and attribution:
// Procedural upward organic particles (Buffer A port)
// Head
// Tail
// Accumulate particles
// Composite over source additively
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec69cd2450d1e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float particleCount;
    char _m6_pad[12];
    float speedScale;
    char _m7_pad[12];
    float sizeScale;
    char _m8_pad[12];
    float tailFreqScale;
    char _m9_pad[12];
    float seedOffset;
    float4 tint;
    float intensity;
    char _m12_pad[12];
    float blend;
    char _m13_pad[12];
    float alpha;
};

struct refAM35_ec69cd2450d1e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float rand(thread const float2& co)
{
    return fract(sin(dot(co, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float organicWave(thread const float& y, thread const float& id, constant ReferenceUniformsec69cd2450d1e& _58)
{
    float2 param = float2(id + _58.seedOffset, 5.0);
    float freq1 = (rand(param) * 3.0) + 2.0;
    float2 param_1 = float2(id + _58.seedOffset, 6.0);
    float amp1 = rand(param_1) * 0.039999999105930328369140625;
    float2 param_2 = float2(id + _58.seedOffset, 7.0);
    float freq2 = (rand(param_2) * 10.0) + 8.0;
    float2 param_3 = float2(id + _58.seedOffset, 8.0);
    float amp2 = rand(param_3) * 0.0199999995529651641845703125;
    float2 param_4 = float2(id + _58.seedOffset, 1.10000002384185791015625);
    float drift = sin(_58.refScreen.z * ((rand(param_4) * 0.300000011920928955078125) + 0.100000001490116119384765625));
    return ((sin((y * freq1) + id) * amp1) + (sin((y * freq2) + id) * amp2)) + (drift * 0.0199999995529651641845703125);
}

static inline __attribute__((always_inline))
float3 createParticle(thread const float2& uv, thread const float& id, thread const float& aspect, constant ReferenceUniformsec69cd2450d1e& _58)
{
    float2 param = float2(id + _58.seedOffset, 1.0);
    float initial_x = rand(param);
    float2 param_1 = float2(id + _58.seedOffset, 2.0);
    float speed = mix(0.039999999105930328369140625, 0.119999997317790985107421875, rand(param_1)) * _58.speedScale;
    float2 param_2 = float2(id + _58.seedOffset, 3.0);
    float phase = rand(param_2) * 200.0;
    float2 param_3 = float2(id + _58.seedOffset, 4.0);
    float size = mix(0.60000002384185791015625, 1.2999999523162841796875, rand(param_3)) * _58.sizeScale;
    float2 param_4 = float2(id + _58.seedOffset, 9.0);
    float tail_dot_freq = mix(150.0, 200.0, rand(param_4)) * _58.tailFreqScale;
    float y_pos = fract((_58.refScreen.z + phase) * speed);
    float param_5 = y_pos;
    float param_6 = id;
    float x_pos = initial_x + organicWave(param_5, param_6, _58);
    float2 pos = float2(x_pos, y_pos);
    float2 uv_aspect = uv;
    uv_aspect.x *= aspect;
    pos.x *= aspect;
    float2 p_head = uv_aspect - pos;
    float head_dist = length(p_head) - (p_head.y * 0.4000000059604644775390625);
    float head_size = 0.0089999996125698089599609375 * size;
    float head = smoothstep(head_size, head_size * 0.300000011920928955078125, head_dist);
    float tail = 0.0;
    if (uv.y < pos.y)
    {
        float y_dist_from_head = pos.y - uv.y;
        float param_7 = uv.y;
        float param_8 = id;
        float tail_x_center = (initial_x + organicWave(param_7, param_8, _58)) * aspect;
        float x_dist_from_center = uv_aspect.x - tail_x_center;
        float dots = smoothstep(0.699999988079071044921875, 0.800000011920928955078125, sin(y_dist_from_head * (-tail_dot_freq)));
        float falloff = exp((-y_dist_from_head) * 18.0);
        float dot_size = (0.004999999888241291046142578125 * falloff) * size;
        tail = (smoothstep(dot_size, 0.0, abs(x_dist_from_center)) * falloff) * dots;
    }
    float intensityLocal = head + (tail * 1.5);
    if (intensityLocal < 0.00999999977648258209228515625)
    {
        return float3(0.0);
    }
    float3 base = _58.tint.xyz * powr(intensityLocal, 2.0);
    float3 glow = mix(float3(1.0, 0.20000000298023223876953125, 0.100000001490116119384765625), _58.tint.xyz, float3(0.5)) * powr(intensityLocal, 4.0);
    return (base + glow) * _58.intensity;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsec69cd2450d1e& _58, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _58.refScreen.xy;
    float aspect = _58.refScreen.x / _58.refScreen.y;
    float3 final_color = float3(0.0);
    int count = int(fast::clamp(_58.particleCount, 1.0, 200.0));
    for (int i = 0; i < 200; i++)
    {
        if (i >= count)
        {
            break;
        }
        float2 param = uv;
        float param_1 = float(i);
        float param_2 = aspect;
        final_color += createParticle(param, param_1, param_2, _58);
    }
    float2 param_3 = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param_3);
    float3 outRGB = mix(src.xyz, src.xyz + final_color, float3(fast::clamp(_58.blend, 0.0, 1.0)));
    float a = src.w * _58.alpha;
    referenceColor = float4(outRGB, 1.0) * a;
}

fragment refAM35_ec69cd2450d1e_out refAM35_ec69cd2450d1e(constant ReferenceUniformsec69cd2450d1e& _58 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec69cd2450d1e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_58, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _466 = any(isnan(referenceColor));
    bool _473;
    if (!_466)
    {
        _473 = any(isinf(referenceColor));
    }
    else
    {
        _473 = _466;
    }
    if (_473)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _486 = referenceColor;
    float3 _492 = fast::clamp(_486.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _492.x;
    referenceColor.y = _492.y;
    referenceColor.z = _492.z;
    out.finalColor = referenceColor;
    return out;
}

