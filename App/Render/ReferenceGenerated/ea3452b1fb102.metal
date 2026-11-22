// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/colorama.xml
// Original source comments and attribution:
// Perlin/fractal noise HSV colorizer — AM port of provided Shadertoy
// Hash helpers without uint bit tricks (for GLES compatibility)
// Random unit vectors
// 2*pi
// Quintic smoother like in the code (x*x*x*((6x-15)x+10))
// 2D Perlin
// normalize to ~[0,1]
// 3D Perlin
// Fractal sum (FBM) with adjustable lacunarity/gain
// Make UV scale invariant like fragCoord/iResolution.y
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea3452b1fb102
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float octaves;
    char _m6_pad[12];
    float scale;
    char _m7_pad[12];
    float lacunarity;
    char _m8_pad[12];
    float gain;
    char _m9_pad[12];
    float timeSpeed;
    char _m10_pad[12];
    float seed;
    char _m11_pad[12];
    uint colorizeHSV;
    char _m12_pad[12];
    float hueScale;
    char _m13_pad[12];
    float saturation;
    char _m14_pad[12];
    float value;
    char _m15_pad[12];
    float blend;
    char _m16_pad[12];
    float alpha;
};

struct refAM35_ea3452b1fb102_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float3 smooth3(thread const float3& x)
{
    return ((x * x) * x) * ((((x * 6.0) - float3(15.0)) * x) + float3(10.0));
}

static inline __attribute__((always_inline))
float hash31(thread const float3& p)
{
    return fract(sin(dot(p, float3(127.09999847412109375, 311.70001220703125, 74.6999969482421875))) * 43758.546875);
}

static inline __attribute__((always_inline))
float3 randVec3(thread const float3& p)
{
    float3 param = p;
    float a = hash31(param);
    float3 param_1 = p + float3(17.1700000762939453125);
    float b = hash31(param_1);
    float theta = a * 6.283185482025146484375;
    float phi = acos(1.0 - (2.0 * b));
    return float3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
}

static inline __attribute__((always_inline))
float perlin3(thread const float3& p)
{
    float3 ip = floor(p);
    float3 f = fract(p);
    float3 param = f;
    float3 u = smooth3(param);
    float3 param_1 = ip;
    float3 g000 = randVec3(param_1);
    float3 param_2 = ip + float3(1.0, 0.0, 0.0);
    float3 g100 = randVec3(param_2);
    float3 param_3 = ip + float3(0.0, 1.0, 0.0);
    float3 g010 = randVec3(param_3);
    float3 param_4 = ip + float3(1.0, 1.0, 0.0);
    float3 g110 = randVec3(param_4);
    float3 param_5 = ip + float3(0.0, 0.0, 1.0);
    float3 g001 = randVec3(param_5);
    float3 param_6 = ip + float3(1.0, 0.0, 1.0);
    float3 g101 = randVec3(param_6);
    float3 param_7 = ip + float3(0.0, 1.0, 1.0);
    float3 g011 = randVec3(param_7);
    float3 param_8 = ip + float3(1.0);
    float3 g111 = randVec3(param_8);
    float n000 = dot(g000, f);
    float n100 = dot(g100, f - float3(1.0, 0.0, 0.0));
    float n010 = dot(g010, f - float3(0.0, 1.0, 0.0));
    float n110 = dot(g110, f - float3(1.0, 1.0, 0.0));
    float n001 = dot(g001, f - float3(0.0, 0.0, 1.0));
    float n101 = dot(g101, f - float3(1.0, 0.0, 1.0));
    float n011 = dot(g011, f - float3(0.0, 1.0, 1.0));
    float n111 = dot(g111, f - float3(1.0));
    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    float nxyz = mix(nxy0, nxy1, u.z);
    return ((nxyz * 1.1547005176544189453125) * 0.5) + 0.5;
}

static inline __attribute__((always_inline))
float fbm3(thread const float3& p, thread const int& oct, constant ReferenceUniformsea3452b1fb102& _306)
{
    float sum = 0.0;
    float amp = 1.0;
    float tot = 0.0;
    float freq = 1.0;
    for (int i = 0; i < 8; i++)
    {
        if (i >= oct)
        {
            break;
        }
        float3 param = p * freq;
        sum += (perlin3(param) * amp);
        tot += amp;
        freq *= _306.lacunarity;
        amp *= _306.gain;
    }
    return sum / fast::max(tot, 9.9999999747524270787835121154785e-07);
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsea3452b1fb102& _306, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _306.refScreen.xy;
    uv.x *= (_306.refScreen.x / _306.refScreen.y);
    int oct = int(fast::clamp(_306.octaves, 1.0, 8.0));
    float t = _306.refScreen.z * _306.timeSpeed;
    float3 p3 = float3((uv * _306.scale) + float2(_306.seed), t);
    float3 param = p3;
    int param_1 = oct;
    float n = fbm3(param, param_1, _306);
    float3 col;
    if (_306.colorizeHSV != 0u)
    {
        float3 param_2 = float3(n * _306.hueScale, fast::clamp(_306.saturation, 0.0, 1.0), _306.value);
        col = hsv2rgb(param_2);
    }
    else
    {
        col = float3(n);
    }
    float2 param_3 = gl_FragCoord.xy / _306.refScreen.xy;
    float4 src = texture2DCv(refInput, refInputSmplr, param_3);
    bool _456 = _306.blend <= 0.0;
    bool _463;
    if (_456)
    {
        _463 = _306.alpha >= 1.0;
    }
    else
    {
        _463 = _456;
    }
    if (_463)
    {
        referenceColor = src;
        return;
    }
    float3 outRGB = mix(src.xyz / float3(fast::max(src.w, 9.9999997473787516355514526367188e-06)), col, float3(fast::clamp(_306.blend, 0.0, 1.0)));
    float a = src.w * _306.alpha;
    referenceColor = float4(outRGB, 1.0) * a;
}

fragment refAM35_ea3452b1fb102_out refAM35_ea3452b1fb102(constant ReferenceUniformsea3452b1fb102& _306 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea3452b1fb102_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_306, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _504 = any(isnan(referenceColor));
    bool _511;
    if (!_504)
    {
        _511 = any(isinf(referenceColor));
    }
    else
    {
        _511 = _504;
    }
    if (_511)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _524 = referenceColor;
    float3 _530 = fast::clamp(_524.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _530.x;
    referenceColor.y = _530.y;
    referenceColor.z = _530.z;
    out.finalColor = referenceColor;
    return out;
}

