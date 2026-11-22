// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxparticle3d.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsefc60eccebd05
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int emitterShape;
    char _m6_pad[12];
    float amount;
    char _m7_pad[12];
    float spread;
    char _m8_pad[12];
    float depth;
    char _m9_pad[12];
    float seed;
    char _m10_pad[12];
    float progress;
    char _m11_pad[12];
    uint autoMove;
    char _m12_pad[12];
    float speed;
    char _m13_pad[12];
    float velocityX;
    char _m14_pad[12];
    float velocityY;
    char _m15_pad[12];
    float velocityZ;
    char _m16_pad[12];
    float gravity;
    char _m17_pad[12];
    float turbulence;
    char _m18_pad[12];
    float drag;
    char _m19_pad[12];
    float particleSize;
    char _m20_pad[12];
    float sizeRandom;
    char _m21_pad[12];
    float glow;
    char _m22_pad[12];
    float motionBlur;
    float4 startColor;
    float4 endColor;
    float rotX;
    char _m26_pad[12];
    float rotY;
    char _m27_pad[12];
    float rotZ;
    char _m28_pad[12];
    float cameraDistance;
    char _m29_pad[12];
    float fov;
    char _m30_pad[12];
    float sourceMix;
    char _m31_pad[12];
    float opacity;
};

struct refAM35_efc60eccebd05_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3x3 rz(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float3x3(float3(c, -s, 0.0), float3(s, c, 0.0), float3(0.0, 0.0, 1.0));
}

static inline __attribute__((always_inline))
float3x3 ry(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float3x3(float3(c, 0.0, s), float3(0.0, 1.0, 0.0), float3(-s, 0.0, c));
}

static inline __attribute__((always_inline))
float3x3 rx(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float3x3(float3(1.0, 0.0, 0.0), float3(0.0, c, -s), float3(0.0, s, c));
}

static inline __attribute__((always_inline))
float3 h3(thread const float& n)
{
    return fract(sin(float3(n, n + 19.1000003814697265625, n + 47.700000762939453125) * float3(127.09999847412109375, 311.70001220703125, 74.6999969482421875)) * 43758.546875);
}

static inline __attribute__((always_inline))
float h1(thread const float& n)
{
    return fract(sin(n * 127.09999847412109375) * 43758.546875);
}

static inline __attribute__((always_inline))
float seg(thread const float2& p, thread const float2& a, thread const float2& b)
{
    float2 pa = p - a;
    float2 ba = b - a;
    float t = fast::clamp(dot(pa, ba) / fast::max(dot(ba, ba), 9.9999999747524270787835121154785e-07), 0.0, 1.0);
    return length(pa - (ba * t));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsefc60eccebd05& _168, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (((gl_FragCoord.xy - _168.refLayer.xy) / _168.refLayer.zw) * 2.0) - float2(1.0);
    float asp = _168.refLayer.z / fast::max(_168.refLayer.w, 1.0);
    uv.x *= asp;
    float2 param = (gl_FragCoord.xy - _168.refLayer.xy) / _168.refLayer.zw;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 sum = float3(0.0);
    float aa = 0.0;
    float _228;
    if (_168.autoMove != 0u)
    {
        _228 = _168.refScreen.z * _168.speed;
    }
    else
    {
        _228 = 0.0;
    }
    float tm = _168.progress + _228;
    float param_1 = (_168.rotZ * 3.1415927410125732421875) / 180.0;
    float param_2 = (_168.rotY * 3.1415927410125732421875) / 180.0;
    float param_3 = (_168.rotX * 3.1415927410125732421875) / 180.0;
    float3x3 R = (rz(param_1) * ry(param_2)) * rx(param_3);
    float3 p;
    for (int i = 0; i < 96; i++)
    {
        float ref_active = 1.0 - step(_168.amount, float(i));
        float fi = float(i) + (_168.seed * 31.729999542236328125);
        float param_4 = fi;
        float3 q = (h3(param_4) * 2.0) - float3(1.0);
        float param_5 = fi * 5.13000011444091796875;
        float age = fract(h1(param_5) + (tm * 0.12999999523162841796875));
        float life = sin(3.1415927410125732421875 * age);
        if (_168.emitterShape == 0)
        {
            p = q * float3(_168.spread * asp, _168.spread, _168.depth * 0.3499999940395355224609375);
        }
        else
        {
            if (_168.emitterShape == 1)
            {
                float param_6 = fi * 2.7000000476837158203125;
                p = (fast::normalize(q + float3(0.001000000047497451305389404296875)) * powr(h1(param_6), 0.333000004291534423828125)) * float3(_168.spread * asp, _168.spread, _168.spread);
            }
            else
            {
                float param_7 = fi;
                float a = (h1(param_7) * 3.1415927410125732421875) * 2.0;
                float param_8 = fi * 3.099999904632568359375;
                p = float3((cos(a) * _168.spread) * asp, ((h1(param_8) - 0.5) * _168.spread) * 0.25, sin(a) * _168.spread);
            }
        }
        float3 vel = float3(_168.velocityX * asp, _168.velocityY, _168.velocityZ);
        float damp = 1.0 / (1.0 + ((_168.drag * age) * 2.0));
        p += (((vel * age) + float3(0.0, (_168.gravity * age) * age, 0.0)) * damp);
        p += (((float3(sin((fi * 1.7000000476837158203125) + (tm * 1.2000000476837158203125)), cos((fi * 2.2999999523162841796875) + (tm * 0.89999997615814208984375)), sin((fi * 0.699999988079071044921875) + tm)) * _168.turbulence) * 0.180000007152557373046875) * life);
        p = R * p;
        float z = (p.z + _168.cameraDistance) + (_168.depth * 0.550000011920928955078125);
        float visible = step(0.180000007152557373046875, z) * ref_active;
        float2 pos = p.xy / float2(z * _168.fov);
        float2 old = (p.xy - ((vel.xy * 0.0350000001490116119384765625) * _168.motionBlur)) / float2(fast::max(z - ((vel.z * 0.0350000001490116119384765625) * _168.motionBlur), 0.20000000298023223876953125) * _168.fov);
        float param_9 = fi * 9.1000003814697265625;
        float rr = ((_168.particleSize * mix(1.0 - _168.sizeRandom, 1.0 + _168.sizeRandom, h1(param_9))) * mix(0.3499999940395355224609375, 1.25, life)) / fast::max(z * 0.550000011920928955078125, 0.3499999940395355224609375);
        float d = length(uv - pos);
        float core = smoothstep(rr, rr * 0.180000007152557373046875, d);
        float halo = exp(((-d) * d) / fast::max((rr * rr) * 7.0, 9.9999999747524270787835121154785e-07));
        float2 param_10 = uv;
        float2 param_11 = pos;
        float2 param_12 = old;
        float trail = (exp(-powr(seg(param_10, param_11, param_12) / fast::max(rr * 0.699999988079071044921875, 9.9999997473787516355514526367188e-05), 2.0)) * _168.motionBlur) * 0.2800000011920928955078125;
        float fade = (smoothstep(0.0, 0.14000000059604644775390625, age) * (1.0 - smoothstep(0.7200000286102294921875, 1.0, age))) * visible;
        float3 c = mix(_168.startColor.xyz, _168.endColor.xyz, float3(age));
        float e = ((core + ((halo * _168.glow) * 0.4199999868869781494140625)) + trail) * fade;
        sum += (c * e);
        aa = fast::max(aa, fast::clamp((core + (halo * 0.3499999940395355224609375)) + trail, 0.0, 1.0) * fade);
    }
    sum /= (float3(1.0) + sum);
    float3 rgb = mix(sum, src.xyz + sum, float3(_168.sourceMix));
    referenceColor = float4(rgb, fast::clamp(fast::max(aa, src.w * _168.sourceMix) * _168.opacity, 0.0, 1.0));
}

fragment refAM35_efc60eccebd05_out refAM35_efc60eccebd05(constant ReferenceUniformsefc60eccebd05& _168 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_efc60eccebd05_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _168, refInput, refInputSmplr, referenceColor);
    bool _695 = any(isnan(referenceColor));
    bool _702;
    if (!_695)
    {
        _702 = any(isinf(referenceColor));
    }
    else
    {
        _702 = _695;
    }
    if (_702)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _715 = referenceColor;
    float3 _721 = fast::clamp(_715.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _721.x;
    referenceColor.y = _721.y;
    referenceColor.z = _721.z;
    out.finalColor = referenceColor;
    return out;
}

