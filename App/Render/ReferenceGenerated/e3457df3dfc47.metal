// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxfractaltexture.xml
// Original source comments and attribution:
/////////////////////////
// vec2 st = acLayerNorm;
// st -= 0.5;
// st.x *= acLayerSize.x/acLayerSize.y;
// st /= 1.0;
// st.x /= acLayerSize.x/acLayerSize.y;
// st += 0.5;
// vec2 sampleCoord = l2s(st);
// vec4 texColor = texture2DCv(inputImg.texture,sampleCoord);
/////////////////////////
// gl_FragColor = result * texColor.a * alpha;
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse3457df3dfc47
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 offset;
    char _m6_pad[8];
    float scale;
    char _m7_pad[12];
    float alpha;
    char _m8_pad[12];
    float angle;
    char _m9_pad[12];
    int blendMode;
};

struct refAM35_e3457df3dfc47_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse3457df3dfc47& _60, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _60.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 uv = (gl_FragCoord.xy - _60.refLayer.xy) / _60.refLayer.zw;
    uv -= float2(0.5);
    uv /= float2(_60.scale);
    uv.x *= (_60.refLayer.z / _60.refLayer.w);
    float param_1 = _60.angle * 0.01745329983532428741455078125;
    uv *= rot2m(param_1);
    float2 m = _60.offset / _60.refScreen.xy;
    float3 p = float3(uv, (0.5 - m.x) + 0.00199666828848421573638916015625);
    for (int i = 0; i < 32; i++)
    {
        float3 _164 = float3(1.2999999523162841796875, 0.999000012874603271484375, 0.777000010013580322265625) * abs((p / float3(dot(p, p))) - float3(1.0, 1.0, m.y * 0.300000011920928955078125));
        p = float3(_164.x, _164.z, _164.y);
    }
    float4 result = float4(p, 1.0);
    result *= _60.alpha;
    float4 factor = result;
    float4 resultfinal;
    if (_60.blendMode == 0)
    {
        factor *= texColor.w;
        resultfinal = factor + (texColor * (1.0 - factor.w));
    }
    else
    {
        if (_60.blendMode == 1)
        {
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_60.blendMode == 2)
            {
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = resultfinal;
}

fragment refAM35_e3457df3dfc47_out refAM35_e3457df3dfc47(constant ReferenceUniformse3457df3dfc47& _60 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e3457df3dfc47_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _60, referenceColor);
    bool _268 = any(isnan(referenceColor));
    bool _275;
    if (!_268)
    {
        _275 = any(isinf(referenceColor));
    }
    else
    {
        _275 = _268;
    }
    if (_275)
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

