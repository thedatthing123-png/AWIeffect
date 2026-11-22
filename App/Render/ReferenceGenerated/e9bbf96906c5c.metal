// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxcolorgrid.xml
// Original source comments and attribution:
/////////////////////////
// vec2 syamjaidtz;
// if (adaptive) { syamjaidtz = acScreenNorm; }
// else { 
// syamjaidtz = ((vec2(acScreenNorm.x,1.0-acScreenNorm.y)*acScreenSize)-acLayerCenter)/acLayerSize;
// syamjaidtz.y*=acLayerSize.y/acLayerSize.x;
// }
// syamjaidtz /= 1.0;
// syamjaidtz *= rot2m(0.0*0.0174533);
// syamjaidtz += vec2((0.0+position.x), (0.0+position.y))*vec2(-1.,1.)/500.;
/////////////////////////
// vec2  px = 4.0*(-acScreenNorm + scale*acLayerNorm.xy) / acScreenSize.y;
// result
// const vec3 luminanceWeighting = vec3(0.2126, 0.7152, 0.0722);
// vec4 gradmap;
// float luminance = dot(result.rgb, luminanceWeighting);
// gradmap = mix(color1,color2,luminance)*result.a;
// vec4 factor = mix(texColorX,gradmap,alpha);
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9bbf96906c5c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progressa;
    char _m6_pad[12];
    float progressb;
    char _m7_pad[12];
    float scale;
    char _m8_pad[12];
    float bright;
    char _m9_pad[12];
    float alpha;
    char _m10_pad[12];
    int blendMode;
};

struct refAM35_e9bbf96906c5c_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse9bbf96906c5c& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 px = (((-(gl_FragCoord.xy / _36.refScreen.xy)) + (gl_FragCoord.xy * _36.scale)) * 4.0) / float2(_36.refScreen.y);
    float id = 0.5 + (0.5 * cos(_36.progressa + (sin(dot(floor(px + float2(0.5)), float2(113.09999847412109375, 17.8099994659423828125))) * 43758.546875)));
    float3 co = float3(0.5) + (cos(float3(_36.progressb + (2.0 * id)) + float3(0.0, 1.0, 2.0)) * 0.5);
    float2 pa = smoothstep(float2(0.0), float2(0.20000000298023223876953125), (float2(0.5) + (cos(px * 6.283100128173828125) * 0.5)) * id);
    float4 result = float4((co * pa.x) * pa.y, 1.0);
    float4 factor = mix(texColorX, result, float4(_36.alpha));
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
    referenceColor = resultfinal;
}

fragment refAM35_e9bbf96906c5c_out refAM35_e9bbf96906c5c(constant ReferenceUniformse9bbf96906c5c& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9bbf96906c5c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _243 = any(isnan(referenceColor));
    bool _250;
    if (!_243)
    {
        _250 = any(isinf(referenceColor));
    }
    else
    {
        _250 = _243;
    }
    if (_250)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _263 = referenceColor;
    float3 _269 = fast::clamp(_263.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _269.x;
    referenceColor.y = _269.y;
    referenceColor.z = _269.z;
    out.finalColor = referenceColor;
    return out;
}

