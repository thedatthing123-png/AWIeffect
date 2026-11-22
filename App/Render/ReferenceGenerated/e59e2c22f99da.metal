// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxscrossglitch.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//      Author : Ian McEwan, Ashima Arts.
//  Maintainer : ijm
//     Lastmod : 20110822 (ijm)
//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
//               Distributed under the MIT License. See LICENSE file.
//               https://github.com/ashima/webgl-noise
//
// First corner
// Other corners
// 2.0*C.x = 1/3 = C.y
// -1.0+3.0*C.x = -0.5 = -D.y
// Permutations
// Gradients: 7x7 points over a square, mapped onto an octahedron.
// The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
// 1.0/7.0
//  mod(p,7*7)
// mod(j,N)
// vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)
//vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
//vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
//Normalise gradients
// Mix final noise value
// const float interval = 3.0;
//////////////////////////
/////////////////////////
// float interval = 3.0;
//
// snoise3(vec3(0.0, y * 0.01, time * 400.0)) * (2.0 + strength * 32.0)
// float whiteNoise = (random(syamjaidtz + mod(time, 10.0)) * 2.0 - 1.0) * (0.15 + strength * 0.15);
// float bnTime = floor(time * 20.0) * 200.0;
// float noiseX = step((snoise3(vec3(0.0, syamjaidtz.x * 3.0, bnTime)) + 1.0) / 2.0, 0.12 + strength * 0.3);
// float noiseY = step((snoise3(vec3(0.0, syamjaidtz.y * 3.0, bnTime)) + 1.0) / 2.0, 0.12 + strength * 0.3);
// float bnUvX = syamjaidtz.x + sin(bnTime) * 0.2 + rgbWave;
// float noiseX2 = step((snoise3(vec3(0.0, syamjaidtz.x * 2.0, bnTime2)) + 1.0) / 2.0, 0.12 + strength * 0.5);
// float noiseY2 = step((snoise3(vec3(0.0, syamjaidtz.y * 8.0, bnTime2)) + 1.0) / 2.0, 0.12 + strength * 0.3);
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

struct ReferenceUniformse59e2c22f99da
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progress;
    char _m6_pad[12];
    float xxc;
    char _m7_pad[12];
    float xxd;
    char _m8_pad[12];
    float xxf;
    char _m9_pad[12];
    float xxh;
    char _m10_pad[12];
    float iter;
    char _m11_pad[12];
    float alpha;
    char _m12_pad[12];
    float xxi;
    char _m13_pad[12];
    float xxj;
    char _m14_pad[12];
    float xxk;
    char _m15_pad[12];
    float xxl;
    char _m16_pad[12];
    float xxm;
    char _m17_pad[12];
    float xxn;
    char _m18_pad[12];
    float xxo;
    char _m19_pad[12];
    float xxp;
};

struct refAM35_e59e2c22f99da_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float random(thread const float2& st)
{
    return fract(sin(dot(st, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float3 mod289(thread const float3& x)
{
    return x - (floor(x * 0.00346020772121846675872802734375) * 289.0);
}

static inline __attribute__((always_inline))
float4 mod289(thread const float4& x)
{
    return x - (floor(x * 0.00346020772121846675872802734375) * 289.0);
}

static inline __attribute__((always_inline))
float4 permute(thread const float4& x)
{
    float4 param = ((x * 34.0) + float4(1.0)) * x;
    return mod289(param);
}

static inline __attribute__((always_inline))
float4 taylorInvSqrt(thread const float4& r)
{
    return float4(1.792842864990234375) - (r * 0.8537347316741943359375);
}

static inline __attribute__((always_inline))
float snoise3(thread const float3& v, constant ReferenceUniformse59e2c22f99da& _230)
{
    float3 i = floor(v + float3(dot(v, float3(0.3333333432674407958984375))));
    float3 x0 = (v - i) + float3(dot(i, float3(0.16666667163372039794921875)));
    float3 g = step(x0.yzx, x0);
    float3 l = float3(1.0) - g;
    float3 i1 = fast::min(g, l.zxy);
    float3 i2 = fast::max(g, l.zxy);
    float3 x1 = (x0 - i1) + float3(0.16666667163372039794921875);
    float3 x2 = (x0 - i2) + float3(0.3333333432674407958984375);
    float3 x3 = x0 - float3(0.5);
    float3 param = i;
    i = mod289(param);
    float4 param_1 = float4(i.z) + float4(0.0, i1.z, i2.z, 1.0);
    float4 param_2 = (permute(param_1) + float4(i.y)) + float4(0.0, i1.y, i2.y, 1.0);
    float4 param_3 = (permute(param_2) + float4(i.x)) + float4(0.0, i1.x, i2.x, 1.0);
    float4 p = permute(param_3);
    float n_ = 0.14285714924335479736328125;
    float3 ns = (float3(2.0, 0.5, 1.0) * n_) - float3(0.0, 1.0, 0.0);
    float4 j = p - (floor((p * ns.z) * ns.z) * 49.0);
    float4 x_ = floor(j * ns.z);
    float4 y_ = floor(j - (x_ * _230.xxd));
    float4 x = (x_ * ns.x) + ns.yyyy;
    float4 y = (y_ * ns.x) + ns.yyyy;
    float4 h = (float4(1.0) - abs(x)) - abs(y);
    float4 b0 = float4(x.xy, y.xy);
    float4 b1 = float4(x.zw, y.zw);
    float4 s0 = (floor(b0) * 2.0) + float4(1.0);
    float4 s1 = (floor(b1) * 2.0) + float4(1.0);
    float4 sh = -step(h, float4(0.0));
    float4 a0 = b0.xzyw + (s0.xzyw * sh.xxyy);
    float4 a1 = b1.xzyw + (s1.xzyw * sh.zzww);
    float3 p0 = float3(a0.xy, h.x);
    float3 p1 = float3(a0.zw, h.y);
    float3 p2 = float3(a1.xy, h.z);
    float3 p3 = float3(a1.zw, h.w);
    float4 param_4 = float4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3));
    float4 norm = taylorInvSqrt(param_4);
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;
    float4 m = fast::max(float4(0.60000002384185791015625) - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), float4(0.0));
    m *= m;
    return 42.0 * dot(m * m, float4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse59e2c22f99da& _230, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_230.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _230.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_230.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _230.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 iRes = float2(_230.refScreen.x, _230.refScreen.y);
            float2 syamjaidtz = gl_FragCoord.xy / _230.refScreen.xy;
            float interval = _230.xxc;
            float time = _230.progress;
            float strength = smoothstep(interval * 0.5, interval, interval - mod(time, interval));
            float2 param_2 = float2(time);
            float2 param_3 = float2(time * 2.0);
            float2 shake = (float2((strength * 8.0) + 0.5) * float2((random(param_2) * 2.0) - 1.0, (random(param_3) * 2.0) - 1.0)) / iRes;
            float y = syamjaidtz.y * _230.refScreen.y;
            float3 param_4 = float3(0.0, y * _230.xxf, time * 400.0);
            float3 param_5 = float3(0.0, y * 0.0199999995529651641845703125, time * 200.0);
            float rgbWave = (((((snoise3(param_4, _230) * (2.0 + (strength * 32.0))) * snoise3(param_5, _230)) * (1.0 + (strength * 4.0))) + (step(0.999499976634979248046875, sin((y * 0.004999999888241291046142578125) + (time * 1.60000002384185791015625))) * 12.0)) + (step(0.99989998340606689453125, sin((y * 0.004999999888241291046142578125) + (time * 2.0))) * (-18.0))) / _230.refScreen.x;
            float rgbDiff = (6.0 + (sin((time * 500.0) + (syamjaidtz.y * 40.0)) * ((20.0 * strength) + 1.0))) / _230.refScreen.x;
            float rgbUvX = syamjaidtz.x + rgbWave;
            float2 param_6 = float2(rgbUvX + rgbDiff, syamjaidtz.y) + shake;
            float r = texture2DCv(refInput, refInputSmplr, param_6).x;
            float2 param_7 = float2(rgbUvX, syamjaidtz.y) + shake;
            float g = texture2DCv(refInput, refInputSmplr, param_7).y;
            float2 param_8 = float2(rgbUvX - rgbDiff, syamjaidtz.y) + shake;
            float b = texture2DCv(refInput, refInputSmplr, param_8).z;
            float2 param_9 = syamjaidtz + float2(mod(time, 10.0));
            float whiteNoise = ((random(param_9) * 2.0) - 1.0) * (0.1500000059604644775390625 + (strength * _230.xxh));
            float bnTime = floor(time * 20.0) * _230.xxi;
            float3 param_10 = float3(0.0, syamjaidtz.x * 3.0, bnTime);
            float noiseX = step((snoise3(param_10, _230) + 1.0) / fast::max(abs(_230.xxj), 9.9999997473787516355514526367188e-05), 0.119999997317790985107421875 + (strength * 0.300000011920928955078125));
            float3 param_11 = float3(0.0, syamjaidtz.y * 3.0, bnTime);
            float noiseY = step((snoise3(param_11, _230) + 1.0) / fast::max(abs(_230.xxk), 9.9999997473787516355514526367188e-05), 0.119999997317790985107421875 + (strength * 0.300000011920928955078125));
            float bnMask = noiseX * noiseY;
            float bnUvX = (syamjaidtz.x + (sin(bnTime) * _230.xxl)) + rgbWave;
            float2 param_12 = float2(bnUvX + rgbDiff, syamjaidtz.y);
            float bnR = texture2DCv(refInput, refInputSmplr, param_12).x * bnMask;
            float2 param_13 = float2(bnUvX, syamjaidtz.y);
            float bnG = texture2DCv(refInput, refInputSmplr, param_13).y * bnMask;
            float2 param_14 = float2(bnUvX - rgbDiff, syamjaidtz.y);
            float bnB = texture2DCv(refInput, refInputSmplr, param_14).z * bnMask;
            float4 blockNoise = float4(bnR, bnG, bnB, 1.0);
            float bnTime2 = floor(time * 25.0) * 300.0;
            float3 param_15 = float3(0.0, syamjaidtz.x * _230.xxm, bnTime2);
            float noiseX2 = step((snoise3(param_15, _230) + 1.0) / 2.0, 0.119999997317790985107421875 + (strength * _230.xxo));
            float3 param_16 = float3(0.0, syamjaidtz.y * _230.xxn, bnTime2);
            float noiseY2 = step((snoise3(param_16, _230) + 1.0) / 2.0, 0.119999997317790985107421875 + (strength * _230.xxp));
            float bnMask2 = noiseX2 * noiseY2;
            float2 param_17 = float2(bnUvX + rgbDiff, syamjaidtz.y);
            float bnR2 = texture2DCv(refInput, refInputSmplr, param_17).x * bnMask2;
            float2 param_18 = float2(bnUvX, syamjaidtz.y);
            float bnG2 = texture2DCv(refInput, refInputSmplr, param_18).y * bnMask2;
            float2 param_19 = float2(bnUvX - rgbDiff, syamjaidtz.y);
            float bnB2 = texture2DCv(refInput, refInputSmplr, param_19).z * bnMask2;
            float4 blockNoise2 = float4(bnR2, bnG2, bnB2, 1.0);
            float waveNoise = ((sin(syamjaidtz.y * 1200.0) + 1.0) / 2.0) * (0.1500000059604644775390625 + (strength * 0.20000000298023223876953125));
            float4 fragColor = (float4(r, g, b, 1.0) * ((1.0 - bnMask) - bnMask2)) + (((float4(whiteNoise) + blockNoise) + blockNoise2) - float4(waveNoise));
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal = (fast::max(factor, texColor) * 1.0) * texColor.w;
            referenceColor = mix(texColor, resultfinal, float4(_230.alpha));
        }
    }
}

fragment refAM35_e59e2c22f99da_out refAM35_e59e2c22f99da(constant ReferenceUniformse59e2c22f99da& _230 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e59e2c22f99da_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_230, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _921 = any(isnan(referenceColor));
    bool _928;
    if (!_921)
    {
        _928 = any(isinf(referenceColor));
    }
    else
    {
        _928 = _921;
    }
    if (_928)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _941 = referenceColor;
    float3 _947 = fast::clamp(_941.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _947.x;
    referenceColor.y = _947.y;
    referenceColor.z = _947.z;
    out.finalColor = referenceColor;
    return out;
}

