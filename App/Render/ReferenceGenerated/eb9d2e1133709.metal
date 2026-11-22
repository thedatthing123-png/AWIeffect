// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/warpblur.xml
// Original source comments and attribution:
// First corner
// Other corners
//   x0 = x0 - 0.0 + 0.0 * C.xxx;
//   x1 = x0 - i1  + 1.0 * C.xxx;
//   x2 = x0 - i2  + 2.0 * C.xxx;
//   x3 = x0 - 1.0 + 3.0 * C.xxx;
// 2.0*C.x = 1/3 = C.y
// -1.0+3.0*C.x = -0.5 = -D.y
// Permutations
// Gradients: 7x7 points over a square, mapped onto an octahedron.
// The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
// 1.0/7.0
//  mod(p,7*7)
// mod(j,N)
//vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
//vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
//Normalise gradients
// Mix final noise value
// Precompute values for skewed triangular grid
// (3.0-sqrt(3.0))/6.0
// 0.5*(sqrt(3.0)-1.0)
// -1.0 + 2.0 * C.x
// 1.0 / 41.0
// First corner (x0)
// Other two corners (x1, x2)
// Do some permutations to avoid
// truncation effects in permutation
// Gradients:
//  41 pts uniformly over a line, mapped onto a diamond
//  The ring size 17*17 = 289 is close to a multiple
//      of 41 (41*7 = 287)
// Normalise gradients implicitly by scaling m
// Approximation of: m *= inversesqrt(a0*a0 + h*h);
// Compute final noise value at P
// Initial values
//
// Loop of octaves
//vec2(offsx,offsy);
//st += mod(vec2(4.365,7.701));
//vec2(parrx, parry);
// X
// Y
// XY
// φr
// φ
// R
// X
// Y
// XY
//q -= 1.;
// φr
// φ
// R
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb9d2e1133709
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 parr;
    char _m6_pad[8];
    float2 position;
    char _m7_pad[8];
    float intensity;
    char _m8_pad[12];
    float evolution;
    char _m9_pad[12];
    int direction;
    char _m10_pad[12];
    float scale;
    char _m11_pad[8];
    float2 stretch;
    char _m12_pad[8];
    float seed;
    char _m13_pad[12];
    uint singleAxis;
    char _m14_pad[12];
    uint screenSpace;
    char _m15_pad[12];
    float octaves;
    char _m16_pad[12];
    float offs;
};

struct refAM35_eb9d2e1133709_out
{
    float4 finalColor [[color(0)]];
};

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
float snoise(thread const float3& v)
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
    float4 y_ = floor(j - (x_ * 7.0));
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
float turbulence(thread float2& st, thread const int& OCTAVES, thread const float2& parallax, thread const float& evolution)
{
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 0.0;
    for (int i = 0; i < OCTAVES; i++)
    {
        float3 param = float3(st, evolution);
        value += (amplitude * abs(snoise(param)));
        st *= 2.0;
        st += parallax;
        amplitude *= 0.5;
    }
    return value;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseb9d2e1133709& _455, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st;
    float2 center;
    if (_455.screenSpace != 0u)
    {
        st = gl_FragCoord.xy / _455.refScreen.xy;
        st.x *= (_455.refScreen.x / _455.refScreen.y);
        center = float2(_455.refScreen.x / _455.refScreen.y, 1.0) * 0.5;
    }
    else
    {
        st = (gl_FragCoord.xy - _455.refLayer.xy) / _455.refLayer.zw;
        st.x *= (_455.refLayer.z / _455.refLayer.w);
        center = float2(_455.refLayer.z / _455.refLayer.w, 1.0) * 0.5;
    }
    st += ((_455.position * float2(-1.0, 1.0)) / float2(500.0));
    float2 parallax = (_455.parr * float2(-1.0, 1.0)) / float2(100.0);
    float2 scaleVec = float2(_455.scale * _455.stretch.y, _455.scale * _455.stretch.x);
    if (_455.screenSpace != 0u)
    {
        float t = scaleVec.x;
        scaleVec.x = scaleVec.y;
        scaleVec.y = t;
    }
    float2 sampleCoord;
    if (_455.singleAxis != 0u)
    {
        if (_455.direction == 0)
        {
            sampleCoord = float2(0.0, st.y - center.y);
        }
        else
        {
            if (_455.direction == 1)
            {
                sampleCoord = float2(st.x - center.x, 0.0);
            }
            else
            {
                if (_455.direction == 2)
                {
                    sampleCoord = st - center;
                }
                else
                {
                    if (_455.direction == 4)
                    {
                        sampleCoord = st - center;
                    }
                    else
                    {
                        if (_455.direction == 5)
                        {
                            sampleCoord = float2(0.0, length(st - center));
                        }
                        else
                        {
                            float tt = abs(precise::atan2(st.x - center.x, st.y - center.y) / 6.28318023681640625) * 2.0;
                            sampleCoord = float2(tt, 0.0);
                        }
                    }
                }
            }
        }
    }
    else
    {
        sampleCoord = st - center;
    }
    float2 param = ((sampleCoord - float2(0.5)) / scaleVec) + float2(0.5);
    int param_1 = int(_455.octaves);
    float2 param_2 = parallax;
    float param_3 = _455.evolution + (7391.93505859375 * _455.seed);
    float _677 = turbulence(param, param_1, param_2, param_3);
    float p = _677;
    p += (_455.offs - 0.25);
    p *= (_455.intensity * 2.0);
    float2 _695;
    if (_455.screenSpace != 0u)
    {
        _695 = gl_FragCoord.xy / _455.refScreen.xy;
    }
    else
    {
        _695 = (gl_FragCoord.xy - _455.refLayer.xy) / _455.refLayer.zw;
    }
    float2 uv = _695;
    float2 v = uv;
    if (_455.direction == 0)
    {
        v.x += p;
    }
    else
    {
        if (_455.direction == 1)
        {
            v.y += p;
        }
        else
        {
            if (_455.direction == 2)
            {
                float2 param_4 = (sampleCoord / scaleVec) + float2(0.5);
                int param_5 = int(_455.octaves);
                float2 param_6 = parallax;
                float param_7 = _455.evolution + (3937.724853515625 * (_455.seed + 6.3379001617431640625));
                float _768 = turbulence(param_4, param_5, param_6, param_7);
                float q = _768;
                q += (_455.offs - 0.25);
                q *= (_455.intensity * 2.0);
                v.x += p;
                v.y += q;
            }
            else
            {
                if (_455.direction == 4)
                {
                    float2 param_8 = (sampleCoord / scaleVec) + float2(0.5);
                    int param_9 = int(_455.octaves);
                    float2 param_10 = parallax;
                    float param_11 = _455.evolution + (3937.724853515625 * (_455.seed + 6.3379001617431640625));
                    float _816 = turbulence(param_8, param_9, param_10, param_11);
                    float q_1 = _816;
                    q_1 += (_455.offs - 0.25);
                    q_1 *= (_455.intensity * 2.0);
                    float cq = cos(q_1);
                    float sq = sin(q_1);
                    v += (fast::normalize(v - float2(0.5)) * p);
                    v *= float2x2(float2(cq, sq), float2(-sq, cq));
                }
                else
                {
                    if (_455.direction == 5)
                    {
                        float cq_1 = cos(p);
                        float sq_1 = sin(p);
                        v *= float2x2(float2(cq_1, sq_1), float2(-sq_1, cq_1));
                    }
                    else
                    {
                        v += (fast::normalize(v - float2(0.5)) * p);
                    }
                }
            }
        }
    }
    v -= uv;
    float2 texelSize = float2(1.0) / _455.refScreen.xy;
    float speed = length(v / texelSize);
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
    float2 param_12 = gl_FragCoord.xy / _455.refScreen.xy;
    float4 outColor = texture2DCv(refInput, refInputSmplr, param_12);
    float2 vnorm = (fast::normalize(v) * texelSize) * speed;
    float2 offsetScale = float2(1.0);
    if (_455.refScreen.y > _455.refScreen.x)
    {
        offsetScale.x *= (_455.refScreen.x / _455.refScreen.y);
    }
    else
    {
        offsetScale.y *= (_455.refScreen.y / _455.refScreen.x);
    }
    float2 ref_sample;
    for (int i = 1; i < nSamples; i++)
    {
        float2 offset = (vnorm * float(i)) / float2(float(nSamples - 1));
        offset *= offsetScale;
        if (_455.screenSpace != 0u)
        {
            ref_sample = gl_FragCoord.xy / _455.refScreen.xy;
        }
        else
        {
            ref_sample = (gl_FragCoord.xy - _455.refLayer.xy) / _455.refLayer.zw;
        }
        ref_sample += offset;
        if (!(_455.screenSpace != 0u))
        {
            ref_sample = (float4(ref_sample, 0.0, 1.0) * _455.refLayerToScreen).xy;
        }
        float2 param_13 = ref_sample;
        outColor += texture2DCv(refInput, refInputSmplr, param_13);
    }
    referenceColor = outColor / float4(float(nSamples));
}

fragment refAM35_eb9d2e1133709_out refAM35_eb9d2e1133709(constant ReferenceUniformseb9d2e1133709& _455 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb9d2e1133709_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_455, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1030 = any(isnan(referenceColor));
    bool _1037;
    if (!_1030)
    {
        _1037 = any(isinf(referenceColor));
    }
    else
    {
        _1037 = _1030;
    }
    if (_1037)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1050 = referenceColor;
    float3 _1056 = fast::clamp(_1050.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1056.x;
    referenceColor.y = _1056.y;
    referenceColor.z = _1056.z;
    out.finalColor = referenceColor;
    return out;
}

