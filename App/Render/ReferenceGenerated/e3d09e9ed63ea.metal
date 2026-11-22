// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/2bumpmap.xml
// Original source comments and attribution:
// Sobel (8 taps)
// Standard (4 taps)
// Map roughness 0..1 to shininess ~ 256..8 (inverse relation)
// Normal from height
// Light vector: directional or point
// Point: position in screen space, depth controls Z
// Directional: use (lightDir, lightDepth) as a direction vector
// Composite lighting
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse3d09e9ed63ea
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int heightSource;
    char _m6_pad[12];
    float heightScale;
    char _m7_pad[12];
    float bumpIntensity;
    char _m8_pad[12];
    float normalRes;
    char _m9_pad[12];
    int quality;
    char _m10_pad[12];
    int lightType;
    char _m11_pad[8];
    float2 lightDir;
    char _m12_pad[8];
    float lightDepth;
    char _m13_pad[12];
    float lightIntensity;
    char _m14_pad[12];
    float ambient;
    char _m15_pad[12];
    float roughness;
    char _m16_pad[12];
    float specularIntensity;
    float4 specularTint;
    uint preserveAlpha;
    char _m19_pad[12];
    uint unpremultBeforeShade;
    char _m20_pad[12];
    float exposure;
};

struct refAM35_e3d09e9ed63ea_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float luma(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float heightAt(thread const float2& uv, constant ReferenceUniformse3d09e9ed63ea& _59, texture2d<float> refInput, sampler refInputSmplr)
{
    if (_59.heightSource == 1)
    {
        float2 param = uv;
        float4 h = texture2DCv(refInput, refInputSmplr, param);
        float3 param_1 = h.xyz;
        return luma(param_1) * _59.heightScale;
    }
    float2 param_2 = uv;
    float4 s = texture2DCv(refInput, refInputSmplr, param_2);
    float3 param_3 = s.xyz;
    return luma(param_3) * _59.heightScale;
}

static inline __attribute__((always_inline))
float3 computeNormal(thread const float2& uv, thread const float2& texel, thread const float& radius, constant ReferenceUniformse3d09e9ed63ea& _59, texture2d<float> refInput, sampler refInputSmplr)
{
    float r = radius;
    if (_59.quality == 1)
    {
        float2 param = uv + (float2(-texel.x, texel.y) * r);
        float tl = heightAt(param, _59, refInput, refInputSmplr);
        float2 param_1 = uv + (float2(0.0, texel.y) * r);
        float tc = heightAt(param_1, _59, refInput, refInputSmplr);
        float2 param_2 = uv + (float2(texel.x, texel.y) * r);
        float tr = heightAt(param_2, _59, refInput, refInputSmplr);
        float2 param_3 = uv + (float2(-texel.x, 0.0) * r);
        float ml = heightAt(param_3, _59, refInput, refInputSmplr);
        float2 param_4 = uv + (float2(texel.x, 0.0) * r);
        float mr = heightAt(param_4, _59, refInput, refInputSmplr);
        float2 param_5 = uv + (float2(-texel.x, -texel.y) * r);
        float bl = heightAt(param_5, _59, refInput, refInputSmplr);
        float2 param_6 = uv + (float2(0.0, -texel.y) * r);
        float bc = heightAt(param_6, _59, refInput, refInputSmplr);
        float2 param_7 = uv + (float2(texel.x, -texel.y) * r);
        float br = heightAt(param_7, _59, refInput, refInputSmplr);
        float dx = ((tr + (2.0 * mr)) + br) - ((tl + (2.0 * ml)) + bl);
        float dy = ((tl + (2.0 * tc)) + tr) - ((bl + (2.0 * bc)) + br);
        return fast::normalize(float3((-dx) * _59.bumpIntensity, (-dy) * _59.bumpIntensity, 1.0));
    }
    else
    {
        float2 param_8 = uv + float2(texel.x * r, 0.0);
        float hR = heightAt(param_8, _59, refInput, refInputSmplr);
        float2 param_9 = uv - float2(texel.x * r, 0.0);
        float hL = heightAt(param_9, _59, refInput, refInputSmplr);
        float2 param_10 = uv + float2(0.0, texel.y * r);
        float hU = heightAt(param_10, _59, refInput, refInputSmplr);
        float2 param_11 = uv - float2(0.0, texel.y * r);
        float hD = heightAt(param_11, _59, refInput, refInputSmplr);
        float dx_1 = hR - hL;
        float dy_1 = hU - hD;
        return fast::normalize(float3((-dx_1) * _59.bumpIntensity, (-dy_1) * _59.bumpIntensity, 1.0));
    }
}

static inline __attribute__((always_inline))
float shininessFromRoughness(thread const float& r)
{
    return mix(256.0, 8.0, fast::clamp(r, 0.0, 1.0));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse3d09e9ed63ea& _59, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _59.refScreen.xy;
    float2 texel = float2(1.0) / _59.refScreen.xy;
    float2 param = uv;
    float4 base = texture2DCv(refInput, refInputSmplr, param);
    float4 src = base;
    bool _344 = _59.unpremultBeforeShade != 0u;
    bool _351;
    if (_344)
    {
        _351 = src.w > 0.0;
    }
    else
    {
        _351 = _344;
    }
    if (_351)
    {
        float _355 = src.w;
        float4 _356 = src;
        float3 _359 = _356.xyz / float3(_355);
        src.x = _359.x;
        src.y = _359.y;
        src.z = _359.z;
    }
    float2 param_1 = uv;
    float2 param_2 = texel;
    float param_3 = _59.normalRes;
    float3 n = computeNormal(param_1, param_2, param_3, _59, refInput, refInputSmplr);
    float3 V = float3(0.0, 0.0, 1.0);
    float3 L;
    if (_59.lightType == 1)
    {
        float3 lightPos = float3(_59.lightDir.x / 2.0, (-_59.lightDir.y) / 2.0, (-_59.lightDepth) * 0.0199999995529651641845703125);
        float3 p = float3((uv * 2.0) - float2(1.0), 0.0);
        L = fast::normalize(lightPos - p);
    }
    else
    {
        L = fast::normalize(float3(_59.lightDir.x, -_59.lightDir.y, _59.lightDepth));
    }
    float diff = fast::max(dot(n, L), 0.0) * _59.lightIntensity;
    float3 H = fast::normalize(L + V);
    float param_4 = _59.roughness;
    float specPow = shininessFromRoughness(param_4);
    float spec = powr(fast::max(dot(n, H), 0.0), specPow) * _59.specularIntensity;
    float amb = _59.ambient;
    float3 lit = src.xyz * (amb + (diff * (1.0 - amb)));
    lit += (_59.specularTint.xyz * spec);
    lit *= _59.exposure;
    float4 outC = float4(lit, src.w);
    bool _492 = _59.unpremultBeforeShade != 0u;
    bool _498;
    if (_492)
    {
        _498 = src.w > 0.0;
    }
    else
    {
        _498 = _492;
    }
    if (_498)
    {
        float4 _503 = outC;
        float3 _505 = _503.xyz * src.w;
        outC.x = _505.x;
        outC.y = _505.y;
        outC.z = _505.z;
    }
    if (_59.preserveAlpha != 0u)
    {
        outC.w = base.w;
    }
    referenceColor = outC;
}

fragment refAM35_e3d09e9ed63ea_out refAM35_e3d09e9ed63ea(constant ReferenceUniformse3d09e9ed63ea& _59 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e3d09e9ed63ea_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_59, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _529 = any(isnan(referenceColor));
    bool _536;
    if (!_529)
    {
        _536 = any(isinf(referenceColor));
    }
    else
    {
        _536 = _529;
    }
    if (_536)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _549 = referenceColor;
    float3 _555 = fast::clamp(_549.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _555.x;
    referenceColor.y = _555.y;
    referenceColor.z = _555.z;
    out.finalColor = referenceColor;
    return out;
}

