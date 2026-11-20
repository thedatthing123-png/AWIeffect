// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/colorista.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse8c9b81f88ba0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float exposure;
    char _m6_pad[12];
    float contrast;
    char _m7_pad[12];
    float shadows;
    char _m8_pad[12];
    float highlights;
    char _m9_pad[12];
    float temperature;
    char _m10_pad[12];
    float tint;
    char _m11_pad[12];
    float saturation;
    char _m12_pad[12];
    float hueShift;
    char _m13_pad[12];
    float strength;
};

struct refAM35_e8c9b81f88ba0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 rgb2hsv(thread const float3& c)
{
    float4 K = float4(0.0, -0.333333313465118408203125, 0.666666686534881591796875, -1.0);
    float4 p = mix(float4(c.zy, K.wz), float4(c.yz, K.xy), float4(step(c.z, c.y)));
    float4 q = mix(float4(p.xyw, c.x), float4(c.x, p.yzx), float4(step(p.x, c.x)));
    float d = q.x - fast::min(q.w, q.y);
    float e = 1.0000000116860974230803549289703e-07;
    return float3(abs(q.z + ((q.w - q.y) / ((6.0 * d) + e))), d / (q.x + e), q.x);
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.333333313465118408203125, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse8c9b81f88ba0& _178, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _178.refScreen.xy;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 raw = src.xyz;
    float3 col = fast::max(raw, float3(0.0));
    col *= powr(2.0, _178.exposure);
    col = ((col - float3(0.5)) * (1.0 + _178.contrast)) + float3(0.5);
    float lum = dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float shadowMask = 1.0 - smoothstep(0.0, 0.550000011920928955078125, lum);
    float highlightMask = smoothstep(0.449999988079071044921875, 1.0, lum);
    col += (float3(_178.shadows * 0.25) * shadowMask);
    col += (float3(_178.highlights * 0.25) * highlightMask);
    col.x += ((_178.temperature * 0.100000001490116119384765625) - (_178.tint * 0.02500000037252902984619140625));
    col.y += (_178.tint * 0.0500000007450580596923828125);
    col.z -= ((_178.temperature * 0.100000001490116119384765625) + (_178.tint * 0.02500000037252902984619140625));
    float3 param_1 = fast::clamp(col, float3(0.0), float3(1.0));
    float3 hsv = rgb2hsv(param_1);
    hsv.x = fract(hsv.x + (_178.hueShift / 360.0));
    hsv.y = fast::clamp(hsv.y * (1.0 + _178.saturation), 0.0, 1.0);
    float3 param_2 = hsv;
    col = fast::clamp(hsv2rgb(param_2), float3(0.0), float3(1.0));
    referenceColor = float4(mix(raw, col, float3(_178.strength)), src.w);
}

fragment refAM35_e8c9b81f88ba0_out refAM35_e8c9b81f88ba0(constant ReferenceUniformse8c9b81f88ba0& _178 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8c9b81f88ba0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _178, referenceColor);
    bool _336 = any(isnan(referenceColor));
    bool _343;
    if (!_336)
    {
        _343 = any(isinf(referenceColor));
    }
    else
    {
        _343 = _336;
    }
    if (_343)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    out.finalColor = referenceColor;
    return out;
}

