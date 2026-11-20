// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/stripes.xml
// Original source comments and attribution:
//st /= st.y;
//st /= acLayerSize.y;
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

struct ReferenceUniformseaf016082e969
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amount;
    char _m6_pad[12];
    float width;
    char _m7_pad[12];
    float angle;
    char _m8_pad[12];
    float phase;
    float4 color;
    uint punchout;
    char _m11_pad[12];
    float smoothing;
    char _m12_pad[12];
    uint screenSpace;
};

struct refAM35_eaf016082e969_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseaf016082e969& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st;
    if (_36.screenSpace != 0u)
    {
        st = gl_FragCoord.xy / _36.refScreen.xy;
        st.y = 1.0 - st.y;
        st -= float2(0.5);
        st.x *= (_36.refScreen.x / _36.refScreen.y);
    }
    else
    {
        st = ((float2((gl_FragCoord.xy / _36.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _36.refScreen.xy).y) * _36.refScreen.xy) - float2(_36.refLayer.x + (_36.refLayer.z * 0.5), (_36.refScreen.y - _36.refLayer.y) - (_36.refLayer.w * 0.5))) / float2(length(_36.refLayer.zw));
    }
    float a = _36.angle * 0.01745329983532428741455078125;
    st *= float2x2(float2(sin(a), -cos(a)), float2(cos(a), sin(a)));
    float p = mod((st.x * _36.amount) + _36.phase, 1.0);
    p = smoothstep(_36.width, _36.width - _36.smoothing, p) * smoothstep(0.0, _36.smoothing, p);
    float4 c = _36.color * p;
    if (_36.punchout != 0u)
    {
        referenceColor = texColor * (1.0 - p);
    }
    else
    {
        c *= texColor.w;
        referenceColor = c + (texColor * (1.0 - c.w));
    }
}

fragment refAM35_eaf016082e969_out refAM35_eaf016082e969(constant ReferenceUniformseaf016082e969& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eaf016082e969_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _215 = any(isnan(referenceColor));
    bool _222;
    if (!_215)
    {
        _222 = any(isinf(referenceColor));
    }
    else
    {
        _222 = _215;
    }
    if (_222)
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

