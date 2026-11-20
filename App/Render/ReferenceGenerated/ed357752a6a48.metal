// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/grid2.xml
// Original source comments and attribution:
//st = ((vec2(acScreenNorm.x,1.0-acScreenNorm.y)*acScreenSize)-acLayerCenter)/length(acLayerSize);
//px = smoothstep(w,w-s,px)*smoothstep(0.0,s,px);
//py = smoothstep(w,w-s,py)*smoothstep(0.0,s,py);
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

struct ReferenceUniformsed357752a6a48
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float spacing;
    char _m7_pad[12];
    float width;
    float4 color;
    uint punchout;
    char _m10_pad[12];
    float smoothing;
    char _m11_pad[12];
    uint screenSpace;
};

struct refAM35_ed357752a6a48_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsed357752a6a48& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st;
    if (_36.screenSpace != 0u)
    {
        st = gl_FragCoord.xy / _36.refScreen.xy;
        st.x *= (_36.refScreen.x / _36.refScreen.y);
        st.y = 1.0 - st.y;
    }
    else
    {
        st = (gl_FragCoord.xy - _36.refLayer.xy) / _36.refLayer.zw;
        st.x *= (_36.refLayer.z / _36.refLayer.w);
        st.y = 1.0 - st.y;
    }
    st -= float2(0.5);
    st -= (_36.position / float2(1000.0));
    float px = mod(st.x, _36.spacing) / _36.spacing;
    float py = mod(st.y, _36.spacing) / _36.spacing;
    px = 1.0 - (abs(px - 0.5) * 2.0);
    py = 1.0 - (abs(py - 0.5) * 2.0);
    float w = fast::clamp(_36.width / _36.spacing, 0.0, 1.0);
    float s = w * _36.smoothing;
    s = mix(s, fast::max(s, 0.5 * w), smoothstep(0.01200000010430812835693359375, 0.00999999977648258209228515625, _36.width));
    s = mix(s, fast::max(s, w), smoothstep(0.006000000052154064178466796875, 0.004999999888241291046142578125, _36.width));
    px = smoothstep((1.0 - w) - s, (1.0 - w) + s, px);
    py = smoothstep((1.0 - w) - s, (1.0 - w) + s, py);
    float p = fast::max(px, py);
    float4 c = _36.color * p;
    if (_36.punchout != 0u)
    {
        referenceColor = texColor * (1.0 - p);
    }
    else
    {
        float alpha = c.w * texColor.w;
        referenceColor = (c * alpha) + (texColor * (1.0 - alpha));
    }
}

fragment refAM35_ed357752a6a48_out refAM35_ed357752a6a48(constant ReferenceUniformsed357752a6a48& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed357752a6a48_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _247 = any(isnan(referenceColor));
    bool _254;
    if (!_247)
    {
        _254 = any(isinf(referenceColor));
    }
    else
    {
        _254 = _247;
    }
    if (_254)
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

