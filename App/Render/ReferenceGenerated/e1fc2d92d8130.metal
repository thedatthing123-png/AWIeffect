// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/ridges2.xml
// Original source comments and attribution:
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
//float turbulence (in vec2 st, in int OCTAVES, in vec2 parallax) {
//    // Initial values
//    float value = 0.0;
//    float amplitude = .5;
//    float frequency = 0.;
//    //
//    // Loop of octaves
//    for (int i = 0; i < OCTAVES; i++) {
//        value += amplitude * abs(snoise(st));
//        st *= 2.;
//        st += parallax;
//        amplitude *= .5;
//    }
//    return value;
//}
// create creases
// invert so creases are at top
// sharpen creases
// scale by previous octave
//vec2(offsx,offsy);
//vec2(parrx, parry);
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

struct ReferenceUniformse1fc2d92d8130
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
    float octaves;
};

struct refAM35_e1fc2d92d8130_out
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
float ridge(thread float& h, thread const float& offset)
{
    h = abs(h);
    h = offset - h;
    h *= h;
    return h;
}

static inline __attribute__((always_inline))
float ridgedMF(thread float2& p, thread const int& OCTAVES, thread const float2& parallax, thread const float& evo)
{
    float lacunarity = 2.0;
    float gain = 0.5;
    float offset = 0.89999997615814208984375;
    float sum = 0.0;
    float freq = 1.0;
    float amp = 0.5;
    float prev = 1.0;
    for (int i = 0; i < OCTAVES; i++)
    {
        float3 param = float3(p * freq, evo);
        float param_1 = snoise(param);
        float param_2 = offset;
        float _461 = ridge(param_1, param_2);
        float n = _461;
        sum += (n * amp);
        sum += ((n * amp) * prev);
        prev = n;
        freq *= lacunarity;
        p += parallax;
        amp *= gain;
    }
    return sum;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse1fc2d92d8130& _499, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _499.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _499.refLayer.xy) / _499.refLayer.zw;
    st.x *= (_499.refLayer.z / _499.refLayer.w);
    st += ((_499.offs * float2(-1.0, 1.0)) / float2(500.0));
    st += mod(float2(821.9210205078125 * _499.seed, 437.316986083984375 * _499.seed), float2(4.3649997711181640625, 7.701000213623046875));
    float2 parallax = (_499.parr * float2(-1.0, 1.0)) / float2(100.0);
    float2 scaleVec = float2(_499.scale * _499.stretch.x, _499.scale * _499.stretch.y);
    float2 param_1 = ((st - float2(0.5)) / scaleVec) + float2(0.5);
    int param_2 = int(_499.octaves);
    float2 param_3 = parallax;
    float param_4 = _499.evolution;
    float _598 = ridgedMF(param_1, param_2, param_3, param_4);
    float p = _598 * _499.intensity;
    float4 rcolor = mix(_499.color1, _499.color2, float4(p));
    rcolor *= texColor.w;
    referenceColor = rcolor + (texColor * (1.0 - rcolor.w));
}

fragment refAM35_e1fc2d92d8130_out refAM35_e1fc2d92d8130(constant ReferenceUniformse1fc2d92d8130& _499 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e1fc2d92d8130_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _499, referenceColor);
    bool _630 = any(isnan(referenceColor));
    bool _637;
    if (!_630)
    {
        _637 = any(isinf(referenceColor));
    }
    else
    {
        _637 = _630;
    }
    if (_637)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _650 = referenceColor;
    float3 _656 = fast::clamp(_650.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _656.x;
    referenceColor.y = _656.y;
    referenceColor.z = _656.z;
    out.finalColor = referenceColor;
    return out;
}

