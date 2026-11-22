// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/flip3.xml
// Original source comments and attribution:
// returns t and normal
// convert from ray to box space
// ray-box intersection in box space
// convert to ray space
// camera movement
// camera matrix
// create view ray
// rotate and translate box
// raytrace
// raytrace box
// shading/lighting
// recover box space data (we want to do shading in object space)
// lighting
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

struct ReferenceUniformse80ca9b1eae55
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float angle;
    char _m6_pad[12];
    float axis;
    char _m7_pad[8];
    float2 pivot;
    char _m8_pad[8];
    float crop;
    char _m9_pad[12];
    float zdist;
    char _m10_pad[12];
    uint solid;
    float4 solidColor;
    float thickness;
    char _m13_pad[12];
    uint enableLight;
    char _m14_pad[12];
    float lightIntensity;
    float4 lightColor;
    float shine;
    char _m17_pad[12];
    float spec;
    char _m18_pad[12];
    float ambient;
    char _m19_pad[8];
    float2 lightDir;
    char _m20_pad[8];
    float lightDepth;
};

struct refAM35_e80ca9b1eae55_out
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
float4x4 translate(thread const float& x, thread const float& y, thread const float& z)
{
    return float4x4(float4(1.0, 0.0, 0.0, 0.0), float4(0.0, 1.0, 0.0, 0.0), float4(0.0, 0.0, 1.0, 0.0), float4(x, y, z, 1.0));
}

static inline __attribute__((always_inline))
float4x4 translate(thread const float3& v)
{
    return float4x4(float4(1.0, 0.0, 0.0, 0.0), float4(0.0, 1.0, 0.0, 0.0), float4(0.0, 0.0, 1.0, 0.0), float4(v.x, v.y, v.z, 1.0));
}

static inline __attribute__((always_inline))
float4x4 referenceRigidInverse(thread const float4x4& m)
{
    return float4x4(float4(m[0].x, m[1].x, m[2].x, 0.0), float4(m[0].y, m[1].y, m[2].y, 0.0), float4(m[0].z, m[1].z, m[2].z, 0.0), float4(-dot(m[0].xyz, m[3].xyz), -dot(m[1].xyz, m[3].xyz), -dot(m[2].xyz, m[3].xyz), 1.0));
}

static inline __attribute__((always_inline))
float4 iBox(thread const float3& ro, thread const float3& rd, thread const float4x4& txx, thread const float4x4& txi, thread const float3& rad)
{
    float3 rdd = (txx * float4(rd, 0.0)).xyz;
    float3 roo = (txx * float4(ro, 1.0)).xyz;
    float3 m = float3(1.0) / rdd;
    float3 n = m * roo;
    float3 k = abs(m) * rad;
    float3 t1 = (-n) - k;
    float3 t2 = (-n) + k;
    float tN = fast::max(fast::max(t1.x, t1.y), t1.z);
    float tF = fast::min(fast::min(t2.x, t2.y), t2.z);
    if ((tN > tF) || (tF < 0.0))
    {
        return float4(-1.0);
    }
    float3 nor = ((-sign(rdd)) * step(t1.yzx, t1)) * step(t1.zxy, t1);
    nor = (txi * float4(nor, 0.0)).xyz;
    return float4(tN, nor);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse80ca9b1eae55& _364, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st = (gl_FragCoord.xy - _364.refLayer.xy) / _364.refLayer.zw;
    st -= float2(0.5);
    float width;
    float height;
    if (_364.refLayer.z > _364.refLayer.w)
    {
        width = _364.refLayer.z / _364.refLayer.w;
        height = 1.0;
        st.x *= (_364.refLayer.z / _364.refLayer.w);
    }
    else
    {
        height = _364.refLayer.w / _364.refLayer.z;
        width = 1.0;
        st.y *= (_364.refLayer.w / _364.refLayer.z);
    }
    float _424;
    if (_364.solid != 0u)
    {
        _424 = fast::max(9.9999997473787516355514526367188e-06, _364.thickness / 10.0);
    }
    else
    {
        _424 = 9.9999997473787516355514526367188e-06;
    }
    float depth = _424;
    float2 p = st;
    float3 ro = float3(0.0, 0.0, 2.0);
    float3 ta = float3(0.0);
    float3 ww = fast::normalize(ta - ro);
    float3 uu = fast::normalize(cross(ww, float3(0.0, 1.0, 0.0)));
    float3 vv = fast::normalize(cross(uu, ww));
    float3 rd = fast::normalize(((uu * p.x) + (vv * p.y)) + (ww * 2.0));
    float axisRad = (_364.axis * 3.141590118408203125) / 180.0;
    float2x2 rotAxis = float2x2(float2(cos(axisRad), -sin(axisRad)), float2(sin(axisRad), cos(axisRad)));
    float3 adjPivot = float3((_364.pivot.x / 200.0) * width, ((-_364.pivot.y) / 200.0) * height, 0.0);
    float2 axisVec = float2(0.0, 1.0) * rotAxis;
    float3 param = float3(axisVec, 0.0);
    float param_1 = (_364.angle * 3.141590118408203125) / 180.0;
    float4x4 orient = rotationAxisAngle(param, param_1);
    float param_2 = 0.0;
    float param_3 = 0.0;
    float param_4 = -_364.zdist;
    float4x4 tra = translate(param_2, param_3, param_4);
    float3 param_5 = adjPivot;
    float3 param_6 = -adjPivot;
    float4x4 txi = ((tra * translate(param_5)) * orient) * translate(param_6);
    float4x4 param_7 = txi;
    float4x4 txx = referenceRigidInverse(param_7);
    float tmin = 10000.0;
    float3 nor = float3(0.0);
    float3 pos = float3(0.0);
    float3 box = float3(width / 2.0, height / 2.0, depth / 2.0);
    float3 param_8 = ro;
    float3 param_9 = rd;
    float4x4 param_10 = txx;
    float4x4 param_11 = txi;
    float3 param_12 = box;
    float4 res = iBox(param_8, param_9, param_10, param_11, param_12);
    bool _579 = res.x > 0.0;
    bool _586;
    if (_579)
    {
        _586 = res.x < tmin;
    }
    else
    {
        _586 = _579;
    }
    if (_586)
    {
        tmin = res.x;
        nor = res.yzw;
    }
    if (tmin < 100.0)
    {
        float3 lightPos = fast::normalize((txx * float4(_364.lightDir.x / 2.0, (-_364.lightDir.y) / 2.0, (-_364.lightDepth) * 2.0, 0.0)).xyz);
        pos = ro + (rd * tmin);
        float occ = 1.0;
        float3 opos = (txx * float4(pos, 1.0)).xyz;
        float3 onor = (txx * float4(nor, 0.0)).xyz;
        float2 param_13 = (float4(mod(((opos.xy * (_364.crop * 0.5)) / box.xy) + float2(0.5), float2(1.0)), 0.0, 1.0) * _364.refLayerToScreen).xy;
        float4 texColor = texture2DCv(refInput, refInputSmplr, param_13) * abs(onor.z);
        occ = 0.60000002384185791015625 + (0.4000000059604644775390625 * nor.y);
        float4 result = texColor;
        if (_364.solid != 0u)
        {
            result = (_364.solidColor * (1.0 - result.w)) + result;
        }
        if (_364.enableLight != 0u)
        {
            float l = fast::clamp(dot(onor, fast::normalize(lightPos)), 0.0, 1.0);
            float3 tc = result.xyz;
            float3 surface = (tc * _364.ambient) + (((tc * _364.lightColor.xyz) * l) * (1.0 - _364.ambient));
            surface *= _364.lightIntensity;
            float s = powr(l, _364.spec);
            surface = mix(surface * (1.0 - (_364.shine * 0.100000001490116119384765625)), float3(1.0), float3(_364.shine * s));
            result.x = surface.x;
            result.y = surface.y;
            result.z = surface.z;
        }
        referenceColor = result;
    }
    else
    {
        referenceColor = float4(0.0);
    }
}

fragment refAM35_e80ca9b1eae55_out refAM35_e80ca9b1eae55(constant ReferenceUniformse80ca9b1eae55& _364 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e80ca9b1eae55_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _364, refInput, refInputSmplr, referenceColor);
    bool _769 = any(isnan(referenceColor));
    bool _776;
    if (!_769)
    {
        _776 = any(isinf(referenceColor));
    }
    else
    {
        _776 = _769;
    }
    if (_776)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _789 = referenceColor;
    float3 _795 = fast::clamp(_789.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _795.x;
    referenceColor.y = _795.y;
    referenceColor.z = _795.z;
    out.finalColor = referenceColor;
    return out;
}

