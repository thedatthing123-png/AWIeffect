// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsmokenoise.xml
// Original source comments and attribution:
/////////////////////////
// syamjaidtz += position*vec2(-1.,1.)/500.;
/////////////////////////
// vec2 uv = fragCoord.xy / iResolution.xy;
// vec4 coloring = vec4(color.rgb,1.0) * texColor.a;
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb44607c6a5bb
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color;
    float2 position;
    char _m7_pad[8];
    float lowThreshold;
    char _m8_pad[12];
    float progressd;
    char _m9_pad[12];
    float thick;
    char _m10_pad[12];
    float alpha;
    char _m11_pad[12];
    float angle;
    char _m12_pad[12];
    int blendMode;
};

struct refAM35_eb44607c6a5bb_out
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
float2 sw(thread const float2& p)
{
    return float2(floor(p.x), floor(p.y));
}

static inline __attribute__((always_inline))
float random(thread const float& x)
{
    return fract(sin(x) * 10000.0);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float param = p.x + (p.y * 10000.0);
    return random(param);
}

static inline __attribute__((always_inline))
float2 se(thread const float2& p)
{
    return float2(ceil(p.x), floor(p.y));
}

static inline __attribute__((always_inline))
float2 nw(thread const float2& p)
{
    return float2(floor(p.x), ceil(p.y));
}

static inline __attribute__((always_inline))
float2 ne(thread const float2& p)
{
    return float2(ceil(p.x), ceil(p.y));
}

static inline __attribute__((always_inline))
float smoothNoise(thread const float2& p)
{
    float2 interp = smoothstep(float2(0.0), float2(1.0), fract(p));
    float2 param = p;
    float2 param_1 = sw(param);
    float2 param_2 = p;
    float2 param_3 = se(param_2);
    float s = mix(_noise(param_1), _noise(param_3), interp.x);
    float2 param_4 = p;
    float2 param_5 = nw(param_4);
    float2 param_6 = p;
    float2 param_7 = ne(param_6);
    float n = mix(_noise(param_5), _noise(param_7), interp.x);
    return mix(s, n, interp.y);
}

static inline __attribute__((always_inline))
float fractalNoise(thread const float2& p)
{
    float n = 0.0;
    float2 param = p;
    n += smoothNoise(param);
    float2 param_1 = p * 2.0;
    n += (smoothNoise(param_1) / 2.0);
    float2 param_2 = p * 4.0;
    n += (smoothNoise(param_2) / 4.0);
    float2 param_3 = p * 8.0;
    n += (smoothNoise(param_3) / 8.0);
    float2 param_4 = p * 16.0;
    n += (smoothNoise(param_4) / 16.0);
    n /= 1.9375;
    return n;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseb44607c6a5bb& _243, texture2d<float> refImage1, sampler refImage1Smplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _243.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = gl_FragCoord.xy / _243.refScreen.xy;
    float4 blackTex = texture2DCv(refImage1, refImage1Smplr, param_1);
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _243.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _243.refScreen.xy).y) * _243.refScreen.xy) - float2(_243.refLayer.x + (_243.refLayer.z * 0.5), (_243.refScreen.y - _243.refLayer.y) - (_243.refLayer.w * 0.5))) / _243.refLayer.zw;
    syamjaidtz.y *= (_243.refLayer.w / _243.refLayer.z);
    syamjaidtz /= float2(1.0);
    float param_2 = _243.angle * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_2);
    syamjaidtz += ((float2(0.0 + _243.position.x, (-350.0) + _243.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 uv = syamjaidtz;
    float2 nuv = float2(uv.x - 0.16666667163372039794921875, uv.y);
    uv *= float2(1.0, -1.0);
    float2 param_3 = nuv * _243.progressd;
    float x = fractalNoise(param_3);
    float2 param_4 = uv;
    float3 final = mix(float3(x), texture2DCv(refImage1, refImage1Smplr, param_4).xyz, float3(powr(abs(uv.y), 4.0)));
    float4 result = float4(final, 1.0) * float4(_243.color.xyz, 1.0);
    float4 factorr = (result + (result * _243.thick)) * _243.alpha;
    float4 targetLuma = factorr;
    float luma = dot(targetLuma.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float lowThresholdB = (_243.lowThreshold * 2.0) - 0.001000000047497451305389404296875;
    float lowThresholdA = lowThresholdB - 1.0;
    float highThresholdA = 1.00100004673004150390625;
    float highThresholdB = highThresholdA + 1.0;
    float lowBlend = smoothstep(lowThresholdA, lowThresholdB, luma);
    float highBlend = 1.0 - smoothstep(highThresholdA, highThresholdB, luma);
    float lumafx = fast::min(lowBlend, highBlend);
    float4 factor = targetLuma * lumafx;
    float4 resultfinal;
    if (_243.blendMode == 0)
    {
        factor *= texColor.w;
        float4 param_5 = texColor;
        float4 param_6 = factor;
        resultfinal = newLayer(param_5, param_6) * texColor.w;
    }
    else
    {
        if (_243.blendMode == 1)
        {
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_243.blendMode == 2)
            {
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(1.0)) * texColor.w;
}

fragment refAM35_eb44607c6a5bb_out refAM35_eb44607c6a5bb(constant ReferenceUniformseb44607c6a5bb& _243 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb44607c6a5bb_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _243, refImage1, refImage1Smplr, referenceColor);
    bool _547 = any(isnan(referenceColor));
    bool _554;
    if (!_547)
    {
        _554 = any(isinf(referenceColor));
    }
    else
    {
        _554 = _547;
    }
    if (_554)
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

