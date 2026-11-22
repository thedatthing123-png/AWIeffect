// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/3polygontun.xml
// Original source comments and attribution:
// Polygon Tunnel Arrow - AM single pass
// Normalized coordinates (-1..1 vertically)
// Twist
// Tunnel mapping (iq technique)
// Grid warps
// Rotate drawing coords
// Rect (as polygon with 4 verts)
// Triangle
// Shading
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseaf9be5de3d0e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float SPEED;
    char _m6_pad[12];
    float TWIST_K;
    char _m7_pad[12];
    float TWIST_FREQ;
    char _m8_pad[12];
    float PHASE;
    char _m9_pad[12];
    float GRID_SCALE;
    char _m10_pad[12];
    float GRID_PHASE;
    char _m11_pad[12];
    float PREWARP_AMP;
    char _m12_pad[12];
    float PREWARP_FREQ;
    char _m13_pad[12];
    float ROT;
    char _m14_pad[12];
    float RECT_SIZE;
    char _m15_pad[12];
    float TRI_SIZE;
    char _m16_pad[12];
    float RECT_OFF_Y;
    char _m17_pad[8];
    float2 TRI_OFFSET;
    char _m18_pad[8];
    float COLOR_GAIN;
    char _m19_pad[12];
    float OUTER_BIAS;
    char _m20_pad[12];
    float GAMMA;
};

struct refAM35_eaf9be5de3d0e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rot2(thread const float& r)
{
    return float2x2(float2(cos(r), sin(r)), float2(-sin(r), cos(r)));
}

static inline __attribute__((always_inline))
float polygon(thread const float2& p, thread const float& vertices, thread const float& size)
{
    float a = precise::atan2(p.x, p.y) + 0.20000000298023223876953125;
    float b = 6.283185482025146484375 / fast::max(vertices, 1.0);
    return (cos((floor(0.5 + (a / b)) * b) - a) * length(p)) - size;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseaf9be5de3d0e& _78, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float time = _78.refScreen.z * _78.SPEED;
    float2 R = _78.refScreen.xy;
    float2 frag = (gl_FragCoord.xy / _78.refScreen.xy) * R;
    float2 p = ((-R) + (frag * 2.0)) / float2(fast::max(R.y, 1.0));
    float2 uvOrig = p;
    float rotZ = 1.0 - (_78.TWIST_K * sin(_78.TWIST_FREQ * sin(length(p * 1.5))));
    float param = rotZ;
    p *= rot2(param);
    float a = precise::atan2(p.y, p.x);
    float rSquare = powr(powr(p.x * p.x, 4.0) + powr(p.y * p.y, 4.0), 0.125);
    float rRound = length(p);
    float r = mix(rSquare, rRound, 0.5 + (0.5 * sin(time * _78.PHASE)));
    float2 uv = float2((0.300000011920928955078125 / fast::max(r, 9.9999997473787516355514526367188e-05)) + time, a / 3.1415927410125732421875);
    uv += float2(0.0, _78.PREWARP_AMP * sin(time + (uv.x * _78.PREWARP_FREQ)));
    float2 uvDraw = fract((uv * _78.GRID_SCALE) + float2(_78.GRID_PHASE * sin(time))) - float2(0.5);
    float param_1 = _78.ROT;
    uvDraw *= rot2(param_1);
    float antialias = 8.0 / fast::max(R.y, 1.0);
    float col = 0.0;
    float2 rectPos = uvDraw + float2(0.0, _78.RECT_OFF_Y);
    float2 param_2 = rectPos;
    float param_3 = 4.0;
    float param_4 = _78.RECT_SIZE;
    col = fast::max(col, smoothstep(antialias, 0.0, polygon(param_2, param_3, param_4)));
    float2 triPos = uvDraw + _78.TRI_OFFSET;
    float2 param_5 = triPos;
    float param_6 = 3.0;
    float param_7 = _78.TRI_SIZE;
    col = fast::max(col, smoothstep(antialias, 0.0, polygon(param_5, param_6, param_7)));
    col = (col * r) * _78.COLOR_GAIN;
    col += (_78.OUTER_BIAS * length(uvOrig));
    float3 outc = float3(col);
    outc = powr(fast::max(outc, float3(0.0)), float3(_78.GAMMA));
    referenceColor = float4(outc, 1.0);
}

fragment refAM35_eaf9be5de3d0e_out refAM35_eaf9be5de3d0e(constant ReferenceUniformseaf9be5de3d0e& _78 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eaf9be5de3d0e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_78, gl_FragCoord, referenceColor);
    bool _317 = any(isnan(referenceColor));
    bool _324;
    if (!_317)
    {
        _324 = any(isinf(referenceColor));
    }
    else
    {
        _324 = _317;
    }
    if (_324)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _338 = referenceColor;
    float3 _344 = fast::clamp(_338.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _344.x;
    referenceColor.y = _344.y;
    referenceColor.z = _344.z;
    out.finalColor = referenceColor;
    return out;
}

