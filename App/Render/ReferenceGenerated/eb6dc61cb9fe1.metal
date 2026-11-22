// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/Awiggle.xml
// Original source comments and attribution:
// Hash and value noise
// Fractal brownian motion
// Mirror-edge UV helper
// Noise timebase
// Generate 3 channels of fbm for x,y,rot,scale using offsets
// Amplitudes
// Convert pixel translation to UV
// Pivot
// Auto expand to hide borders (scale up slightly)
// For each screen uv, compute source uv by applying inverse transform
// Forward T: scale*scl -> rotate(rot) -> translate(posUV), also autoS
// Inverse: undo translate, then rotate(-rot), then scale by 1/(scl*autoS)
// undo translation
// undo rotation
// undo scale
// Edge handling
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL radians() function
template<typename T>
inline T radians(T d)
{
    return d * T(0.01745329251);
}

struct ReferenceUniformseb6dc61cb9fe1
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float ampPosX;
    char _m6_pad[12];
    float ampPosY;
    char _m7_pad[12];
    float ampRot;
    char _m8_pad[12];
    float ampScale;
    char _m9_pad[12];
    float frequency;
    char _m10_pad[12];
    float octaves;
    char _m11_pad[12];
    float roughness;
    char _m12_pad[12];
    float seed;
    char _m13_pad[12];
    float strength;
    char _m14_pad[12];
    float pivotX;
    char _m15_pad[12];
    float pivotY;
    char _m16_pad[12];
    uint mirrorEdges;
    char _m17_pad[12];
    float expand;
};

struct refAM35_eb6dc61cb9fe1_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

static inline __attribute__((always_inline))
float _noise1(thread const float& x, constant ReferenceUniformseb6dc61cb9fe1& _91)
{
    float i = floor(x);
    float f = fract(x);
    float u = (f * f) * (3.0 - (2.0 * f));
    float param = i + _91.seed;
    float param_1 = (i + 1.0) + _91.seed;
    return mix(hash(param), hash(param_1), u);
}

static inline __attribute__((always_inline))
float fbm(thread const float& x, thread const float& oct, thread const float& rough, constant ReferenceUniformseb6dc61cb9fe1& _91)
{
    float a = 1.0;
    float f = 1.0;
    float sum = 0.0;
    float norm = 0.0;
    for (int i = 0; i < 8; i++)
    {
        if (float(i) >= oct)
        {
            break;
        }
        float param = x * f;
        sum += (_noise1(param, _91) * a);
        norm += a;
        a *= fast::clamp(rough, 0.0, 1.0);
        f *= 2.0;
    }
    float _159;
    if (norm > 0.0)
    {
        _159 = sum / norm;
    }
    else
    {
        _159 = 0.0;
    }
    return _159;
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float2x2 rot2(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float2 mirror(thread const float2& uv)
{
    return abs((fract((uv * 0.5) + float2(0.5)) * 2.0) - float2(1.0));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 sampleTex(texture2d<float> t, sampler tSmplr, thread const float2& uv)
{
    float2 param = uv;
    return texture2DCv(t, tSmplr, param);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseb6dc61cb9fe1& _91, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _91.refScreen.xy;
    float t = _91.refScreen.z * _91.frequency;
    float oct = fast::clamp(_91.octaves, 1.0, 6.0);
    float param = t + 37.1699981689453125;
    float param_1 = oct;
    float param_2 = _91.roughness;
    float nX = (fbm(param, param_1, param_2, _91) * 2.0) - 1.0;
    float param_3 = t + 91.73000335693359375;
    float param_4 = oct;
    float param_5 = _91.roughness;
    float nY = (fbm(param_3, param_4, param_5, _91) * 2.0) - 1.0;
    float param_6 = t + 153.1100006103515625;
    float param_7 = oct;
    float param_8 = _91.roughness;
    float nR = (fbm(param_6, param_7, param_8, _91) * 2.0) - 1.0;
    float param_9 = t + 241.57000732421875;
    float param_10 = oct;
    float param_11 = _91.roughness;
    float nS = (fbm(param_9, param_10, param_11, _91) * 2.0) - 1.0;
    float2 posPx = float2(_91.ampPosX * nX, _91.ampPosY * nY) * _91.strength;
    float rotDeg = (_91.ampRot * nR) * _91.strength;
    float scl = 1.0 + ((_91.ampScale * nS) * _91.strength);
    float2 param_12 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texSize = getTexSize(param_12);
    float2 posUV = posPx / fast::max(texSize, float2(1.0));
    float2 pivot = float2(_91.pivotX, _91.pivotY);
    float autoS = 1.0 + _91.expand;
    float rot = radians(rotDeg);
    float2 rel = uv - pivot;
    rel -= posUV;
    float param_13 = -rot;
    rel = rot2(param_13) * rel;
    rel /= float2(fast::max(scl * autoS, 9.9999999747524270787835121154785e-07));
    float2 srcUV = pivot + rel;
    float4 col;
    if (_91.mirrorEdges != 0u)
    {
        float2 param_14 = srcUV;
        float2 param_15 = mirror(param_14);
        col = sampleTex(refInput, refInputSmplr, param_15);
    }
    else
    {
        bool _384 = any(srcUV < float2(0.0));
        bool _391;
        if (!_384)
        {
            _391 = any(srcUV > float2(1.0));
        }
        else
        {
            _391 = _384;
        }
        if (_391)
        {
            col = float4(0.0);
        }
        else
        {
            float2 param_16 = srcUV;
            col = sampleTex(refInput, refInputSmplr, param_16);
        }
    }
    referenceColor = col;
}

fragment refAM35_eb6dc61cb9fe1_out refAM35_eb6dc61cb9fe1(constant ReferenceUniformseb6dc61cb9fe1& _91 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb6dc61cb9fe1_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_91, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _406 = any(isnan(referenceColor));
    bool _413;
    if (!_406)
    {
        _413 = any(isinf(referenceColor));
    }
    else
    {
        _413 = _406;
    }
    if (_413)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _428 = referenceColor;
    float3 _434 = fast::clamp(_428.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _434.x;
    referenceColor.y = _434.y;
    referenceColor.z = _434.z;
    out.finalColor = referenceColor;
    return out;
}

