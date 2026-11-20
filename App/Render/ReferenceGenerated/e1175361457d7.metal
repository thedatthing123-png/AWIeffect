// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/clouds3.xml
// Original source comments and attribution:
// Based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
// Four corners in 2D of a tile
// Initial values
//
// Loop of octaves
//vec2(offsx,offsy);
//vec2(parrx, parry);
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

struct ReferenceUniformse1175361457d7
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 parr;
    char _m6_pad[8];
    float2 offs;
    char _m7_pad[8];
    float scale;
    char _m8_pad[8];
    float2 stretch;
    char _m9_pad[8];
    float intensity;
    char _m10_pad[12];
    float seed;
    float4 color1;
    float4 color2;
    float octaves;
};

struct refAM35_e1175361457d7_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float random(thread const float2& st)
{
    return fract(sin(dot(st, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& st)
{
    float2 i = floor(st);
    float2 f = fract(st);
    float2 param = i;
    float a = random(param);
    float2 param_1 = i + float2(1.0, 0.0);
    float b = random(param_1);
    float2 param_2 = i + float2(0.0, 1.0);
    float c = random(param_2);
    float2 param_3 = i + float2(1.0);
    float d = random(param_3);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    return (mix(a, b, u.x) + (((c - a) * u.y) * (1.0 - u.x))) + (((d - b) * u.x) * u.y);
}

static inline __attribute__((always_inline))
float fbm(thread float2& st, thread const float2& parallax, thread const int& octaveCount, thread const float& intens)
{
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 0.0;
    for (int i = 0; i < octaveCount; i++)
    {
        float2 param = st;
        value += (amplitude * _noise(param));
        st *= 2.0;
        st += parallax;
        amplitude *= intens;
    }
    return value;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse1175361457d7& _171, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _171.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _171.refLayer.xy) / _171.refLayer.zw;
    st.x *= (_171.refLayer.z / _171.refLayer.w);
    st += ((_171.offs * float2(-1.0, 1.0)) / float2(500.0));
    st += mod(float2(821.9210205078125 * _171.seed, 437.316986083984375 * _171.seed), float2(4.3649997711181640625, 7.701000213623046875));
    float2 parallax = (_171.parr * float2(-1.0, 1.0)) / float2(100.0);
    float2 scaleVec = float2(_171.scale * _171.stretch.x, _171.scale * _171.stretch.y);
    float2 param_1 = (((st - float2(0.5)) * 3.0) / scaleVec) + float2(0.5);
    float2 param_2 = parallax;
    int param_3 = int(_171.octaves);
    float param_4 = _171.intensity;
    float _278 = fbm(param_1, param_2, param_3, param_4);
    float4 rcolor = mix(_171.color1, _171.color2, float4(_278));
    rcolor *= texColor.w;
    referenceColor = rcolor + (texColor * (1.0 - rcolor.w));
}

fragment refAM35_e1175361457d7_out refAM35_e1175361457d7(constant ReferenceUniformse1175361457d7& _171 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e1175361457d7_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _171, referenceColor);
    bool _299 = any(isnan(referenceColor));
    bool _306;
    if (!_299)
    {
        _306 = any(isinf(referenceColor));
    }
    else
    {
        _306 = _299;
    }
    if (_306)
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

