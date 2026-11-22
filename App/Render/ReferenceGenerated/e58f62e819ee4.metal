// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxspeedlines.xml
// Original source comments and attribution:
/////////////////////////
//Pseudo-random
//Bilinearly interpolated noise (4 samples)
//Funciton to make the noise continuous while wrapping around angle 
//t : 0->1
//Some continous radial perlin noise
//Impression of speed : stretch noise as the distance increases.
//Time drift (animation)
//Colorize function (transforms BW Intensity to color)
//Red-Yellow Gradient
//While highlights
//Intensity ramp
/////////////////////////
// vec2 uv = 2.2*(fragCoord-0.5*vec2(iResolution.xy))/iResolution.xx;
//Squared distance
//Normalized Angle
//Saturate and offset values
//Intersity ramp from center
//Colorize (palette remap )
// vec4 factor = vec4(0.30,0.30,0.30,1.0) + gradmap;
// gradmap = mix(colorbg,color,luminance)*factora.a;
// vec4 factor = gradmap;
// SOLID
// resultfinal = newLayer(texColor, nx) * texColor.a;
// MASK
// vec4 c = (factora + vec4(1.)*(1.-factora.a));
// resultfinal = vec4((texColor.rgb/texColor.a)*c.rgb,1.0) * texColor.a;
// OUTLINE
// resultfinal = vec4( 1.-((1.-(texColor.rgb/texColor.a))*(1.-factor.rgb)),1.0) * texColor.a;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse58f62e819ee4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int blendMode;
    float4 color;
    float progressa;
    char _m8_pad[12];
    float density;
    char _m9_pad[12];
    float highlight;
    char _m10_pad[12];
    float feather;
    char _m11_pad[12];
    float scalex;
    char _m12_pad[8];
    float2 position;
    char _m13_pad[8];
    float angle;
    char _m14_pad[12];
    float alpha;
};

struct refAM35_e58f62e819ee4_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float rotatedMirror(thread float& t, thread const float& r)
{
    t = fract(t + r);
    return 2.0 * abs(t - 0.5);
}

static inline __attribute__((always_inline))
float hash(thread const float2& p)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
float smoothNoise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i + float2(0.0);
    float a = hash(param);
    float2 param_1 = i + float2(1.0, 0.0);
    float b = hash(param_1);
    float2 param_2 = i + float2(0.0, 1.0);
    float c = hash(param_2);
    float2 param_3 = i + float2(1.0);
    float d = hash(param_3);
    return (((a + ((b - a) * u.x)) + ((c - a) * u.y)) + (((((a - b) - c) + d) * u.x) * u.y)) / 4.0;
}

static inline __attribute__((always_inline))
float radialPerlinNoise(thread const float& t, thread float& d, constant ReferenceUniformse58f62e819ee4& _193)
{
    d = powr(d, 0.00999999977648258209228515625);
    float dOffset = (-floor(_193.progressa * 10.0)) * 0.100000001490116119384765625;
    float param = t;
    float param_1 = 0.100000001490116119384765625;
    float _208 = rotatedMirror(param, param_1);
    float2 p = float2(_208, d + dOffset);
    float2 param_2 = p * 44.200000762939453125;
    float f1 = smoothNoise(param_2);
    float param_3 = t;
    float param_4 = 0.4000000059604644775390625;
    float _224 = rotatedMirror(param_3, param_4);
    p = float2(_224, d + dOffset) * 2.099999904632568359375;
    float2 param_5 = p * 44.200000762939453125;
    float f2 = smoothNoise(param_5);
    float param_6 = t;
    float param_7 = 0.800000011920928955078125;
    float _240 = rotatedMirror(param_6, param_7);
    p = float2(_240, d + dOffset) * 3.7000000476837158203125;
    float2 param_8 = p * 44.200000762939453125;
    float f3 = smoothNoise(param_8);
    float param_9 = t;
    float param_10 = 0.0;
    float _255 = rotatedMirror(param_9, param_10);
    p = float2(_255, d + dOffset) * 5.80000019073486328125;
    float2 param_11 = p * 44.200000762939453125;
    float f4 = smoothNoise(param_11);
    return (((f1 + (0.5 * f2)) + (0.25 * f3)) + (0.125 * f4)) * 3.0;
}

static inline __attribute__((always_inline))
float3 colorize(thread float& f, constant ReferenceUniformse58f62e819ee4& _193)
{
    f = fast::clamp(f * 0.949999988079071044921875, 0.0, 1.0);
    float3 c = mix(float3(0.0), _193.color.xyz, float3(f));
    c = mix(c, float3(1.0), float3((f * 4.0) - 3.0));
    float3 cAttenuated = mix(float3(0.0), c, float3(f + 0.100000001490116119384765625));
    return cAttenuated;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse58f62e819ee4& _193, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _193.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 uv = gl_FragCoord.xy / _193.refScreen.xy;
    uv += ((float2(250.0 + _193.position.x, (-250.0) + _193.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    uv *= (1.7000000476837158203125 * _193.scalex);
    float param_1 = _193.angle * 0.01745329983532428741455078125;
    uv *= rot2m(param_1);
    float d = dot(uv, uv);
    float t = 0.5 + (precise::atan2(uv.y, uv.x) / _193.density);
    float param_2 = t;
    float param_3 = d;
    float _386 = radialPerlinNoise(param_2, param_3, _193);
    float v = _386;
    v = (-2.38000011444091796875) + (v * _193.highlight);
    v = mix(0.0, v, 0.5 * smoothstep(0.300000011920928955078125, 0.3499999940395355224609375 + _193.feather, d));
    float param_4 = v;
    float3 _408 = colorize(param_4, _193);
    float4 result;
    result.x = _408.x;
    result.y = _408.y;
    result.z = _408.z;
    float4 nx = mix(float4(0.0), _193.color, float4(v)) * texColor.w;
    float4 nxx = mix(float4(1.0), _193.color, float4(v)) * texColor.w;
    float4 factora = float4(0.300000011920928955078125, 0.300000011920928955078125, 0.300000011920928955078125, 1.0) + result;
    float luminance = dot(factora.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 resultfinal;
    if (_193.blendMode == 0)
    {
        float4 param_5 = float4(0.0, 0.0, 0.0, 1.0);
        float4 param_6 = nx;
        float4 rrr = newLayer(param_5, param_6) * texColor.w;
        float4 targetLuma = rrr;
        float luma = dot(targetLuma.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        float lowThresholdB = 0.4189999997615814208984375;
        float lowThresholdA = lowThresholdB - 0.0500000007450580596923828125;
        float highThresholdA = 1.00100004673004150390625;
        float highThresholdB = highThresholdA + 0.0500000007450580596923828125;
        float lowBlend = smoothstep(lowThresholdA, lowThresholdB, luma);
        float highBlend = 1.0 - smoothstep(highThresholdA, highThresholdB, luma);
        float lumafx = fast::min(lowBlend, highBlend);
        float4 fxLuma = targetLuma * lumafx;
        float4 param_7 = texColor;
        float4 param_8 = fxLuma;
        resultfinal = newLayer(param_7, param_8) * texColor.w;
    }
    else
    {
        float4 gradmap;
        if (_193.blendMode == 1)
        {
            gradmap = mix(float4(1.0), _193.color, float4(luminance)) * nxx.w;
            float4 factor = gradmap;
            float3 top = texColor.xyz;
            float3 bot = nxx.xyz * texColor.w;
            float3 mx = fast::min(top, bot);
            resultfinal = float4(mx, texColor.w);
        }
        else
        {
            if (_193.blendMode == 2)
            {
                gradmap = mix(float4(0.0, 0.0, 0.0, 1.0), _193.color, float4(luminance)) * factora.w;
                float4 factor_1 = gradmap;
                float3 top_1 = texColor.xyz;
                float3 bot_1 = result.xyz * texColor.w;
                float3 mx_1 = fast::max(top_1, bot_1);
                resultfinal = float4(mx_1, texColor.w);
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_193.alpha)) * texColor.w;
}

fragment refAM35_e58f62e819ee4_out refAM35_e58f62e819ee4(constant ReferenceUniformse58f62e819ee4& _193 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e58f62e819ee4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_193, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _601 = any(isnan(referenceColor));
    bool _608;
    if (!_601)
    {
        _608 = any(isinf(referenceColor));
    }
    else
    {
        _608 = _601;
    }
    if (_608)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _621 = referenceColor;
    float3 _627 = fast::clamp(_621.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _627.x;
    referenceColor.y = _627.y;
    referenceColor.z = _627.z;
    out.finalColor = referenceColor;
    return out;
}

