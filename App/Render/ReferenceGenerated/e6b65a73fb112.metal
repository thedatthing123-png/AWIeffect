// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/360-reorient-sphere.xml
// Original source comments and attribution:

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

struct ReferenceUniformse6b65a73fb112
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 orient_euler;
    float3 rotate;
};

struct refAM35_e6b65a73fb112_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4x4 rotationAxisAngle(thread const float3& v, thread const float& angle)
{
    float s = sin(angle);
    float c = cos(angle);
    float ic = 1.0 - c;
    return float4x4(float4(((v.x * v.x) * ic) + c, ((v.y * v.x) * ic) - (s * v.z), ((v.z * v.x) * ic) + (s * v.y), 0.0), float4(((v.x * v.y) * ic) + (s * v.z), ((v.y * v.y) * ic) + c, ((v.z * v.y) * ic) - (s * v.x), 0.0), float4(((v.x * v.z) * ic) - (s * v.y), ((v.y * v.z) * ic) + (s * v.x), ((v.z * v.z) * ic) + c, 0.0), float4(0.0, 0.0, 0.0, 1.0));
}

static inline __attribute__((always_inline))
float4x4 referenceEuler(thread const float3& _degrees, thread const bool& inverted)
{
    float3 r = radians(_degrees);
    float3 s = sin(r);
    float3 c = cos(r);
    float4x4 rx = float4x4(float4(1.0, 0.0, 0.0, 0.0), float4(0.0, c.x, -s.x, 0.0), float4(0.0, s.x, c.x, 0.0), float4(0.0, 0.0, 0.0, 1.0));
    float4x4 ry = float4x4(float4(c.y, 0.0, s.y, 0.0), float4(0.0, 1.0, 0.0, 0.0), float4(-s.y, 0.0, c.y, 0.0), float4(0.0, 0.0, 0.0, 1.0));
    float4x4 rz = float4x4(float4(c.z, -s.z, 0.0, 0.0), float4(s.z, c.z, 0.0, 0.0), float4(0.0, 0.0, 1.0, 0.0), float4(0.0, 0.0, 0.0, 1.0));
    float4x4 m = (rz * rx) * ry;
    float4x4 _113;
    if (inverted)
    {
        _113 = transpose(m);
    }
    else
    {
        _113 = m;
    }
    return _113;
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse6b65a73fb112& _244)
{
    return (float4(v, 0.0, 1.0) * _244.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse6b65a73fb112& _244, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 st = (gl_FragCoord.xy - _244.refLayer.xy) / _244.refLayer.zw;
    float lon = (st.x * 3.1415927410125732421875) * 2.0;
    float lat = asin((st.y - 0.5) * 2.0);
    float3 xyz = float3(cos(lon) * cos(lat), sin(lon) * cos(lat), sin(lat));
    float3 r = _244.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = rotationAxisAngle(param_4, param_5);
    float3 param_6 = _244.orient_euler;
    bool param_7 = true;
    xyz = ((((float4(xyz, 0.0) * referenceEuler(param_6, param_7)) * rz) * rx) * ry).xyz;
    lat = asin(xyz.z);
    lon = precise::atan2(xyz.y, xyz.x);
    if (lon < 0.0)
    {
        lon += 6.283185482025146484375;
    }
    float2 conv_uv = float2(lon / 6.283185482025146484375, (sin(lat) / 2.0) + 0.5);
    float inside = ((step(0.0, st.x) * step(st.x, 1.0)) * step(0.0, st.y)) * step(st.y, 1.0);
    float2 param_8 = conv_uv;
    float2 param_9 = l2s(param_8, _244);
    referenceColor = texture2DCv(refInput, refInputSmplr, param_9) * inside;
}

fragment refAM35_e6b65a73fb112_out refAM35_e6b65a73fb112(constant ReferenceUniformse6b65a73fb112& _244 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e6b65a73fb112_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_244, gl_FragCoord, referenceColor, refInput, refInputSmplr);
    bool _399 = any(isnan(referenceColor));
    bool _406;
    if (!_399)
    {
        _406 = any(isinf(referenceColor));
    }
    else
    {
        _406 = _399;
    }
    if (_406)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _420 = referenceColor;
    float3 _426 = fast::clamp(_420.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _426.x;
    referenceColor.y = _426.y;
    referenceColor.z = _426.z;
    out.finalColor = referenceColor;
    return out;
}

