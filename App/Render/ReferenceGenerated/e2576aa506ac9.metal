// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/water_droplets.xml
// Original source comments and attribution:
// Water Droplets (Shadertoy-style) -> Alight Motion port
// Small hash helpers (no texture required)
// Droplet height field
// Derive per-droplet properties from hashes
// Position per (i, dropIndex)
// [-1,1] range like original code
// Cosine ripples
// fade as ring expands
// Nonlinear shaping similar to original
// Compute surface normal from height field
// Aspect-correct droplet space: x scaled by screen aspect, centered [-1,1]
// Generate normal
// Droplet mask from height field (limits effect region)
// Sample environment by normal.xy mapped to UV
// If no envTex provided, sample the input image instead
// Optionally distort the clip using a shockwave derived from the droplet gradient
// Convert from aspect-correct droplet space to normalized screen UVs
// apply only where droplets exist
// Output
// Only droplets: color from env, masked by droplet presence
// Masked additive over source to avoid global brightening
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse2576aa506ac9
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float dropletCount;
    char _m6_pad[12];
    float expandSpeed;
    char _m7_pad[12];
    float heightFactor;
    char _m8_pad[12];
    float rippleFreq;
    char _m9_pad[12];
    float timeSpeed;
    char _m10_pad[12];
    float seed;
    char _m11_pad[12];
    float normalOffset;
    char _m12_pad[12];
    float normalStrength;
    char _m13_pad[12];
    float blend;
    char _m14_pad[12];
    float alpha;
    char _m15_pad[12];
    uint dropletsOnly;
    char _m16_pad[12];
    uint shockwave;
    char _m17_pad[12];
    float shockStrength;
    char _m18_pad[12];
    float shockWidth;
};

struct refAM35_e2576aa506ac9_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash11(thread float& p)
{
    p = fract(p * 0.103100001811981201171875);
    p *= (p + 33.3300018310546875);
    p *= (p + p);
    return fract(p);
}

static inline __attribute__((always_inline))
float hash21(thread const float2& p)
{
    float3 p3 = fract(p.xyx * 0.103100001811981201171875);
    p3 += float3(dot(p3, p3.yzx + float3(33.3300018310546875)));
    return fract((p3.x + p3.y) * p3.z);
}

static inline __attribute__((always_inline))
float2 hash22(thread const float2& p)
{
    float2 param = p;
    float n = hash21(param);
    float2 param_1 = p + float2(17.1700000762939453125);
    float m = hash21(param_1);
    return float2(n, m);
}

static inline __attribute__((always_inline))
float getDropletHeight(thread const float2& uv, constant ReferenceUniformse2576aa506ac9& _114)
{
    float timeVal = (_114.refScreen.z + _114.seed) * _114.timeSpeed;
    float height = 0.0;
    int N = int(fast::clamp(_114.dropletCount, 1.0, 64.0));
    float _272;
    for (int i = 0; i < 64; i++)
    {
        if (i >= N)
        {
            break;
        }
        float fi = float(i);
        float param = (fi * 1.12300002574920654296875) + 0.23700000345706939697265625;
        float _167 = hash11(param);
        float decayRate = 0.323000013828277587890625 + (2.0 * _167);
        float param_1 = (fi * 0.712999999523162841796875) + 0.001000000047497451305389404296875;
        float _177 = hash11(param_1);
        float dropletStrength = _177;
        float param_2 = (fi * 2.3710000514984130859375) + 0.3449999988079071044921875;
        float _187 = hash11(param_2);
        float dropletStrengthBias = 0.100000001490116119384765625 + (0.20000000298023223876953125 * _187);
        float dropFractionFull = timeVal / decayRate;
        float dropIndex = floor(dropFractionFull);
        float dropFraction = fract(dropFractionFull);
        float2 param_3 = float2((fi * 0.731000006198883056640625) + (dropIndex * 0.100000001490116119384765625), dropIndex * 1.12300002574920654296875);
        float2 rnd = hash22(param_3);
        float2 dropletPosition = (rnd * 2.0) - float2(1.0);
        float ringRadius = ((_114.expandSpeed * dropFraction) * dropletStrength) - dropletStrengthBias;
        ringRadius = fast::max(ringRadius, 9.9999997473787516355514526367188e-05);
        float distToDroplet = distance(uv, dropletPosition);
        float within = (distToDroplet > ringRadius) ? 0.0 : 1.0;
        float edgeDist = fast::max(0.0, ringRadius - distToDroplet) / ringRadius;
        float h = (within > 0.5) ? distToDroplet : 0.0;
        h = (cos(3.1415927410125732421875 + (((h - ringRadius) * _114.rippleFreq) * dropletStrength)) * 0.5) + 0.5;
        h *= (1.0 - dropFraction);
        if (within > 0.5)
        {
            _272 = distToDroplet / ringRadius;
        }
        else
        {
            _272 = 0.0;
        }
        h *= _272;
        float shaped = 1.0 - ((cos(h * 3.1415927410125732421875) + 1.0) * 0.5);
        height += (shaped * _114.heightFactor);
    }
    return height;
}

static inline __attribute__((always_inline))
float3 getDropletNormal(thread const float2& uv, constant ReferenceUniformse2576aa506ac9& _114)
{
    float off = _114.normalOffset;
    float3 ofs = float3(-off, 0.0, off);
    float2 param = uv;
    float s11 = getDropletHeight(param, _114);
    float2 param_1 = uv + ofs.xy;
    float s01 = getDropletHeight(param_1, _114);
    float2 param_2 = uv + ofs.zy;
    float s21 = getDropletHeight(param_2, _114);
    float2 param_3 = uv + ofs.yx;
    float s10 = getDropletHeight(param_3, _114);
    float2 param_4 = uv + ofs.yz;
    float s12 = getDropletHeight(param_4, _114);
    float3 va = fast::normalize(float3(ofs.z, 0.0, s21 - s11));
    float3 vb = fast::normalize(float3(0.0, ofs.z, s12 - s11));
    float3 n = fast::normalize(cross(va, vb));
    float3 _369 = n;
    float2 _371 = _369.xy * (s11 * _114.normalStrength);
    n.x = _371.x;
    n.y = _371.y;
    return fast::normalize(n);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse2576aa506ac9& _114, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 aspect = float2(_114.refScreen.x / _114.refScreen.y, 1.0);
    float2 uv = ((gl_FragCoord.xy / _114.refScreen.xy) - float2(0.5)) * 2.0;
    uv.x *= aspect.x;
    float2 param = uv;
    float3 normal = getDropletNormal(param, _114);
    float2 param_1 = uv;
    float h = getDropletHeight(param_1, _114);
    float mask = fast::clamp(h * 8.0, 0.0, 1.0);
    float2 envUV = (normal.xy * 0.5) + float2(0.5);
    float2 param_2 = envUV;
    float3 envColor = texture2DCv(refInput, refInputSmplr, param_2).xyz;
    float2 srcUV = gl_FragCoord.xy / _114.refScreen.xy;
    bool _442 = _114.shockwave != 0u;
    bool _450;
    if (_442)
    {
        _450 = !(_114.dropletsOnly != 0u);
    }
    else
    {
        _450 = _442;
    }
    if (_450)
    {
        float eps = fast::max(0.001000000047497451305389404296875, _114.normalOffset);
        float2 param_3 = uv + float2(eps, 0.0);
        float2 param_4 = uv - float2(eps, 0.0);
        float hx = getDropletHeight(param_3, _114) - getDropletHeight(param_4, _114);
        float2 param_5 = uv + float2(0.0, eps);
        float2 param_6 = uv - float2(0.0, eps);
        float hy = getDropletHeight(param_5, _114) - getDropletHeight(param_6, _114);
        float2 grad = float2(hx, hy) / float2(2.0 * eps);
        float edge = fast::clamp(length(grad) * _114.shockWidth, 0.0, 1.0);
        float2 dir = fast::normalize(grad + float2(9.9999999747524270787835121154785e-07));
        float2 offset = (dir * edge) * _114.shockStrength;
        float2 offsetScreen = float2(offset.x / aspect.x, offset.y) * 0.5;
        srcUV += (offsetScreen * mask);
    }
    float2 param_7 = srcUV;
    float4 src = texture2DCv(refInput, refInputSmplr, param_7);
    if (_114.dropletsOnly != 0u)
    {
        float3 col = envColor * mask;
        float a = mask * _114.alpha;
        referenceColor = float4(col, 1.0) * a;
    }
    else
    {
        float3 outRGB = mix(src.xyz, src.xyz + (envColor * mask), float3(fast::clamp(_114.blend, 0.0, 1.0)));
        float a_1 = src.w * _114.alpha;
        referenceColor = float4(outRGB, 1.0) * a_1;
    }
}

fragment refAM35_e2576aa506ac9_out refAM35_e2576aa506ac9(constant ReferenceUniformse2576aa506ac9& _114 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e2576aa506ac9_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_114, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _594 = any(isnan(referenceColor));
    bool _601;
    if (!_594)
    {
        _601 = any(isinf(referenceColor));
    }
    else
    {
        _601 = _594;
    }
    if (_601)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _614 = referenceColor;
    float3 _620 = fast::clamp(_614.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _620.x;
    referenceColor.y = _620.y;
    referenceColor.z = _620.z;
    out.finalColor = referenceColor;
    return out;
}

