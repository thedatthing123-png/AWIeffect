// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/mystery_book.xml
// Original source comments and attribution:
// Shadertoy constants
// Helpers
// Scene Logic
// 1. Wooden Table
// Book Dimensions
// Spine
// Right Side
// Left Side
// Camera
// Table
// Cover & Spine
// Pages
// Right
// Left
// Shadows
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb128ccb140e5
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float openProgress;
    char _m6_pad[12];
    float zoom;
    char _m7_pad[12];
    float camRot;
};

struct refAM35_eb128ccb140e5_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float sdRoundBox(thread const float3& p, thread const float3& b, thread const float& r)
{
    float3 q = abs(p) - b;
    return (length(fast::max(q, float3(0.0))) + fast::min(fast::max(q.x, fast::max(q.y, q.z)), 0.0)) - r;
}

static inline __attribute__((always_inline))
float sdBox(thread const float3& p, thread const float3& b)
{
    float3 q = abs(p) - b;
    return length(fast::max(q, float3(0.0))) + fast::min(fast::max(q.x, fast::max(q.y, q.z)), 0.0);
}

static inline __attribute__((always_inline))
float2 map(thread const float3& p, constant ReferenceUniformseb128ccb140e5& _274)
{
    float2 res = float2(100.0, 0.0);
    float dTable = p.y + 0.0500000007450580596923828125;
    if (dTable < res.x)
    {
        res = float2(dTable, 1.0);
    }
    float3 dim = float3(1.2000000476837158203125, 0.1500000059604644775390625, 1.60000002384185791015625);
    float coverThick = 0.0199999995529651641845703125;
    float3 pb = p - float3(0.0, 0.0500000007450580596923828125, 0.0);
    float3 pSpine = pb;
    pSpine.y -= (dim.y * 0.5);
    float3 param = pSpine;
    float3 param_1 = float3(0.100000001490116119384765625, dim.y * 0.60000002384185791015625, dim.z);
    float param_2 = 0.0199999995529651641845703125;
    float dSpine = sdRoundBox(param, param_1, param_2);
    if (dSpine < res.x)
    {
        res = float2(dSpine, 5.0);
    }
    float3 pR = pb;
    float3 localR = pR - float3(dim.x + 0.0199999995529651641845703125, 0.0, 0.0);
    float3 param_3 = localR - float3(0.0, (-dim.y) * 0.5, 0.0);
    float3 param_4 = float3(dim.x, coverThick, dim.z);
    float dRCover = sdBox(param_3, param_4);
    float3 param_5 = localR - float3(0.0, coverThick, 0.0);
    float3 param_6 = float3(dim.x - 0.0500000007450580596923828125, (dim.y * 0.5) - coverThick, dim.z - 0.0500000007450580596923828125);
    float dRPages = sdBox(param_5, param_6);
    if (dRCover < res.x)
    {
        res = float2(dRCover, 2.0);
    }
    if (dRPages < res.x)
    {
        res = float2(dRPages, 4.0);
    }
    float rotAng = (1.0 - _274.openProgress) * 3.1415927410125732421875;
    float3 pL_rot = pb;
    float param_7 = rotAng;
    float3 _288 = pL_rot;
    float2 _290 = _288.xy * rot(param_7);
    pL_rot.x = _290.x;
    pL_rot.y = _290.y;
    float3 localL = pL_rot - float3((-dim.x) - 0.0199999995529651641845703125, 0.0, 0.0);
    float3 param_8 = localL - float3(0.0, (-dim.y) * 0.5, 0.0);
    float3 param_9 = float3(dim.x, coverThick, dim.z);
    float dLCover = sdBox(param_8, param_9);
    float3 param_10 = localL - float3(0.0, coverThick, 0.0);
    float3 param_11 = float3(dim.x - 0.0500000007450580596923828125, (dim.y * 0.5) - coverThick, dim.z - 0.0500000007450580596923828125);
    float dLPages = sdBox(param_10, param_11);
    if (dLCover < res.x)
    {
        res = float2(dLCover, 2.0);
    }
    if (dLPages < res.x)
    {
        res = float2(dLPages, 3.0);
    }
    return res;
}

static inline __attribute__((always_inline))
float rayMarch(thread const float3& ro, thread const float3& rd, thread float& m, constant ReferenceUniformseb128ccb140e5& _274)
{
    float dO = 0.0;
    m = 0.0;
    for (int i = 0; i < 100; i++)
    {
        float3 p = ro + (rd * dO);
        float3 param = p;
        float2 dS = map(param, _274);
        dO += dS.x;
        m = dS.y;
        bool _390 = dO > 50.0;
        bool _399;
        if (!_390)
        {
            _399 = abs(dS.x) < 0.001000000047497451305389404296875;
        }
        else
        {
            _399 = _390;
        }
        if (_399)
        {
            break;
        }
    }
    return dO;
}

static inline __attribute__((always_inline))
float3 getNormal(thread const float3& p, constant ReferenceUniformseb128ccb140e5& _274)
{
    float3 param = p;
    float d = map(param, _274).x;
    float2 e = float2(0.001000000047497451305389404296875, 0.0);
    float3 param_1 = p - e.xyy;
    float3 param_2 = p - e.yxy;
    float3 param_3 = p - e.yyx;
    float3 n = float3(d) - float3(map(param_1, _274).x, map(param_2, _274).x, map(param_3, _274).x);
    return fast::normalize(n);
}

static inline __attribute__((always_inline))
float3 getWood(thread const float2& uv)
{
    float n = sin((uv.x * 20.0) + (sin(uv.y * 50.0) * 2.0));
    return float3(0.300000011920928955078125, 0.1500000059604644775390625, 0.0500000007450580596923828125) * (0.800000011920928955078125 + (0.20000000298023223876953125 * n));
}

static inline __attribute__((always_inline))
float hash21(thread const float2& p)
{
    float3 p3 = fract(p.xyx * 0.103100001811981201171875);
    p3 += float3(dot(p3, p3.yzx + float3(33.3300018310546875)));
    return fract((p3.x + p3.y) * p3.z);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseb128ccb140e5& _274, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (float2(gl_FragCoord.x, _274.refScreen.y - gl_FragCoord.y) / _274.refScreen.xy) - float2(0.5);
    uv.x *= (_274.refLayer.z / _274.refLayer.w);
    float3 ro = float3(0.0, 3.5, -4.0) * _274.zoom;
    float param = _274.camRot;
    float3 _510 = ro;
    float2 _512 = _510.xz * rot(param);
    ro.x = _512.x;
    ro.z = _512.y;
    float3 lookAt = float3(0.0);
    float3 f = fast::normalize(lookAt - ro);
    float3 r = fast::normalize(cross(float3(0.0, 1.0, 0.0), f));
    float3 u = cross(f, r);
    float3 rd = fast::normalize((f + (r * uv.x)) + (u * uv.y));
    float m = 0.0;
    float3 param_1 = ro;
    float3 param_2 = rd;
    float param_3;
    float _553 = rayMarch(param_1, param_2, param_3, _274);
    m = param_3;
    float d = _553;
    float3 col = float3(0.00999999977648258209228515625, 0.0, 0.0199999995529651641845703125);
    if (d < 50.0)
    {
        float3 p = ro + (rd * d);
        float3 param_4 = p;
        float3 n = getNormal(param_4, _274);
        float3 lightPos = float3(1.0, 3.0, -1.0);
        float3 l = fast::normalize(lightPos - p);
        float dif = fast::clamp(dot(n, l), 0.0, 1.0);
        float amb = 0.100000001490116119384765625;
        float3 albedo = float3(0.5);
        if (m == 1.0)
        {
            float2 param_5 = p.xz;
            albedo = getWood(param_5);
            float spec = powr(fast::max(dot(reflect(-l, n), -rd), 0.0), 16.0);
            albedo += float3(spec * 0.100000001490116119384765625);
        }
        else
        {
            if ((m == 2.0) || (m == 5.0))
            {
                float2 param_6 = p.xz * 10.0;
                float grain = hash21(param_6);
                albedo = float3(0.1500000059604644775390625, 0.0199999995529651641845703125, 0.0199999995529651641845703125) * (0.800000011920928955078125 + (0.20000000298023223876953125 * grain));
                float spec_1 = powr(fast::max(dot(reflect(-l, n), -rd), 0.0), 8.0);
                albedo += float3(spec_1 * 0.20000000298023223876953125);
            }
            else
            {
                if ((m == 3.0) || (m == 4.0))
                {
                    albedo = float3(0.89999997615814208984375, 0.85000002384185791015625, 0.75);
                    float3 dim = float3(1.2000000476837158203125, 0.1500000059604644775390625, 1.60000002384185791015625);
                    float2 pageUV = float2(0.0);
                    bool isTopFace = false;
                    if (m == 4.0)
                    {
                        float3 local = (p - float3(0.0, 0.0500000007450580596923828125, 0.0)) - float3(dim.x + 0.0199999995529651641845703125, 0.0, 0.0);
                        if (n.y > 0.5)
                        {
                            isTopFace = true;
                            pageUV.x = fast::clamp((local.x + dim.x) / (2.0 * dim.x), 0.0, 1.0);
                            pageUV.y = fast::clamp((local.z + dim.z) / (2.0 * dim.z), 0.0, 1.0);
                        }
                    }
                    else
                    {
                        float3 pb = p - float3(0.0, 0.0500000007450580596923828125, 0.0);
                        float rotAng = (1.0 - _274.openProgress) * 3.1415927410125732421875;
                        float3 pL_rot = pb;
                        float param_7 = rotAng;
                        float3 _720 = pL_rot;
                        float2 _722 = _720.xy * rot(param_7);
                        pL_rot.x = _722.x;
                        pL_rot.y = _722.y;
                        float3 local_1 = pL_rot - float3((-dim.x) - 0.0199999995529651641845703125, 0.0, 0.0);
                        if (n.y > (-0.5))
                        {
                            isTopFace = true;
                            pageUV.x = fast::clamp((local_1.x + dim.x) / (2.0 * dim.x), 0.0, 1.0);
                            pageUV.y = fast::clamp((local_1.z + dim.z) / (2.0 * dim.z), 0.0, 1.0);
                            pageUV.x = 1.0 - pageUV.x;
                        }
                    }
                    if (isTopFace)
                    {
                        float3 tex = refInput.sample(refInputSmplr, pageUV).xyz;
                        float2 param_8 = p.xz * 50.0;
                        tex *= (0.89999997615814208984375 + (0.100000001490116119384765625 * hash21(param_8)));
                        float vig = smoothstep(0.4900000095367431640625, 0.449999988079071044921875, abs(pageUV.x - 0.5)) * smoothstep(0.4900000095367431640625, 0.449999988079071044921875, abs(pageUV.y - 0.5));
                        albedo = mix(albedo * 0.5, tex, float3(vig));
                    }
                    else
                    {
                        float lines = sin(p.y * 200.0);
                        albedo *= (0.800000011920928955078125 + (0.20000000298023223876953125 * lines));
                    }
                }
            }
        }
        float3 color = albedo * (amb + dif);
        float sh = 1.0;
        float dS = 0.0199999995529651641845703125;
        float shadowVal = 1.0;
        for (int i = 0; i < 20; i++)
        {
            float3 param_9 = p + (l * dS);
            float h = map(param_9, _274).x;
            if (h < 0.001000000047497451305389404296875)
            {
                shadowVal = 0.100000001490116119384765625;
                break;
            }
            shadowVal = fast::min(shadowVal, (10.0 * h) / dS);
            dS += h;
            if (dS > 2.0)
            {
                break;
            }
        }
        color *= mix(0.20000000298023223876953125, 1.0, shadowVal);
        color = mix(color, float3(0.00999999977648258209228515625, 0.0, 0.0199999995529651641845703125), float3(smoothstep(5.0, 15.0, d)));
        col = color;
    }
    col = powr(col, float3(0.4544999897480010986328125));
    col *= (1.0 - (length(uv) * 0.5));
    referenceColor = float4(col, 1.0);
}

fragment refAM35_eb128ccb140e5_out refAM35_eb128ccb140e5(constant ReferenceUniformseb128ccb140e5& _274 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb128ccb140e5_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_274, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _901 = any(isnan(referenceColor));
    bool _908;
    if (!_901)
    {
        _908 = any(isinf(referenceColor));
    }
    else
    {
        _908 = _901;
    }
    if (_908)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _921 = referenceColor;
    float3 _927 = fast::clamp(_921.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _927.x;
    referenceColor.y = _927.y;
    referenceColor.z = _927.z;
    out.finalColor = referenceColor;
    return out;
}

