// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/omino-glass.xml
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
//p = 1.-pow((1.-p),edgeexp);
//if(wrap > 0)
//    xy = mod(xy,acScreenSize);
// Flat
// Point Light
// Directonal Light
//result = vec4(slopeX,slopeY,0.5,1.0);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec8c20b043809
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float refraction;
    char _m7_pad[12];
    float aberration;
    char _m8_pad[12];
    float featureSize;
    char _m9_pad[12];
    float samples;
    float4 tintcolor;
    float blend;
    char _m12_pad[12];
    int shadingType;
    char _m13_pad[12];
    float lightIntensity;
    char _m14_pad[12];
    float lightShine;
    char _m15_pad[12];
    float lightSpec;
    char _m16_pad[12];
    float lightAmbient;
    float4 lightColor;
    float2 lightDir;
    char _m19_pad[8];
    float lightDepth;
    char _m20_pad[12];
    uint useLumaHeight;
    char _m21_pad[12];
    float roughness;
    char _m22_pad[12];
    float roughnessScale;
    char _m23_pad[12];
    float evolution;
    char _m24_pad[12];
    float seed;
};

struct refAM35_ec8c20b043809_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot2(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
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
    float param = 0.300000011920928955078125;
    float2x2 rr = rot2(param);
    for (int i = 0; i < OCTAVES; i++)
    {
        float3 param_1 = float3(st, evolution);
        value += (amplitude * abs(snoise(param_1)));
        st *= 2.0;
        st *= rr;
        st += parallax;
        amplitude *= 0.5;
    }
    return value;
}

static inline __attribute__((always_inline))
float sampleDistortLuma(thread const float2& p, texture2d<float> refBuffer2, sampler refBuffer2Smplr, constant ReferenceUniformsec8c20b043809& _527, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float2 param = p / _527.refScreen.xy;
    float4 samp = texture2DCv(refBuffer2, refBuffer2Smplr, param);
    float luma = dot(samp.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    if (_527.strength > 0.0)
    {
        float2 param_1 = p / _527.refScreen.xy;
        float4 blurSamp = texture2DCv(refBuffer1, refBuffer1Smplr, param_1);
        float p_1 = fast::min(blurSamp.w, samp.w);
        luma += p_1;
        luma *= smoothstep(0.5, 1.0, blurSamp.w);
    }
    return luma;
}

static inline __attribute__((always_inline))
float4 sampleLinearSrc(thread const float2& p, thread const float4& texColor, constant ReferenceUniformsec8c20b043809& _527, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float4 tc = (texColor * (1.0 - _527.tintcolor.w)) + (float4(_527.tintcolor.xyz, 1.0) * _527.tintcolor.w);
    float2 param = p / _527.refScreen.xy;
    float4 c = texture2DCv(refReference, refReferenceSmplr, param);
    c = mix(c, (tc / float4(fast::max(9.9999997473787516355514526367188e-05, tc.w))) * c, float4(_527.blend * tc.w));
    return c;
}

static inline __attribute__((always_inline))
float4 pluckColor(thread const float4& texColor, thread const float2& xy, thread const float4& rgb, constant ReferenceUniformsec8c20b043809& _527, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float2 param = xy;
    float4 param_1 = texColor;
    float4 c = sampleLinearSrc(param, param_1, _527, refReference, refReferenceSmplr);
    c *= rgb;
    return c;
}

static inline __attribute__((always_inline))
float4 chromatizePixel(thread const float2& xy, thread const float2& offset, thread const float4& texColor, constant ReferenceUniformsec8c20b043809& _527, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float4 result = float4(0.0);
    float4 param = texColor;
    float2 param_1 = xy - (offset * 1.5);
    float4 param_2 = float4(0.20000000298023223876953125, 0.0, 0.0, 0.20000000298023223876953125);
    result += pluckColor(param, param_1, param_2, _527, refReference, refReferenceSmplr);
    float4 param_3 = texColor;
    float2 param_4 = xy - offset;
    float4 param_5 = float4(0.300000011920928955078125, 0.0, 0.0, 0.20000000298023223876953125);
    result += pluckColor(param_3, param_4, param_5, _527, refReference, refReferenceSmplr);
    float4 param_6 = texColor;
    float2 param_7 = xy - (offset / float2(2.0));
    float4 param_8 = float4(0.5, 0.33329999446868896484375, 0.0, 0.20000000298023223876953125);
    result += pluckColor(param_6, param_7, param_8, _527, refReference, refReferenceSmplr);
    float4 param_9 = texColor;
    float2 param_10 = xy;
    float4 param_11 = float4(0.0, 0.3333300054073333740234375, 0.0, 0.20000000298023223876953125);
    result += pluckColor(param_9, param_10, param_11, _527, refReference, refReferenceSmplr);
    float4 param_12 = texColor;
    float2 param_13 = xy + (offset / float2(2.0));
    float4 param_14 = float4(0.0, 0.3333300054073333740234375, 0.5, 0.20000000298023223876953125);
    result += pluckColor(param_12, param_13, param_14, _527, refReference, refReferenceSmplr);
    float4 param_15 = texColor;
    float2 param_16 = xy + offset;
    float4 param_17 = float4(0.0, 0.0, 0.300000011920928955078125, 0.20000000298023223876953125);
    result += pluckColor(param_15, param_16, param_17, _527, refReference, refReferenceSmplr);
    float4 param_18 = texColor;
    float2 param_19 = xy + (offset * 1.5);
    float4 param_20 = float4(0.0, 0.0, 0.20000000298023223876953125, 0.20000000298023223876953125);
    result += pluckColor(param_18, param_19, param_20, _527, refReference, refReferenceSmplr);
    return result;
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformsec8c20b043809& _527)
{
    float3 lightPos = float3(_527.lightDir.x / 2.0, (-_527.lightDir.y) / 2.0, (-_527.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos - p);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformsec8c20b043809& _527)
{
    float3 lightPos = float3(_527.lightDir.x / 2.0, (-_527.lightDir.y) / 2.0, (-_527.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, constant ReferenceUniformsec8c20b043809& _527)
{
    float shine = _527.lightShine;
    float ambient = _527.lightAmbient;
    float spec = _527.lightSpec;
    float4 result = float4(0.0);
    if (_527.shadingType == 0)
    {
        result = texColor;
    }
    else
    {
        if (_527.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _527);
            float3 tc = texColor.xyz / float3(fast::max(texColor.w, 9.9999997473787516355514526367188e-05));
            float3 surface = (tc * ambient) + (((tc * _527.lightColor.xyz) * l) * (1.0 - ambient));
            surface *= _527.lightIntensity;
            float s = powr(l, spec);
            surface = mix(surface * (1.0 - (shine * 0.100000001490116119384765625)), float3(1.0), float3(shine * s));
            result = fast::clamp(float4(surface, 1.0), float4(0.0), float4(1.0)) * texColor.w;
        }
        else
        {
            if (_527.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _527);
                float3 tc_1 = texColor.xyz / float3(fast::max(texColor.w, 9.9999997473787516355514526367188e-05));
                float3 surface_1 = (tc_1 * ambient) + (((tc_1 * _527.lightColor.xyz) * l_1) * (1.0 - ambient));
                surface_1 *= _527.lightIntensity;
                float s_1 = powr(l_1, spec);
                surface_1 = mix(surface_1 * (1.0 - (shine * 0.100000001490116119384765625)), float3(1.0), float3(shine * s_1));
                result = fast::clamp(float4(surface_1, 1.0), float4(0.0), float4(1.0)) * texColor.w;
            }
        }
    }
    return result;
}

static inline __attribute__((always_inline))
float4 evaluatePixelXy(thread const float2& srcXy, thread const float4& texColor, texture2d<float> refBuffer2, sampler refBuffer2Smplr, constant ReferenceUniformsec8c20b043809& _527, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float2 _imageSize = _527.refScreen.xy;
    float2 slope = float2(0.0);
    float2 dx = float2(2.0, 0.0);
    float2 dy = float2(0.0, 2.0);
    float floatSamples = _527.samples;
    int intSamples = int(_527.samples);
    int _948 = -intSamples;
    for (int i = _948; i < intSamples; i++)
    {
        float n = float(i);
        float2 param = srcXy + (dx * (n - 0.5));
        float2 param_1 = (srcXy + (dx * n)) + float2(0.5);
        slope.x += (sampleDistortLuma(param, refBuffer2, refBuffer2Smplr, _527, refBuffer1, refBuffer1Smplr) - sampleDistortLuma(param_1, refBuffer2, refBuffer2Smplr, _527, refBuffer1, refBuffer1Smplr));
        float2 param_2 = srcXy + (dy * (n - 0.5));
        float2 param_3 = (srcXy + (dy * n)) + float2(0.5);
        slope.y += (sampleDistortLuma(param_2, refBuffer2, refBuffer2Smplr, _527, refBuffer1, refBuffer1Smplr) - sampleDistortLuma(param_3, refBuffer2, refBuffer2Smplr, _527, refBuffer1, refBuffer1Smplr));
    }
    slope /= float2(floatSamples);
    float3 p = float3(slope, -0.5);
    float3 n_1 = fast::normalize(p);
    float2 sourceXy = srcXy + ((slope * _527.featureSize) * _527.refraction);
    float2 aberrXy = (slope * _527.featureSize) * _527.aberration;
    float2 param_4 = sourceXy;
    float2 param_5 = aberrXy;
    float4 param_6 = texColor;
    float4 result = chromatizePixel(param_4, param_5, param_6, _527, refReference, refReferenceSmplr);
    result.w = 1.0;
    result = fast::clamp(result, float4(0.0), float4(1.0));
    float4 param_7 = result;
    float3 param_8 = p;
    float3 param_9 = n_1;
    return applyShading(param_7, param_8, param_9, _527);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refBuffer2, sampler refBuffer2Smplr, constant ReferenceUniformsec8c20b043809& _527, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refReference, sampler refReferenceSmplr, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _527.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    if (as_type<int>(_527.refComposition.z) == 1)
    {
        float4 result = texColor;
        if (!(_527.useLumaHeight != 0u))
        {
            float _1091 = result.w;
            float3 _1092 = float3(_1091);
            result.x = _1092.x;
            result.y = _1092.y;
            result.z = _1092.z;
        }
        if (abs(_527.roughness) > 9.9999997473787516355514526367188e-05)
        {
            float2 st = (gl_FragCoord.xy - _527.refLayer.xy) / _527.refLayer.zw;
            st.x *= (_527.refLayer.z / _527.refLayer.w);
            float scale = 0.1500000059604644775390625 * _527.roughnessScale;
            int OCTAVES = 2;
            float2 parallax = float2(0.0);
            float p;
            if (_527.roughness < 0.0)
            {
                float2 param_1 = ((st - float2(0.5)) / float2(scale)) + float2(0.5);
                int param_2 = OCTAVES;
                float2 param_3 = parallax;
                float param_4 = _527.evolution + (7391.93505859375 * _527.seed);
                float _1163 = turbulence(param_1, param_2, param_3, param_4);
                p = _1163 * ((-_527.roughness) / 3.0);
            }
            else
            {
                float2 param_5 = ((st - float2(0.5)) / float2(scale)) + float2(0.5);
                int param_6 = OCTAVES;
                float2 param_7 = parallax;
                float param_8 = _527.evolution + (7391.93505859375 * _527.seed);
                float _1191 = turbulence(param_5, param_6, param_7, param_8);
                p = (1.0 - _1191) * (_527.roughness / 3.0);
            }
            float4 _1199 = result;
            float3 _1201 = _1199.xyz * (1.0 - p);
            result.x = _1201.x;
            result.y = _1201.y;
            result.z = _1201.z;
        }
        referenceColor = result;
    }
    else
    {
        float2 param_9 = (gl_FragCoord.xy / _527.refScreen.xy) * _527.refScreen.xy;
        float4 param_10 = texColor;
        referenceColor = evaluatePixelXy(param_9, param_10, refBuffer2, refBuffer2Smplr, _527, refBuffer1, refBuffer1Smplr, refReference, refReferenceSmplr) * texColor.w;
    }
}

fragment refAM35_ec8c20b043809_out refAM35_ec8c20b043809(constant ReferenceUniformsec8c20b043809& _527 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refBuffer2 [[texture(2)]], texture2d<float> refReference [[texture(3)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refBuffer2Smplr [[sampler(2)]], sampler refReferenceSmplr [[sampler(3)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec8c20b043809_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refBuffer2, refBuffer2Smplr, _527, refBuffer1, refBuffer1Smplr, refReference, refReferenceSmplr, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _1233 = any(isnan(referenceColor));
    bool _1240;
    if (!_1233)
    {
        _1240 = any(isinf(referenceColor));
    }
    else
    {
        _1240 = _1233;
    }
    if (_1240)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1253 = referenceColor;
    float3 _1259 = fast::clamp(_1253.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1259.x;
    referenceColor.y = _1259.y;
    referenceColor.z = _1259.z;
    out.finalColor = referenceColor;
    return out;
}

