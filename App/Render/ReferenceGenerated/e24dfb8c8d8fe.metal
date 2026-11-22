// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/lighting.xml
// Original source comments and attribution:
// ShaderToy -> Alight Motion mapping
// iResolution.xy -> acScreenSize
// iTime -> acTime
// fragCoord -> acScreenNorm * acScreenSize
// Normalized pixel coordinates (from -1 to 1), aspect-corrected
// Animated domain warp via FBM
// center around 0
// Distance from bolt centerline (x=0)
// Base color and intensity with subtle jitter
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse24dfb8c8d8fe
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float colorR;
    char _m6_pad[12];
    float colorG;
    char _m7_pad[12];
    float colorB;
    char _m8_pad[12];
    float intensity;
    char _m9_pad[12];
    float width;
    char _m10_pad[12];
    float speed;
    char _m11_pad[12];
    float octaves;
    char _m12_pad[12];
    float warp;
    char _m13_pad[12];
    float rotate;
};

struct refAM35_e24dfb8c8d8fe_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rotate2d(thread const float& theta)
{
    float c = cos(theta);
    float s = sin(theta);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float hash12(thread const float2& p)
{
    float3 p3 = fract(p.xyx * 0.103100001811981201171875);
    p3 += float3(dot(p3, p3.yzx + float3(33.3300018310546875)));
    return fract((p3.x + p3.y) * p3.z);
}

static inline __attribute__((always_inline))
float _noise2(thread const float2& p)
{
    float2 ip = floor(p);
    float2 fp = fract(p);
    float2 param = ip;
    float a = hash12(param);
    float2 param_1 = ip + float2(1.0, 0.0);
    float b = hash12(param_1);
    float2 param_2 = ip + float2(0.0, 1.0);
    float c = hash12(param_2);
    float2 param_3 = ip + float2(1.0);
    float d = hash12(param_3);
    float2 t = smoothstep(float2(0.0), float2(1.0), fp);
    return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}

static inline __attribute__((always_inline))
float fbm(thread float2& p, thread const int& octaveCount, thread const float& rotAngle)
{
    float value = 0.0;
    float amplitude = 0.5;
    float param = rotAngle;
    float2x2 R = rotate2d(param);
    for (int i = 0; i < 12; i++)
    {
        if (i >= octaveCount)
        {
            break;
        }
        float2 param_1 = p;
        value += (amplitude * _noise2(param_1));
        p = (R * p) * 2.0;
        amplitude *= 0.5;
    }
    return value;
}

static inline __attribute__((always_inline))
float hash11(thread float& p)
{
    p = fract(p * 0.103100001811981201171875);
    p *= (p + 33.3300018310546875);
    p *= (p + p);
    return fract(p);
}

static inline __attribute__((always_inline))
void imagePass(thread float4& fragColor, thread const float2& fragCoord, constant ReferenceUniformse24dfb8c8d8fe& _207)
{
    float2 iResolution = _207.refScreen.xy;
    float2 uv = fragCoord / iResolution;
    uv = (uv * 2.0) - float2(1.0);
    uv.x *= (iResolution.x / iResolution.y);
    float t = _207.refScreen.z * _207.speed;
    int oct = int(_207.octaves + 0.5);
    float2 param = uv + float2(t);
    int param_1 = oct;
    float param_2 = _207.rotate;
    float _255 = fbm(param, param_1, param_2);
    float wobble = _255;
    uv += float2((_207.warp * (wobble - 0.5)) * 2.0);
    float dist = fast::max(9.9999997473787516355514526367188e-05, abs(uv.x));
    float3 baseCol = float3(_207.colorR, _207.colorG, _207.colorB);
    float param_3 = _207.refScreen.z;
    float _289 = hash11(param_3);
    float jitter = mix(0.0, _207.intensity, _289);
    float glow = powr((jitter * _207.width) / dist, 1.0);
    float3 col = baseCol * glow;
    fragColor = float4(col, 1.0);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse24dfb8c8d8fe& _207, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 fragCoord = (gl_FragCoord.xy / _207.refScreen.xy) * _207.refScreen.xy;
    float2 param_1 = fragCoord;
    float4 param;
    imagePass(param, param_1, _207);
    float4 c = param;
    referenceColor = c;
}

fragment refAM35_e24dfb8c8d8fe_out refAM35_e24dfb8c8d8fe(constant ReferenceUniformse24dfb8c8d8fe& _207 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e24dfb8c8d8fe_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_207, gl_FragCoord, referenceColor);
    bool _337 = any(isnan(referenceColor));
    bool _344;
    if (!_337)
    {
        _344 = any(isinf(referenceColor));
    }
    else
    {
        _344 = _337;
    }
    if (_344)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _358 = referenceColor;
    float3 _364 = fast::clamp(_358.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _364.x;
    referenceColor.y = _364.y;
    referenceColor.z = _364.z;
    out.finalColor = referenceColor;
    return out;
}

