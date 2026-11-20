// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/turbulence2.xml
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
//rcolor *= texColor.a;
//gl_FragColor = rcolor + texColor*(1.0-rcolor.a);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef1a32c8ec2aa
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 parr;
    char _m6_pad[8];
    float2 offs;
    char _m7_pad[8];
    float evolution;
    char _m8_pad[12];
    float scale;
    char _m9_pad[8];
    float2 stretch;
    char _m10_pad[8];
    float intensity;
    char _m11_pad[12];
    float seed;
    float4 color1;
    float4 color2;
    float alpha;
    char _m15_pad[12];
    int blendMode;
    char _m16_pad[12];
    float bias0;
    char _m17_pad[12];
    float octaves;
};

struct refAM35_ef1a32c8ec2aa_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsef1a32c8ec2aa& _461, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _461.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _461.refLayer.xy) / _461.refLayer.zw;
    st.x *= (_461.refLayer.z / _461.refLayer.w);
    st += ((_461.offs * float2(-1.0, 1.0)) / float2(500.0));
    float2 parallax = (_461.parr * float2(-1.0, 1.0)) / float2(100.0);
    float2 scaleVec = float2(_461.scale * _461.stretch.y, _461.scale * _461.stretch.x);
    float2 param_1 = ((st - float2(0.5)) / scaleVec) + float2(0.5);
    int param_2 = int(_461.octaves);
    float2 param_3 = parallax;
    float param_4 = _461.evolution + (7391.93505859375 * _461.seed);
    float _550 = turbulence(param_1, param_2, param_3, param_4);
    float p = _550 * _461.intensity;
    p = fast::clamp(p + _461.bias0, 0.0, 1.0);
    float4 rcolor = mix(_461.color1, _461.color2, float4(p));
    float4 result;
    if (_461.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(texColor.w)) * rcolor.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_461.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - rcolor.xyz)), 1.0) * texColor.w;
        }
        else
        {
            result = float4(rcolor.xyz, 1.0) * texColor.w;
        }
    }
    referenceColor = mix(texColor, result, float4(_461.alpha));
}

fragment refAM35_ef1a32c8ec2aa_out refAM35_ef1a32c8ec2aa(constant ReferenceUniformsef1a32c8ec2aa& _461 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef1a32c8ec2aa_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _461, referenceColor);
    bool _647 = any(isnan(referenceColor));
    bool _654;
    if (!_647)
    {
        _654 = any(isinf(referenceColor));
    }
    else
    {
        _654 = _647;
    }
    if (_654)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    out.finalColor = referenceColor;
    return out;
}

