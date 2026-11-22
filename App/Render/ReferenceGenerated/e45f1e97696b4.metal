// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxfworks.xml
// Original source comments and attribution:
/////////////////////////
// #define FIREWORKS AMOUNT
// #define BASE_PAUSE FIREWORKS / 60.
// int SPARKS = int(SPARKSS);
/////////////////////////
// normal
// screen
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

struct ReferenceUniformse45f1e97696b4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int blendMode;
    char _m6_pad[8];
    float2 position;
    char _m7_pad[8];
    float progress;
    char _m8_pad[12];
    float orientX;
    char _m9_pad[12];
    float orientY;
    char _m10_pad[12];
    float scale;
    char _m11_pad[12];
    float bright;
    char _m12_pad[12];
    float alpha;
    char _m13_pad[12];
    float AMOUNT;
    char _m14_pad[12];
    float SPARKS;
    char _m15_pad[12];
    uint onecolor;
    float4 color1;
    float4 color2;
};

struct refAM35_e45f1e97696b4_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float n21(thread const float2& n)
{
    return fract(sin(dot(n, float2(12.98980045318603515625, 4.141399860382080078125))) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 rocket(thread const float2& start, thread const float& t)
{
    float y = t;
    float x = sin((y * 10.0) + cos(t * 3.0)) * 0.100000001490116119384765625;
    float2 p = start + float2(x, y * 8.0);
    return p;
}

static inline __attribute__((always_inline))
float2 randomSpark(thread const float& _noise)
{
    float2 v0 = float2((_noise - 0.5) * 13.0, (fract(_noise * 123.0) - 0.5) * 15.0);
    return v0;
}

static inline __attribute__((always_inline))
float2 circularSpark(thread const float& i, thread float& noiseId, thread const float& noiseSpark, constant ReferenceUniformse45f1e97696b4& _91)
{
    noiseId = fract(noiseId * 7897654.5);
    float a = (6.280000209808349609375 / fast::max(abs(_91.SPARKS), 1.0)) * i;
    float speed = 10.0 * fast::clamp(noiseId, 0.699999988079071044921875, 1.0);
    float x = sin(a + (_91.orientX * ((noiseId - 0.5) * 3.0)));
    float y = cos(a + ((_91.orientY * (fract(noiseId * 4567.33203125) - 0.5)) * 2.0));
    float2 v0 = float2(x, y) * speed;
    return v0;
}

static inline __attribute__((always_inline))
float3 firework(thread float2& uv, thread const float& index, thread const float& pauseTime, constant ReferenceUniformse45f1e97696b4& _91)
{
    float3 col = float3(0.0);
    float timeScale = 1.0;
    float2 gravity = float2(0.0, -9.80000019073486328125);
    float explodeTime = 0.89999997615814208984375;
    float rocketTime = 1.10000002384185791015625;
    float episodeTime = (rocketTime + explodeTime) + pauseTime;
    float ratio = _91.refScreen.x / _91.refScreen.y;
    float timeScaled = (_91.progress - pauseTime) / timeScale;
    float id = floor(timeScaled / episodeTime);
    float et = mod(timeScaled, episodeTime);
    float2 param = float2(id + 1.0, index + 1.0);
    float noiseId = n21(param);
    float scale = fast::clamp(fract(noiseId * 567.530029296875) * 30.0, 10.0, 30.0);
    uv *= scale;
    rocketTime -= (fract(noiseId * 1234.54296875) * 0.5);
    float2 param_1 = float2(0.0 + (((noiseId - 0.5) * scale) * ratio), 0.0 - (scale / 2.0));
    float param_2 = fast::clamp(et, 0.0, rocketTime);
    float2 pRocket = rocket(param_1, param_2);
    if (et < rocketTime)
    {
        float rd = length(uv - pRocket);
        col += (float3(0.89999997615814208984375, 0.300000011920928955078125, 0.0) * powr(0.0500000007450580596923828125 / rd, 1.89999997615814208984375));
    }
    bool _278 = et > rocketTime;
    bool _286;
    if (_278)
    {
        _286 = et < (rocketTime + explodeTime);
    }
    else
    {
        _286 = _278;
    }
    if (_286)
    {
        float burst = sign(fract(noiseId * 44432.21875) - 0.60000002384185791015625);
        float2 v0;
        float _391;
        for (int i = 0; i < int(_91.SPARKS); i++)
        {
            float2 center = pRocket;
            float fi = float(i);
            float2 param_3 = float2((id * 10.0) + (index * 20.0), float(i + 1));
            float noiseSpark = fract(n21(param_3) * 332.44000244140625);
            float t = et - rocketTime;
            if (fract(noiseId * 3532.330078125) > 0.5)
            {
                float param_4 = noiseSpark;
                v0 = randomSpark(param_4);
                t -= (noiseSpark * (fract(noiseId * 543.0) * 0.20000000298023223876953125));
            }
            else
            {
                float param_5 = fi;
                float param_6 = noiseId;
                float param_7 = noiseSpark;
                float2 _363 = circularSpark(param_5, param_6, param_7, _91);
                v0 = _363;
                if ((fract(noiseId * 973.219970703125) - 0.5) > 0.0)
                {
                    float re = mod(fi, 4.0 + (10.0 * noiseId));
                    t -= ((floor(re / 2.0) * burst) * 0.100000001490116119384765625);
                }
                else
                {
                    if (mod(fi, 2.0) == 0.0)
                    {
                        _391 = 0.0;
                    }
                    else
                    {
                        _391 = (burst * 0.5) * fast::clamp(noiseId, 0.300000011920928955078125, 1.0);
                    }
                    t -= _391;
                }
            }
            float2 s = (v0 * t) + (((gravity * t) * t) / float2(2.0));
            float2 p = center + s;
            float d = length(uv - p);
            if (t > 0.0)
            {
                float fade = fast::clamp(1.0 - (t / explodeTime), 0.0, 1.0);
                float3 sparkColor = float3(noiseId * 0.89999997615814208984375, 0.5 * fract(noiseId * 456.329986572265625), 0.5 * fract(noiseId * 1456.3299560546875));
                float3 c = sparkColor * (0.0500000007450580596923828125 / d);
                col += (c * fade);
            }
        }
    }
    return col;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse45f1e97696b4& _91, texture2d<float> refImage1, sampler refImage1Smplr, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _91.refScreen.xy;
    float4 texColorX = texture2DCv(refImage1, refImage1Smplr, param);
    float2 param_1 = gl_FragCoord.xy / _91.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
    float2 uv = gl_FragCoord.xy / _91.refScreen.xy;
    uv /= float2(_91.scale);
    uv += ((_91.position * float2(-1.0, 1.0)) / float2(500.0));
    uv -= float2(0.5);
    uv.x *= (_91.refScreen.x / _91.refScreen.y);
    float3 col = float3(0.0);
    for (float i = 0.0; i < _91.AMOUNT; i += 1.0)
    {
        float2 param_2 = uv;
        float param_3 = i + 1.0;
        float param_4 = i * (_91.AMOUNT / 60.0);
        float3 _548 = firework(param_2, param_3, param_4, _91);
        col += _548;
    }
    float4 result = float4(col, 1.0);
    float luminance = dot(result.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 gradmap = mix(_91.color1, _91.color2, float4(luminance)) * result.w;
    float4 factor;
    if (_91.onecolor != 0u)
    {
        factor = mix(texColorX, gradmap, float4(_91.alpha));
    }
    else
    {
        factor = mix(texColorX, result, float4(_91.alpha));
    }
    float4 resultfinal;
    if (_91.blendMode == 0)
    {
        resultfinal = (factor * _91.bright) * texColor.w;
    }
    else
    {
        if (_91.blendMode == 1)
        {
            factor *= _91.bright;
            resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_91.alpha)) * texColor.w;
}

fragment refAM35_e45f1e97696b4_out refAM35_e45f1e97696b4(constant ReferenceUniformse45f1e97696b4& _91 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e45f1e97696b4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_91, refImage1, refImage1Smplr, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _667 = any(isnan(referenceColor));
    bool _674;
    if (!_667)
    {
        _674 = any(isinf(referenceColor));
    }
    else
    {
        _674 = _667;
    }
    if (_674)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _687 = referenceColor;
    float3 _693 = fast::clamp(_687.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _693.x;
    referenceColor.y = _693.y;
    referenceColor.z = _693.z;
    out.finalColor = referenceColor;
    return out;
}

