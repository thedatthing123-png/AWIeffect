// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/glitch_pro.xml
// Original source comments and attribution:
// Precision Glitch (Shadertoy-style) -> Alight Motion port
// Timing
// 1. Large horizontal tearing
// 5. Scan lines
// 3 & 4. Datamosh & Static blocks
// Static block
// Datamosh block
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse5ad5e1e9a0fb
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float timeSpeed;
    char _m6_pad[12];
    float glitchRate;
    char _m7_pad[12];
    float flickerThreshold;
    char _m8_pad[12];
    float seed;
    char _m9_pad[12];
    float tearHeightMin;
    char _m10_pad[12];
    float tearHeightRand;
    char _m11_pad[12];
    float tearOffsetMax;
    char _m12_pad[12];
    float tearScanFreq;
    char _m13_pad[12];
    float tearScanAmp;
    char _m14_pad[12];
    float bandMix;
    char _m15_pad[12];
    float blockGridMin;
    char _m16_pad[12];
    float blockGridRand;
    char _m17_pad[12];
    float blockGridY;
    char _m18_pad[12];
    float blockAffectThr;
    char _m19_pad[12];
    float staticProbThr;
    char _m20_pad[12];
    uint enableColorBands;
    char _m21_pad[12];
    float bandProbThr;
};

struct refAM35_e5ad5e1e9a0fb_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float random(thread const float2& st)
{
    return fract(sin(dot(st, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 random2(thread const float2& st)
{
    float2 param = st;
    float2 param_1 = st + float2(1.0);
    return float2(random(param), random(param_1));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse5ad5e1e9a0fb& _65, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 fragCoord = (gl_FragCoord.xy / _65.refScreen.xy) * _65.refScreen.xy;
    float2 uv = gl_FragCoord.xy / _65.refScreen.xy;
    float2 param = uv;
    float4 originalColor = texture2DCv(refInput, refInputSmplr, param);
    float t = floor(((_65.refScreen.z * _65.timeSpeed) + (_65.seed * 0.001000000047497451305389404296875)) * _65.glitchRate);
    float2 param_1 = float2(t, 0.0);
    float glitchTrigger = random(param_1);
    if (glitchTrigger > _65.flickerThreshold)
    {
        float2 param_2 = float2(t, 2.0);
        float tearY = random(param_2);
        float2 param_3 = float2(t, 3.0);
        float tearHeight = _65.tearHeightMin + (random(param_3) * _65.tearHeightRand);
        float2 param_4 = float2(t, 4.0);
        float tearOffset = (random(param_4) - 0.5) * (_65.tearOffsetMax * 2.0);
        bool _162 = uv.y > tearY;
        bool _172;
        if (_162)
        {
            _172 = uv.y < (tearY + fast::max(tearHeight, 0.0));
        }
        else
        {
            _172 = _162;
        }
        if (_172)
        {
            float2 param_5 = float2(t, 5.0);
            float isColorBand = random(param_5);
            bool _186 = _65.enableColorBands != 0u;
            bool _194;
            if (_186)
            {
                _194 = isColorBand > _65.bandProbThr;
            }
            else
            {
                _194 = _186;
            }
            if (_194)
            {
                float2 duv = uv;
                duv.x = fract(duv.x + tearOffset);
                float2 param_6 = duv;
                float4 displacedColor = texture2DCv(refInput, refInputSmplr, param_6);
                float2 param_7 = float2(t, 6.0);
                float2 param_8 = float2(t, 7.0);
                float2 param_9 = float2(t, 8.0);
                float3 bandColor = float3(random(param_7), random(param_8), random(param_9));
                float4 _228 = displacedColor;
                float3 _236 = mix(_228.xyz, bandColor, float3(fast::clamp(_65.bandMix, 0.0, 1.0)));
                displacedColor.x = _236.x;
                displacedColor.y = _236.y;
                displacedColor.z = _236.z;
                float scanLine = sin(fragCoord.y * _65.tearScanFreq) * _65.tearScanAmp;
                float4 _255 = displacedColor;
                float3 _262 = fast::clamp(_255.xyz - float3(scanLine), float3(0.0), float3(1.0));
                displacedColor.x = _262.x;
                displacedColor.y = _262.y;
                displacedColor.z = _262.z;
                originalColor = displacedColor;
            }
            else
            {
                float2 duv_1 = uv;
                duv_1.x = fract(duv_1.x + tearOffset);
                float2 param_10 = duv_1;
                originalColor = texture2DCv(refInput, refInputSmplr, param_10);
            }
        }
        float2 param_11 = float2(t, 9.0);
        float gridX = _65.blockGridMin + (random(param_11) * _65.blockGridRand);
        float2 blockGrid = floor(uv * float2(fast::max(1.0, gridX), fast::max(1.0, _65.blockGridY)));
        float2 param_12 = blockGrid + float2(t);
        float blockTrigger = random(param_12);
        if (blockTrigger > _65.blockAffectThr)
        {
            float2 param_13 = (blockGrid + float2(10.0)) + float2(t);
            float blockType = random(param_13);
            if (blockType > _65.staticProbThr)
            {
                float2 sc = fract(uv * 10.0);
                float2 param_14 = sc;
                float2 param_15 = sc.yx;
                float2 param_16 = uv;
                float3 _355 = fast::clamp(float3(random(param_14), random(param_15), random(param_16)), float3(0.0), float3(1.0));
                originalColor.x = _355.x;
                originalColor.y = _355.y;
                originalColor.z = _355.z;
            }
            else
            {
                float2 param_17 = blockGrid + float2(23.0);
                float2 ro = (random2(param_17) - float2(0.5)) * 2.0;
                float2 param_18 = fract(uv + ro);
                originalColor = texture2DCv(refInput, refInputSmplr, param_18);
            }
        }
    }
    referenceColor = originalColor;
}

fragment refAM35_e5ad5e1e9a0fb_out refAM35_e5ad5e1e9a0fb(constant ReferenceUniformse5ad5e1e9a0fb& _65 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e5ad5e1e9a0fb_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _65, refInput, refInputSmplr, referenceColor);
    bool _387 = any(isnan(referenceColor));
    bool _394;
    if (!_387)
    {
        _394 = any(isinf(referenceColor));
    }
    else
    {
        _394 = _387;
    }
    if (_394)
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

