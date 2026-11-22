// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/wobble-rail-streaks.xml
// Original source comments and attribution:
// Wobble Rail Streaks - AM single pass, GLES-safe
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse095ca329604f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float SPEED;
    char _m6_pad[12];
    float UV_SCALE;
    char _m7_pad[12];
    float STEPS;
    char _m8_pad[12];
    float DENOM_BIAS;
    char _m9_pad[12];
    float GAIN;
    char _m10_pad[12];
    float WOBBLE_FREQ;
    char _m11_pad[12];
    float WOBBLE_AMP;
    char _m12_pad[12];
    float PULL_MIN;
    char _m13_pad[12];
    float PULL_ADD;
    char _m14_pad[12];
    float DOT_MIN;
    char _m15_pad[12];
    float DOT_ADD;
    char _m16_pad[12];
    float PAT_MIN;
    char _m17_pad[12];
    float PAT_ADD;
    char _m18_pad[12];
    float PAT_BASE;
    char _m19_pad[12];
    float PAT_GAIN;
    char _m20_pad[12];
    float THRESH_1;
    char _m21_pad[12];
    float THRESH_2;
    char _m22_pad[12];
    float BRIGHT_1;
    char _m23_pad[12];
    float BRIGHT_2;
    char _m24_pad[12];
    float SHADOW_DECAY;
    char _m25_pad[12];
    float SHADOW_GAIN;
    char _m26_pad[12];
    float R_MIN;
    char _m27_pad[12];
    float R_ADD;
    char _m28_pad[12];
    float G_MIN;
    char _m29_pad[12];
    float G_ADD;
    char _m30_pad[12];
    float B_MIN;
    char _m31_pad[12];
    float B_ADD;
    char _m32_pad[12];
    float GAMMA;
};

struct refAM35_e095ca329604f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float rand21(thread const float2& c)
{
    return fract(sin(dot(c, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse095ca329604f& _31, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 R = _31.refScreen.xy;
    float2 frag = (gl_FragCoord.xy / _31.refScreen.xy) * R;
    float2 p = (((frag * 2.0) - R) / float2(fast::min(R.x, R.y))) * _31.UV_SCALE;
    float z0 = _31.refScreen.z * _31.SPEED;
    float i = floor(z0);
    float offs = fract(z0);
    float shadow = 1.0;
    float3 outc = float3(0.0);
    int maxSteps = int(fast::clamp(_31.STEPS, 1.0, 300.0));
    for (int zi = 1; zi < 300; zi++)
    {
        if (zi >= maxSteps)
        {
            break;
        }
        float z = float(zi);
        float z2 = z - offs;
        float randz = z + i;
        float2 param = float2(randz, 1.0);
        float dadt = ((rand21(param) * 2.0) - 1.0) * 0.5;
        float2 param_1 = float2(randz, 1.0);
        float a = ((rand21(param_1) * 2.0) * 3.1415927410125732421875) + (dadt * _31.refScreen.z);
        float2 param_2 = float2(randz, 3.0);
        float pullback = (rand21(param_2) * _31.PULL_ADD) + _31.PULL_MIN;
        float2 param_3 = float2(randz, 4.0);
        float r = (rand21(param_3) * _31.R_ADD) + _31.R_MIN;
        float2 param_4 = float2(randz, 5.0);
        float g = (rand21(param_4) * _31.G_ADD) + _31.G_MIN;
        float2 param_5 = float2(randz, 6.0);
        float b = (rand21(param_5) * _31.B_ADD) + _31.B_MIN;
        float2 origin = (float2(sin(randz * 0.004999999888241291046142578125) + sin(randz * 0.00200000009499490261077880859375), cos(randz * 0.004999999888241291046142578125) + cos(randz * 0.00200000009499490261077880859375)) * z2) * 0.00200000009499490261077880859375;
        float2 dir = float2(cos(a), sin(a));
        float dist = dot(dir, p - origin) * z2;
        float xdist = dot(float2(-dir.y, dir.x), p - origin) * z2;
        float wobble = (dist - pullback) + (sin(xdist * _31.WOBBLE_FREQ) * _31.WOBBLE_AMP);
        if (wobble > 0.0)
        {
            float2 param_6 = float2(randz, 7.0);
            float dotsize = (rand21(param_6) * _31.DOT_ADD) + _31.DOT_MIN;
            float2 param_7 = float2(randz, 8.0);
            float patternsize = (rand21(param_7) * _31.PAT_ADD) + _31.PAT_MIN;
            float pattern = (step(dotsize, length(fract(float2(dist, xdist) * patternsize) - float2(0.5))) * _31.PAT_GAIN) + _31.PAT_BASE;
            float bright = 1.0;
            if (wobble < _31.THRESH_1)
            {
                bright = _31.BRIGHT_1;
            }
            else
            {
                if (wobble < _31.THRESH_2)
                {
                    bright = _31.BRIGHT_2;
                }
                else
                {
                    bright = pattern;
                }
            }
            float3 col = float3(r, g, b);
            float3 cacc = (((col * _31.GAIN) * shadow) / float3(z2 + _31.DENOM_BIAS)) * bright;
            outc = cacc;
            outc = powr(fast::max(outc, float3(0.0)), float3(_31.GAMMA));
            referenceColor = float4(outc, 1.0);
            return;
        }
        else
        {
            shadow *= (1.0 - (exp((dist - pullback) * _31.SHADOW_DECAY) * _31.SHADOW_GAIN));
        }
    }
    referenceColor = float4(0.0, 0.0, 0.0, 1.0);
}

fragment refAM35_e095ca329604f_out refAM35_e095ca329604f(constant ReferenceUniformse095ca329604f& _31 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e095ca329604f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_31, gl_FragCoord, referenceColor);
    bool _408 = any(isnan(referenceColor));
    bool _415;
    if (!_408)
    {
        _415 = any(isinf(referenceColor));
    }
    else
    {
        _415 = _408;
    }
    if (_415)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _429 = referenceColor;
    float3 _435 = fast::clamp(_429.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _435.x;
    referenceColor.y = _435.y;
    referenceColor.z = _435.z;
    out.finalColor = referenceColor;
    return out;
}

