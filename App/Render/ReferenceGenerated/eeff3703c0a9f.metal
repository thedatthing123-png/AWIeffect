// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/displacemap-radial.xml
// Original source comments and attribution:
//(acLayerCenterNorm-acScreenNorm)/acLayerSizeNorm;
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

struct ReferenceUniformseeff3703c0a9f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float offsAngle;
    char _m6_pad[12];
    float offsRadius;
    char _m7_pad[12];
    int typex;
    char _m8_pad[12];
    int typey;
    char _m9_pad[12];
    int edges;
    char _m10_pad[8];
    float2 centerPoint;
    char _m11_pad[8];
    uint fromctr;
    char _m12_pad[12];
    uint invert;
};

struct refAM35_eeff3703c0a9f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseeff3703c0a9f& _61, thread float4& referenceColor, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float2 param = gl_FragCoord.xy / _61.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float luminance = dot(texColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 offs = float2(_61.offsAngle, _61.offsRadius);
    float px;
    if (_61.typex == 0)
    {
        px = luminance;
    }
    else
    {
        if (_61.typex == 1)
        {
            px = texColor.x;
        }
        else
        {
            if (_61.typex == 2)
            {
                px = texColor.y;
            }
            else
            {
                if (_61.typex == 3)
                {
                    px = texColor.z;
                }
                else
                {
                    offs *= 0.0;
                }
            }
        }
    }
    float py;
    if (_61.typey == 0)
    {
        py = luminance;
    }
    else
    {
        if (_61.typey == 1)
        {
            py = texColor.x;
        }
        else
        {
            if (_61.typey == 2)
            {
                py = texColor.y;
            }
            else
            {
                if (_61.typey == 3)
                {
                    py = texColor.z;
                }
                else
                {
                    offs *= 0.0;
                }
            }
        }
    }
    if (_61.fromctr != 0u)
    {
        px = (px - 0.5) * 2.0;
        py = (py - 0.5) * 2.0;
    }
    if (_61.invert != 0u)
    {
        px = 1.0 - px;
        py = 1.0 - py;
    }
    float2 p = float2(px, py);
    float2 adjOffs = (offs * p) * texColor.w;
    float2 uv = gl_FragCoord.xy / _61.refScreen.xy;
    float2 center = (_61.centerPoint / float2(1000.0)) * float2(-1.0, 1.0);
    uv -= ((float2(_61.refLayer.x + (_61.refLayer.z * 0.5), (_61.refScreen.y - _61.refLayer.y) - (_61.refLayer.w * 0.5)) / _61.refScreen.xy) - center);
    uv.y *= (_61.refScreen.y / _61.refScreen.x);
    float param_1 = adjOffs.x * 0.01745329983532428741455078125;
    uv *= rot(param_1);
    uv += (fast::normalize(uv) * (adjOffs.y / length(_61.refScreen.xy)));
    uv.y /= (_61.refScreen.y / _61.refScreen.x);
    uv += ((float2(_61.refLayer.x + (_61.refLayer.z * 0.5), (_61.refScreen.y - _61.refLayer.y) - (_61.refLayer.w * 0.5)) / _61.refScreen.xy) - center);
    float2 ref_sample = uv;
    if (_61.edges == 0)
    {
        float2 param_2 = ref_sample;
        referenceColor = texture2DCv(refReference, refReferenceSmplr, param_2);
    }
    else
    {
        if (_61.edges == 1)
        {
            ref_sample = float2(1.0) - abs(mod(ref_sample, float2(2.0)) - float2(1.0));
            float2 param_3 = ref_sample;
            referenceColor = texture2DCv(refReference, refReferenceSmplr, param_3) * texColor.w;
        }
        else
        {
            if (_61.edges == 2)
            {
                bool _348 = ref_sample.x < 0.0;
                bool _355;
                if (!_348)
                {
                    _355 = ref_sample.x > 1.0;
                }
                else
                {
                    _355 = _348;
                }
                bool _362;
                if (!_355)
                {
                    _362 = ref_sample.y < 0.0;
                }
                else
                {
                    _362 = _355;
                }
                bool _369;
                if (!_362)
                {
                    _369 = ref_sample.y > 1.0;
                }
                else
                {
                    _369 = _362;
                }
                if (_369)
                {
                    referenceColor = float4(0.0);
                }
                else
                {
                    float2 param_4 = ref_sample;
                    referenceColor = texture2DCv(refReference, refReferenceSmplr, param_4) * texColor.w;
                }
            }
            else
            {
                if (_61.edges == 3)
                {
                    ref_sample = mod(ref_sample, float2(1.0));
                    float2 param_5 = ref_sample;
                    referenceColor = texture2DCv(refReference, refReferenceSmplr, param_5) * texColor.w;
                }
                else
                {
                    float2 param_6 = ref_sample;
                    referenceColor = texture2DCv(refReference, refReferenceSmplr, param_6) * texColor.w;
                }
            }
        }
    }
}

fragment refAM35_eeff3703c0a9f_out refAM35_eeff3703c0a9f(constant ReferenceUniformseeff3703c0a9f& _61 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_eeff3703c0a9f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _61, referenceColor, refReference, refReferenceSmplr);
    bool _405 = any(isnan(referenceColor));
    bool _412;
    if (!_405)
    {
        _412 = any(isinf(referenceColor));
    }
    else
    {
        _412 = _405;
    }
    if (_412)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _425 = referenceColor;
    float3 _431 = fast::clamp(_425.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _431.x;
    referenceColor.y = _431.y;
    referenceColor.z = _431.z;
    out.finalColor = referenceColor;
    return out;
}

