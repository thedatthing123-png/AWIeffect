// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxvrcombinednew.xml
// Original source comments and attribution:
//to spherical
//radial azmuth polar
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

struct ReferenceUniformse7b3f4c464331
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 orient_euler;
    float3 rotate;
    uint flatten;
    char _m8_pad[12];
    float dist;
    char _m9_pad[12];
    float w;
    char _m10_pad[12];
    float h;
};

struct refAM35_e7b3f4c464331_out
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
    float4x4 _124;
    if (inverted)
    {
        _124 = transpose(m);
    }
    else
    {
        _124 = m;
    }
    return _124;
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse7b3f4c464331& _255)
{
    return (float4(v, 0.0, 1.0) * _255.refLayerToScreen).xy;
}

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
void referenceMain(thread float& hfovDegrees, thread float& vfovDegrees, constant ReferenceUniformse7b3f4c464331& _255, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 st = (gl_FragCoord.xy - _255.refLayer.xy) / _255.refLayer.zw;
    if ((_255.flatten != 0u) == false)
    {
        float lon = (st.x * 3.1415927410125732421875) * 2.0;
        float lat = asin((st.y - 0.5) * 2.0);
        float3 xyz = float3(cos(lon) * cos(lat), sin(lon) * cos(lat), sin(lat));
        float3 r = _255.rotate * 0.01745329983532428741455078125;
        float3 param = float3(1.0, 0.0, 0.0);
        float param_1 = r.x;
        float4x4 rx = rotationAxisAngle(param, param_1);
        float3 param_2 = float3(0.0, 1.0, 0.0);
        float param_3 = r.y;
        float4x4 ry = rotationAxisAngle(param_2, param_3);
        float3 param_4 = float3(0.0, 0.0, 1.0);
        float param_5 = r.z;
        float4x4 rz = rotationAxisAngle(param_4, param_5);
        float3 param_6 = _255.orient_euler;
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
        float2 param_9 = l2s(param_8, _255);
        referenceColor = texture2DCv(refInput, refInputSmplr, param_9) * inside;
    }
    else
    {
        float2 uv = (st * 2.0) - float2(1.0);
        float3 camDir = fast::normalize(float3(uv * float2(tan((0.5 * hfovDegrees) * 0.01745329238474369049072265625), tan((0.5 * vfovDegrees) * 0.01745329238474369049072265625)), 1.0 / _255.dist));
        float3 r_1 = _255.rotate * 0.01745329983532428741455078125;
        float3 param_10 = float3(1.0, 0.0, 0.0);
        float param_11 = r_1.x;
        float4x4 rx_1 = rotationAxisAngle(param_10, param_11);
        float3 param_12 = float3(0.0, 1.0, 0.0);
        float param_13 = r_1.y;
        float4x4 ry_1 = rotationAxisAngle(param_12, param_13);
        float3 param_14 = float3(0.0, 0.0, 1.0);
        float param_15 = r_1.z;
        float4x4 rz_1 = rotationAxisAngle(param_14, param_15);
        float3 param_16 = _255.orient_euler;
        bool param_17 = true;
        float3 rd = ((((float4(camDir, 0.0) * referenceEuler(param_16, param_17)) * rz_1) * rx_1) * ry_1).xyz;
        float2 cutting = float2(0.0);
        float2 param_18 = float2(int2(refInput.get_width(), refInput.get_height()));
        float2 imgSize = getTexSize(param_18);
        float asp_i = imgSize.y / imgSize.x;
        float asp_o = _255.h / _255.w;
        if (asp_i > asp_o)
        {
            cutting.x = 0.0;
            cutting.y = 0.5 * (1.0 - (asp_o / asp_i));
        }
        else
        {
            cutting.y = 0.0;
            cutting.x = 0.5 * (1.0 - (asp_i / asp_o));
        }
        float2 conv_uv_1 = float2(precise::atan2(rd.z, rd.x) + 3.1415927410125732421875, acos(-rd.y)) / float2(6.283185482025146484375, 3.1415927410125732421875);
        float inside_1 = ((step(cutting.x, st.x) * step(st.x, 1.0 - cutting.x)) * step(cutting.y, st.y)) * step(st.y, 1.0 - cutting.y);
        float2 param_19 = conv_uv_1;
        float2 param_20 = l2s(param_19, _255);
        referenceColor = texture2DCv(refInput, refInputSmplr, param_20) * inside_1;
    }
}

fragment refAM35_e7b3f4c464331_out refAM35_e7b3f4c464331(constant ReferenceUniformse7b3f4c464331& _255 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e7b3f4c464331_out out = {};
    float hfovDegrees = 120.0;
    float vfovDegrees = 60.0;
    float4 referenceColor = float4(0.0);
    referenceMain(hfovDegrees, vfovDegrees, _255, gl_FragCoord, referenceColor, refInput, refInputSmplr);
    bool _580 = any(isnan(referenceColor));
    bool _587;
    if (!_580)
    {
        _587 = any(isinf(referenceColor));
    }
    else
    {
        _587 = _580;
    }
    if (_587)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _600 = referenceColor;
    float3 _606 = fast::clamp(_600.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _606.x;
    referenceColor.y = _606.y;
    referenceColor.z = _606.z;
    out.finalColor = referenceColor;
    return out;
}

