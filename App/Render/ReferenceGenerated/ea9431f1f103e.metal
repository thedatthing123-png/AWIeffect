// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/colormatch.xml
// Original source comments and attribution:
// Color Transfer (Reinhard-like mean/std match in YUV) with min/max contrast match
// - AM official style: fixed loops, only builtins, no derivatives
// Grid sampling over both source and reference to estimate stats
// 8x8 = 64 taps
// simple skip pattern without bitwise ops
// optional subsample skip (checkerboard) using mod on floats
// stratified jitter using uv to reduce shimmer
// Current pixel in YUV
// Contrast match via min/max (on Y only)
// partial blend to avoid clipping
// Mean/std transfer
// Luma/chroma split
// keep original luma
// Chroma strength
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

struct ReferenceUniformsea9431f1f103e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint useLayerBelow;
    char _m6_pad[12];
    float strength;
    char _m7_pad[12];
    float chromaStrength;
    char _m8_pad[12];
    uint preserveLuma;
    char _m9_pad[12];
    uint matchContrast;
    char _m10_pad[12];
    uint halfSamples;
    char _m11_pad[12];
    float alpha;
};

struct refAM35_ea9431f1f103e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 rgb2yuv(thread const float3& c)
{
    float y = dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float u = c.z - y;
    float v = c.x - y;
    return float3(y, u, v);
}

static inline __attribute__((always_inline))
void accumStats(thread const float3& c, thread float3& sum, thread float3& sum2, thread float3& minv, thread float3& maxv)
{
    sum += c;
    sum2 += (c * c);
    minv = fast::min(minv, c);
    maxv = fast::max(maxv, c);
}

static inline __attribute__((always_inline))
float3 yuv2rgb(thread const float3& yuv)
{
    float y = yuv.x;
    float u = yuv.y;
    float v = yuv.z;
    float r = v + y;
    float b = u + y;
    float g = ((y - (0.2125999927520751953125 * r)) - (0.072200000286102294921875 * b)) / 0.715200006961822509765625;
    return fast::clamp(float3(r, g, b), float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsea9431f1f103e& _129, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _129.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 cSrc = src.xyz;
    bool halfFlag = _129.halfSamples != 0u;
    float3 sumS = float3(0.0);
    float3 sum2S = float3(0.0);
    float3 minS = float3(1000000000.0);
    float3 maxS = float3(-1000000000.0);
    float3 sumR = float3(0.0);
    float3 sum2R = float3(0.0);
    float3 minR = float3(1000000000.0);
    float3 maxR = float3(-1000000000.0);
    int count = 0;
    float3 r;
    for (int y = 0; y < 8; y++)
    {
        for (int x = 0; x < 8; x++)
        {
            bool _197;
            if (halfFlag)
            {
                _197 = mod(float(x + y), 2.0) > 0.5;
            }
            else
            {
                _197 = halfFlag;
            }
            if (_197)
            {
                continue;
            }
            float2 p = float2(float(x) + 0.5, float(y) + 0.5) / float2(8.0);
            float2 jitter = uv * 0.001000000047497451305389404296875;
            p = fast::clamp(p + jitter, float2(0.0), float2(1.0));
            float2 param_1 = p;
            float3 s = texture2DCv(refInput, refInputSmplr, param_1).xyz;
            if (_129.useLayerBelow != 0u)
            {
                float2 param_2 = p;
                r = texture2DCv(refReference, refReferenceSmplr, param_2).xyz;
            }
            else
            {
                float2 param_3 = p;
                r = texture2DCv(refInput, refInputSmplr, param_3).xyz;
            }
            float3 param_4 = s;
            float3 param_5 = rgb2yuv(param_4);
            float3 param_6 = sumS;
            float3 param_7 = sum2S;
            float3 param_8 = minS;
            float3 param_9 = maxS;
            accumStats(param_5, param_6, param_7, param_8, param_9);
            sumS = param_6;
            sum2S = param_7;
            minS = param_8;
            maxS = param_9;
            float3 param_10 = r;
            float3 param_11 = rgb2yuv(param_10);
            float3 param_12 = sumR;
            float3 param_13 = sum2R;
            float3 param_14 = minR;
            float3 param_15 = maxR;
            accumStats(param_11, param_12, param_13, param_14, param_15);
            sumR = param_12;
            sum2R = param_13;
            minR = param_14;
            maxR = param_15;
            count++;
        }
    }
    float fcount = float(count);
    float3 meanS = sumS / float3(fast::max(fcount, 1.0));
    float3 meanR = sumR / float3(fast::max(fcount, 1.0));
    float3 varS = fast::max((sum2S / float3(fast::max(fcount, 1.0))) - (meanS * meanS), float3(0.0));
    float3 varR = fast::max((sum2R / float3(fast::max(fcount, 1.0))) - (meanR * meanR), float3(0.0));
    float3 stdS = sqrt(varS + float3(9.9999999747524270787835121154785e-07));
    float3 stdR = sqrt(varR + float3(9.9999999747524270787835121154785e-07));
    float3 param_16 = cSrc;
    float3 yuvS = rgb2yuv(param_16);
    float3 yuv = yuvS;
    if (_129.matchContrast != 0u)
    {
        float yMinS = minS.x;
        float yMaxS = maxS.x;
        float yMinR = minR.x;
        float yMaxR = maxR.x;
        float yNorm = (yuv.x - yMinS) / fast::max(yMaxS - yMinS, 9.9999997473787516355514526367188e-06);
        float yMatched = mix(yMinR, yMaxR, fast::clamp(yNorm, 0.0, 1.0));
        yuv.x = mix(yuv.x, yMatched, 0.699999988079071044921875);
    }
    float3 z = (yuv - meanS) / stdS;
    float3 yuvT = (z * stdR) + meanR;
    if (_129.preserveLuma != 0u)
    {
        yuvT.x = yuvS.x;
    }
    float3 _401 = yuvT;
    float2 _408 = mix(yuvS.yz, _401.yz, float2(_129.chromaStrength));
    yuvT.y = _408.x;
    yuvT.z = _408.y;
    float3 param_17 = yuvT;
    float3 cMatch = yuv2rgb(param_17);
    float3 outRGB = mix(cSrc, cMatch, float3(_129.strength));
    float aOut = src.w * _129.alpha;
    referenceColor = float4(outRGB, 1.0) * aOut;
}

fragment refAM35_ea9431f1f103e_out refAM35_ea9431f1f103e(constant ReferenceUniformsea9431f1f103e& _129 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea9431f1f103e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _129, refInput, refInputSmplr, refReference, refReferenceSmplr, referenceColor);
    bool _447 = any(isnan(referenceColor));
    bool _454;
    if (!_447)
    {
        _454 = any(isinf(referenceColor));
    }
    else
    {
        _454 = _447;
    }
    if (_454)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _467 = referenceColor;
    float3 _473 = fast::clamp(_467.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _473.x;
    referenceColor.y = _473.y;
    referenceColor.z = _473.z;
    out.finalColor = referenceColor;
    return out;
}

