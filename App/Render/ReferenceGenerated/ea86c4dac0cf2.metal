// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/cinematic_bokeh.xml
// Original source comments and attribution:
// Polygon mapping function
// Shape modulation
// Anamorphic scaling and aspect correction
// Professional highlight blooming
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

struct ReferenceUniformsea86c4dac0cf2
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int blurShape;
    char _m6_pad[12];
    float blurWidth;
    char _m7_pad[12];
    float blurHeight;
    char _m8_pad[12];
    float blurRadius;
    char _m9_pad[12];
    float highlightThreshold;
    char _m10_pad[12];
    float highlightGain;
    char _m11_pad[12];
    float quality;
};

struct refAM35_ea86c4dac0cf2_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsea86c4dac0cf2& _34, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _34.refScreen.xy;
    float aspect = _34.refScreen.x / _34.refScreen.y;
    float r = _34.blurRadius;
    float iterations = _34.quality;
    float3 acc = float3(0.0);
    float tot = 0.0;
    float sides = float(_34.blurShape);
    for (int i = 0; i < 32; i++)
    {
        if (float(i) >= iterations)
        {
            break;
        }
        float fi = float(i);
        float theta = fi * 2.3999631404876708984375;
        float rad = sqrt(fi) / sqrt(iterations);
        if (sides > 2.5)
        {
            float deg = 6.283185482025146484375 / sides;
            rad *= (1.0 / cos(mod(theta, deg) - (deg * 0.5)));
        }
        float2 off = float2(cos(theta), sin(theta));
        float2 offset = (off * rad) * r;
        offset.x *= (_34.blurWidth / aspect);
        offset.y *= _34.blurHeight;
        float2 param = uv + offset;
        float3 col = texture2DCv(refInput, refInputSmplr, param).xyz;
        float lum = dot(col, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
        float weight = powr(fast::max(0.0, (lum - _34.highlightThreshold) / (1.0 - fast::min(0.9900000095367431640625, _34.highlightThreshold))), _34.highlightGain) + 0.00999999977648258209228515625;
        acc += (col * weight);
        tot += weight;
    }
    float3 finalCol = acc / float3(tot);
    referenceColor = float4(finalCol, 1.0);
}

fragment refAM35_ea86c4dac0cf2_out refAM35_ea86c4dac0cf2(constant ReferenceUniformsea86c4dac0cf2& _34 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea86c4dac0cf2_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _34, refInput, refInputSmplr, referenceColor);
    bool _214 = any(isnan(referenceColor));
    bool _221;
    if (!_214)
    {
        _221 = any(isinf(referenceColor));
    }
    else
    {
        _221 = _214;
    }
    if (_221)
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

