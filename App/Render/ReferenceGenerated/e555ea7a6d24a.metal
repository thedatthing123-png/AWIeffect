// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/mirror.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse555ea7a6d24a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int type;
    char _m6_pad[12];
    int blendMode;
    char _m7_pad[12];
    float alpha;
    char _m8_pad[12];
    float offset;
};

struct refAM35_e555ea7a6d24a_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse555ea7a6d24a& _39)
{
    return (float4(v, 0.0, 1.0) * _39.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse555ea7a6d24a& _39, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st = (gl_FragCoord.xy - _39.refLayer.xy) / _39.refLayer.zw;
    float2 param = gl_FragCoord.xy / _39.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    if (_39.type == 1)
    {
        st.y = 1.0 - st.y;
        st.y += _39.offset;
    }
    else
    {
        st.x = 1.0 - st.x;
        st.x += _39.offset;
    }
    float2 param_1 = st;
    float2 param_2 = l2s(param_1, _39);
    float4 color = texture2DCv(refInput, refInputSmplr, param_2);
    float4 result;
    if (_39.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(texColor.w)) * color.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_39.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - color.xyz)), 1.0) * texColor.w;
        }
        else
        {
            if (_39.blendMode == 3)
            {
                result = (texColor * (1.0 - color.w)) + color;
            }
            else
            {
                if (_39.blendMode == 4)
                {
                    result = (color * (1.0 - texColor.w)) + texColor;
                }
                else
                {
                    result = color;
                }
            }
        }
    }
    referenceColor = mix(texColor, result, float4(_39.alpha));
}

fragment refAM35_e555ea7a6d24a_out refAM35_e555ea7a6d24a(constant ReferenceUniformse555ea7a6d24a& _39 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e555ea7a6d24a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_39, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _213 = any(isnan(referenceColor));
    bool _220;
    if (!_213)
    {
        _220 = any(isinf(referenceColor));
    }
    else
    {
        _220 = _213;
    }
    if (_220)
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

