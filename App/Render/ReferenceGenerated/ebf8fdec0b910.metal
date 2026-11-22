// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/colorgrade.xml
// Original source comments and attribution:
// Utility functions
// Random function for grain
// Apply temperature and tint
// Apply exposure
// Split into shadows, midtones, and highlights
// Apply color wheel tints
// Apply contrast
// Convert to HSV for saturation and vibrance
// Apply saturation
// Apply vibrance (saturation that protects skin tones)
// Convert back to RGB
// Apply film grain
// Apply vignette
// Apply fade
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsebf8fdec0b910
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float EXPOSURE;
    char _m6_pad[12];
    float CONTRAST;
    char _m7_pad[12];
    float SATURATION;
    char _m8_pad[12];
    float VIBRANCE;
    float4 SHADOWS_COLOR;
    float SHADOWS_STRENGTH;
    float4 MIDTONES_COLOR;
    float MIDTONES_STRENGTH;
    float4 HIGHLIGHTS_COLOR;
    float HIGHLIGHTS_STRENGTH;
    char _m15_pad[12];
    float TEMPERATURE;
    char _m16_pad[12];
    float TINT;
    char _m17_pad[12];
    float GRAIN;
    char _m18_pad[12];
    float VIGNETTE;
    char _m19_pad[12];
    float FADE;
};

struct refAM35_ebf8fdec0b910_out
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
    float4 K = float4(0.0, -0.3333333432674407958984375, 0.666666686534881591796875, -1.0);
    float4 p = mix(float4(c.zy, K.wz), float4(c.yz, K.xy), float4(step(c.z, c.y)));
    float4 q = mix(float4(p.xyw, c.x), float4(c.x, p.yzx), float4(step(p.x, c.x)));
    float d = q.x - fast::min(q.w, q.y);
    float e = 1.0000000133514319600180897396058e-10;
    return float3(abs(q.z + ((q.w - q.y) / ((6.0 * d) + e))), d / (q.x + e), q.x);
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
float random(thread const float2& st)
{
    return fract(sin(dot(st, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsebf8fdec0b910& _192, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _192.refScreen.xy;
    float2 param = uv;
    float4 color = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = color.xyz;
    if (_192.TEMPERATURE != 0.0)
    {
        float t = _192.TEMPERATURE * 0.0500000007450580596923828125;
        rgb.x += t;
        rgb.z -= t;
    }
    if (_192.TINT != 0.0)
    {
        float t_1 = _192.TINT * 0.0500000007450580596923828125;
        rgb.y += t_1;
    }
    rgb *= powr(2.0, _192.EXPOSURE);
    float luminance = dot(rgb, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float shadowsMask = 1.0 - smoothstep(0.0, 0.5, luminance);
    float highlightsMask = smoothstep(0.5, 1.0, luminance);
    float midtonesMask = (1.0 - shadowsMask) - highlightsMask;
    float3 shadowsColor = mix(float3(1.0), _192.SHADOWS_COLOR.xyz, float3(_192.SHADOWS_STRENGTH));
    float3 midtonesColor = mix(float3(1.0), _192.MIDTONES_COLOR.xyz, float3(_192.MIDTONES_STRENGTH));
    float3 highlightsColor = mix(float3(1.0), _192.HIGHLIGHTS_COLOR.xyz, float3(_192.HIGHLIGHTS_STRENGTH));
    rgb = (((rgb * shadowsColor) * shadowsMask) + ((rgb * midtonesColor) * midtonesMask)) + ((rgb * highlightsColor) * highlightsMask);
    rgb = mix(float3(0.5), rgb, float3(_192.CONTRAST));
    float3 param_1 = rgb;
    float3 hsv = rgb2hsv(param_1);
    hsv.y *= _192.SATURATION;
    if (_192.VIBRANCE != 0.0)
    {
        float sat = hsv.y;
        hsv.y = mix(sat, powr(sat, 0.25), _192.VIBRANCE);
    }
    float3 param_2 = hsv;
    rgb = hsv2rgb(param_2);
    if (_192.GRAIN > 0.0)
    {
        float2 param_3 = uv * _192.refScreen.z;
        float grain = (random(param_3) * 2.0) - 1.0;
        rgb += float3(grain * _192.GRAIN);
    }
    if (_192.VIGNETTE > 0.0)
    {
        float2 center = uv - float2(0.5);
        float vignette = 1.0 - ((dot(center, center) * 1.5) * _192.VIGNETTE);
        rgb *= fast::clamp(vignette, 0.0, 1.0);
    }
    if (_192.FADE > 0.0)
    {
        rgb = mix(rgb, float3(0.5), float3(_192.FADE));
    }
    referenceColor = float4(rgb, color.w);
}

fragment refAM35_ebf8fdec0b910_out refAM35_ebf8fdec0b910(constant ReferenceUniformsebf8fdec0b910& _192 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ebf8fdec0b910_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _192, refInput, refInputSmplr, referenceColor);
    bool _430 = any(isnan(referenceColor));
    bool _437;
    if (!_430)
    {
        _437 = any(isinf(referenceColor));
    }
    else
    {
        _437 = _430;
    }
    if (_437)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _450 = referenceColor;
    float3 _456 = fast::clamp(_450.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _456.x;
    referenceColor.y = _456.y;
    referenceColor.z = _456.z;
    out.finalColor = referenceColor;
    return out;
}

