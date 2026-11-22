// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/heatmap_perlin_noise.xml
// Original source comments and attribution:
// Hash 3D pour le bruit de Perlin 3D
// Bruit de Perlin 3D propre
// Gradients aux 8 coins du cube
// Produits scalaires
// Interpolation lisse
// Interpolation trilinéaire
// FBm 3D avec animation temporelle intégrée
// Constrained loop for mobile compatibility
// Aspect ratio correction
// Animation : la 3ème dimension est le temps
// Bruit de Perlin 3D (espace 2D + temps)
// Normalisation 0..1
// --- LOGIQUE DE COULEUR ---
// Utilisation du bruit comme "wave"
// Calcul des canaux RVB indépendants avec Sinus
// Saturation
// Luminosité
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse26753b8c360e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float globalFreq;
    char _m6_pad[12];
    float speed;
    char _m7_pad[12];
    float freqRed;
    char _m8_pad[12];
    float freqGreen;
    char _m9_pad[12];
    float freqBlue;
    char _m10_pad[12];
    float phaseRed;
    char _m11_pad[12];
    float phaseGreen;
    char _m12_pad[12];
    float phaseBlue;
    char _m13_pad[12];
    float saturation;
    char _m14_pad[12];
    float brightness;
    char _m15_pad[12];
    float blend;
};

struct refAM35_e26753b8c360e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float3 hash33(thread float3& p)
{
    p = float3(dot(p, float3(127.09999847412109375, 311.70001220703125, 74.6999969482421875)), dot(p, float3(269.5, 183.3000030517578125, 246.100006103515625)), dot(p, float3(113.5, 271.899993896484375, 124.59999847412109375)));
    return float3(-1.0) + (fract(sin(p) * 43758.546875) * 2.0);
}

static inline __attribute__((always_inline))
float perlinNoise3D(thread const float3& p)
{
    float3 pi = floor(p);
    float3 pf = p - pi;
    float3 param = pi + float3(0.0);
    float3 _86 = hash33(param);
    float3 g000 = _86;
    float3 param_1 = pi + float3(1.0, 0.0, 0.0);
    float3 _93 = hash33(param_1);
    float3 g100 = _93;
    float3 param_2 = pi + float3(0.0, 1.0, 0.0);
    float3 _99 = hash33(param_2);
    float3 g010 = _99;
    float3 param_3 = pi + float3(1.0, 1.0, 0.0);
    float3 _105 = hash33(param_3);
    float3 g110 = _105;
    float3 param_4 = pi + float3(0.0, 0.0, 1.0);
    float3 _111 = hash33(param_4);
    float3 g001 = _111;
    float3 param_5 = pi + float3(1.0, 0.0, 1.0);
    float3 _117 = hash33(param_5);
    float3 g101 = _117;
    float3 param_6 = pi + float3(0.0, 1.0, 1.0);
    float3 _123 = hash33(param_6);
    float3 g011 = _123;
    float3 param_7 = pi + float3(1.0);
    float3 _129 = hash33(param_7);
    float3 g111 = _129;
    float n000 = dot(g000, pf);
    float n100 = dot(g100, pf - float3(1.0, 0.0, 0.0));
    float n010 = dot(g010, pf - float3(0.0, 1.0, 0.0));
    float n110 = dot(g110, pf - float3(1.0, 1.0, 0.0));
    float n001 = dot(g001, pf - float3(0.0, 0.0, 1.0));
    float n101 = dot(g101, pf - float3(1.0, 0.0, 1.0));
    float n011 = dot(g011, pf - float3(0.0, 1.0, 1.0));
    float n111 = dot(g111, pf - float3(1.0));
    float3 u = (pf * pf) * (float3(3.0) - (pf * 2.0));
    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    return mix(nxy0, nxy1, u.z);
}

static inline __attribute__((always_inline))
float fbm3D(thread const float3& p, thread const int& octaves)
{
    float value = 0.0;
    float amplitude = 0.800000011920928955078125;
    float frequency = 0.12999999523162841796875;
    for (int i = 0; i < 4; i++)
    {
        if (i >= octaves)
        {
            break;
        }
        float3 param = p * frequency;
        value += (amplitude * perlinNoise3D(param));
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return value;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse26753b8c360e& _277, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 suv = gl_FragCoord.xy / _277.refScreen.xy;
    float2 uv = (gl_FragCoord.xy - _277.refLayer.xy) / _277.refLayer.zw;
    float aspect = _277.refLayer.z / _277.refLayer.w;
    uv = (uv - float2(0.5)) * 2.0;
    uv.x *= aspect;
    float3 p = float3(uv * 3.0, _277.refScreen.z * _277.speed);
    float3 param = p;
    int param_1 = 4;
    float _noise = fbm3D(param, param_1);
    _noise = (_noise + 1.0) * 0.5;
    float wave = (_noise * 6.28318023681640625) * _277.globalFreq;
    float rC = 0.5 + (0.5 * sin((wave * _277.freqRed) + _277.phaseRed));
    float gC = 0.5 + (0.5 * sin((wave * _277.freqGreen) + _277.phaseGreen));
    float bC = 0.5 + (0.5 * sin((wave * _277.freqBlue) + _277.phaseBlue));
    float3 col = float3(rC, gC, bC);
    float gray = dot(col, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    col = mix(float3(gray), col, float3(fast::clamp(_277.saturation, 0.0, 2.0)));
    col *= _277.brightness;
    float2 param_2 = suv;
    float4 base = texture2DCv(refInput, refInputSmplr, param_2);
    float4 effectCol = float4(col * base.w, base.w);
    referenceColor = mix(base, effectCol, float4(_277.blend));
}

fragment refAM35_e26753b8c360e_out refAM35_e26753b8c360e(constant ReferenceUniformse26753b8c360e& _277 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e26753b8c360e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _277, refInput, refInputSmplr, referenceColor);
    bool _435 = any(isnan(referenceColor));
    bool _442;
    if (!_435)
    {
        _442 = any(isinf(referenceColor));
    }
    else
    {
        _442 = _435;
    }
    if (_442)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _455 = referenceColor;
    float3 _461 = fast::clamp(_455.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _461.x;
    referenceColor.y = _461.y;
    referenceColor.z = _461.z;
    out.finalColor = referenceColor;
    return out;
}

