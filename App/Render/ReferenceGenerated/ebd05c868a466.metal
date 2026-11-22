// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/shatter_voronoi_mp.xml
// Original source comments and attribution:
// Voronoi Shatter Multi‑Pass
// Pass 0: compute shattered image into shatterPass (RGB) and write edge mask to alpha
// Pass 1: extract edge mask from shatterPass.a into edgeMask (downsampled)
// Pass 2: horizontal blur edgeMask -> hblur
// Pass 3: vertical blur hblur -> vblur
// Pass 4: composite shatterPass + edge glow (vblur * edgeColor * edgeGlow)
// Hash helpers
// Rot2
// Voronoi: return nearest distance and ID; also second-nearest distance for edge width
// jittered cell point
// Simple separable blur (incremental Gaussian) on edge mask
// Shatter & edge mask in alpha
// content UV
// Keep isotropy
// Voronoi sites
// in cell space
// World site position (normalize to uv space)
// Cell random direction and angle
// Gravity (down in uv-y)
// Inverse transform: map current pixel back to source space of its cell
// undo rotation
// undo translation
// Undo aspect for sampling
// Edge metric from difference of nearest and 2nd nearest distances
// Extract edge mask from shatterPass alpha and write to edgeMask
// Horizontal blur edge mask
// Vertical blur
// Final composite
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL radians() function
template<typename T>
inline T radians(T d)
{
    return d * T(0.01745329251);
}

struct ReferenceUniformsebd05c868a466
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progress;
    char _m6_pad[12];
    float cellScale;
    char _m7_pad[12];
    float randomness;
    char _m8_pad[12];
    float scatter;
    char _m9_pad[12];
    float rotAmount;
    char _m10_pad[12];
    float gravity;
    char _m11_pad[12];
    float edgeWidth;
    char _m12_pad[12];
    float edgeFeather;
    float4 edgeColor;
    float edgeGlow;
    char _m15_pad[12];
    int quality;
    char _m16_pad[12];
    uint glowOnly;
};

struct refAM35_ebd05c868a466_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash21(thread const float2& p)
{
    return fract((10000.0 * sin((17.0 * p.x) + (0.100000001490116119384765625 * p.y))) * (0.100000001490116119384765625 + abs(sin((13.0 * p.y) + (7.0 * p.x)))));
}

static inline __attribute__((always_inline))
float hash11(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

static inline __attribute__((always_inline))
float4 voronoi(thread const float2& uv, thread const float& cellScale, thread const float& randAmt)
{
    float2 g = uv * cellScale;
    float2 i = floor(g);
    float2 f = fract(g);
    float d1 = 1000000000.0;
    float2 id1 = float2(0.0);
    float d2 = 1000000000.0;
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float2 o = float2(float(x), float(y));
            float2 h = i + o;
            float2 param = h;
            float s = hash21(param);
            float param_1 = s * 91.6999969482421875;
            float2 p = fract(float2(s, hash11(param_1)) + float2(randAmt * 0.60000002384185791015625));
            float2 diff = (o + p) - f;
            float d = dot(diff, diff);
            if (d < d1)
            {
                d2 = d1;
                d1 = d;
                id1 = h + p;
            }
            else
            {
                if (d < d2)
                {
                    d2 = d;
                }
            }
        }
    }
    return float4(d1, d2, id1);
}

static inline __attribute__((always_inline))
float2x2 r2(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 blurInternal(texture2d<float> tex, sampler texSmplr, thread const float2& texOffset, thread const float2& st, thread const float& numBlurPixelsPerSide)
{
    float adjSigma = numBlurPixelsPerSide / 2.145966053009033203125;
    float3 incG;
    incG.x = 1.0 / (2.5066282749176025390625 * fast::max(adjSigma, 9.9999997473787516355514526367188e-05));
    incG.y = exp((-0.5) / (fast::max(adjSigma, 9.9999997473787516355514526367188e-05) * fast::max(adjSigma, 9.9999997473787516355514526367188e-05)));
    incG.z = incG.y * incG.y;
    float2 param = st;
    float4 avg = texture2DCv(tex, texSmplr, param) * incG.x;
    float sum = incG.x;
    for (float i = 1.0; i <= 32.0; i += 2.0)
    {
        float o0 = i;
        float o1 = i + 1.0;
        float3 _266 = incG;
        float3 _268 = incG;
        float2 _270 = _268.xy * _266.yz;
        incG.x = _270.x;
        incG.y = _270.y;
        float w0 = incG.x;
        float3 _278 = incG;
        float3 _280 = incG;
        float2 _282 = _280.xy * _278.yz;
        incG.x = _282.x;
        incG.y = _282.y;
        float w1 = incG.x;
        float w = w0 + w1;
        float off = ((o0 * w0) + (o1 * w1)) / fast::max(w, 9.9999999747524270787835121154785e-07);
        float2 o = texOffset * off;
        float2 param_1 = st - o;
        avg += (texture2DCv(tex, texSmplr, param_1) * w);
        float2 param_2 = st + o;
        avg += (texture2DCv(tex, texSmplr, param_2) * w);
        sum += (2.0 * w);
        if (i > numBlurPixelsPerSide)
        {
            break;
        }
    }
    return avg / float4(fast::max(sum, 9.9999999747524270787835121154785e-07));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsebd05c868a466& _352, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr, texture2d<float> refBuffer3, sampler refBuffer3Smplr, texture2d<float> refBuffer4, sampler refBuffer4Smplr)
{
    int Q = _352.quality;
    float _360;
    if (Q == 1)
    {
        _360 = 6.0;
    }
    else
    {
        _360 = (Q == 2) ? 10.0 : 14.0;
    }
    float taps = _360;
    if (as_type<int>(_352.refComposition.z) == 0)
    {
        float2 uv = (gl_FragCoord.xy - _352.refLayer.xy) / _352.refLayer.zw;
        uv.x *= (_352.refLayer.z / _352.refLayer.w);
        float2 param = uv;
        float param_1 = _352.cellScale;
        float param_2 = _352.randomness;
        float4 v = voronoi(param, param_1, param_2);
        float d1 = sqrt(v.x);
        float d2 = sqrt(v.y);
        float2 site = v.zw;
        float2 siteUV = site / float2(_352.cellScale);
        float2 param_3 = floor(site);
        float sid = hash21(param_3);
        float2 dir = fast::normalize(float2(cos(sid * 6.283100128173828125), sin(sid * 6.283100128173828125)) + float2(0.001000000047497451305389404296875));
        float ang = (radians(_352.rotAmount) * _352.progress) * ((sid * 2.0) - 1.0);
        float2 grav = float2(0.0, (_352.gravity * _352.progress) * _352.progress);
        float2 T = ((dir * _352.scatter) * _352.progress) + grav;
        float2 p = uv - siteUV;
        float param_4 = -ang;
        p = r2(param_4) * p;
        p -= T;
        float2 sampleUV = p + siteUV;
        sampleUV.x /= (_352.refLayer.z / _352.refLayer.w);
        float2 param_5 = (float4(sampleUV, 0.0, 1.0) * _352.refLayerToScreen).xy;
        float4 src = texture2DCv(refInput, refInputSmplr, param_5);
        float e = fast::clamp(((d2 - d1) * _352.cellScale) * _352.edgeWidth, 0.0, 1.0);
        float edgeMask = 1.0 - smoothstep(0.0, _352.edgeFeather, e);
        referenceColor = float4(src.xyz, edgeMask * src.w);
        return;
    }
    if (as_type<int>(_352.refComposition.z) == 1)
    {
        float2 param_6 = gl_FragCoord.xy / _352.refScreen.xy;
        float4 s = texture2DCv(refBuffer1, refBuffer1Smplr, param_6);
        referenceColor = float4(s.w);
        return;
    }
    if (as_type<int>(_352.refComposition.z) == 2)
    {
        float _587;
        if (Q == 1)
        {
            _587 = 6.0;
        }
        else
        {
            _587 = (Q == 2) ? 10.0 : 14.0;
        }
        float k = _587;
        float kernelSize = k;
        float2 texOffset = float2(1.0 / fast::max(floor(float2(_352.refComposition.w, _352.refScreen.w) / float2(2.0)), float2(1.0)).x, 0.0);
        float2 param_7 = texOffset;
        float2 param_8 = gl_FragCoord.xy / _352.refScreen.xy;
        float param_9 = kernelSize;
        referenceColor = blurInternal(refBuffer2, refBuffer2Smplr, param_7, param_8, param_9);
        return;
    }
    if (as_type<int>(_352.refComposition.z) == 3)
    {
        float _634;
        if (Q == 1)
        {
            _634 = 6.0;
        }
        else
        {
            _634 = (Q == 2) ? 10.0 : 14.0;
        }
        float k_1 = _634;
        float kernelSize_1 = k_1;
        float2 texOffset_1 = float2(0.0, 1.0 / fast::max(floor(float2(_352.refComposition.w, _352.refScreen.w) / float2(2.0)), float2(1.0)).y);
        float2 param_10 = texOffset_1;
        float2 param_11 = gl_FragCoord.xy / _352.refScreen.xy;
        float param_12 = kernelSize_1;
        referenceColor = blurInternal(refBuffer3, refBuffer3Smplr, param_10, param_11, param_12);
        return;
    }
    float2 param_13 = gl_FragCoord.xy / _352.refScreen.xy;
    float4 shattered = texture2DCv(refBuffer1, refBuffer1Smplr, param_13);
    float3 baseRGB = shattered.xyz;
    float2 param_14 = gl_FragCoord.xy / _352.refScreen.xy;
    float edgeB = texture2DCv(refBuffer4, refBuffer4Smplr, param_14).x;
    float3 glowRGB = ((_352.edgeColor.xyz * edgeB) * _352.edgeGlow) * _352.edgeColor.w;
    float3 _714;
    if (_352.glowOnly != 0u)
    {
        _714 = glowRGB;
    }
    else
    {
        _714 = baseRGB + glowRGB;
    }
    float3 outRGB = _714;
    referenceColor = float4(outRGB, shattered.w);
}

fragment refAM35_ebd05c868a466_out refAM35_ebd05c868a466(constant ReferenceUniformsebd05c868a466& _352 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refBuffer2 [[texture(2)]], texture2d<float> refBuffer3 [[texture(3)]], texture2d<float> refBuffer4 [[texture(4)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refBuffer2Smplr [[sampler(2)]], sampler refBuffer3Smplr [[sampler(3)]], sampler refBuffer4Smplr [[sampler(4)]], float4 gl_FragCoord [[position]])
{
    refAM35_ebd05c868a466_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_352, gl_FragCoord, refInput, refInputSmplr, referenceColor, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr, refBuffer3, refBuffer3Smplr, refBuffer4, refBuffer4Smplr);
    bool _735 = any(isnan(referenceColor));
    bool _742;
    if (!_735)
    {
        _742 = any(isinf(referenceColor));
    }
    else
    {
        _742 = _735;
    }
    if (_742)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _755 = referenceColor;
    float3 _761 = fast::clamp(_755.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _761.x;
    referenceColor.y = _761.y;
    referenceColor.z = _761.z;
    out.finalColor = referenceColor;
    return out;
}

