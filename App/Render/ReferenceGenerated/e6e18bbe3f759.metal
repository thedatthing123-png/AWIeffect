// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/bend.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse6e18bbe3f759
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int originType;
    char _m6_pad[12];
    float amount;
    char _m7_pad[12];
    float offset;
    char _m8_pad[12];
    int oppositeType;
    char _m9_pad[12];
    float highLimit;
    char _m10_pad[12];
    float lowLimit;
};

struct refAM35_e6e18bbe3f759_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 bend(thread float2& p, thread const float& a, thread const float& l, thread const float& w, thread const bool& vertical)
{
    if (abs(a) < 0.001000000047497451305389404296875)
    {
        float v = p.y;
        p.y -= fast::clamp(p.y, 0.0, l);
        return float2(p.x, v);
    }
    float2 sc = float2(sin(a), cos(a));
    if (vertical)
    {
        float ra = (0.5 * l) / a;
        p.x -= ra;
        float s = sign(a);
        float u = abs(ra) - length(p);
        float v_1 = ra * precise::atan2(s * p.y, (-s) * p.x);
        u *= s;
        return float2(u, v_1);
    }
    else
    {
        float ra_1 = (0.5 * w) / a;
        p.y -= ra_1;
        float s_1 = sign(a);
        float v_2 = abs(ra_1) - length(p);
        float u_1 = ra_1 * precise::atan2(s_1 * p.x, (-s_1) * p.y);
        v_2 *= s_1;
        return float2(u_1, v_2);
    }
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse6e18bbe3f759& _50)
{
    return (float4(v, 0.0, 1.0) * _50.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse6e18bbe3f759& _50, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 c = float2(0.0);
    float angleVal = _50.amount;
    float originOffset = _50.offset;
    float adjOffset = _50.offset * 0.9900000095367431640625;
    float2 a;
    float2 b;
    bool vertical;
    if (_50.originType == 0)
    {
        a = float2(adjOffset, 0.5);
        b = float2(1.0, 0.5);
        c = float2(0.0, 0.5);
        vertical = false;
    }
    else
    {
        if (_50.originType == 1)
        {
            a = float2(1.0 - adjOffset, 0.5);
            b = float2(0.0, 0.5);
            c = float2(1.0, 0.5);
            vertical = false;
            angleVal = -_50.amount;
        }
        else
        {
            if (_50.originType == 2)
            {
                a = float2(0.5, 1.0 - adjOffset);
                b = float2(0.5, 0.0);
                c = float2(0.5, 1.0);
                vertical = true;
            }
            else
            {
                if (_50.originType == 3)
                {
                    a = float2(0.5, adjOffset);
                    b = float2(0.5, 1.0);
                    c = float2(0.5, 0.0);
                    vertical = true;
                    angleVal = -_50.amount;
                }
            }
        }
    }
    float2 a2b = b - a;
    float2 a2c = ((gl_FragCoord.xy - _50.refLayer.xy) / _50.refLayer.zw) - a;
    float checkOffset = dot(a2b, a2c);
    if (checkOffset < 0.0)
    {
        if ((_50.oppositeType == 0) || (adjOffset <= 0.0))
        {
            float2 param = gl_FragCoord.xy / _50.refScreen.xy;
            referenceColor = texture2DCv(refInput, refInputSmplr, param);
            return;
        }
        else
        {
            if (adjOffset < _50.lowLimit)
            {
                angleVal *= (adjOffset / _50.lowLimit);
            }
            b = c;
            a2b = b - a;
            angleVal = angleVal;
            if (_50.oppositeType == 2)
            {
                angleVal = -angleVal;
            }
        }
    }
    else
    {
        if (adjOffset >= (_50.highLimit * 0.9900000095367431640625))
        {
            angleVal *= (1.0 - ((adjOffset - (_50.highLimit * 0.9900000095367431640625)) / (0.9900000095367431640625 - (_50.highLimit * 0.9900000095367431640625))));
        }
    }
    angleVal = ((angleVal * 0.01745329238474369049072265625) * 0.5) / length(a2b);
    float2 vv = (gl_FragCoord.xy - _50.refLayer.xy) / _50.refLayer.zw;
    float2 av = a;
    if (vertical)
    {
        vv.x *= (_50.refLayer.z / _50.refLayer.w);
        av.x *= (_50.refLayer.z / _50.refLayer.w);
        float2 param_1 = vv - av;
        float param_2 = angleVal;
        float param_3 = 1.0;
        float param_4 = 1.0;
        bool param_5 = vertical;
        float2 _394 = bend(param_1, param_2, param_3, param_4, param_5);
        float2 uv = _394;
        uv.x *= (_50.refLayer.w / _50.refLayer.z);
        av.x *= (_50.refLayer.w / _50.refLayer.z);
        float2 param_6 = uv + av;
        uv = l2s(param_6, _50);
        float insideTexture = ((step(0.0, uv.x) * step(uv.x, 1.0)) * step(0.0, uv.y)) * step(uv.y, 1.0);
        float2 param_7 = uv;
        referenceColor = texture2DCv(refInput, refInputSmplr, param_7) * insideTexture;
    }
    else
    {
        vv.y *= (_50.refLayer.w / _50.refLayer.z);
        av.y *= (_50.refLayer.w / _50.refLayer.z);
        float2 param_8 = vv - av;
        float param_9 = angleVal;
        float param_10 = 1.0;
        float param_11 = 1.0;
        bool param_12 = vertical;
        float2 _469 = bend(param_8, param_9, param_10, param_11, param_12);
        float2 uv_1 = _469;
        uv_1.y *= (_50.refLayer.z / _50.refLayer.w);
        av.y *= (_50.refLayer.z / _50.refLayer.w);
        float2 param_13 = uv_1 + av;
        uv_1 = l2s(param_13, _50);
        float insideTexture_1 = ((step(0.0, uv_1.x) * step(uv_1.x, 1.0)) * step(0.0, uv_1.y)) * step(uv_1.y, 1.0);
        float2 param_14 = uv_1;
        referenceColor = texture2DCv(refInput, refInputSmplr, param_14) * insideTexture_1;
    }
}

fragment refAM35_e6e18bbe3f759_out refAM35_e6e18bbe3f759(constant ReferenceUniformse6e18bbe3f759& _50 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e6e18bbe3f759_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_50, gl_FragCoord, referenceColor, refInput, refInputSmplr);
    bool _519 = any(isnan(referenceColor));
    bool _526;
    if (!_519)
    {
        _526 = any(isinf(referenceColor));
    }
    else
    {
        _526 = _519;
    }
    if (_526)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _540 = referenceColor;
    float3 _546 = fast::clamp(_540.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _546.x;
    referenceColor.y = _546.y;
    referenceColor.z = _546.z;
    out.finalColor = referenceColor;
    return out;
}

