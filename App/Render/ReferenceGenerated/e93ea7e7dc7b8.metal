// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/ccglass.xml
// Original source comments and attribution:
// Luminance
// --- Normal Mapping Logic ---
// Sampling adjacent pixels to calculate surface gradient (slope)
// Calculate surface normal based on height
// --- Displacement (Refraction) ---
// --- Lighting Logic ---
// Distant
// Point
// Blinn-Phong Shading
// Specular & Metal Logic
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse93ea7e7dc7b8
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int property;
    char _m6_pad[12];
    float softness;
    char _m7_pad[12];
    float height;
    char _m8_pad[12];
    float displacement;
    char _m9_pad[12];
    int lightType;
    char _m10_pad[12];
    float lightIntensity;
    float4 lightColor;
    float lightHeight;
    char _m13_pad[8];
    float2 lightPosition;
    char _m14_pad[8];
    float lightDirection;
    char _m15_pad[12];
    float ambient;
    char _m16_pad[12];
    float diffuse;
    char _m17_pad[12];
    float specular;
    char _m18_pad[12];
    float roughness;
    char _m19_pad[12];
    float metal;
};

struct refAM35_e93ea7e7dc7b8_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float getVal(thread const float4& col, thread const int& prop)
{
    if (prop == 1)
    {
        return col.x;
    }
    if (prop == 2)
    {
        return col.y;
    }
    if (prop == 3)
    {
        return col.z;
    }
    if (prop == 4)
    {
        return col.w;
    }
    return dot(col.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse93ea7e7dc7b8& _90, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _90.refScreen.xy;
    float soft = fast::max(_90.softness, 1.0) * 0.001000000047497451305389404296875;
    float2 param = uv + float2(-soft, 0.0);
    float4 s_left = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = uv + float2(soft, 0.0);
    float4 s_right = texture2DCv(refInput, refInputSmplr, param_1);
    float2 param_2 = uv + float2(0.0, soft);
    float4 s_up = texture2DCv(refInput, refInputSmplr, param_2);
    float2 param_3 = uv + float2(0.0, -soft);
    float4 s_down = texture2DCv(refInput, refInputSmplr, param_3);
    float4 param_4 = s_left;
    int param_5 = _90.property;
    float v_l = getVal(param_4, param_5);
    float4 param_6 = s_right;
    int param_7 = _90.property;
    float v_r = getVal(param_6, param_7);
    float4 param_8 = s_up;
    int param_9 = _90.property;
    float v_u = getVal(param_8, param_9);
    float4 param_10 = s_down;
    int param_11 = _90.property;
    float v_d = getVal(param_10, param_11);
    float h_scale = _90.height * 0.100000001490116119384765625;
    float3 normal = fast::normalize(float3(v_l - v_r, v_d - v_u, 1.0 / h_scale));
    float2 refractOff = normal.xy * (_90.displacement * 0.00999999977648258209228515625);
    float2 param_12 = uv + refractOff;
    float4 src = texture2DCv(refInput, refInputSmplr, param_12);
    float3 l_dir;
    if (_90.lightType == 0)
    {
        float rad = (_90.lightDirection - 90.0) * 0.01745329238474369049072265625;
        float h_rad = (_90.lightHeight * 0.89999997615814208984375) * 0.01745329238474369049072265625;
        l_dir = fast::normalize(float3(cos(rad) * cos(h_rad), sin(rad) * cos(h_rad), sin(h_rad)));
    }
    else
    {
        l_dir = fast::normalize(float3(_90.lightPosition - uv, _90.lightHeight * 0.00999999977648258209228515625));
    }
    float3 viewDir = float3(0.0, 0.0, 1.0);
    float3 halfDir = fast::normalize(l_dir + viewDir);
    float diff = fast::max(dot(normal, l_dir), 0.0);
    float spec = powr(fast::max(dot(normal, halfDir), 0.0), 1.0 / fast::max(_90.roughness, 0.001000000047497451305389404296875));
    float3 ambCol = src.xyz * (_90.ambient * 0.00999999977648258209228515625);
    float3 diffCol = (((src.xyz * diff) * (_90.diffuse * 0.00999999977648258209228515625)) * _90.lightColor.xyz) * (_90.lightIntensity * 0.00999999977648258209228515625);
    float3 specBase = ((_90.lightColor.xyz * spec) * (_90.specular * 0.00999999977648258209228515625)) * (_90.lightIntensity * 0.00999999977648258209228515625);
    float3 specCol = mix(specBase, specBase * src.xyz, float3(_90.metal * 0.00999999977648258209228515625));
    float3 finalCol = (ambCol + diffCol) + specCol;
    referenceColor = float4(finalCol, src.w);
}

fragment refAM35_e93ea7e7dc7b8_out refAM35_e93ea7e7dc7b8(constant ReferenceUniformse93ea7e7dc7b8& _90 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e93ea7e7dc7b8_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _90, refInput, refInputSmplr, referenceColor);
    bool _349 = any(isnan(referenceColor));
    bool _356;
    if (!_349)
    {
        _356 = any(isinf(referenceColor));
    }
    else
    {
        _356 = _349;
    }
    if (_356)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _369 = referenceColor;
    float3 _375 = fast::clamp(_369.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _375.x;
    referenceColor.y = _375.y;
    referenceColor.z = _375.z;
    out.finalColor = referenceColor;
    return out;
}

