// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxhexagonblur.xml
// Original source comments and attribution:
/////////////////////////
// const int NUM_SAMPLES = 16;
/////////////////////////
/////////////////////////
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseed18fc59f8e7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float NUM_SAMPLES;
    char _m6_pad[12];
    float STRENGTH;
    char _m7_pad[12];
    float hardness;
    char _m8_pad[12];
    float alpha;
    char _m9_pad[12];
    float iter;
};

struct refAM35_eed18fc59f8e7_out
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
float3 srgb2lin(thread const float3& c)
{
    return c * c;
}

static inline __attribute__((always_inline))
float3 lin2srgb(thread const float3& c)
{
    return sqrt(c);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseed18fc59f8e7& _60, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _60.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param_1);
    float2 iResolution = float2(_60.refScreen.x, _60.refScreen.y);
    float2 syamjaidtz = gl_FragCoord.xy / _60.refScreen.xy;
    float2 uv = syamjaidtz;
    float3 sumcol0 = float3(0.0);
    float2 blurdir = float2(1.0, 0.57735025882720947265625);
    float2 blurvec = fast::normalize(blurdir) / iResolution;
    float2 p0 = uv - (blurvec * (0.5 * _60.STRENGTH));
    float2 p1 = uv + (blurvec * (0.5 * _60.STRENGTH));
    float2 stepvec = (p1 - p0) / float2(_60.NUM_SAMPLES);
    float2 p = p0;
    for (int i = 0; i < int(_60.NUM_SAMPLES); i++)
    {
        float2 param_2 = p;
        float3 param_3 = texture2DCv(refInput, refInputSmplr, param_2).xyz;
        sumcol0 += srgb2lin(param_3);
        p += stepvec;
    }
    sumcol0 /= float3(_60.NUM_SAMPLES);
    float3 sumcol1 = float3(0.0);
    float2 blurdir_1 = float2(-1.0, 0.57735025882720947265625);
    float2 blurvec_1 = fast::normalize(blurdir_1) / iResolution;
    float2 p0_1 = uv - (blurvec_1 * (0.5 * _60.STRENGTH));
    float2 p1_1 = uv + (blurvec_1 * (0.5 * _60.STRENGTH));
    float2 stepvec_1 = (p1_1 - p0_1) / float2(_60.NUM_SAMPLES);
    float2 p_1 = p0_1;
    for (int i_1 = 0; i_1 < int(_60.NUM_SAMPLES); i_1++)
    {
        float2 param_4 = p_1;
        float3 param_5 = texture2DCv(refInput, refInputSmplr, param_4).xyz;
        sumcol1 += srgb2lin(param_5);
        p_1 += stepvec_1;
    }
    sumcol1 /= float3(_60.NUM_SAMPLES);
    float3 sumcol = fast::min(sumcol0, sumcol1);
    float3 param_6 = sumcol;
    float4 fragColor = float4(lin2srgb(param_6), 1.0);
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal = (factor * _60.hardness) * texColor.w;
    referenceColor = mix(texColor, resultfinal, float4(_60.alpha));
}

fragment refAM35_eed18fc59f8e7_out refAM35_eed18fc59f8e7(constant ReferenceUniformseed18fc59f8e7& _60 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eed18fc59f8e7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _60, referenceColor);
    bool _281 = any(isnan(referenceColor));
    bool _288;
    if (!_281)
    {
        _288 = any(isinf(referenceColor));
    }
    else
    {
        _288 = _281;
    }
    if (_288)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _301 = referenceColor;
    float3 _307 = fast::clamp(_301.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _307.x;
    referenceColor.y = _307.y;
    referenceColor.z = _307.z;
    out.finalColor = referenceColor;
    return out;
}

