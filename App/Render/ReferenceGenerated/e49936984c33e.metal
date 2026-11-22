// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxhardglitch.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
// gl_FragColor = layerM? newLayer(texColor,fxLuma) : fxLuma;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse49936984c33e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int type;
    char _m6_pad[12];
    float progress;
    char _m7_pad[12];
    float glitchAmplitude;
    char _m8_pad[12];
    float seed;
    char _m9_pad[12];
    float glitchNarrowness;
    char _m10_pad[12];
    float glitchBlockiness;
    char _m11_pad[12];
    float glitchMinimizer;
    char _m12_pad[12];
    float alpha;
    char _m13_pad[12];
    uint rcolor;
    char _m14_pad[12];
    uint gcolor;
    char _m15_pad[12];
    uint bcolor;
};

struct refAM35_e49936984c33e_out
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
float rand(thread const float2& p, constant ReferenceUniformse49936984c33e& _88)
{
    float t = floor(_88.progress * 20.0) / 10.0;
    return fract(sin(dot(p, float2(t * 12.98980045318603515625, t * 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& uv, thread const float& blockiness, constant ReferenceUniformse49936984c33e& _88)
{
    float2 lv = fract(uv);
    float2 id = floor(uv);
    float2 param = id;
    float n1 = rand(param, _88);
    float2 param_1 = id + float2(1.0, 0.0);
    float n2 = rand(param_1, _88);
    float2 param_2 = id + float2(0.0, 1.0);
    float n3 = rand(param_2, _88);
    float2 param_3 = id + float2(1.0);
    float n4 = rand(param_3, _88);
    float2 u = smoothstep(float2(0.0), float2(1.0 + blockiness), lv);
    return mix(mix(n1, n2, u.x), mix(n3, n4, u.x), u.y);
}

static inline __attribute__((always_inline))
float fbm(thread float2& uv, thread int& count, thread const float& blockiness, thread const float& complexity, constant ReferenceUniformse49936984c33e& _88)
{
    float val = 0.0;
    float amp = 0.5;
    while (count != 0)
    {
        float2 param = uv;
        float param_1 = blockiness;
        val += (amp * _noise(param, param_1, _88));
        amp *= 0.5;
        uv *= complexity;
        count--;
    }
    return val;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse49936984c33e& _88, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _88.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 uv = gl_FragCoord.xy / _88.refScreen.xy;
    float aspect = _88.refScreen.x / _88.refScreen.y;
    float2 a = float2(uv.x * aspect, uv.y);
    float2 uv2 = float2(a.x / _88.refScreen.x, exp(a.y));
    float param_1 = _88.seed * 0.01745329983532428741455078125;
    uv2 *= rot2m(param_1);
    float2 param_2 = uv2;
    int param_3 = 4;
    float param_4 = _88.glitchBlockiness;
    float param_5 = _88.glitchNarrowness;
    float _266 = fbm(param_2, param_3, param_4, param_5, _88);
    float shift = _88.glitchAmplitude * powr(_266, _88.glitchMinimizer);
    float colR;
    if (_88.rcolor != 0u)
    {
        float2 param_6 = float2(uv.x + shift, uv.y);
        colR = texture2DCv(refInput, refInputSmplr, param_6).x * (1.0 - shift);
    }
    else
    {
        float2 param_7 = float2(uv.x - shift, uv.y);
        colR = texture2DCv(refInput, refInputSmplr, param_7).x * (1.0 - shift);
    }
    float colG;
    if (_88.gcolor != 0u)
    {
        float2 param_8 = float2(uv.x + shift, uv.y);
        colG = texture2DCv(refInput, refInputSmplr, param_8).y * (1.0 - shift);
    }
    else
    {
        float2 param_9 = float2(uv.x - shift, uv.y);
        colG = texture2DCv(refInput, refInputSmplr, param_9).y * (1.0 - shift);
    }
    float colB;
    if (_88.bcolor != 0u)
    {
        float2 param_10 = float2(uv.x + shift, uv.y);
        colB = texture2DCv(refInput, refInputSmplr, param_10).z * (1.0 - shift);
    }
    else
    {
        float2 param_11 = float2(uv.x - shift, uv.y);
        colB = texture2DCv(refInput, refInputSmplr, param_11).z * (1.0 - shift);
    }
    float3 f = float3(colR, colG, colB);
    float4 result = float4(f, 1.0);
    float4 factor = result * _88.alpha;
    factor *= texColor.w;
    float4 resultfinal = factor + (texColor * (1.0 - factor.w));
    float4 targetLuma = resultfinal;
    float luma = dot(targetLuma.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float lowThresholdB = 0.0040000001899898052215576171875;
    float lowThresholdA = lowThresholdB - 9.9999997473787516355514526367188e-06;
    float highThresholdA = 1.00100004673004150390625;
    float highThresholdB = highThresholdA + 9.9999997473787516355514526367188e-06;
    float lowBlend = smoothstep(lowThresholdA, lowThresholdB, luma);
    float highBlend = 1.0 - smoothstep(highThresholdA, highThresholdB, luma);
    float lumafx = fast::min(lowBlend, highBlend);
    float4 fxLuma = targetLuma * lumafx;
    float4 rfinal;
    if (_88.type == 0)
    {
        rfinal = resultfinal * texColor.w;
    }
    else
    {
        if (_88.type == 1)
        {
            rfinal = fxLuma;
        }
        else
        {
            if (_88.type == 2)
            {
                float4 param_12 = texColor;
                float4 param_13 = fxLuma;
                rfinal = newLayer(param_12, param_13);
            }
        }
    }
    referenceColor = rfinal;
}

fragment refAM35_e49936984c33e_out refAM35_e49936984c33e(constant ReferenceUniformse49936984c33e& _88 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e49936984c33e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_88, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _486 = any(isnan(referenceColor));
    bool _493;
    if (!_486)
    {
        _493 = any(isinf(referenceColor));
    }
    else
    {
        _493 = _486;
    }
    if (_493)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _506 = referenceColor;
    float3 _512 = fast::clamp(_506.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _512.x;
    referenceColor.y = _512.y;
    referenceColor.z = _512.z;
    out.finalColor = referenceColor;
    return out;
}

