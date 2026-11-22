// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/newhalf.xml
// Original source comments and attribution:
// Helpers
// Sobel edge detector (luminance-based)
// sample 3x3 luminances
// Sobel X and Y
// simple box blur of mask (3x3)
// radius expressed as number of px steps; use small kernel around uv
// halftone params
// use renamed parameter (blend) and local name blendOut
// displacement params
// colors
// edges params
// rotate coordinate system
// cell coordinates and center in px
// sample the source at cell center
// compute dot radius
// distance to cell center for this fragment (rotated px space)
// choose dot color
// displacement mask
// halftone color
// EDGE MASK: compute edge strength around uv (Sobel), optionally blur it, then map by threshold & strength
// raw edge magnitude
// small blur to soften edge mask (costly kernels but small radius expected)
// normalize and apply threshold -> mask 0..1, multiply by edgeStrength parameter
// determine base background (displaced or original)
// compute final composition:
// if edges-only is on, modulate halftone by edge mask so middle is unaffected
// when replacing: allow edges-only to still mask the halftone in middle
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

struct ReferenceUniformse5472df25c99f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float dotSize;
    char _m6_pad[12];
    float spacing;
    char _m7_pad[12];
    float angle;
    char _m8_pad[12];
    float progress;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    uint ellipse;
    char _m11_pad[12];
    float ellipseX;
    char _m12_pad[12];
    float ellipseY;
    float4 primaryColor;
    float4 secondaryColor;
    uint colorMode;
    char _m16_pad[12];
    float contrast;
    char _m17_pad[12];
    float brightness;
    char _m18_pad[12];
    float edgeSoft;
    char _m19_pad[12];
    uint useDisplacement;
    char _m20_pad[12];
    float dispAmount;
    char _m21_pad[12];
    float dispThreshold;
    char _m22_pad[12];
    uint dispInvert;
    char _m23_pad[12];
    float dispSoft;
    char _m24_pad[12];
    uint edgesHalftone;
    char _m25_pad[12];
    float edgeThreshold;
    char _m26_pad[12];
    float edgeBlur;
    char _m27_pad[12];
    float edgeStrength;
    char _m28_pad[12];
    uint overlay;
    char _m29_pad[12];
    float blend;
};

struct refAM35_e5472df25c99f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float2 getResolution(texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 s = getTexSize(param);
    bool _82 = s.x <= 0.0;
    bool _90;
    if (!_82)
    {
        _90 = s.y <= 0.0;
    }
    else
    {
        _90 = _82;
    }
    if (_90)
    {
        s = float2(1920.0, 1080.0);
    }
    return s;
}

static inline __attribute__((always_inline))
float2 rot(thread const float2& p, thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2((p.x * c) - (p.y * s), (p.x * s) + (p.y * c));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float applyToneF(thread float& v, thread const float& contrast, thread const float& brightness)
{
    v = (((v - 0.5) * contrast) + 0.5) + brightness;
    return fast::clamp(v, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float colorDist(thread const float3& a, thread const float3& b)
{
    return length(a - b);
}

static inline __attribute__((always_inline))
float sobelEdge(thread const float2& uv, thread const float2& px, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = fast::clamp(uv + float2(-px.x, -px.y), float2(0.0), float2(1.0));
    float tl = dot(texture2DCv(refInput, refInputSmplr, param).xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_1 = fast::clamp(uv + float2(0.0, -px.y), float2(0.0), float2(1.0));
    float l = dot(texture2DCv(refInput, refInputSmplr, param_1).xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_2 = fast::clamp(uv + float2(px.x, -px.y), float2(0.0), float2(1.0));
    float tr = dot(texture2DCv(refInput, refInputSmplr, param_2).xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_3 = fast::clamp(uv + float2(-px.x, 0.0), float2(0.0), float2(1.0));
    float ml = dot(texture2DCv(refInput, refInputSmplr, param_3).xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_4 = fast::clamp(uv, float2(0.0), float2(1.0));
    float mm = dot(texture2DCv(refInput, refInputSmplr, param_4).xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_5 = fast::clamp(uv + float2(px.x, 0.0), float2(0.0), float2(1.0));
    float mr = dot(texture2DCv(refInput, refInputSmplr, param_5).xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_6 = fast::clamp(uv + float2(-px.x, px.y), float2(0.0), float2(1.0));
    float bl = dot(texture2DCv(refInput, refInputSmplr, param_6).xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_7 = fast::clamp(uv + float2(0.0, px.y), float2(0.0), float2(1.0));
    float b = dot(texture2DCv(refInput, refInputSmplr, param_7).xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_8 = fast::clamp(uv + float2(px.x, px.y), float2(0.0), float2(1.0));
    float br = dot(texture2DCv(refInput, refInputSmplr, param_8).xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float gx = (((((-tl) - (2.0 * ml)) - bl) + tr) + (2.0 * mr)) + br;
    float gy = (((((-tl) - (2.0 * l)) - tr) + bl) + (2.0 * b)) + br;
    return length(float2(gx, gy));
}

static inline __attribute__((always_inline))
float blurMask(thread const float2& uv, thread const float2& px, thread const float& radius, texture2d<float> refInput, sampler refInputSmplr)
{
    float s = 0.0;
    float count = 0.0;
    int r = int(fast::max(0.0, floor(radius)));
    int _307 = -r;
    for (int y = _307; y <= r; y++)
    {
        int _318 = -r;
        for (int x = _318; x <= r; x++)
        {
            float2 off = float2(float(x) * px.x, float(y) * px.y);
            float2 param = fast::clamp(uv + off, float2(0.0), float2(1.0));
            float2 param_1 = px;
            s += sobelEdge(param, param_1, refInput, refInputSmplr);
            count += 1.0;
        }
    }
    return s / fast::max(1.0, count);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse5472df25c99f& _372, thread float4& referenceColor)
{
    float2 res = getResolution(refInput, refInputSmplr);
    float2 uv = gl_FragCoord.xy / _372.refScreen.xy;
    float2 frag = uv * res;
    float2 center = res * 0.5;
    float2 px = float2(1.0 / res.x, 1.0 / res.y);
    float dSize = fast::max(1.0, _372.dotSize);
    float dSpacing = fast::max(1.0, _372.spacing);
    float angDeg = _372.angle;
    float rotAngle = radians(angDeg) + (_372.progress * 6.283185482025146484375);
    float s = _372.scale;
    float edgeSoftness = fast::max(0.001000000047497451305389404296875, _372.edgeSoft);
    float cont = fast::max(0.0, _372.contrast);
    float bright = _372.brightness;
    bool useSampleColor = _372.colorMode != 0u;
    bool useEllipse = _372.ellipse != 0u;
    float eX = fast::max(0.001000000047497451305389404296875, _372.ellipseX);
    float eY = fast::max(0.001000000047497451305389404296875, _372.ellipseY);
    float blendOut = fast::clamp(_372.blend, 0.0, 1.0);
    bool doDisp = _372.useDisplacement != 0u;
    float dispAmountPx = _372.dispAmount;
    float dispThresholdVal = fast::clamp(_372.dispThreshold, 0.0, 1.0);
    bool dispInv = _372.dispInvert != 0u;
    float dispSoft = fast::max(0.0, _372.dispSoft);
    float3 colPrimary = _372.primaryColor.xyz;
    float3 colSecondary = _372.secondaryColor.xyz;
    bool onlyEdges = _372.edgesHalftone != 0u;
    float eThresh = fast::clamp(_372.edgeThreshold, 0.0, 1.0);
    float eBlur = fast::max(0.0, _372.edgeBlur);
    float eStr = fast::max(0.0, _372.edgeStrength);
    float2 local = frag - center;
    float2 param = local;
    float param_1 = rotAngle;
    local = rot(param, param_1);
    float2 rotPos = local + center;
    float2 cell = floor(rotPos / float2(dSpacing));
    float2 cellCenterPx = (cell + float2(0.5)) * dSpacing;
    float2 sampleUV = fast::clamp(cellCenterPx / res, float2(0.0), float2(1.0));
    float2 param_2 = sampleUV;
    float3 sampleColor = texture2DCv(refInput, refInputSmplr, param_2).xyz;
    float lum = dot(sampleColor, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float param_3 = lum;
    float param_4 = cont;
    float param_5 = bright;
    float _561 = applyToneF(param_3, param_4, param_5);
    lum = _561;
    float inv = 1.0 - lum;
    float baseRadius = fast::clamp(((dSize * s) * 0.5) / dSpacing, 0.0, 0.5);
    float radius = baseRadius * inv;
    float dx = rotPos.x - cellCenterPx.x;
    float dy = rotPos.y - cellCenterPx.y;
    if (useEllipse)
    {
        dx /= eX;
        dy /= eY;
    }
    float dist = length(float2(dx, dy));
    float pxRadius = radius * dSpacing;
    float edge = fast::max(1.0, dSpacing * 0.00999999977648258209228515625) * edgeSoftness;
    float alphaDot = 1.0 - smoothstep(pxRadius - edge, pxRadius + edge, dist);
    float3 param_6 = sampleColor;
    float3 param_7 = colPrimary;
    float primaryMatch = 1.0 - smoothstep(dispThresholdVal, dispThresholdVal + 0.20000000298023223876953125, colorDist(param_6, param_7));
    float3 dotCol;
    if (useSampleColor)
    {
        dotCol = sampleColor;
    }
    else
    {
        dotCol = mix(colSecondary, colPrimary, float3(primaryMatch));
    }
    float3 param_8 = sampleColor;
    float3 param_9 = colPrimary;
    float match = 1.0 - smoothstep(dispThresholdVal, dispThresholdVal + 0.25, colorDist(param_8, param_9));
    match = powr(match, 1.0 + (dispSoft * 2.0));
    float2 dir = fast::normalize(float2(rotPos.x - cellCenterPx.x, rotPos.y - cellCenterPx.y) + float2(9.9999999747524270787835121154785e-07, 0.0));
    if (length(float2(rotPos.x - cellCenterPx.x, rotPos.y - cellCenterPx.y)) < 0.5)
    {
        dir = float2(0.0, -1.0);
    }
    float _sign = dispInv ? (-1.0) : 1.0;
    float2 dispUVoffset = ((dir * _sign) * (match * dispAmountPx)) / float2(res.y);
    float2 displacedUV = fast::clamp(uv + dispUVoffset, float2(0.0), float2(1.0));
    float2 param_10 = displacedUV;
    float3 displacedBackground = texture2DCv(refInput, refInputSmplr, param_10).xyz;
    float3 finalDotCol;
    if (useSampleColor)
    {
        finalDotCol = sampleColor * (0.300000011920928955078125 + (0.699999988079071044921875 * (1.0 - lum)));
    }
    else
    {
        finalDotCol = dotCol;
    }
    float3 halftone = finalDotCol * alphaDot;
    float2 param_11 = uv;
    float2 param_12 = px;
    float e = sobelEdge(param_11, param_12, refInput, refInputSmplr);
    if (eBlur > 0.5)
    {
        float2 param_13 = uv;
        float2 param_14 = px;
        float param_15 = eBlur;
        float b = blurMask(param_13, param_14, param_15, refInput, refInputSmplr);
        e = mix(e, b, 0.60000002384185791015625);
    }
    float eMask = smoothstep(eThresh, eThresh + (0.25 * fast::max(0.001000000047497451305389404296875, eBlur)), e) * eStr;
    eMask = fast::clamp(eMask, 0.0, 1.0);
    float3 _777;
    if (doDisp)
    {
        _777 = displacedBackground;
    }
    else
    {
        float2 param_16 = uv;
        _777 = texture2DCv(refInput, refInputSmplr, param_16).xyz;
    }
    float3 baseBg = _777;
    float finalDotMix = alphaDot * blendOut;
    if (onlyEdges)
    {
        finalDotMix *= eMask;
    }
    float3 outCol;
    if (_372.overlay != 0u)
    {
        outCol = mix(baseBg, halftone, float3(finalDotMix));
    }
    else
    {
        float2 param_17 = uv;
        float3 original = texture2DCv(refInput, refInputSmplr, param_17).xyz;
        if (onlyEdges)
        {
            outCol = mix(original, mix(baseBg, halftone, float3(finalDotMix)), float3(blendOut));
        }
        else
        {
            outCol = mix(original, halftone, float3(blendOut));
        }
    }
    referenceColor = float4(outCol, 1.0);
}

fragment refAM35_e5472df25c99f_out refAM35_e5472df25c99f(constant ReferenceUniformse5472df25c99f& _372 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e5472df25c99f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _372, referenceColor);
    bool _845 = any(isnan(referenceColor));
    bool _852;
    if (!_845)
    {
        _852 = any(isinf(referenceColor));
    }
    else
    {
        _852 = _845;
    }
    if (_852)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _866 = referenceColor;
    float3 _872 = fast::clamp(_866.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _872.x;
    referenceColor.y = _872.y;
    referenceColor.z = _872.z;
    out.finalColor = referenceColor;
    return out;
}

