// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/holomatrix2.xml
// Original source comments and attribution:
// -----------------------------------------------
// LOW RESOLUTION — snap UV to block grid
// -----------------------------------------------
// -----------------------------------------------
// TV DISTORTION — full screen wave warp
// -----------------------------------------------
// -----------------------------------------------
// GLITCH — block displacement
// FIXED: no dynamic indexing, pure math only
// -----------------------------------------------
// Chance check
// -----------------------------------------------
// COLOR SEPARATION — RGB channel split
// -----------------------------------------------
// -----------------------------------------------
// COLORIZATION — shadow/mid/highlight toning
// -----------------------------------------------
// -----------------------------------------------
// GLOW — 4-tap only, no loop
// -----------------------------------------------
// -----------------------------------------------
// SCAN LINES — modulo math, no texture
// -----------------------------------------------
// -----------------------------------------------
// MOVING LINES — bright bands scrolling
// -----------------------------------------------
// Up
// Down
// -----------------------------------------------
// STATIC — hash noise, no texture
// -----------------------------------------------
// -----------------------------------------------
// FLICKER — opacity pulse, no texture
// -----------------------------------------------
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse77bf324369ab
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float moreDamage;
    char _m6_pad[12];
    float moreOften;
    char _m7_pad[12];
    uint punchIt;
    char _m8_pad[12];
    float effectScale;
    char _m9_pad[12];
    float randomSeed;
    char _m10_pad[12];
    uint colorizeOn;
    char _m11_pad[12];
    float srcBrightness;
    char _m12_pad[12];
    float srcContrast;
    char _m13_pad[12];
    float highlightR;
    char _m14_pad[12];
    float highlightG;
    char _m15_pad[12];
    float highlightB;
    char _m16_pad[12];
    float midtoneR;
    char _m17_pad[12];
    float midtoneG;
    char _m18_pad[12];
    float midtoneB;
    char _m19_pad[12];
    float shadowR;
    char _m20_pad[12];
    float shadowG;
    char _m21_pad[12];
    float shadowB;
    char _m22_pad[12];
    float colorizeAmt;
    char _m23_pad[12];
    uint glowOn;
    char _m24_pad[12];
    float glowThresh;
    char _m25_pad[12];
    float glowRadius;
    char _m26_pad[12];
    float glowIntensity;
    char _m27_pad[12];
    uint scanLinesOn;
    char _m28_pad[12];
    float scanDistance;
    char _m29_pad[12];
    float scanThickness;
    char _m30_pad[12];
    int scanDir;
    char _m31_pad[12];
    uint linesOn;
    char _m32_pad[12];
    float lineSpeed;
    char _m33_pad[12];
    float lineHeight;
    char _m34_pad[12];
    uint colorSepOn;
    char _m35_pad[12];
    float colorSepAmt;
    char _m36_pad[12];
    float colorSepChance;
    char _m37_pad[12];
    uint staticOn;
    char _m38_pad[12];
    float staticOpacity;
    char _m39_pad[12];
    uint glitchOn;
    char _m40_pad[12];
    float glitchChance;
    char _m41_pad[12];
    float glitchAmt;
    char _m42_pad[12];
    float glitchSize;
    char _m43_pad[12];
    float glitchSpeed;
    char _m44_pad[12];
    uint flickerOn;
    char _m45_pad[12];
    float flickerMin;
    char _m46_pad[12];
    float flickerChance;
    char _m47_pad[12];
    uint lowResOn;
    char _m48_pad[12];
    float lowResPct;
    char _m49_pad[12];
    uint tvDistOn;
    char _m50_pad[12];
    float tvDistAmt;
    char _m51_pad[12];
    float blend;
};

struct refAM35_e77bf324369ab_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float hashV(thread const float2& p)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
float noiseV(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i;
    float2 param_1 = i + float2(1.0, 0.0);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 param_3 = i + float2(1.0);
    return mix(mix(hashV(param), hashV(param_1), f.x), mix(hashV(param_2), hashV(param_3), f.x), f.y);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse77bf324369ab& _103, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _103.refScreen.xy;
    float t = _103.refScreen.z;
    float sc = _103.effectScale;
    float2 param = fast::clamp(uv, float2(0.0), float2(1.0));
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float2 sampleUV = uv;
    if (_103.lowResOn != 0u)
    {
        float res = fast::max(_103.lowResPct, 0.0500000007450580596923828125);
        float2 blockSize = float2(1.0) / (_103.refScreen.xy * res);
        sampleUV = (floor(uv / blockSize) * blockSize) + (blockSize * 0.5);
        sampleUV = fast::clamp(sampleUV, float2(0.0), float2(1.0));
    }
    if (_103.tvDistOn != 0u)
    {
        float2 param_1 = float2(uv.y * 5.0, t * 2.0);
        float tvWave = (noiseV(param_1) * 2.0) - 1.0;
        sampleUV.x += ((tvWave * _103.tvDistAmt) * _103.moreDamage);
        sampleUV = fast::clamp(sampleUV, float2(0.0), float2(1.0));
    }
    float2 param_2 = sampleUV;
    float3 col = texture2DCv(refInput, refInputSmplr, param_2).xyz;
    if (_103.glitchOn != 0u)
    {
        float gTime = floor(t * _103.glitchSpeed);
        float bSize = _103.glitchSize * sc;
        float2 block = floor(uv / float2(fast::max(bSize, 0.00999999977648258209228515625)));
        float2 param_3 = block + float2(gTime, _103.randomSeed * 100.0);
        float gRnd = hashV(param_3);
        float thresh = 1.0 - (_103.glitchAmt * _103.moreOften);
        float fired = step(thresh, gRnd);
        float2 param_4 = float2(gTime + 5.0, _103.randomSeed);
        float cRnd = hashV(param_4);
        fired *= step(1.0 - (_103.glitchChance * 2.0), cRnd);
        float2 param_5 = block + float2(gTime + 1.0, 0.5);
        float dispX = (((hashV(param_5) * 2.0) - 1.0) * bSize) * 3.0;
        float2 param_6 = fast::clamp(sampleUV + float2(dispX * fired, 0.0), float2(0.0), float2(1.0));
        float3 gCol = texture2DCv(refInput, refInputSmplr, param_6).xyz;
        col = mix(col, gCol, float3(fired));
    }
    if (_103.colorSepOn != 0u)
    {
        float2 param_7 = float2(floor(t * 4.0), _103.randomSeed + 7.0);
        float cRnd_1 = hashV(param_7);
        float fired_1 = step(1.0 - (_103.colorSepChance * 2.0), cRnd_1);
        float ca = (_103.colorSepAmt * _103.moreDamage) * fired_1;
        float2 param_8 = fast::clamp(sampleUV + float2(ca, 0.0), float2(0.0), float2(1.0));
        col.x = mix(col.x, texture2DCv(refInput, refInputSmplr, param_8).x, fired_1);
        float2 param_9 = fast::clamp(sampleUV - float2(ca, 0.0), float2(0.0), float2(1.0));
        col.z = mix(col.z, texture2DCv(refInput, refInputSmplr, param_9).z, fired_1);
    }
    float luma = dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    luma = fast::clamp(luma + _103.srcBrightness, 0.0, 1.0);
    luma = fast::clamp(((luma - 0.5) * (1.0 + _103.srcContrast)) + 0.5, 0.0, 1.0);
    if (_103.colorizeOn != 0u)
    {
        float3 shadow = float3(_103.shadowR, _103.shadowG, _103.shadowB);
        float3 midtone = float3(_103.midtoneR, _103.midtoneG, _103.midtoneB);
        float3 highlight = float3(_103.highlightR, _103.highlightG, _103.highlightB);
        float3 colorized = mix(shadow, midtone, float3(smoothstep(0.0, 0.5, luma)));
        colorized = mix(colorized, highlight, float3(smoothstep(0.5, 1.0, luma)));
        col = mix(col, colorized, float3(_103.colorizeAmt));
    }
    if (_103.glowOn != 0u)
    {
        float gr = (_103.glowRadius * 15.0) * sc;
        float2 px = float2(gr / _103.refScreen.x, gr / _103.refScreen.y);
        float lumaC = dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        float gmask = smoothstep(_103.glowThresh - 0.100000001490116119384765625, _103.glowThresh + 0.100000001490116119384765625, lumaC);
        float2 param_10 = fast::clamp(sampleUV + float2(px.x, 0.0), float2(0.0), float2(1.0));
        float3 g0 = texture2DCv(refInput, refInputSmplr, param_10).xyz;
        float2 param_11 = fast::clamp(sampleUV - float2(px.x, 0.0), float2(0.0), float2(1.0));
        float3 g1 = texture2DCv(refInput, refInputSmplr, param_11).xyz;
        float2 param_12 = fast::clamp(sampleUV + float2(0.0, px.y), float2(0.0), float2(1.0));
        float3 g2 = texture2DCv(refInput, refInputSmplr, param_12).xyz;
        float2 param_13 = fast::clamp(sampleUV - float2(0.0, px.y), float2(0.0), float2(1.0));
        float3 g3 = texture2DCv(refInput, refInputSmplr, param_13).xyz;
        float3 gBlur = ((((g0 + g1) + g2) + g3) * 0.25) * gmask;
        float3 glow = (gBlur * _103.glowIntensity) * _103.moreDamage;
        col = float3(1.0) - ((float3(1.0) - col) * (float3(1.0) - (glow * 0.699999988079071044921875)));
    }
    if (_103.scanLinesOn != 0u)
    {
        float sd = float(_103.scanDir);
        float sDist = fast::max(_103.scanDistance * sc, 1.0);
        float sThk = (_103.scanThickness / sDist) * 0.5;
        sThk = fast::clamp(sThk, 0.00999999977648258209228515625, 0.4900000095367431640625);
        float hMask = 1.0;
        float vMask = 1.0;
        if ((sd < 0.5) || (sd > 1.5))
        {
            float hp = fract((uv.y * _103.refScreen.y) / sDist);
            hMask = mix(0.25, 1.0, 1.0 - (smoothstep(sThk * 0.5, sThk, hp) * (1.0 - smoothstep(1.0 - sThk, 1.0 - (sThk * 0.5), hp))));
        }
        if (sd > 0.5)
        {
            float vp = fract((uv.x * _103.refScreen.x) / sDist);
            vMask = mix(0.25, 1.0, 1.0 - (smoothstep(sThk * 0.5, sThk, vp) * (1.0 - smoothstep(1.0 - sThk, 1.0 - (sThk * 0.5), vp))));
        }
        col *= (hMask * vMask);
    }
    if (_103.linesOn != 0u)
    {
        float luPos = fract(uv.y + (t * _103.lineSpeed));
        float luMask = smoothstep(0.0, _103.lineHeight, luPos) * (1.0 - smoothstep(_103.lineHeight, _103.lineHeight * 1.10000002384185791015625, luPos));
        float ldPos = fract(uv.y - ((t * _103.lineSpeed) * 0.699999988079071044921875));
        float ldMask = smoothstep(0.0, _103.lineHeight, ldPos) * (1.0 - smoothstep(_103.lineHeight, _103.lineHeight * 1.10000002384185791015625, ldPos));
        float lineMask = fast::max(luMask, ldMask);
        col = mix(col, col * 1.5, float3(lineMask * 0.60000002384185791015625));
    }
    if (_103.staticOn != 0u)
    {
        float2 param_14 = float2(floor(uv.x * _103.refScreen.x) + (floor(t * 30.0) * 1000.0), floor(uv.y * _103.refScreen.y) + (_103.randomSeed * 500.0));
        float sNoise = hashV(param_14);
        col += float3(((sNoise - 0.5) * _103.staticOpacity) * _103.moreDamage);
    }
    if (_103.flickerOn != 0u)
    {
        float2 param_15 = float2(floor(t * 15.0), _103.randomSeed * 30.0);
        float fRnd = hashV(param_15);
        float fired_2 = step(1.0 - (_103.flickerChance * 2.0), fRnd);
        float flOp = mix(1.0, _103.flickerMin, fired_2);
        col *= flOp;
    }
    col = fast::clamp(col, float3(0.0), float3(1.0));
    referenceColor = float4(mix(src.xyz, col, float3(_103.blend)), src.w);
}

fragment refAM35_e77bf324369ab_out refAM35_e77bf324369ab(constant ReferenceUniformse77bf324369ab& _103 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e77bf324369ab_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _103, refInput, refInputSmplr, referenceColor);
    bool _842 = any(isnan(referenceColor));
    bool _849;
    if (!_842)
    {
        _849 = any(isinf(referenceColor));
    }
    else
    {
        _849 = _842;
    }
    if (_849)
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

