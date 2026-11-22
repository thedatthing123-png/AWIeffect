// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/tiles-rot-glow.xml
// Original source comments and attribution:
// Rotating tiled boxes glow - AM single pass
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea91d335188cb
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float SCALE;
    char _m6_pad[12];
    float ROT_SPEED;
    char _m7_pad[12];
    float BORDER;
    char _m8_pad[12];
    float DIST_COEF;
    char _m9_pad[12];
    float EDGE_FREQ;
    char _m10_pad[12];
    float EDGE_TIME;
    char _m11_pad[12];
    float EDGE_POW;
    char _m12_pad[12];
    float EDGE_GAIN;
    char _m13_pad[12];
    float POW_R;
    char _m14_pad[12];
    float POW_G;
    char _m15_pad[12];
    float POW_B;
};

struct refAM35_ea91d335188cb_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    return float2x2(float2(cos(a), -sin(a)), float2(sin(a), cos(a)));
}

static inline __attribute__((always_inline))
float sdBox(thread const float2& p, thread const float& b)
{
    float2 d = abs(p) - float2(b);
    return length(fast::max(d, float2(0.0)));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsea91d335188cb& _55, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 R = _55.refScreen.xy;
    float2 frag = (gl_FragCoord.xy / _55.refScreen.xy) * R;
    float2 uv = (frag - (R * 0.5)) / float2(fast::max(R.x, 1.0));
    float a = _55.ROT_SPEED * _55.refScreen.z;
    float param = a;
    uv = rot(param) * uv;
    uv += float2(0.5 / _55.SCALE);
    float2 scaled_uv = uv * _55.SCALE;
    float2 tile = fract(scaled_uv) - float2(0.5);
    float square_dist = length(floor(scaled_uv));
    float square_dist_distortion = (square_dist * _55.EDGE_FREQ) * (1.0 + powr(sin(_55.refScreen.z * _55.EDGE_TIME), 2.0));
    float edge = sin((0.5 * _55.refScreen.z) + square_dist_distortion);
    edge *= edge;
    edge = powr(edge, _55.EDGE_POW) * _55.EDGE_GAIN;
    float border = _55.BORDER;
    float2 param_1 = tile;
    float param_2 = edge;
    float value = 1.5 - smoothstep(0.0 - border, 0.0 + border, sdBox(param_1, param_2));
    value -= (square_dist * _55.DIST_COEF);
    value = fast::max(value, 0.0);
    float3 col = float3(powr(value, _55.POW_R), powr(value, _55.POW_G), powr(value, _55.POW_B));
    referenceColor = float4(col, 1.0);
}

fragment refAM35_ea91d335188cb_out refAM35_ea91d335188cb(constant ReferenceUniformsea91d335188cb& _55 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea91d335188cb_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_55, gl_FragCoord, referenceColor);
    bool _215 = any(isnan(referenceColor));
    bool _222;
    if (!_215)
    {
        _222 = any(isinf(referenceColor));
    }
    else
    {
        _222 = _215;
    }
    if (_222)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _236 = referenceColor;
    float3 _242 = fast::clamp(_236.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _242.x;
    referenceColor.y = _242.y;
    referenceColor.z = _242.z;
    out.finalColor = referenceColor;
    return out;
}

