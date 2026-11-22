// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/lightning.xml
// Original source comments and attribution:
// 2D Random
// 2D Noise based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
// Four corners in 2D of a tile
// Interpolation
// Cubic Hermine Curve.  Same as SmoothStep()
//u = f*f*(3.0-2.0*f);
// Jagged noise for lightning
// Mix 4 coorners percentages
//float xnoise(vec2 st) {
//    float n = noise(st);
//    n = abs(n);
//    n = 0.9-n;
//    n = n*n;
//    n = mod(n,1.) * 2. - 1.;
//    return n;
//}
//float c = sdLine(st,a,b);
//if( tint.r >= tint.g && tint.g >= tint.b ) {
//} else if( tint.r >= tint.b && tint.b >= tint.g ) {
//}
//vec4 color = vec4(lcolor,max(max(lcolor.r,lcolor.g),lcolor.b));
// max(1., lcolor.r + lcolor.g + lcolor.b);
// normal
// multiply
// screen
//} else if( blendMode==3 ) {         // overflow
//    result = color;
// punchout
// sourceonly
// overlay
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

struct ReferenceUniformse8da2ffb2563e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 start;
    char _m6_pad[8];
    float2 end;
    char _m7_pad[8];
    float evolution;
    char _m8_pad[12];
    float seed;
    float4 color1;
    float4 color2;
    float4 color3;
    float limit;
    char _m13_pad[12];
    float intensity;
    char _m14_pad[12];
    float glow;
    char _m15_pad[12];
    float core;
    char _m16_pad[12];
    float alpha;
    char _m17_pad[12];
    float count;
    char _m18_pad[12];
    float octaves;
    char _m19_pad[12];
    uint ref_smooth;
    char _m20_pad[12];
    int blendMode;
};

struct refAM35_e8da2ffb2563e_out
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
float _noise(thread const float2& st, constant ReferenceUniformse8da2ffb2563e& _113)
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
    float2 u;
    if (_113.ref_smooth != 0u)
    {
        u = smoothstep(float2(0.0), float2(1.0), f);
    }
    else
    {
        u = f;
    }
    return (mix(a, b, u.x) + (((c - a) * u.y) * (1.0 - u.x))) + (((d - b) * u.x) * u.y);
}

static inline __attribute__((always_inline))
float2 projectAndClamp(thread const float2& a, thread const float2& b)
{
    return b * fast::clamp(dot(a, b) / dot(b, b), 0.0, 1.0);
}

static inline __attribute__((always_inline))
float fractNoise(thread float2& st, thread const int& octaves, constant ReferenceUniformse8da2ffb2563e& _113)
{
    st *= 4.0;
    float2 param = st;
    float result = _noise(param, _113);
    if (octaves >= 2)
    {
        float2 param_1 = st * 2.0;
        result += (_noise(param_1, _113) * 0.5);
    }
    if (octaves >= 3)
    {
        float2 param_2 = st * 4.0;
        result += (_noise(param_2, _113) * 0.300000011920928955078125);
    }
    if (octaves >= 4)
    {
        float2 param_3 = st * 8.0;
        result += (_noise(param_3, _113) * 0.20000000298023223876953125);
    }
    if (octaves >= 5)
    {
        float2 param_4 = st * 16.0;
        result += (_noise(param_4, _113) * 0.100000001490116119384765625);
    }
    return result;
}

static inline __attribute__((always_inline))
float3 lightning(thread float2& st, thread const float2& a, thread const float2& b, thread const float& scale, thread const float& seed, thread const float& width, thread const float& limit, constant ReferenceUniformse8da2ffb2563e& _113)
{
    float2 ab = b - a;
    float2 n = fast::normalize(ab).yx;
    n.y *= (-1.0);
    float2 param = st - a;
    float2 param_1 = ab;
    float2 p = projectAndClamp(param, param_1) + a;
    float t = distance(p, a) / distance(b, a);
    float f = smoothstep(0.0, 0.5, 0.5 - abs(t - 0.5));
    float2 param_2 = float2(t, seed);
    int param_3 = int(_113.octaves);
    float _272 = fractNoise(param_2, param_3, _113);
    st += (((((n * (_272 - 1.0)) * scale) * 0.300000011920928955078125) * length(ab)) * f);
    float c = length(st - p);
    float l = smoothstep(fast::clamp(limit, 0.0, 0.5) - 0.5, 0.5, abs(0.5 - t));
    float xl = fast::clamp(limit - 0.5, 0.0, 1.0);
    l = (l * (1.0 - xl)) + xl;
    return float3(smoothstep((0.006000000052154064178466796875 * width) * _113.core, 0.0, c), smoothstep(0.034000001847743988037109375 * width, -0.0320000015199184417724609375, c), smoothstep((0.034000001847743988037109375 * width) * _113.glow, 0.0, c)) * l;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse8da2ffb2563e& _113, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _113.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _113.refLayer.xy) / _113.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_113.refLayer.z / _113.refLayer.w);
    float3 lcolor = float3(0.0);
    float adjseed = mod(258.350006103515625 + (42.779998779296875 * _113.seed), 138.9709930419921875);
    float w = 0.100000001490116119384765625;
    float slimit = 0.20000000298023223876953125;
    float2 a = _113.start / float2(1000.0);
    float2 b = _113.end / float2(1000.0);
    a.y *= (-1.0);
    b.y *= (-1.0);
    int icount = int(_113.count);
    for (int i = 0; i < icount; i++)
    {
        w += 0.20000000298023223876953125;
        slimit += 7.400000095367431640625;
        adjseed = mod((adjseed * sin(adjseed + 1.2000000476837158203125)) + 4.30000019073486328125, 45.31999969482421875);
        float2 param_1 = float2(w, _113.evolution);
        float2 param_2 = float2(slimit, _113.evolution);
        float2 param_3 = st;
        float2 param_4 = a;
        float2 param_5 = b;
        float param_6 = 1.0;
        float param_7 = _113.evolution + adjseed;
        float param_8 = powr((_noise(param_1, _113) + 1.0) / 2.0, 1.58399999141693115234375);
        float param_9 = powr(((_noise(param_2, _113) * _113.limit) + 1.0) / 2.584000110626220703125, 1.58399999141693115234375);
        float3 _481 = lightning(param_3, param_4, param_5, param_6, param_7, param_8, param_9, _113);
        lcolor += (_481 * _113.intensity);
    }
    float4 color = (((_113.color1 * lcolor.x) + (_113.color2 * lcolor.y)) + (_113.color3 * lcolor.z)) / float4(3.0);
    color *= _113.alpha;
    float4 result;
    if (_113.blendMode == 0)
    {
        color *= texColor.w;
        result = color + (texColor * (1.0 - color.w));
    }
    else
    {
        if (_113.blendMode == 1)
        {
            float4 c = color + (float4(1.0) * (1.0 - color.w));
            result = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_113.blendMode == 2)
            {
                result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - color.xyz)), 1.0) * texColor.w;
            }
            else
            {
                if (_113.blendMode == 4)
                {
                    result = texColor * (1.0 - color.w);
                }
                else
                {
                    if (_113.blendMode == 6)
                    {
                        result = color;
                    }
                    else
                    {
                        if (_113.blendMode == 5)
                        {
                            float3 top = color.xyz / float3(color.w);
                            float3 bot = texColor.xyz / float3(texColor.w);
                            float3 t = smoothstep(float3(0.5), float3(0.5), bot);
                            float3 r3 = (t * (float3(1.0) - ((float3(1.0) - ((bot - float3(0.5)) * 2.0)) * (float3(1.0) - top)))) + ((float3(1.0) - t) * ((bot * 2.0) * top));
                            float4 r4 = (float4(r3, 1.0) * color.w) * texColor.w;
                            result = (texColor * (1.0 - r4.w)) + r4;
                        }
                    }
                }
            }
        }
    }
    referenceColor = result;
}

fragment refAM35_e8da2ffb2563e_out refAM35_e8da2ffb2563e(constant ReferenceUniformse8da2ffb2563e& _113 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8da2ffb2563e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_113, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _690 = any(isnan(referenceColor));
    bool _697;
    if (!_690)
    {
        _697 = any(isinf(referenceColor));
    }
    else
    {
        _697 = _690;
    }
    if (_697)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _710 = referenceColor;
    float3 _716 = fast::clamp(_710.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _716.x;
    referenceColor.y = _716.y;
    referenceColor.z = _716.z;
    out.finalColor = referenceColor;
    return out;
}

