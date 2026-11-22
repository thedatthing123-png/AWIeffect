// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/3d_point_cloud.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse713978f9f30a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float density;
    char _m7_pad[12];
    float partSize;
    char _m8_pad[12];
    float depthFreq;
    char _m9_pad[12];
    float intensity;
    char _m10_pad[12];
    float rotX;
    char _m11_pad[12];
    float rotY;
    char _m12_pad[12];
    float rotZ;
};

struct refAM35_e713978f9f30a_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse713978f9f30a& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _33.refLayer.xy) / _33.refLayer.zw;
    float d = fast::max(_33.density, 4.0);
    float2 cell = floor(uv * d);
    float2 center = (cell + float2(0.5)) / float2(d);
    float2 param = center;
    float4 c = texture2DCv(refInput, refInputSmplr, param);
    float l = dot(c.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 p = fract(uv * d) - float2(0.5);
    float z = (l - 0.5) * _33.depthFreq;
    float ay = _33.rotY * 0.01745329983532428741455078125;
    float ax = _33.rotX * 0.01745329983532428741455078125;
    float2 shift = (float2(sin(ay) * z, (-sin(ax)) * z) / float2(d)) * 8.0;
    float dist = length(p - (shift * d));
    float point = smoothstep(_33.partSize * 0.5, _33.partSize * 0.1599999964237213134765625, dist);
    float halo = exp(((-dist) * dist) / fast::max((_33.partSize * _33.partSize) * 0.60000002384185791015625, 0.001000000047497451305389404296875)) * _33.intensity;
    float2 param_1 = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param_1);
    float3 pc = c.xyz * (point + (halo * 0.25));
    referenceColor = float4(mix(src.xyz, pc, float3(_33.strength)), mix(src.w, c.w * point, _33.strength));
}

fragment refAM35_e713978f9f30a_out refAM35_e713978f9f30a(constant ReferenceUniformse713978f9f30a& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e713978f9f30a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
    bool _206 = any(isnan(referenceColor));
    bool _213;
    if (!_206)
    {
        _213 = any(isinf(referenceColor));
    }
    else
    {
        _213 = _206;
    }
    if (_213)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _227 = referenceColor;
    float3 _233 = fast::clamp(_227.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _233.x;
    referenceColor.y = _233.y;
    referenceColor.z = _233.z;
    out.finalColor = referenceColor;
    return out;
}

