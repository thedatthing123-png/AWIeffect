// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/gradientoverlay2.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformsec9e48a380de9
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    float angle;
    char _m8_pad[8];
    float2 offset;
    char _m9_pad[8];
    float scale;
    char _m10_pad[12];
    float alpha;
    char _m11_pad[12];
    int gradType;
    char _m12_pad[12];
    int blendMode;
};

struct refAM35_ec9e48a380de9_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsec9e48a380de9& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float a = _36.angle * 0.01745329983532428741455078125;
    float2 st = (gl_FragCoord.xy - _36.refLayer.xy) / _36.refLayer.zw;
    st -= float2(0.5);
    st -= ((_36.offset * float2(1.0, -1.0)) / float2(500.0));
    st /= float2(_36.scale);
    st *= float2x2(float2(sin(a), -cos(a)), float2(cos(a), sin(a)));
    st += float2(0.5);
    float t;
    if (_36.gradType == 0)
    {
        t = st.x;
    }
    else
    {
        if (_36.gradType == 1)
        {
            t = length(st - float2(0.5)) * 2.0;
        }
        else
        {
            if (_36.gradType == 2)
            {
                float2 xy = st - float2(0.5);
                float2 zw = float2(0.0, 1.0);
                float a_1 = precise::atan2(xy.x, xy.y);
                float b = precise::atan2(zw.x, zw.y);
                t = mod((a_1 - b) + 6.280000209808349609375, 6.280000209808349609375) / 6.280000209808349609375;
            }
            else
            {
                t = st.x;
            }
        }
    }
    t = fast::clamp(t, 0.0, 1.0);
    float4 color = mix(_36.color1, _36.color2, float4(t));
    float4 result;
    if (_36.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(texColor.w)) * color.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_36.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - color.xyz)), 1.0) * texColor.w;
        }
        else
        {
            result = float4(color.xyz, 1.0) * texColor.w;
        }
    }
    referenceColor = mix(texColor, result, float4(_36.alpha * color.w));
}

fragment refAM35_ec9e48a380de9_out refAM35_ec9e48a380de9(constant ReferenceUniformsec9e48a380de9& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec9e48a380de9_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _260 = any(isnan(referenceColor));
    bool _267;
    if (!_260)
    {
        _267 = any(isinf(referenceColor));
    }
    else
    {
        _267 = _260;
    }
    if (_267)
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

