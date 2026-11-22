// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/3D Perception (BETA).xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
// Matriks rotasi X
// Matriks rotasi Y
// Gabungan rotasi
// Hit bidang z = 0
// --- Efek cermin ---
// 0 atau 1 setiap π
// if (flipX == 1.0) {
// if (flipY == 1.0) {
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

struct ReferenceUniformseece15aa8abca
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 ROT;
    float MIRX;
    char _m7_pad[12];
    float MIRY;
};

struct refAM35_eece15aa8abca_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseece15aa8abca& _43, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _43.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param_1);
    float2 iResolution = float2(_43.refScreen.x, _43.refScreen.y);
    float2 uv = gl_FragCoord.xy / _43.refScreen.xy;
    uv = (uv * 2.0) - float2(1.0);
    uv.x *= (iResolution.x / iResolution.y);
    float nearPlane = 1.0;
    float rotX = _43.ROT.y * 0.00999999977648258209228515625;
    float rotY = _43.ROT.x * 0.00999999977648258209228515625;
    float rotZ = _43.ROT.z * 0.00999999977648258209228515625;
    float3 rayOrigin = float3(0.0, 0.0, rotZ);
    float3 rayDir = fast::normalize(float3(uv, -nearPlane));
    float cosX = cos(rotX);
    float sinX = sin(rotX);
    float3x3 rotXMat = float3x3(float3(1.0, 0.0, 0.0), float3(0.0, cosX, -sinX), float3(0.0, sinX, cosX));
    float cosY = cos(rotY);
    float sinY = sin(rotY);
    float3x3 rotYMat = float3x3(float3(cosY, 0.0, sinY), float3(0.0, 1.0, 0.0), float3(-sinY, 0.0, cosY));
    rayDir = (rotYMat * rotXMat) * rayDir;
    float t = (-rayOrigin.z) / rayDir.z;
    float3 hitPos = rayOrigin + (rayDir * t);
    float2 texUV = hitPos.xy;
    texUV.x /= (iResolution.x / iResolution.y);
    texUV = (texUV * 0.5) + float2(0.5);
    float flipX = mod(floor(rotX / 3.1415927410125732421875), 2.0);
    float flipY = mod(floor(rotY / 3.1415927410125732421875), 2.0);
    if (_43.MIRX > 0.100000001490116119384765625)
    {
        texUV.x = 1.0 - texUV.x;
    }
    if (_43.MIRY > 0.100000001490116119384765625)
    {
        texUV.y = 1.0 - texUV.y;
    }
    float2 param_2 = texUV;
    float4 color = texture2DCv(refInput, refInputSmplr, param_2);
    bool _237 = texUV.x < 0.0;
    bool _244;
    if (!_237)
    {
        _244 = texUV.x > 1.0;
    }
    else
    {
        _244 = _237;
    }
    bool _251;
    if (!_244)
    {
        _251 = texUV.y < 0.0;
    }
    else
    {
        _251 = _244;
    }
    bool _258;
    if (!_251)
    {
        _258 = texUV.y > 1.0;
    }
    else
    {
        _258 = _251;
    }
    if (_258)
    {
        color = float4(0.0);
    }
    float4 fragColor = color;
    referenceColor = fragColor * color.w;
}

fragment refAM35_eece15aa8abca_out refAM35_eece15aa8abca(constant ReferenceUniformseece15aa8abca& _43 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eece15aa8abca_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _43, referenceColor);
    bool _274 = any(isnan(referenceColor));
    bool _281;
    if (!_274)
    {
        _281 = any(isinf(referenceColor));
    }
    else
    {
        _281 = _274;
    }
    if (_281)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _294 = referenceColor;
    float3 _300 = fast::clamp(_294.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _300.x;
    referenceColor.y = _300.y;
    referenceColor.z = _300.z;
    out.finalColor = referenceColor;
    return out;
}

