// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/wavewarp2.xml
// Original source comments and attribution:
//if( !screenSpace ) {
//    st = (vec4(st,0.0,1.0) * acLayerToScreen).xy;
//}
//vec4(ddist*texColor.a,texColor.gba);
//mat2 rot = mat2(
//    cos(a), -sin(a),
//    sin(a), cos(a)
//);
//
//vec2 st = acLayerNorm;
//st += sin((st*rot).y*freq+phase)*mag;
//gl_FragColor = texture2DCv(inputImg.texture,(vec4(st,0.0,1.0)*acLayerToScreen).xy);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb23379931981
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float phase;
    char _m6_pad[12];
    float a1d;
    char _m7_pad[12];
    float m1;
    char _m8_pad[12];
    float m2;
    char _m9_pad[12];
    float a2d;
    char _m10_pad[12];
    float damping;
    char _m11_pad[12];
    float dampingSpace;
    char _m12_pad[12];
    float dampingOrigin;
    char _m13_pad[12];
    uint screenSpace;
};

struct refAM35_eb23379931981_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseb23379931981& _31, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float a1 = _31.a1d * 0.01745329983532428741455078125;
    float a2 = (_31.a1d + _31.a2d) * 0.01745329983532428741455078125;
    float2 st;
    if (_31.screenSpace != 0u)
    {
        st = gl_FragCoord.xy / _31.refScreen.xy;
    }
    else
    {
        st = (gl_FragCoord.xy - _31.refLayer.xy) / _31.refLayer.zw;
    }
    float2 raw_v = float2(cos(a1), -sin(a1));
    float raw_p = dot(st, raw_v);
    float space_damp = 1.0;
    if (_31.dampingSpace < 0.0)
    {
        space_damp = 1.0 - (fast::clamp(abs(raw_p - _31.dampingOrigin), 0.0, 1.0) * (0.0 - _31.dampingSpace));
    }
    else
    {
        if (_31.dampingSpace > 0.0)
        {
            space_damp = 1.0 - ((1.0 - fast::clamp(abs(raw_p - _31.dampingOrigin), 0.0, 1.0)) * _31.dampingSpace);
        }
    }
    float space = _31.m1 * space_damp;
    float2 v = float2(cos(a1), -sin(a1)) * space;
    float p = dot(st, v);
    float ddist = abs(p / space);
    float damp = 1.0;
    if (_31.damping < 0.0)
    {
        damp = 1.0 - (fast::clamp(abs(ddist - _31.dampingOrigin), 0.0, 1.0) * (0.0 - _31.damping));
    }
    else
    {
        if (_31.damping > 0.0)
        {
            damp = 1.0 - ((1.0 - fast::clamp(abs(ddist - _31.dampingOrigin), 0.0, 1.0)) * _31.damping);
        }
    }
    float2 offs = (float2(cos(a2), -sin(a2)) * (_31.m2 * damp)) / float2(100.0);
    offs *= sin(p + (_31.phase * 6.28318023681640625));
    float2 param = (gl_FragCoord.xy / _31.refScreen.xy) + offs;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    referenceColor = texColor;
}

fragment refAM35_eb23379931981_out refAM35_eb23379931981(constant ReferenceUniformseb23379931981& _31 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb23379931981_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_31, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _234 = any(isnan(referenceColor));
    bool _241;
    if (!_234)
    {
        _241 = any(isinf(referenceColor));
    }
    else
    {
        _241 = _234;
    }
    if (_241)
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

