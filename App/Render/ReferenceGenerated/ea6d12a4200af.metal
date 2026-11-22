// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/electricedges.xml
// Original source comments and attribution:
// 2D multiplanar sharp noise, loosely based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
// Four corners in 2D of a tile
// Smooth Interpolation
// Cubic Hermine Curve.  Same as SmoothStep()
//vec2 u = f*f*(3.0-2.0*f);
// u = smoothstep(0.,1.,f);
// Sharp interpolation
// Mix 4 coorners percentages
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
// Initial values
//
// Loop of octaves
//float dist = distance + distOffs; //*rr;
//float pp = smoothstep(dist+th, dist, p) * smoothstep(dist-th, dist, p);
//float lines = saturate(sin((st2.y+contourOffset) * contourCount)) * smoothstep(0.1,0.2,blurTexColorMid.a);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea6d12a4200af
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float _distance;
    char _m6_pad[12];
    float thickness;
    char _m7_pad[12];
    float complexity;
    char _m8_pad[12];
    float disort;
    float4 color1;
    float4 color2;
    float alpha;
    char _m12_pad[12];
    float glowAlpha;
    char _m13_pad[12];
    float seed;
    char _m14_pad[12];
    float evolution;
    char _m15_pad[12];
    float fill;
    char _m16_pad[12];
    float maskStrength;
    char _m17_pad[12];
    float maskEvolution;
    char _m18_pad[12];
    float maskScale;
    char _m19_pad[12];
    float maskSeed;
    float4 maskColor;
    uint renderContours;
    char _m22_pad[12];
    float contourCount;
    char _m23_pad[12];
    float contourOffset;
    char _m24_pad[12];
    float contourAngle;
};

struct refAM35_ea6d12a4200af_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rot2d(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, s), float2(-s, c));
}

static inline __attribute__((always_inline))
float2 random2(thread const float2& p)
{
    return fract(sin(float2(dot(p, float2(127.09999847412109375, 311.70001220703125)), dot(p, float2(269.5, 183.3000030517578125)))) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 _noise(thread const float2& st)
{
    float2 i = floor(st);
    float2 f = fract(st);
    float2 param = i;
    float2 a = random2(param);
    float2 param_1 = i + float2(1.0, 0.0);
    float2 b = random2(param_1);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 c = random2(param_2);
    float2 param_3 = i + float2(1.0);
    float2 d = random2(param_3);
    float2 u = f;
    return (mix(a, b, float2(u.x)) + (((c - a) * u.y) * (1.0 - u.x))) + (((d - b) * u.x) * u.y);
}

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
float saturate0(thread const float& v)
{
    return fast::clamp(v, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float4 saturate0(thread const float4& v)
{
    return fast::clamp(v, float4(0.0), float4(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsea6d12a4200af& _581, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float2 st = (gl_FragCoord.xy - _581.refLayer.xy) / _581.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_581.refLayer.z / _581.refLayer.w);
    float2 evoseed = (float2(3.0) * _581.evolution) + (float2(62.5587005615234375, 137.1934967041015625) * _581.seed);
    float2 pixelSize = float2(1.0) / _581.refScreen.xy;
    float param = 0.100000001490116119384765625;
    float2 param_1 = evoseed + (((st * rot2d(param)) * 2.0) * _581.complexity);
    float2 l1 = _noise(param_1);
    float param_2 = 0.300000011920928955078125;
    float2 param_3 = evoseed + (((st * rot2d(param_2)) * 4.0) * _581.complexity);
    float2 l2 = _noise(param_3);
    float param_4 = 1.41999995708465576171875;
    float2 param_5 = evoseed + (((st * rot2d(param_4)) * 8.0) * _581.complexity);
    float2 l3 = _noise(param_5);
    float param_6 = 2.533999919891357421875;
    float2 param_7 = evoseed + (((st * rot2d(param_6)) * 16.0) * _581.complexity);
    float2 l4 = _noise(param_7);
    float2 offs = abs(abs(l1 - l2) - abs(l3 - l4));
    float2 param_8 = gl_FragCoord.xy / _581.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_8);
    float2 param_9 = gl_FragCoord.xy / _581.refScreen.xy;
    float4 blurTexColorMid = texture2DCv(refBuffer1, refBuffer1Smplr, param_9);
    float2 param_10 = (gl_FragCoord.xy / _581.refScreen.xy) + (pixelSize * float2(0.0, -4.0));
    float4 blurTexColorUp = texture2DCv(refBuffer1, refBuffer1Smplr, param_10);
    float2 param_11 = (gl_FragCoord.xy / _581.refScreen.xy) + (pixelSize * float2(-4.0, 0.0));
    float4 blurTexColorLeft = texture2DCv(refBuffer1, refBuffer1Smplr, param_11);
    float2 param_12 = gl_FragCoord.xy / _581.refScreen.xy;
    float4 compColor = texture2DCv(refReference, refReferenceSmplr, param_12);
    float dx = blurTexColorMid.w - blurTexColorLeft.w;
    float dy = blurTexColorMid.w - blurTexColorUp.w;
    float2 norm = fast::normalize(float2(dx, dy));
    float2 param_13 = (gl_FragCoord.xy / _581.refScreen.xy) + ((norm * length(offs)) * (_581.disort * 0.054999999701976776123046875));
    float4 blurTexColor = texture2DCv(refBuffer1, refBuffer1Smplr, param_13);
    float2 param_14 = ((st - float2(0.5)) / float2(_581.maskScale)) + float2(0.5);
    int param_15 = 3;
    float2 param_16 = float2(0.0);
    float param_17 = _581.maskEvolution + (91.93499755859375 * _581.maskSeed);
    float _815 = turbulence(param_14, param_15, param_16, param_17);
    float turbBase = _815;
    float TINT_RANGE = 0.0199999995529651641845703125;
    float turb = smoothstep(_581.maskStrength - (TINT_RANGE + 0.20000000298023223876953125), _581.maskStrength - (TINT_RANGE + 0.100000001490116119384765625), turbBase);
    float suppress = smoothstep(_581.maskStrength - (TINT_RANGE + 0.100000001490116119384765625), _581.maskStrength - TINT_RANGE, turbBase);
    float ttint = smoothstep(_581.maskStrength - TINT_RANGE, _581.maskStrength - 0.001000000047497451305389404296875, turbBase);
    float p = blurTexColor.w;
    float dist = 1.0 - ((_581._distance * 0.4000000059604644775390625) + 0.5);
    float pp = powr(1.0 - abs(p - dist), (1.0 - ((_581.thickness * 0.89999997615814208984375) * suppress)) * 30.0);
    pp *= smoothstep(0.00999999977648258209228515625, 0.119999997317790985107421875, p);
    pp *= smoothstep(1.0, 0.999000012874603271484375, p);
    float qq = powr(1.0 - abs(p - dist), (1.0 - ((_581.thickness * 0.89999997615814208984375) * suppress)) * 25.0);
    qq *= smoothstep(0.00999999977648258209228515625, 0.119999997317790985107421875, p);
    qq *= smoothstep(1.0, 0.999000012874603271484375, p);
    if (_581.renderContours != 0u)
    {
        float arad = _581.contourAngle * 0.01745329983532428741455078125;
        float2 st2 = st;
        st2.y += (blurTexColorMid.w * 0.100000001490116119384765625);
        float param_18 = (length((offs * _581.disort) * 1.10000002384185791015625) * 0.20000000298023223876953125) + arad;
        st2 *= rot2d(param_18);
        st2.y += (blurTexColorMid.w * 0.100000001490116119384765625);
        float param_19 = sin(((st2.y + _581.contourOffset) + ((offs.y * _581.disort) * 0.014999999664723873138427734375)) * _581.contourCount);
        float lines = saturate0(param_19) * smoothstep(0.100000001490116119384765625, 0.20000000298023223876953125, blurTexColorMid.w);
        pp += powr(lines, (1.0 - ((_581.thickness * 0.89999997615814208984375) * suppress)) * 30.0);
        qq += powr(lines, (1.0 - ((_581.thickness * 0.89999997615814208984375) * suppress)) * 25.0);
    }
    float4 c0 = float4(powr(float3(pp), float3(1.0) / _581.color1.xyz), pp) * _581.alpha;
    float4 c1 = float4(powr(float3(qq), float3(1.0) / _581.color2.xyz), qq) * _581.glowAlpha;
    float4 param_20 = c0 + c1;
    float4 c = saturate0(param_20);
    c *= (mix(_581.maskColor, float4(1.0), float4(ttint)) * turb);
    referenceColor = ((texColor * _581.fill) * (1.0 - c.w)) + c;
}

fragment refAM35_ea6d12a4200af_out refAM35_ea6d12a4200af(constant ReferenceUniformsea6d12a4200af& _581 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refReference [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refReferenceSmplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea6d12a4200af_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _581, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr, refReference, refReferenceSmplr, referenceColor);
    bool _1081 = any(isnan(referenceColor));
    bool _1088;
    if (!_1081)
    {
        _1088 = any(isinf(referenceColor));
    }
    else
    {
        _1088 = _1081;
    }
    if (_1088)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1101 = referenceColor;
    float3 _1107 = fast::clamp(_1101.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1107.x;
    referenceColor.y = _1107.y;
    referenceColor.z = _1107.z;
    out.finalColor = referenceColor;
    return out;
}

