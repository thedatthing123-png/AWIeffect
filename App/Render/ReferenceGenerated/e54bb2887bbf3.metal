// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/split-cubes-raymarch.xml
// Original source comments and attribution:
// Split Cubes Raymarch - GLES-friendly single pass
// Map 0..5 to fixed palette without dynamic array indexing
// Determine face influence
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

struct ReferenceUniformse54bb2887bbf3
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float BPM;
    char _m6_pad[12];
    float STEPS;
    char _m7_pad[12];
    float EPS;
    char _m8_pad[12];
    float MAX_DIST;
    char _m9_pad[12];
    float SPIN_SCALE;
};

struct refAM35_e54bb2887bbf3_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 rot2(thread const float2& a, thread const float& b)
{
    float c = cos(b);
    float s = sin(b);
    return float2((a.x * c) - (a.y * s), (a.x * s) + (a.y * c));
}

static inline __attribute__((always_inline))
float tick(thread float& t)
{
    t = smoothstep(0.0, 1.0, t);
    t = smoothstep(0.0, 1.0, t);
    return t;
}

static inline __attribute__((always_inline))
float _noise1(thread const float& a)
{
    return fract(a * 123.47628021240234375);
}

static inline __attribute__((always_inline))
float sdBox(thread const float3& p, thread const float3& r)
{
    float3 d = abs(p) - r;
    return fast::min(fast::max(d.x, fast::max(d.y, d.z)), 0.0) + length(fast::max(d, float3(0.0)));
}

static inline __attribute__((always_inline))
float sdRoundBox(thread const float3& p, thread const float3& r, thread const float& rr)
{
    float3 param = p;
    float3 param_1 = r - float3(rr);
    return sdBox(param, param_1) - rr;
}

static inline __attribute__((always_inline))
float2 splitScene(thread float3& p, thread const float& spinScale, thread const float& SPEED, constant ReferenceUniformse54bb2887bbf3& _153)
{
    float time = _153.refScreen.z * SPEED;
    float param = fract(time);
    float _164 = tick(param);
    float t = _164;
    float param_1 = floor(time);
    float mode = _noise1(param_1) * 3.0;
    float axisDirection = (fract(mode) < 0.5) ? (-1.0) : 1.0;
    float spinDirection = (mod(mode, 0.5) < 0.25) ? (-1.0) : 1.0;
    t *= spinDirection;
    float clipDist = 0.0;
    if (mode < 1.0)
    {
        float2 param_2 = p.yz;
        float param_3 = (t * 1.57079637050628662109375) * spinScale;
        float2 _203 = rot2(param_2, param_3);
        p.y = _203.x;
        p.z = _203.y;
        clipDist = (p.x * axisDirection) - 0.5;
    }
    else
    {
        if (mode < 2.0)
        {
            float2 param_4 = p.xz;
            float param_5 = (t * 1.57079637050628662109375) * spinScale;
            float2 _227 = rot2(param_4, param_5);
            p.x = _227.x;
            p.z = _227.y;
            clipDist = (p.y * axisDirection) - 0.5;
        }
        else
        {
            float2 param_6 = p.xy;
            float param_7 = (t * 1.57079637050628662109375) * spinScale;
            float2 _246 = rot2(param_6, param_7);
            p.x = _246.x;
            p.y = _246.y;
            clipDist = (p.z * axisDirection) - 0.5;
        }
    }
    clipDist *= (1.0 - (spinScale * 2.0));
    float3 lp = mod(p + float3(0.5), float3(1.0)) - float3(0.5);
    float3 param_8 = p;
    float3 param_9 = float3(1.5);
    float3 param_10 = lp;
    float3 param_11 = float3(0.4799999892711639404296875);
    float param_12 = 0.039999999105930328369140625;
    float distCubes = fast::max(sdBox(param_8, param_9), sdRoundBox(param_10, param_11, param_12));
    float3 stickerSize = float3(0.4000000059604644775390625, 0.4000000059604644775390625, 1.0);
    float stickerRadius = 0.0500000007450580596923828125;
    float3 param_13 = lp;
    float3 param_14 = stickerSize;
    float param_15 = stickerRadius;
    float3 param_16 = lp;
    float3 param_17 = stickerSize.yzx;
    float param_18 = stickerRadius;
    float3 param_19 = lp;
    float3 param_20 = stickerSize.zxy;
    float param_21 = stickerRadius;
    float distStickers = fast::min(fast::min(sdRoundBox(param_13, param_14, param_15), sdRoundBox(param_16, param_17, param_18)), sdRoundBox(param_19, param_20, param_21));
    float3 param_22 = p;
    float3 param_23 = float3(1.39999997615814208984375);
    distStickers = fast::max(distStickers, -sdBox(param_22, param_23));
    distCubes = fast::max(distCubes, clipDist);
    float color = 0.0;
    color += (floor(p.x + 1.5) * 3.0);
    color += (floor(p.y + 1.5) * 7.0);
    color += (floor(p.z + 1.5) * 11.0);
    color += mode;
    float _358;
    if (distStickers < 0.0)
    {
        _358 = 1.0 + color;
    }
    else
    {
        _358 = 0.0;
    }
    return float2(distCubes, _358);
}

static inline __attribute__((always_inline))
float2 sceneSDF(thread const float3& p, thread const float& SPEED, constant ReferenceUniformse54bb2887bbf3& _153)
{
    float3 param = p;
    float param_1 = 0.0;
    float param_2 = SPEED;
    float2 _374 = splitScene(param, param_1, param_2, _153);
    float2 a = _374;
    float3 param_3 = p;
    float param_4 = _153.SPIN_SCALE;
    float param_5 = SPEED;
    float2 _384 = splitScene(param_3, param_4, param_5, _153);
    float2 b = _384;
    float2 _390;
    if (a.x < b.x)
    {
        _390 = float2(a.x, a.y);
    }
    else
    {
        _390 = float2(b.x, b.y);
    }
    return _390;
}

static inline __attribute__((always_inline))
float hash2(thread const float2& a)
{
    return fract(sin(dot(a, float2(4.432429790496826171875, 12.476200103759765625)) * 13.4376201629638671875));
}

static inline __attribute__((always_inline))
float3 colorForIndex(thread const int& idx)
{
    if (idx == 0)
    {
        return float3(1.0, 0.0, 0.0);
    }
    if (idx == 1)
    {
        return float3(1.0, 1.0, 0.0);
    }
    if (idx == 2)
    {
        return float3(0.0, 1.0, 0.0);
    }
    if (idx == 3)
    {
        return float3(1.0);
    }
    if (idx == 4)
    {
        return float3(0.0, 0.0, 1.0);
    }
    return float3(1.0, 0.5, 0.0);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse54bb2887bbf3& _153, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 R = _153.refScreen.xy;
    float2 uv = (gl_FragCoord.xy / _153.refScreen.xy) - float2(0.5);
    uv.x *= (R.x / fast::max(R.y, 1.0));
    float SPEED = fast::max(_153.BPM, 1.0) / 60.0;
    float3 cam = float3(0.0, 0.0, -10.0);
    float3 dir = fast::normalize(float3(uv, 1.5));
    float angYZ = (sin(_153.refScreen.z) * 0.300000011920928955078125) + 0.300000011920928955078125;
    float2 param = cam.yz;
    float param_1 = angYZ;
    float2 _498 = rot2(param, param_1);
    cam.y = _498.x;
    cam.z = _498.y;
    float2 param_2 = dir.yz;
    float param_3 = angYZ;
    float2 _508 = rot2(param_2, param_3);
    dir.y = _508.x;
    dir.z = _508.y;
    float angXZ = _153.refScreen.z * 0.5;
    float2 param_4 = cam.xz;
    float param_5 = angXZ;
    float2 _522 = rot2(param_4, param_5);
    cam.x = _522.x;
    cam.z = _522.y;
    float2 param_6 = dir.xz;
    float param_7 = angXZ;
    float2 _532 = rot2(param_6, param_7);
    dir.x = _532.x;
    dir.z = _532.y;
    float t = 0.0;
    float2 k = float2(0.0);
    int maxSteps = int(fast::clamp(_153.STEPS, 1.0, 200.0));
    for (int i = 0; i < 200; i++)
    {
        if (i >= maxSteps)
        {
            break;
        }
        float3 param_8 = cam + (dir * t);
        float param_9 = SPEED;
        k = sceneSDF(param_8, param_9, _153);
        t += k.x;
        if (k.x < _153.EPS)
        {
            break;
        }
        if (t > _153.MAX_DIST)
        {
            k.y = -1.0;
            break;
        }
    }
    float3 h = cam + (dir * t);
    float2 o = float2(0.001000000047497451305389404296875, 0.0);
    float3 param_10 = h + float3(o.x, o.y, o.y);
    float param_11 = SPEED;
    float3 param_12 = h - float3(o.x, o.y, o.y);
    float param_13 = SPEED;
    float3 param_14 = h + float3(o.y, o.x, o.y);
    float param_15 = SPEED;
    float3 param_16 = h - float3(o.y, o.x, o.y);
    float param_17 = SPEED;
    float3 param_18 = h + float3(o.y, o.y, o.x);
    float param_19 = SPEED;
    float3 param_20 = h - float3(o.y, o.y, o.x);
    float param_21 = SPEED;
    float3 n = fast::normalize(float3(sceneSDF(param_10, param_11, _153).x - sceneSDF(param_12, param_13, _153).x, sceneSDF(param_14, param_15, _153).x - sceneSDF(param_16, param_17, _153).x, sceneSDF(param_18, param_19, _153).x - sceneSDF(param_20, param_21, _153).x));
    float mat = k.y;
    float3 outc;
    if (abs(mat) < 9.9999999747524270787835121154785e-07)
    {
        float fresnel = powr(1.0 - dot(-dir, n), 5.0);
        fresnel = mix(0.001599999959580600261688232421875, 0.100000001490116119384765625, fresnel);
        outc = float3(fresnel);
    }
    else
    {
        if (mat < (-0.5))
        {
            float2 luv = uv * (1.0 - (length(uv) * 0.20000000298023223876953125));
            float2 c = floor((luv * 10.0) + float2(_153.refScreen.z));
            float2 u = fract((luv * 10.0) + float2(_153.refScreen.z)) - float2(0.5);
            float2 param_22 = c + float2(0.100000001490116119384765625 * floor(_153.refScreen.z * SPEED));
            int colorIndex = int(floor((hash2(param_22) * 6.0) + 9.9999997473787516355514526367188e-05));
            colorIndex = clamp(colorIndex, 0, 5);
            float3 param_23 = float3(u, 0.0);
            float3 param_24 = float3(0.4600000083446502685546875);
            float param_25 = 0.0500000007450580596923828125;
            float d = sdRoundBox(param_23, param_24, param_25);
            float mask = smoothstep(0.0, 0.00999999977648258209228515625, -d);
            float vignette = smoothstep(1.0, 0.300000011920928955078125, length(luv)) * 0.699999988079071044921875;
            int param_26 = colorIndex;
            outc = (colorForIndex(param_26) * mask) * vignette;
        }
        else
        {
            float m = mod(mat, 6.0);
            m += ((step(0.100000001490116119384765625, n.x) + 0.0) * float(abs(n.x) > 0.100000001490116119384765625));
            m += ((step(0.100000001490116119384765625, n.y) + 2.0) * float(abs(n.y) > 0.100000001490116119384765625));
            m += ((step(0.100000001490116119384765625, n.z) + 4.0) * float(abs(n.z) > 0.100000001490116119384765625));
            int idx = int(mod(m, 6.0));
            int param_27 = idx;
            outc = colorForIndex(param_27);
        }
    }
    outc = powr(fast::max(outc, float3(0.0)), float3(0.4544999897480010986328125));
    outc = powr(outc, float3(1.2000000476837158203125, 1.10000002384185791015625, 1.0));
    referenceColor = float4(outc, 1.0);
}

fragment refAM35_e54bb2887bbf3_out refAM35_e54bb2887bbf3(constant ReferenceUniformse54bb2887bbf3& _153 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e54bb2887bbf3_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_153, gl_FragCoord, referenceColor);
    bool _871 = any(isnan(referenceColor));
    bool _878;
    if (!_871)
    {
        _878 = any(isinf(referenceColor));
    }
    else
    {
        _878 = _871;
    }
    if (_878)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _892 = referenceColor;
    float3 _898 = fast::clamp(_892.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _898.x;
    referenceColor.y = _898.y;
    referenceColor.z = _898.z;
    out.finalColor = referenceColor;
    return out;
}

