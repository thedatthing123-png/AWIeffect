// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/monitor_on_table.xml
// Original source comments and attribution:
// Material IDs
// Rotation matrix
// SDF Box
// Scene Map
// 1. Room Geometry
// 2. Table Geometry
// Table Top
// Table Legs
// 3. Monitor Geometry
// Stand Base
// Stand Neck
// Screen Bezel
// Screen Surface
// Raymarch
// Normals
// Soft Shadows
// Reduced steps for mobile
// Camera Setup
// Apply rotation
// Render
// Background/Fog color
// Fog
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse52053df16be1
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float zoom;
    char _m6_pad[12];
    float rotation;
};

struct refAM35_e52053df16be1_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 Rot(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float sdBox(thread const float3& p, thread const float3& b)
{
    float3 q = abs(p) - b;
    return length(fast::max(q, float3(0.0))) + fast::min(fast::max(q.x, fast::max(q.y, q.z)), 0.0);
}

static inline __attribute__((always_inline))
float2 map(thread const float3& p)
{
    float2 res = float2(50.0, 0.0);
    float dFloor = p.y;
    float dWall = 2.5 - p.z;
    if (dFloor < res.x)
    {
        res = float2(dFloor, 1.0);
    }
    if (dWall < res.x)
    {
        res = float2(dWall, 5.0);
    }
    float tH = 0.800000011920928955078125;
    float tW = 1.39999997615814208984375;
    float tD = 0.699999988079071044921875;
    float tThick = 0.0500000007450580596923828125;
    float3 pTop = p - float3(0.0, tH, 0.0);
    float3 param = pTop;
    float3 param_1 = float3(tW * 0.5, tThick * 0.5, tD * 0.5);
    float dTop = sdBox(param, param_1);
    float3 pLegs = p;
    pLegs.x = abs(pLegs.x);
    pLegs.z = abs(pLegs.z);
    pLegs -= float3(tW * 0.4000000059604644775390625, tH * 0.5, tD * 0.4000000059604644775390625);
    float3 param_2 = pLegs;
    float3 param_3 = float3(0.039999999105930328369140625, tH * 0.5, 0.039999999105930328369140625);
    float dLegs = sdBox(param_2, param_3);
    float dTable = fast::min(dTop, dLegs);
    if (dTable < res.x)
    {
        res = float2(dTable, 2.0);
    }
    float3 pm = p - float3(0.0, tH + (tThick * 0.5), 0.0);
    float3 param_4 = pm - float3(0.0, 0.00999999977648258209228515625, 0.0);
    float3 param_5 = float3(0.1500000059604644775390625, 0.00999999977648258209228515625, 0.119999997317790985107421875);
    float dBase = sdBox(param_4, param_5);
    float3 param_6 = pm - float3(0.0, 0.1500000059604644775390625, 0.0500000007450580596923828125);
    float3 param_7 = float3(0.039999999105930328369140625, 0.1500000059604644775390625, 0.0199999995529651641845703125);
    float dNeck = sdBox(param_6, param_7);
    float3 ph = pm - float3(0.0, 0.449999988079071044921875, 0.0);
    float3 param_8 = ph;
    float3 param_9 = float3(0.60000002384185791015625, 0.3499999940395355224609375, 0.039999999105930328369140625);
    float dBezel = sdBox(param_8, param_9);
    float dMonitorFrame = fast::min(dBase, fast::min(dNeck, dBezel));
    if (dMonitorFrame < res.x)
    {
        res = float2(dMonitorFrame, 3.0);
    }
    float3 param_10 = ph - float3(0.0, 0.0, -0.041000001132488250732421875);
    float3 param_11 = float3(0.569999992847442626953125, 0.319999992847442626953125, 0.001000000047497451305389404296875);
    float dScreen = sdBox(param_10, param_11);
    if (dScreen < res.x)
    {
        res = float2(dScreen, 4.0);
    }
    return res;
}

static inline __attribute__((always_inline))
float2 rayMarch(thread const float3& ro, thread const float3& rd)
{
    float dO = 0.0;
    float m = 0.0;
    for (int i = 0; i < 100; i++)
    {
        float3 p = ro + (rd * dO);
        float3 param = p;
        float2 dS = map(param);
        dO += dS.x;
        m = dS.y;
        bool _294 = dO > 50.0;
        bool _302;
        if (!_294)
        {
            _302 = abs(dS.x) < 0.001000000047497451305389404296875;
        }
        else
        {
            _302 = _294;
        }
        if (_302)
        {
            break;
        }
    }
    return float2(dO, m);
}

static inline __attribute__((always_inline))
float3 getNormal(thread const float3& p)
{
    float3 param = p;
    float d = map(param).x;
    float2 e = float2(0.001000000047497451305389404296875, 0.0);
    float3 param_1 = p - e.xyy;
    float3 param_2 = p - e.yxy;
    float3 param_3 = p - e.yyx;
    float3 n = float3(d) - float3(map(param_1).x, map(param_2).x, map(param_3).x);
    return fast::normalize(n);
}

static inline __attribute__((always_inline))
float getShadow(thread const float3& p, thread const float3& l, thread const float& k)
{
    float res = 1.0;
    float t = 0.0199999995529651641845703125;
    for (int i = 0; i < 20; i++)
    {
        float3 param = p + (l * t);
        float h = map(param).x;
        if (h < 0.001000000047497451305389404296875)
        {
            return 0.0;
        }
        res = fast::min(res, (k * h) / t);
        t += h;
        if (t > 10.0)
        {
            break;
        }
    }
    return res;
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse52053df16be1& _406, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy / _406.refScreen.xy) - float2(0.5);
    uv.x *= (_406.refLayer.z / _406.refLayer.w);
    float d = 4.0 / _406.zoom;
    float3 pivot = float3(0.0, 1.25, 0.0);
    float3 camPos = float3(0.0, 0.5, -d);
    float param = _406.rotation;
    float3 _442 = camPos;
    float2 _444 = _442.xz * Rot(param);
    camPos.x = _444.x;
    camPos.z = _444.y;
    camPos += pivot;
    float3 lookAt = pivot;
    float3 f = fast::normalize(lookAt - camPos);
    float3 r = fast::normalize(cross(float3(0.0, 1.0, 0.0), f));
    float3 u = cross(f, r);
    float3 rd = fast::normalize((f + (r * uv.x)) + (u * uv.y));
    float3 param_1 = camPos;
    float3 param_2 = rd;
    float2 tr = rayMarch(param_1, param_2);
    float dist = tr.x;
    float m = tr.y;
    float3 col = float3(0.0500000007450580596923828125, 0.0500000007450580596923828125, 0.07999999821186065673828125);
    if (dist < 50.0)
    {
        float3 p = camPos + (rd * dist);
        float3 param_3 = p;
        float3 n = getNormal(param_3);
        float3 lightPos = float3(2.0, 4.0, -2.0);
        float3 l = fast::normalize(lightPos - p);
        float3 param_4 = p;
        float3 param_5 = l;
        float param_6 = 8.0;
        float shadow = getShadow(param_4, param_5, param_6);
        float diff = fast::max(0.0, dot(n, l));
        float amb = 0.0500000007450580596923828125;
        float3 albedo = float3(0.5);
        if (m == 1.0)
        {
            albedo = float3(0.1500000059604644775390625);
            if ((fract(p.x) > 0.5) != (fract(p.z) > 0.5))
            {
                albedo *= 0.800000011920928955078125;
            }
        }
        else
        {
            if (m == 2.0)
            {
                albedo = float3(0.949999988079071044921875);
            }
            else
            {
                if (m == 3.0)
                {
                    albedo = float3(0.100000001490116119384765625);
                }
                else
                {
                    if (m == 5.0)
                    {
                        albedo = float3(0.800000011920928955078125, 0.800000011920928955078125, 0.85000002384185791015625);
                    }
                    else
                    {
                        if (m == 4.0)
                        {
                            float3 screenCenter = float3(0.0, 1.27499997615814208984375, -0.041000001132488250732421875);
                            float3 local = p - screenCenter;
                            float2 sUV = ((local.xy / float2(0.569999992847442626953125, 0.319999992847442626953125)) * 0.5) + float2(0.5);
                            sUV = fast::clamp(sUV, float2(0.0), float2(1.0));
                            albedo = refInput.sample(refInputSmplr, sUV).xyz;
                            col = albedo * 1.5;
                        }
                    }
                }
            }
        }
        if (m != 4.0)
        {
            col = albedo * ((diff * shadow) + amb);
            float3 h = fast::normalize(l - rd);
            float spec = powr(fast::max(0.0, dot(n, h)), 32.0);
            float specStr = (m == 2.0) ? 0.5 : 0.300000011920928955078125;
            col += float3((spec * specStr) * shadow);
        }
        col = mix(col, float3(0.0500000007450580596923828125, 0.0500000007450580596923828125, 0.07999999821186065673828125), float3(1.0 - exp((-dist) * 0.0199999995529651641845703125)));
    }
    col = powr(col, float3(0.4544999897480010986328125));
    referenceColor = float4(col, 1.0);
}

fragment refAM35_e52053df16be1_out refAM35_e52053df16be1(constant ReferenceUniformse52053df16be1& _406 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e52053df16be1_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _406, refInput, refInputSmplr, referenceColor);
    bool _668 = any(isnan(referenceColor));
    bool _675;
    if (!_668)
    {
        _675 = any(isinf(referenceColor));
    }
    else
    {
        _675 = _668;
    }
    if (_675)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _688 = referenceColor;
    float3 _694 = fast::clamp(_688.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _694.x;
    referenceColor.y = _694.y;
    referenceColor.z = _694.z;
    out.finalColor = referenceColor;
    return out;
}

