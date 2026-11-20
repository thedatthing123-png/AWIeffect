// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/warped_noise_field.xml
// Original source comments and attribution:
// Warped noise field, approximating os2NoiseWithDerivatives_ImproveXY via
// simplex noise + finite-difference derivatives.
/* 3D Simplex noise from IQ (public domain-ish) */
// First corner
// Other corners
//  x0 = x0 - 0.0 + 0.0 * C.xxx;
// Permutations
// Gradients: 7x7 points over a square, mapped onto an octahedron.
// 1.0/7.0
// Normalise gradients
// Mix contributions from the four corners
// Approximate derivatives by finite differences
// convert back to pixel space
// tan(60)/? factor from source
// First evaluation
// Warped evaluation
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

struct ReferenceUniformse093cdee083c0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float scale;
    char _m6_pad[12];
    float time;
    char _m7_pad[12];
    float speed;
    char _m8_pad[12];
    float warpAmount;
    char _m9_pad[12];
    float eps;
    float4 baseColor;
    uint blendSource;
};

struct refAM35_e093cdee083c0_out
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
    float3 x3 = (x0 - float3(1.0)) + float3(0.5);
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
float4 snoiseWithDerivatives(thread const float3& p, thread const float& e)
{
    float3 param = p;
    float n = snoise(param);
    float3 ex = float3(e, 0.0, 0.0);
    float3 ey = float3(0.0, e, 0.0);
    float3 ez = float3(0.0, 0.0, e);
    float3 param_1 = p + ex;
    float3 param_2 = p - ex;
    float nx = snoise(param_1) - snoise(param_2);
    float3 param_3 = p + ey;
    float3 param_4 = p - ey;
    float ny = snoise(param_3) - snoise(param_4);
    float3 param_5 = p + ez;
    float3 param_6 = p - ez;
    float nz = snoise(param_5) - snoise(param_6);
    float3 d = float3(nx, ny, nz) / float3(2.0 * e);
    return float4(d, n);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse093cdee083c0& _481, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 res = _481.refScreen.xy;
    float m = fast::max(res.x, res.y);
    float2 frag = (gl_FragCoord.xy / _481.refScreen.xy) * res;
    float2 uv = (frag / float2(m)) * _481.scale;
    float t = mod(_481.time * _481.speed, 578.0) * 0.866025388240814208984375;
    float3 X = float3(uv, t);
    float3 param = X;
    float param_1 = _481.eps;
    float4 nr = snoiseWithDerivatives(param, param_1);
    float3 param_2 = X - (nr.xyz * _481.warpAmount);
    float param_3 = _481.eps;
    nr = snoiseWithDerivatives(param_2, param_3);
    float value = nr.w;
    float3 col = _481.baseColor.xyz * (0.5 + (0.5 * value));
    float4 outC = float4(col, 1.0);
    if (_481.blendSource != 0u)
    {
        float2 param_4 = gl_FragCoord.xy / _481.refScreen.xy;
        float4 src = texture2DCv(refInput, refInputSmplr, param_4);
        float4 _592 = outC;
        float3 _594 = _592.xyz * src.xyz;
        outC.x = _594.x;
        outC.y = _594.y;
        outC.z = _594.z;
        outC.w = 1.0;
    }
    referenceColor = outC;
}

fragment refAM35_e093cdee083c0_out refAM35_e093cdee083c0(constant ReferenceUniformse093cdee083c0& _481 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e093cdee083c0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_481, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _609 = any(isnan(referenceColor));
    bool _616;
    if (!_609)
    {
        _616 = any(isinf(referenceColor));
    }
    else
    {
        _616 = _609;
    }
    if (_616)
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

