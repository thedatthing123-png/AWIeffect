// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxtonecurve.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse98c76d49aae0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float highlights;
    char _m6_pad[12];
    float lights;
    char _m7_pad[12];
    float shadows;
    char _m8_pad[12];
    float darks;
    char _m9_pad[12];
    float alpha;
};

struct refAM35_e98c76d49aae0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse98c76d49aae0& _42, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _42.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = _42.refScreen.xy;
    float2 image_size = getTexSize(param_1);
    float2 iResolution = float2(_42.refScreen.x, _42.refScreen.y);
    float2 iMouse = float2(0.5);
    float2 syamjaidtz = gl_FragCoord.xy / _42.refScreen.xy;
    float2 param_2 = gl_FragCoord.xy / _42.refScreen.xy;
    float4 col = texture2DCv(refInput, refInputSmplr, param_2);
    float lum = ((col.x + col.y) + col.z) / 3.0;
    float4 lightValues;
    lightValues.x = lum;
    lightValues.y = lum;
    lightValues.z = 1.0 - lum;
    lightValues.w = 1.0 - lum;
    float4 _119 = lightValues;
    float2 _125 = (_119.xz - float2(0.25)) * 1.33333337306976318359375;
    lightValues.x = _125.x;
    lightValues.z = _125.y;
    float4 _131 = lightValues;
    float2 _135 = (_131.yw - float2(0.5)) * 2.0;
    lightValues.y = _135.x;
    lightValues.w = _135.y;
    lightValues = fast::max(lightValues, float4(0.0)) * 1.5;
    lightValues = ((float4(3.0) - (lightValues * 2.0)) * lightValues) * lightValues;
    float4 paramWeights;
    paramWeights.x = (_42.lights * _42.lights) * sign(_42.lights);
    paramWeights.y = (_42.highlights * _42.highlights) * sign(_42.highlights);
    paramWeights.z = (_42.shadows * _42.shadows) * sign(_42.shadows);
    paramWeights.w = (_42.darks * _42.darks) * sign(_42.darks);
    float sum = (((abs(paramWeights.x) + abs(paramWeights.y)) + abs(paramWeights.z)) + abs(paramWeights.w)) + 1.0;
    float4 _221 = col;
    float3 _224 = _221.xyz + float3(dot(lightValues, paramWeights) / sum);
    col.x = _224.x;
    col.y = _224.y;
    col.z = _224.z;
    float3 _237 = fast::min(col.xyz, float3(col.w));
    float4 fragColor;
    fragColor.x = _237.x;
    fragColor.y = _237.y;
    fragColor.z = _237.z;
    fragColor.w = col.w;
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal = factor * texColor.w;
    referenceColor = mix(texColor, resultfinal, float4(_42.alpha)) * texColor.w;
}

fragment refAM35_e98c76d49aae0_out refAM35_e98c76d49aae0(constant ReferenceUniformse98c76d49aae0& _42 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e98c76d49aae0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _42, referenceColor);
    bool _275 = any(isnan(referenceColor));
    bool _282;
    if (!_275)
    {
        _282 = any(isinf(referenceColor));
    }
    else
    {
        _282 = _275;
    }
    if (_282)
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

