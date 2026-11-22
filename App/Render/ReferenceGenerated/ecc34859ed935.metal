// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsnewoffsetglitch.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//////////////////////////
/////////////////////////
// if(L2S) { id = l2s(id); }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsecc34859ed935
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint autop;
    char _m6_pad[12];
    uint OFFSIDE;
    char _m7_pad[12];
    float PROGRESS;
    char _m8_pad[12];
    float SPEED;
    char _m9_pad[12];
    float glitchAmplitude;
    char _m10_pad[12];
    float AMOUNT;
    char _m11_pad[12];
    float scale;
    char _m12_pad[8];
    float2 stretch;
    char _m13_pad[8];
    float DISTORT;
    char _m14_pad[12];
    float STEP;
    char _m15_pad[12];
    float glitchNarrowness;
    char _m16_pad[12];
    float glitchBlockiness;
    char _m17_pad[12];
    float glitchMinimizer;
    char _m18_pad[12];
    float alpha;
    char _m19_pad[12];
    uint rcolor;
    char _m20_pad[12];
    uint gcolor;
    char _m21_pad[12];
    uint bcolor;
};

struct refAM35_ecc34859ed935_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float rand(thread const float2& p, constant ReferenceUniformsecc34859ed935& _73)
{
    float _81;
    if (_73.autop != 0u)
    {
        _81 = _73.PROGRESS + (_73.refScreen.z * _73.SPEED);
    }
    else
    {
        _81 = _73.PROGRESS;
    }
    float EVO = _81;
    float t = floor(EVO * 10.0) / 10.0;
    return fract(sin(dot(p, float2(t * 12.98980045318603515625, t * 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& uv, thread const float& blockiness, constant ReferenceUniformsecc34859ed935& _73)
{
    float2 lv = fract(uv);
    float2 id = floor(uv);
    float2 param = id;
    float n1 = rand(param, _73);
    float2 param_1 = id + float2(1.0, 0.0);
    float n2 = rand(param_1, _73);
    float2 param_2 = id + float2(0.0, 1.0);
    float n3 = rand(param_2, _73);
    float2 param_3 = id + float2(1.0);
    float n4 = rand(param_3, _73);
    float2 u = smoothstep(float2(0.0), float2(1.0 + blockiness), lv);
    return mix(mix(n1, n2, u.x), mix(n3, n4, u.x), u.y);
}

static inline __attribute__((always_inline))
float fbm(thread float2& uv, thread int& count, thread const float& blockiness, thread const float& complexity, constant ReferenceUniformsecc34859ed935& _73)
{
    float val = 0.0;
    float amp = 0.5;
    while (count != 0)
    {
        float2 param = uv;
        float param_1 = blockiness;
        val += (amp * _noise(param, param_1, _73));
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
void referenceMain(constant ReferenceUniformsecc34859ed935& _73, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_73.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _73.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_73.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _73.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_73.refScreen.x, _73.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = gl_FragCoord.xy / _73.refScreen.xy;
            float2 uv = syamjaidtz;
            float2 a = float2(uv.x * (iResolution.x / iResolution.y), uv.y);
            float2 uv2 = float2(a.x / iResolution.x, exp(a.y));
            float2 id = floor(uv * _73.AMOUNT);
            float2 scaleVec = float2(_73.scale * _73.stretch.x, _73.scale * _73.stretch.y);
            uv2 /= scaleVec;
            float2 param_3 = id;
            float2 param_4 = uv2;
            int param_5 = int(rand(param_3, _73) * _73.DISTORT);
            float param_6 = _73.glitchBlockiness;
            float param_7 = _73.glitchNarrowness;
            float _340 = fbm(param_4, param_5, param_6, param_7, _73);
            float shift = _73.glitchAmplitude * powr(_340, _73.glitchMinimizer);
            float scanline = abs(cos(uv.y * 400.0));
            scanline = smoothstep(0.0, 2.0, scanline);
            shift = smoothstep(9.9999997473787516355514526367188e-06, _73.STEP, shift);
            float colR;
            if (_73.rcolor != 0u)
            {
                float2 param_8 = float2(uv.x + shift, uv.y);
                colR = texture2DCv(refInput, refInputSmplr, param_8).x * (1.0 - shift);
            }
            else
            {
                float2 param_9 = float2(uv.x - shift, uv.y);
                colR = texture2DCv(refInput, refInputSmplr, param_9).x * (1.0 - shift);
            }
            float colG;
            if (_73.gcolor != 0u)
            {
                float2 param_10 = float2(uv.x + shift, uv.y);
                colG = texture2DCv(refInput, refInputSmplr, param_10).y * (1.0 - shift);
            }
            else
            {
                float2 param_11 = float2(uv.x - shift, uv.y);
                colG = texture2DCv(refInput, refInputSmplr, param_11).y * (1.0 - shift);
            }
            float colB;
            if (_73.bcolor != 0u)
            {
                float2 param_12 = float2(uv.x + shift, uv.y);
                colB = texture2DCv(refInput, refInputSmplr, param_12).z * (1.0 - shift);
            }
            else
            {
                float2 param_13 = float2(uv.x - shift, uv.y);
                colB = texture2DCv(refInput, refInputSmplr, param_13).z * (1.0 - shift);
            }
            float3 f = float3(colR, colG, colB);
            float4 factor = float4(f, texColor.w) * _73.alpha;
            if (_73.OFFSIDE != 0u)
            {
                factor *= texColor.w;
            }
            float4 param_14 = texColor * texColor.w;
            float4 param_15 = factor;
            float4 resultfinal = newLayer(param_14, param_15);
            referenceColor = resultfinal;
        }
    }
}

fragment refAM35_ecc34859ed935_out refAM35_ecc34859ed935(constant ReferenceUniformsecc34859ed935& _73 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ecc34859ed935_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_73, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _508 = any(isnan(referenceColor));
    bool _515;
    if (!_508)
    {
        _515 = any(isinf(referenceColor));
    }
    else
    {
        _515 = _508;
    }
    if (_515)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _528 = referenceColor;
    float3 _534 = fast::clamp(_528.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _534.x;
    referenceColor.y = _534.y;
    referenceColor.z = _534.z;
    out.finalColor = referenceColor;
    return out;
}

