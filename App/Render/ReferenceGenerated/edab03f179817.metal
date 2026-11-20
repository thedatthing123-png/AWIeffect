// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/glaw.xml
// Original source comments and attribution:
// URP-style soft-knee threshold prefilter: keeps only the bright energy
// sample count from quality
// scatter -> gaussian falloff (high scatter = wider, softer glow)
// uniform disc density, denser center
// keep the glow circular
// Add
// Screen
// Lighten
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsedab03f179817
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float threshold;
    char _m6_pad[12];
    float softKnee;
    char _m7_pad[12];
    float radius;
    char _m8_pad[12];
    float scatter;
    char _m9_pad[12];
    float intensity;
    float4 glowColor;
    int blendMode;
    char _m12_pad[12];
    int quality;
    char _m13_pad[12];
    uint glowOnly;
    char _m14_pad[12];
    float mixAmt;
};

struct refAM35_edab03f179817_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 samp(thread const float2& c, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = fast::clamp(c, float2(0.0005000000237487256526947021484375), float2(0.999499976634979248046875));
    return texture2DCv(refInput, refInputSmplr, param).xyz;
}

static inline __attribute__((always_inline))
float3 prefilter(thread const float3& c, constant ReferenceUniformsedab03f179817& _66)
{
    float br = fast::max(c.x, fast::max(c.y, c.z));
    float knee = (_66.threshold * _66.softKnee) + 9.9999997473787516355514526367188e-05;
    float soft = (br - _66.threshold) + knee;
    soft = fast::clamp(soft, 0.0, 2.0 * knee);
    soft = (soft * soft) / (4.0 * knee);
    float contrib = fast::max(soft, br - _66.threshold);
    contrib /= fast::max(br, 9.9999997473787516355514526367188e-05);
    return c * contrib;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformsedab03f179817& _66, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 res = _66.refScreen.xy;
    float aspect = res.x / fast::max(1.0, res.y);
    float2 uv = gl_FragCoord.xy / _66.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 base = src.xyz;
    float samples = 64.0;
    if (_66.quality == 0)
    {
        samples = 24.0;
    }
    else
    {
        if (_66.quality == 1)
        {
            samples = 48.0;
        }
    }
    float k = mix(7.0, 1.2000000476837158203125, _66.scatter);
    float golden = 2.3999631404876708984375;
    float3 sum = float3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 64; i++)
    {
        if (float(i) >= samples)
        {
            break;
        }
        float fi = float(i);
        float t = (fi + 0.5) / samples;
        float r = sqrt(t);
        float ang = fi * golden;
        float2 off = (float2(cos(ang), sin(ang)) * r) * _66.radius;
        off.x /= aspect;
        float w = exp(((-r) * r) * k);
        float2 param_1 = uv + off;
        float3 param_2 = samp(param_1, refInput, refInputSmplr);
        sum += (prefilter(param_2, _66) * w);
        wsum += w;
    }
    float3 glow = sum / float3(fast::max(wsum, 9.9999997473787516355514526367188e-05));
    glow *= (_66.glowColor.xyz * _66.intensity);
    float3 outc;
    if (_66.blendMode == 0)
    {
        outc = base + glow;
    }
    else
    {
        if (_66.blendMode == 1)
        {
            outc = float3(1.0) - ((float3(1.0) - base) * (float3(1.0) - fast::clamp(glow, float3(0.0), float3(1.0))));
        }
        else
        {
            outc = fast::max(base, glow);
        }
    }
    if (_66.glowOnly != 0u)
    {
        outc = glow;
    }
    outc = mix(base, outc, float3(_66.mixAmt));
    referenceColor = float4(outc, src.w);
}

fragment refAM35_edab03f179817_out refAM35_edab03f179817(constant ReferenceUniformsedab03f179817& _66 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_edab03f179817_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _66, gl_FragCoord, referenceColor);
    bool _327 = any(isnan(referenceColor));
    bool _334;
    if (!_327)
    {
        _334 = any(isinf(referenceColor));
    }
    else
    {
        _334 = _327;
    }
    if (_334)
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

