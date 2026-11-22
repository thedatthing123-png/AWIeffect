// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/mulitsharpen.xml
// Original source comments and attribution:
// ═══════════════════════════════════════════════════════════════
//  S_Sharpen — Sapphire port for Alight Motion  (GLSL ES 1.00)
//
//  ALGORITHM
//  ─────────
//  Sapphire S_Sharpen works by extracting multiple frequency
//  bands from the image (like a Laplacian pyramid) and boosting
//  each band independently, then adding them back.
//
//  We replicate the four "detail scales":
//    Tiny   ≈ 0.5 × smallDetailSize
//    Small  ≈ 1.0 × smallDetailSize
//    Medium ≈ 2.0 × smallDetailSize
//    Large  ≈ 4.0 × smallDetailSize
//
//  Each scale = (blur at current radius) − (blur at 2× radius)
//  This is a band-pass at each frequency band.
//
//  Edge threshold: if the local gradient magnitude is above
//  edgeThresh, sharpening is reduced to prevent halos.
//
//  Quality modes:
//    Best: 9-tap Gaussian blur per band → fewer ringing artefacts
//    Fast: 5-tap box blur per band → classic USM look
//
//  Luma/Chroma: convert to YUV, apply luma & chroma scaling
//  Per-channel: final RGB scale multipliers
//  Matte: optional luminance or alpha mask
//
//  FUNCTION ORDER (GLSL ES 1.00 — all before first use):
//   1. Color space helpers
//   2. Texture sampling helpers
//   3. Gaussian / box blur (single pass, horizontal + vertical combined)
//   4. Band-pass extraction
//   5. Edge gradient magnitude
//   6. main()
// ═══════════════════════════════════════════════════════════════
// ── 1. Color space ────────────────────────────────────────────
// RGB → YUV (BT.709)
// YUV → RGB (BT.709)
// ── 2. Sampling helpers ───────────────────────────────────────
// Pixel size in UV space
// ── 3. Blur functions ─────────────────────────────────────────
//
//  Both blur functions take a radius in UV space and return
//  the blurred color at uv.
//
//  "Best" mode: 9-tap Gaussian weights (σ ≈ radius/2)
//  "Fast" mode: 5-tap uniform box
//
//  We do a separable 2D blur by combining H and V offsets in
//  a single pass using a 3×3 (fast) or 5×5 (best) kernel.
//  This is an approximation but very close to separable.
// Gaussian 9-tap (3×3 grid) — Best quality
// Gaussian weights for offsets -1, 0, +1 at sigma=0.5
// w = [0.27901, 0.44198, 0.27901]  (normalized)
// 3×3 separable Gaussian
// Gaussian 25-tap (5x5 grid) — Best quality, larger radius
// Fully unrolled — no array indexing (GLSL ES 1.00 safe)
// Box blur 5-tap — Fast mode
// Dispatch blur by quality
// Best: use 5x5 Gaussian for larger radii, 3x3 for small
// ── 4. Band-pass at a given scale ────────────────────────────
//
//  band(scale) = blur(scale) - blur(scale * 2)
//  This isolates frequency content at ~scale pixel width.
//
// ── 5. Edge gradient magnitude ────────────────────────────────
//
//  Sobel 3×3 gradient magnitude (luminance channel).
//  Used for edge threshold: suppress sharpening on strong edges
//  to avoid halos (same concept as S_Sharpen Edge Threshold).
//
// ── 6. main ───────────────────────────────────────────────────
// Base pixel
// ── Detail scale radii ────────────────────────────────────
// smallDetailSize is in UV fraction of the image width
// Tiny   ≈ 0.5 ×  small
// Small  ≈ 1.0 ×  small
// Medium ≈ 2.0 ×  small
// Large  ≈ 4.0 ×  small
// ── Extract band-pass signals ─────────────────────────────
// ── Edge threshold gate ───────────────────────────────────
// Edges stronger than edgeThresh suppress sharpening
// to avoid dark halos (matches Sapphire behavior)
// ── Combined sharpening signal (before luma/chroma split) ─
// ── Luma / Chroma separation ──────────────────────────────
// Apply luma and chroma sharpening separately in YUV space
// Y channel
// U channel
// V channel
// ── Per-channel RGB scale ──────────────────────────────────
// Each channel's sharpening can be boosted/reduced individually
// net sharpening delta
// ── Matte / mask ──────────────────────────────────────────
// Luma mask: use luminance of source as mask
// Optional blur of mask (box approximation)
// Alpha mask
// Blend sharpened with original using mask
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse98e0bd11fc6f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int quality;
    char _m6_pad[12];
    float sharpenAmp;
    char _m7_pad[12];
    float sharpenWidth;
    char _m8_pad[12];
    float edgeThresh;
    char _m9_pad[12];
    float smallDetailSize;
    char _m10_pad[12];
    float scaleTinyDetails;
    char _m11_pad[12];
    float scaleSmallDetails;
    char _m12_pad[12];
    float scaleMediumDetails;
    char _m13_pad[12];
    float scaleLargeDetails;
    char _m14_pad[12];
    float sharpenLuma;
    char _m15_pad[12];
    float sharpenChroma;
    char _m16_pad[12];
    float sharpenRed;
    char _m17_pad[12];
    float sharpenGreen;
    char _m18_pad[12];
    float sharpenBlue;
    char _m19_pad[12];
    int maskUse;
    char _m20_pad[12];
    float blurMask;
    char _m21_pad[12];
    uint invertMask;
    char _m22_pad[12];
    float alpha;
};

struct refAM35_e98e0bd11fc6f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 pixSize(constant ReferenceUniformse98e0bd11fc6f& _169)
{
    return float2(1.0) / _169.refLayer.zw;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 samp(thread const float2& uv, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = fast::clamp(uv, float2(0.0), float2(1.0));
    return texture2DCv(refInput, refInputSmplr, param);
}

static inline __attribute__((always_inline))
float4 blurGaussian5(thread const float2& uv, thread const float2& r, texture2d<float> refInput, sampler refInputSmplr)
{
    float4 col = float4(0.0);
    float2 param = uv + float2((-2.0) * r.x, (-2.0) * r.y);
    col += (samp(param, refInput, refInputSmplr) * 0.00390625);
    float2 param_1 = uv + float2((-1.0) * r.x, (-2.0) * r.y);
    col += (samp(param_1, refInput, refInputSmplr) * 0.015625);
    float2 param_2 = uv + float2(0.0, (-2.0) * r.y);
    col += (samp(param_2, refInput, refInputSmplr) * 0.0234375);
    float2 param_3 = uv + float2(1.0 * r.x, (-2.0) * r.y);
    col += (samp(param_3, refInput, refInputSmplr) * 0.015625);
    float2 param_4 = uv + float2(2.0 * r.x, (-2.0) * r.y);
    col += (samp(param_4, refInput, refInputSmplr) * 0.00390625);
    float2 param_5 = uv + float2((-2.0) * r.x, (-1.0) * r.y);
    col += (samp(param_5, refInput, refInputSmplr) * 0.015625);
    float2 param_6 = uv + float2((-1.0) * r.x, (-1.0) * r.y);
    col += (samp(param_6, refInput, refInputSmplr) * 0.0625);
    float2 param_7 = uv + float2(0.0, (-1.0) * r.y);
    col += (samp(param_7, refInput, refInputSmplr) * 0.09375);
    float2 param_8 = uv + float2(1.0 * r.x, (-1.0) * r.y);
    col += (samp(param_8, refInput, refInputSmplr) * 0.0625);
    float2 param_9 = uv + float2(2.0 * r.x, (-1.0) * r.y);
    col += (samp(param_9, refInput, refInputSmplr) * 0.015625);
    float2 param_10 = uv + float2((-2.0) * r.x, 0.0);
    col += (samp(param_10, refInput, refInputSmplr) * 0.0234375);
    float2 param_11 = uv + float2((-1.0) * r.x, 0.0);
    col += (samp(param_11, refInput, refInputSmplr) * 0.09375);
    float2 param_12 = uv + float2(0.0);
    col += (samp(param_12, refInput, refInputSmplr) * 0.140625);
    float2 param_13 = uv + float2(1.0 * r.x, 0.0);
    col += (samp(param_13, refInput, refInputSmplr) * 0.09375);
    float2 param_14 = uv + float2(2.0 * r.x, 0.0);
    col += (samp(param_14, refInput, refInputSmplr) * 0.0234375);
    float2 param_15 = uv + float2((-2.0) * r.x, 1.0 * r.y);
    col += (samp(param_15, refInput, refInputSmplr) * 0.015625);
    float2 param_16 = uv + float2((-1.0) * r.x, 1.0 * r.y);
    col += (samp(param_16, refInput, refInputSmplr) * 0.0625);
    float2 param_17 = uv + float2(0.0, 1.0 * r.y);
    col += (samp(param_17, refInput, refInputSmplr) * 0.09375);
    float2 param_18 = uv + float2(1.0 * r.x, 1.0 * r.y);
    col += (samp(param_18, refInput, refInputSmplr) * 0.0625);
    float2 param_19 = uv + float2(2.0 * r.x, 1.0 * r.y);
    col += (samp(param_19, refInput, refInputSmplr) * 0.015625);
    float2 param_20 = uv + float2((-2.0) * r.x, 2.0 * r.y);
    col += (samp(param_20, refInput, refInputSmplr) * 0.00390625);
    float2 param_21 = uv + float2((-1.0) * r.x, 2.0 * r.y);
    col += (samp(param_21, refInput, refInputSmplr) * 0.015625);
    float2 param_22 = uv + float2(0.0, 2.0 * r.y);
    col += (samp(param_22, refInput, refInputSmplr) * 0.0234375);
    float2 param_23 = uv + float2(1.0 * r.x, 2.0 * r.y);
    col += (samp(param_23, refInput, refInputSmplr) * 0.015625);
    float2 param_24 = uv + float2(2.0 * r.x, 2.0 * r.y);
    col += (samp(param_24, refInput, refInputSmplr) * 0.00390625);
    return col;
}

static inline __attribute__((always_inline))
float4 blurGaussian(thread const float2& uv, thread const float2& radius, texture2d<float> refInput, sampler refInputSmplr)
{
    float4 col = float4(0.0);
    float w0 = 0.44198000431060791015625;
    float w1 = 0.279009997844696044921875;
    float2 r = radius;
    float2 param = uv + float2(-r.x, -r.y);
    col += ((samp(param, refInput, refInputSmplr) * w1) * w1);
    float2 param_1 = uv + float2(0.0, -r.y);
    col += ((samp(param_1, refInput, refInputSmplr) * w0) * w1);
    float2 param_2 = uv + float2(r.x, -r.y);
    col += ((samp(param_2, refInput, refInputSmplr) * w1) * w1);
    float2 param_3 = uv + float2(-r.x, 0.0);
    col += ((samp(param_3, refInput, refInputSmplr) * w1) * w0);
    float2 param_4 = uv + float2(0.0);
    col += ((samp(param_4, refInput, refInputSmplr) * w0) * w0);
    float2 param_5 = uv + float2(r.x, 0.0);
    col += ((samp(param_5, refInput, refInputSmplr) * w1) * w0);
    float2 param_6 = uv + float2(-r.x, r.y);
    col += ((samp(param_6, refInput, refInputSmplr) * w1) * w1);
    float2 param_7 = uv + float2(0.0, r.y);
    col += ((samp(param_7, refInput, refInputSmplr) * w0) * w1);
    float2 param_8 = uv + float2(r.x, r.y);
    col += ((samp(param_8, refInput, refInputSmplr) * w1) * w1);
    return col;
}

static inline __attribute__((always_inline))
float4 blurBox(thread const float2& uv, thread const float2& radius, texture2d<float> refInput, sampler refInputSmplr)
{
    float4 col = float4(0.0);
    float w = 0.111111111938953399658203125;
    float2 param = uv + float2(-radius.x, -radius.y);
    col += (samp(param, refInput, refInputSmplr) * w);
    float2 param_1 = uv + float2(0.0, -radius.y);
    col += (samp(param_1, refInput, refInputSmplr) * w);
    float2 param_2 = uv + float2(radius.x, -radius.y);
    col += (samp(param_2, refInput, refInputSmplr) * w);
    float2 param_3 = uv + float2(-radius.x, 0.0);
    col += (samp(param_3, refInput, refInputSmplr) * w);
    float2 param_4 = uv + float2(0.0);
    col += (samp(param_4, refInput, refInputSmplr) * w);
    float2 param_5 = uv + float2(radius.x, 0.0);
    col += (samp(param_5, refInput, refInputSmplr) * w);
    float2 param_6 = uv + float2(-radius.x, radius.y);
    col += (samp(param_6, refInput, refInputSmplr) * w);
    float2 param_7 = uv + float2(0.0, radius.y);
    col += (samp(param_7, refInput, refInputSmplr) * w);
    float2 param_8 = uv + float2(radius.x, radius.y);
    col += (samp(param_8, refInput, refInputSmplr) * w);
    return col;
}

static inline __attribute__((always_inline))
float4 doBlur(thread const float2& uv, thread const float2& radius, constant ReferenceUniformse98e0bd11fc6f& _169, texture2d<float> refInput, sampler refInputSmplr)
{
    if (_169.quality == 0)
    {
        float mag = length(radius * _169.refLayer.zw);
        if (mag > 2.0)
        {
            float2 param = uv;
            float2 param_1 = radius;
            return blurGaussian5(param, param_1, refInput, refInputSmplr);
        }
        else
        {
            float2 param_2 = uv;
            float2 param_3 = radius;
            return blurGaussian(param_2, param_3, refInput, refInputSmplr);
        }
    }
    else
    {
        float2 param_4 = uv;
        float2 param_5 = radius;
        return blurBox(param_4, param_5, refInput, refInputSmplr);
    }
}

static inline __attribute__((always_inline))
float4 bandPass(thread const float2& uv, thread const float2& pxSz, thread const float& scaleUV, constant ReferenceUniformse98e0bd11fc6f& _169, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 r1 = pxSz * scaleUV;
    float2 r2 = (pxSz * scaleUV) * 2.0;
    float2 param = uv;
    float2 param_1 = r1;
    float4 b1 = doBlur(param, param_1, _169, refInput, refInputSmplr);
    float2 param_2 = uv;
    float2 param_3 = r2;
    float4 b2 = doBlur(param_2, param_3, _169, refInput, refInputSmplr);
    return b1 - b2;
}

static inline __attribute__((always_inline))
float edgeGrad(thread const float2& uv, thread const float2& pxSz, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = uv + float2(-pxSz.x, -pxSz.y);
    float tl = dot(samp(param, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_1 = uv + float2(0.0, -pxSz.y);
    float tc = dot(samp(param_1, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_2 = uv + float2(pxSz.x, -pxSz.y);
    float tr = dot(samp(param_2, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_3 = uv + float2(-pxSz.x, 0.0);
    float ml = dot(samp(param_3, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_4 = uv + float2(pxSz.x, 0.0);
    float mr = dot(samp(param_4, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_5 = uv + float2(-pxSz.x, pxSz.y);
    float bl = dot(samp(param_5, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_6 = uv + float2(0.0, pxSz.y);
    float bc = dot(samp(param_6, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 param_7 = uv + float2(pxSz.x, pxSz.y);
    float br = dot(samp(param_7, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float gx = (((((-tl) - (2.0 * ml)) - bl) + tr) + (2.0 * mr)) + br;
    float gy = (((((-tl) - (2.0 * tc)) - tr) + bl) + (2.0 * bc)) + br;
    return length(float2(gx, gy));
}

static inline __attribute__((always_inline))
float3 rgb2yuv(thread const float3& c)
{
    float y = ((0.2125999927520751953125 * c.x) + (0.715200006961822509765625 * c.y)) + (0.072200000286102294921875 * c.z);
    float u = (((-0.114600002765655517578125) * c.x) - (0.385399997234344482421875 * c.y)) + (0.5 * c.z);
    float v = ((0.5 * c.x) - (0.4541999995708465576171875 * c.y)) - (0.0458000004291534423828125 * c.z);
    return float3(y, u, v);
}

static inline __attribute__((always_inline))
float3 yuv2rgb(thread const float3& yuv)
{
    float r = yuv.x + (1.574800014495849609375 * yuv.z);
    float g = (yuv.x - (0.1872999966144561767578125 * yuv.y)) - (0.468100011348724365234375 * yuv.z);
    float b = yuv.x + (1.85559999942779541015625 * yuv.y);
    return fast::clamp(float3(r, g, b), float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse98e0bd11fc6f& _169, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _169.refScreen.xy;
    float2 pxSz = pixSize(_169);
    float2 param = uv;
    float4 srcPx = samp(param, refInput, refInputSmplr);
    float3 srcRGB = srcPx.xyz;
    float base = fast::max(_169.smallDetailSize, 9.9999997473787516355514526367188e-05) + (_169.sharpenWidth * 0.0500000007450580596923828125);
    float scTiny = base * 0.5;
    float scSmall = base;
    float scMedium = base * 2.0;
    float scLarge = base * 4.0;
    float2 param_1 = uv;
    float2 param_2 = pxSz;
    float param_3 = scTiny;
    float3 bandTiny = bandPass(param_1, param_2, param_3, _169, refInput, refInputSmplr).xyz;
    float2 param_4 = uv;
    float2 param_5 = pxSz;
    float param_6 = scSmall;
    float3 bandSmall = bandPass(param_4, param_5, param_6, _169, refInput, refInputSmplr).xyz;
    float2 param_7 = uv;
    float2 param_8 = pxSz;
    float param_9 = scMedium;
    float3 bandMedium = bandPass(param_7, param_8, param_9, _169, refInput, refInputSmplr).xyz;
    float2 param_10 = uv;
    float2 param_11 = pxSz;
    float param_12 = scLarge;
    float3 bandLarge = bandPass(param_10, param_11, param_12, _169, refInput, refInputSmplr).xyz;
    float2 param_13 = uv;
    float2 param_14 = pxSz;
    float grad = edgeGrad(param_13, param_14, refInput, refInputSmplr);
    float edgeMask = 1.0 - smoothstep(_169.edgeThresh * 0.5, _169.edgeThresh, grad);
    float3 sharp = (((((bandTiny * _169.scaleTinyDetails) + (bandSmall * _169.scaleSmallDetails)) + (bandMedium * _169.scaleMediumDetails)) + (bandLarge * _169.scaleLargeDetails)) * _169.sharpenAmp) * edgeMask;
    float3 param_15 = srcRGB;
    float3 srcYUV = rgb2yuv(param_15);
    float3 param_16 = sharp;
    float3 sharpYUV = rgb2yuv(param_16);
    float3 outYUV;
    outYUV.x = srcYUV.x + (sharpYUV.x * _169.sharpenLuma);
    outYUV.y = srcYUV.y + (sharpYUV.y * _169.sharpenChroma);
    outYUV.z = srcYUV.z + (sharpYUV.z * _169.sharpenChroma);
    float3 param_17 = outYUV;
    float3 outRGB = yuv2rgb(param_17);
    float3 sharpRGB = outRGB - srcRGB;
    sharpRGB *= float3(_169.sharpenRed, _169.sharpenGreen, _169.sharpenBlue);
    outRGB = fast::clamp(srcRGB + sharpRGB, float3(0.0), float3(1.0));
    float maskVal = 1.0;
    if (_169.maskUse == 1)
    {
        maskVal = dot(srcRGB, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
        if (_169.blurMask > 0.001000000047497451305389404296875)
        {
            float bm = _169.blurMask;
            float2 param_18 = uv + float2(-bm, 0.0);
            float ml = dot(samp(param_18, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
            float2 param_19 = uv + float2(bm, 0.0);
            float mr = dot(samp(param_19, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
            float2 param_20 = uv + float2(0.0, -bm);
            float mu = dot(samp(param_20, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
            float2 param_21 = uv + float2(0.0, bm);
            float md = dot(samp(param_21, refInput, refInputSmplr).xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
            maskVal = ((((maskVal + ml) + mr) + mu) + md) * 0.20000000298023223876953125;
        }
    }
    else
    {
        if (_169.maskUse == 2)
        {
            maskVal = srcPx.w;
            if (_169.blurMask > 0.001000000047497451305389404296875)
            {
                float bm_1 = _169.blurMask;
                float2 param_22 = uv + float2(-bm_1, 0.0);
                float al = samp(param_22, refInput, refInputSmplr).w;
                float2 param_23 = uv + float2(bm_1, 0.0);
                float ar = samp(param_23, refInput, refInputSmplr).w;
                float2 param_24 = uv + float2(0.0, -bm_1);
                float au = samp(param_24, refInput, refInputSmplr).w;
                float2 param_25 = uv + float2(0.0, bm_1);
                float ad = samp(param_25, refInput, refInputSmplr).w;
                maskVal = ((((maskVal + al) + ar) + au) + ad) * 0.20000000298023223876953125;
            }
        }
    }
    if (_169.invertMask != 0u)
    {
        maskVal = 1.0 - maskVal;
    }
    maskVal = fast::clamp(maskVal, 0.0, 1.0);
    float3 finalRGB = mix(srcRGB, outRGB, float3(maskVal));
    referenceColor = float4(finalRGB, srcPx.w) * _169.alpha;
}

fragment refAM35_e98e0bd11fc6f_out refAM35_e98e0bd11fc6f(constant ReferenceUniformse98e0bd11fc6f& _169 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e98e0bd11fc6f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_169, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _1330 = any(isnan(referenceColor));
    bool _1337;
    if (!_1330)
    {
        _1337 = any(isinf(referenceColor));
    }
    else
    {
        _1337 = _1330;
    }
    if (_1337)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1350 = referenceColor;
    float3 _1356 = fast::clamp(_1350.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1356.x;
    referenceColor.y = _1356.y;
    referenceColor.z = _1356.z;
    out.finalColor = referenceColor;
    return out;
}

