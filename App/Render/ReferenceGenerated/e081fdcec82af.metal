// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/Fastadjust++.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse081fdcec82af
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float exposure;
    char _m6_pad[12];
    float gamma;
    char _m7_pad[12];
    float brightness;
    char _m8_pad[12];
    float contrast;
    char _m9_pad[12];
    float shadows;
    char _m10_pad[12];
    float highlights;
    char _m11_pad[12];
    float saturation;
    char _m12_pad[12];
    float vibrance;
    char _m13_pad[12];
    float temperature;
    char _m14_pad[12];
    float tint;
    char _m15_pad[12];
    float hue;
    char _m16_pad[12];
    float redGamma;
    char _m17_pad[12];
    float greenGamma;
    char _m18_pad[12];
    float blueGamma;
};

struct refAM35_e081fdcec82af_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse081fdcec82af& _178, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _178.refScreen.xy;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 col = fast::max(src.xyz, float3(0.0));
    col *= powr(2.0, _178.exposure);
    col = powr(fast::max(col, float3(0.0)), float3(1.0 / fast::max(_178.gamma, 0.001000000047497451305389404296875)));
    col += float3(_178.brightness);
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
    hsv.x = fract(hsv.x + (_178.hue / 360.0));
    float naturalSat = hsv.y;
    float vibMask = 1.0 - naturalSat;
    hsv.y = fast::clamp((naturalSat * (1.0 + _178.saturation)) + ((_178.vibrance * vibMask) * 0.5), 0.0, 1.0);
    float3 param_2 = hsv;
    col = hsv2rgb(param_2);
    col.x = powr(fast::max(col.x, 0.0), 1.0 / fast::max(_178.redGamma, 0.001000000047497451305389404296875));
    col.y = powr(fast::max(col.y, 0.0), 1.0 / fast::max(_178.greenGamma, 0.001000000047497451305389404296875));
    col.z = powr(fast::max(col.z, 0.0), 1.0 / fast::max(_178.blueGamma, 0.001000000047497451305389404296875));
    referenceColor = float4(fast::clamp(col, float3(0.0), float3(1.0)), src.w);
}

fragment refAM35_e081fdcec82af_out refAM35_e081fdcec82af(constant ReferenceUniformse081fdcec82af& _178 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e081fdcec82af_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _178, referenceColor);
    bool _386 = any(isnan(referenceColor));
    bool _393;
    if (!_386)
    {
        _393 = any(isinf(referenceColor));
    }
    else
    {
        _393 = _386;
    }
    if (_393)
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

