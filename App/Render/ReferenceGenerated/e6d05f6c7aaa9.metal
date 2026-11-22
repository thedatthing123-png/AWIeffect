// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/pixelate2.xml
// Original source comments and attribution:
//color = mix(color, vec4(0.0,0.0,0.0,color.a), vignette * distCenter);
//color = vec4(color.rgb * (1.0-(vignette*distCenter)), color.a);
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

struct ReferenceUniformse6d05f6c7aaa9
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float size;
    char _m6_pad[8];
    float2 stretch;
    char _m7_pad[8];
    float2 offset;
    char _m8_pad[8];
    float angle;
    char _m9_pad[12];
    float vignette;
    char _m10_pad[12];
    uint screenSpace;
    char _m11_pad[12];
    float threshold;
    char _m12_pad[12];
    float saturation;
};

struct refAM35_e6d05f6c7aaa9_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse6d05f6c7aaa9& _54, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 sizeVec = float2(_54.size, _54.size);
    sizeVec.x *= _54.stretch.x;
    sizeVec.y *= _54.stretch.y;
    float2 pixelSize = sizeVec / _54.refScreen.xy;
    float2 st = gl_FragCoord.xy / _54.refScreen.xy;
    if (!(_54.screenSpace != 0u))
    {
        st -= (float2(_54.refLayer.x + (_54.refLayer.z * 0.5), (_54.refScreen.y - _54.refLayer.y) - (_54.refLayer.w * 0.5)) / _54.refScreen.xy);
    }
    float param = _54.angle * 0.01745329983532428741455078125;
    st *= rot(param);
    st -= (_54.offset / float2(1000.0));
    float2 posInPixel = mod(st, pixelSize);
    posInPixel -= (pixelSize / float2(2.0));
    float param_1 = (-_54.angle) * 0.01745329983532428741455078125;
    posInPixel *= rot(param_1);
    posInPixel += (pixelSize / float2(2.0));
    float2 pixelCenter = ((gl_FragCoord.xy / _54.refScreen.xy) - posInPixel) + (pixelSize / float2(2.0));
    float distCenter = smoothstep(0.0, 1.0, length((posInPixel / pixelSize) - float2(0.5)));
    float2 param_2 = pixelCenter;
    float4 color = texture2DCv(refInput, refInputSmplr, param_2);
    float tclamp = step(_54.threshold, color.w);
    bool _207 = color.w > 0.0;
    bool _214;
    if (_207)
    {
        _214 = _54.saturation > 0.0;
    }
    else
    {
        _214 = _207;
    }
    if (_214)
    {
        color /= float4(color.w / fast::max(color.w, _54.saturation));
    }
    color *= tclamp;
    color = mix(color, float4(fast::min((color.xyz * color.xyz) * color.xyz, float3(0.89999997615814208984375)), (color.w * color.w) * color.w), float4((step(1.5, _54.size) * _54.vignette) * distCenter));
    referenceColor = color;
}

fragment refAM35_e6d05f6c7aaa9_out refAM35_e6d05f6c7aaa9(constant ReferenceUniformse6d05f6c7aaa9& _54 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e6d05f6c7aaa9_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_54, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _276 = any(isnan(referenceColor));
    bool _283;
    if (!_276)
    {
        _283 = any(isinf(referenceColor));
    }
    else
    {
        _283 = _276;
    }
    if (_283)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _296 = referenceColor;
    float3 _302 = fast::clamp(_296.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _302.x;
    referenceColor.y = _302.y;
    referenceColor.z = _302.z;
    out.finalColor = referenceColor;
    return out;
}

