// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/vr-player.xml
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

struct ReferenceUniformsecb9c2e3a4604
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 orient_euler;
    float3 rotate;
    float dist;
    char _m8_pad[12];
    int aspectRatio;
    char _m9_pad[12];
    float scale;
};

struct refAM35_ecb9c2e3a4604_out
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
    float4x4 _118;
    if (inverted)
    {
        _118 = transpose(m);
    }
    else
    {
        _118 = m;
    }
    return _118;
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformsecb9c2e3a4604& _250)
{
    return (float4(v, 0.0, 1.0) * _250.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float& hfovDegrees, thread float& vfovDegrees, constant ReferenceUniformsecb9c2e3a4604& _250, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 st = ((float2(1.0 - ((gl_FragCoord.xy - _250.refLayer.xy) / _250.refLayer.zw).x, ((gl_FragCoord.xy - _250.refLayer.xy) / _250.refLayer.zw).y) - float2(0.5)) / float2(_250.scale)) + float2(0.5);
    float2 uv = (st * 2.0) - float2(1.0);
    float3 camDir = fast::normalize(float3(uv * float2(tan((0.5 * hfovDegrees) * 0.01745329238474369049072265625), tan((0.5 * vfovDegrees) * 0.01745329238474369049072265625)), 1.0 / _250.dist));
    float3 r = _250.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = rotationAxisAngle(param_4, param_5);
    float3 param_6 = _250.orient_euler;
    bool param_7 = true;
    float3 rd = ((((float4(camDir, 0.0) * referenceEuler(param_6, param_7)) * rz) * rx) * ry).xyz;
    float2 cutting = float2(0.0);
    float inWidth = _250.refLayer.z;
    float inHeight = _250.refLayer.z;
    float width;
    float height;
    if (_250.aspectRatio == 0)
    {
        width = 16.0;
        height = 9.0;
    }
    else
    {
        if (_250.aspectRatio == 1)
        {
            width = 4.0;
            height = 3.0;
        }
        else
        {
            if (_250.aspectRatio == 2)
            {
                width = 1.0;
                height = 1.0;
            }
            else
            {
                if (_250.aspectRatio == 3)
                {
                    width = 3.0;
                    height = 4.0;
                }
                else
                {
                    if (_250.aspectRatio == 4)
                    {
                        width = 4.0;
                        height = 5.0;
                    }
                    else
                    {
                        if (_250.aspectRatio == 5)
                        {
                            width = 9.0;
                            height = 16.0;
                        }
                        else
                        {
                            width = 9.0;
                            height = 16.0;
                        }
                    }
                }
            }
        }
    }
    float fitHeight = (height * inWidth) / width;
    float fitWidth = (width * inHeight) / height;
    float2 clipDimens;
    if (fitHeight >= inHeight)
    {
        clipDimens = float2(fitWidth, inHeight);
    }
    else
    {
        clipDimens = float2(inWidth, fitHeight);
    }
    clipDimens /= _250.refLayer.zw;
    float2 conv_uv = float2(precise::atan2(rd.z, rd.x) + 3.1415927410125732421875, acos(-rd.y)) / float2(6.283185482025146484375, 3.1415927410125732421875);
    conv_uv.x = fast::clamp(conv_uv.x, 1.0 / _250.refLayer.z, 1.0 - (1.0 / _250.refLayer.z));
    conv_uv.y = fast::clamp(conv_uv.y, 1.0 / _250.refLayer.w, 1.0 - (1.0 / _250.refLayer.w));
    float inside = ((step(-clipDimens.x, uv.x) * step(uv.x, clipDimens.x)) * step(-clipDimens.y, uv.y)) * step(uv.y, clipDimens.y);
    float2 param_8 = conv_uv;
    float2 param_9 = l2s(param_8, _250);
    referenceColor = texture2DCv(refInput, refInputSmplr, param_9) * inside;
}

fragment refAM35_ecb9c2e3a4604_out refAM35_ecb9c2e3a4604(constant ReferenceUniformsecb9c2e3a4604& _250 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ecb9c2e3a4604_out out = {};
    float hfovDegrees = 120.0;
    float vfovDegrees = 60.0;
    float4 referenceColor = float4(0.0);
    referenceMain(hfovDegrees, vfovDegrees, _250, gl_FragCoord, referenceColor, refInput, refInputSmplr);
    bool _541 = any(isnan(referenceColor));
    bool _548;
    if (!_541)
    {
        _548 = any(isinf(referenceColor));
    }
    else
    {
        _548 = _541;
    }
    if (_548)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _560 = referenceColor;
    float3 _566 = fast::clamp(_560.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _566.x;
    referenceColor.y = _566.y;
    referenceColor.z = _566.z;
    out.finalColor = referenceColor;
    return out;
}

