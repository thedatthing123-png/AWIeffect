// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxmtint.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
// if (adaptive) { 
// ...this is the video
// ...some contrast
// ...it's ok it's black and white!
// ...tint the dark values into cyan/teal.
// ...tint the light values into orange.
//
// ...mouse X to slide filter
// normal
// multiply
// screen
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsedc4cbd35eb7f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progressa;
    char _m6_pad[12];
    float progressc;
    char _m7_pad[12];
    float progressd;
    char _m8_pad[12];
    float progresse;
    char _m9_pad[12];
    float progressf;
    char _m10_pad[12];
    float bright;
    char _m11_pad[12];
    float alpha;
    char _m12_pad[12];
    int blendMode;
};

struct refAM35_edc4cbd35eb7f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsedc4cbd35eb7f& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = gl_FragCoord.xy / _36.refScreen.xy;
    float2 uv = syamjaidtz;
    float2 param_1 = uv;
    float3 orig = texture2DCv(refInput, refInputSmplr, param_1).xyz;
    float3 col = (orig * orig) * _36.progressa;
    float bri = ((col.x + col.y) + col.z) / 2.0;
    float v = smoothstep(0.0, _36.progressc, bri);
    col = mix(float3(_36.progressd, _36.progresse, _36.progressf) * bri, col, float3(v));
    v = smoothstep(0.20000000298023223876953125, 1.10000002384185791015625, bri);
    col = mix(col, fast::min(float3(1.0, 0.5, 0.0) * bri, float3(1.0)), float3(v));
    float x = 0.0;
    col = mix(orig, col, float3(step(x, uv.x)));
    float4 fragColor = float4(fast::min(col, float3(1.0)), 1.0);
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_36.blendMode == 0)
    {
        resultfinal = (factor * _36.bright) * texColor.w;
    }
    else
    {
        if (_36.blendMode == 1)
        {
            factor *= _36.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_36.blendMode == 2)
            {
                factor *= _36.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_36.alpha));
}

fragment refAM35_edc4cbd35eb7f_out refAM35_edc4cbd35eb7f(constant ReferenceUniformsedc4cbd35eb7f& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_edc4cbd35eb7f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _251 = any(isnan(referenceColor));
    bool _258;
    if (!_251)
    {
        _258 = any(isinf(referenceColor));
    }
    else
    {
        _258 = _251;
    }
    if (_258)
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

