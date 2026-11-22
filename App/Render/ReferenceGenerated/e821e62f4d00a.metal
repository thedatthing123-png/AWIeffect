// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/newdisshake.xml
// Original source comments and attribution:

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

struct ReferenceUniformse821e62f4d00a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float dissolveAmt;
    char _m6_pad[12];
    float dissolveSpeed;
    char _m7_pad[12];
    float dissolveCurve;
    char _m8_pad[12];
    float amplitude;
    char _m9_pad[12];
    float frequency;
    char _m10_pad[12];
    float seed;
    char _m11_pad[12];
    float smoothness;
    char _m12_pad[12];
    float xRandAmp;
    char _m13_pad[12];
    float xRandFreq;
    char _m14_pad[12];
    float xWaveAmp;
    char _m15_pad[12];
    float xWaveFreq;
    char _m16_pad[12];
    float xPhase;
    char _m17_pad[12];
    float yRandAmp;
    char _m18_pad[12];
    float yRandFreq;
    char _m19_pad[12];
    float yWaveAmp;
    char _m20_pad[12];
    float yWaveFreq;
    char _m21_pad[12];
    float yPhase;
    char _m22_pad[12];
    float zRandAmp;
    char _m23_pad[12];
    float zRandFreq;
    char _m24_pad[12];
    float zWaveAmp;
    char _m25_pad[12];
    float zWaveFreq;
    char _m26_pad[12];
    float zPhase;
    char _m27_pad[12];
    float tiltRandAmp;
    char _m28_pad[12];
    float tiltRandFreq;
    char _m29_pad[12];
    float tiltWaveAmp;
    char _m30_pad[12];
    float tiltWaveFreq;
    char _m31_pad[12];
    float tiltPhase;
    char _m32_pad[12];
    float redAmp;
    char _m33_pad[12];
    float greenAmp;
    char _m34_pad[12];
    float blueAmp;
    char _m35_pad[12];
    float redPhase;
    char _m36_pad[12];
    float greenPhase;
    char _m37_pad[12];
    float bluePhase;
    char _m38_pad[12];
    float rgbRandomness;
    char _m39_pad[12];
    float rgbFrequency;
    char _m40_pad[12];
    int edgeMode;
    char _m41_pad[12];
    float globalMix;
};

struct refAM35_e821e62f4d00a_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

static inline __attribute__((always_inline))
float smoothNoise(thread const float& t, thread const float& s)
{
    float i = floor(t);
    float f = fract(t);
    float param = i + s;
    float a = hash(param);
    float param_1 = (i + 1.0) + s;
    float b = hash(param_1);
    float param_2 = (i + 2.0) + s;
    float c = hash(param_2);
    float param_3 = (i + 3.0) + s;
    float d = hash(param_3);
    float f2 = f * f;
    float f3 = f2 * f;
    float cr0 = ((((-0.5) * a) + (1.5 * b)) - (1.5 * c)) + (0.5 * d);
    float cr1 = ((a - (2.5 * b)) + (2.0 * c)) - (0.5 * d);
    float cr2 = ((-0.5) * a) + (0.5 * c);
    float cr3 = b;
    return (((cr0 * f3) + (cr1 * f2)) + (cr2 * f)) + cr3;
}

static inline __attribute__((always_inline))
float layeredNoise(thread const float& t, thread const float& s, thread const float& smooth_amt)
{
    float n = 0.0;
    float amp = 1.0;
    float totalAmp = 0.0;
    float freq = 1.0;
    int layers = 4;
    for (int i = 0; i < 4; i++)
    {
        float fi = float(i);
        float layerSeed = s + (fi * 17.3099994659423828125);
        float param = t * freq;
        float param_1 = layerSeed;
        float rawNoise = (smoothNoise(param, param_1) * 2.0) - 1.0;
        n += (rawNoise * amp);
        totalAmp += amp;
        amp *= mix(0.60000002384185791015625, 0.300000011920928955078125, smooth_amt);
        freq *= mix(2.099999904632568359375, 1.7000000476837158203125, smooth_amt);
    }
    return n / fast::max(totalAmp, 9.9999997473787516355514526367188e-06);
}

static inline __attribute__((always_inline))
float getRandomShake(thread const float& time, thread const float& freq, thread const float& phase, thread const float& seedOffset, thread const float& smooth_amt, constant ReferenceUniformse821e62f4d00a& _261)
{
    float t = (time + phase) * freq;
    float s = _261.seed + seedOffset;
    float param = t;
    float param_1 = s;
    float param_2 = smooth_amt;
    return layeredNoise(param, param_1, param_2);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float getWaveShake(thread const float& time, thread const float& freq, thread const float& phase)
{
    return sin((((time + phase) * freq) * 2.0) * 3.1415927410125732421875);
}

static inline __attribute__((always_inline))
float getShakeAxis(thread const float& time, thread const float& masterAmp, thread const float& masterFreq, thread const float& randAmp, thread const float& randFreq, thread const float& waveAmp, thread const float& waveFreq, thread const float& phase, thread const float& seedOff, constant ReferenceUniformse821e62f4d00a& _261)
{
    float result = 0.0;
    if (randAmp > 9.9999997473787516355514526367188e-06)
    {
        float param = time;
        float param_1 = masterFreq * randFreq;
        float param_2 = phase;
        float param_3 = seedOff;
        float param_4 = _261.smoothness;
        float rnd = getRandomShake(param, param_1, param_2, param_3, param_4, _261);
        result += (rnd * randAmp);
    }
    if (waveAmp > 9.9999997473787516355514526367188e-06)
    {
        float param_5 = time;
        float param_6 = waveFreq;
        float param_7 = phase;
        float wav = getWaveShake(param_5, param_6, param_7);
        result += (wav * waveAmp);
    }
    return result * masterAmp;
}

static inline __attribute__((always_inline))
float2 applyShakeToUV(thread const float2& uv, thread const float& time, thread const float& channelAmp, thread const float& channelPhase, thread const float& rgbRandX, thread const float& rgbRandY, thread const float& rgbRandZ, thread const float& rgbRandTilt, constant ReferenceUniformse821e62f4d00a& _261)
{
    float t = time + (channelPhase * 0.100000001490116119384765625);
    float param = t;
    float param_1 = _261.amplitude;
    float param_2 = _261.frequency;
    float param_3 = _261.xRandAmp;
    float param_4 = _261.xRandFreq;
    float param_5 = _261.xWaveAmp;
    float param_6 = _261.xWaveFreq;
    float param_7 = _261.xPhase;
    float param_8 = 0.0;
    float shakeX = getShakeAxis(param, param_1, param_2, param_3, param_4, param_5, param_6, param_7, param_8, _261);
    float param_9 = t;
    float param_10 = _261.amplitude;
    float param_11 = _261.frequency;
    float param_12 = _261.yRandAmp;
    float param_13 = _261.yRandFreq;
    float param_14 = _261.yWaveAmp;
    float param_15 = _261.yWaveFreq;
    float param_16 = _261.yPhase;
    float param_17 = 100.0;
    float shakeY = getShakeAxis(param_9, param_10, param_11, param_12, param_13, param_14, param_15, param_16, param_17, _261);
    float param_18 = t;
    float param_19 = _261.amplitude;
    float param_20 = _261.frequency;
    float param_21 = _261.zRandAmp;
    float param_22 = _261.zRandFreq;
    float param_23 = _261.zWaveAmp;
    float param_24 = _261.zWaveFreq;
    float param_25 = _261.zPhase;
    float param_26 = 200.0;
    float shakeZ = getShakeAxis(param_18, param_19, param_20, param_21, param_22, param_23, param_24, param_25, param_26, _261);
    float param_27 = t;
    float param_28 = _261.amplitude;
    float param_29 = _261.frequency;
    float param_30 = _261.tiltRandAmp;
    float param_31 = _261.tiltRandFreq;
    float param_32 = _261.tiltWaveAmp;
    float param_33 = _261.tiltWaveFreq;
    float param_34 = _261.tiltPhase;
    float param_35 = 300.0;
    float shakeTilt = getShakeAxis(param_27, param_28, param_29, param_30, param_31, param_32, param_33, param_34, param_35, _261);
    shakeX += rgbRandX;
    shakeY += rgbRandY;
    shakeZ += rgbRandZ;
    shakeTilt += rgbRandTilt;
    shakeX *= channelAmp;
    shakeY *= channelAmp;
    shakeZ *= channelAmp;
    shakeTilt *= channelAmp;
    float2 center = float2(0.5);
    float2 result = uv - center;
    float tiltRad = (shakeTilt * 3.1415927410125732421875) / 180.0;
    float cs = cos(tiltRad);
    float sn = sin(tiltRad);
    result = float2((result.x * cs) - (result.y * sn), (result.x * sn) + (result.y * cs));
    float zoomFactor = 1.0 / fast::max(1.0 + shakeZ, 0.100000001490116119384765625);
    result *= zoomFactor;
    result += center;
    result.x += (shakeX * 0.00999999977648258209228515625);
    result.y += (shakeY * 0.00999999977648258209228515625);
    return result;
}

static inline __attribute__((always_inline))
float2 applyEdge(thread const float2& uv, thread const float& mode)
{
    if (mode < 1.5)
    {
        return uv;
    }
    else
    {
        if (mode < 2.5)
        {
            return fract(uv);
        }
        else
        {
            float2 r = uv;
            float _360;
            if (mod(floor(r.x), 2.0) == 0.0)
            {
                _360 = fract(r.x);
            }
            else
            {
                _360 = 1.0 - fract(r.x);
            }
            r.x = _360;
            float _379;
            if (mod(floor(r.y), 2.0) == 0.0)
            {
                _379 = fract(r.y);
            }
            else
            {
                _379 = 1.0 - fract(r.y);
            }
            r.y = _379;
            return r;
        }
    }
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse821e62f4d00a& _261, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _261.refScreen.xy;
    float t = _261.refScreen.z;
    float em = float(_261.edgeMode);
    float rgbRandXR = 0.0;
    float rgbRandYR = 0.0;
    float rgbRandZR = 0.0;
    float rgbRandTiltR = 0.0;
    float rgbRandXG = 0.0;
    float rgbRandYG = 0.0;
    float rgbRandZG = 0.0;
    float rgbRandTiltG = 0.0;
    float rgbRandXB = 0.0;
    float rgbRandYB = 0.0;
    float rgbRandZB = 0.0;
    float rgbRandTiltB = 0.0;
    if (_261.rgbRandomness > 9.9999997473787516355514526367188e-06)
    {
        float rt = t * _261.rgbFrequency;
        float param = rt;
        float param_1 = 1.0;
        float param_2 = 0.0;
        float param_3 = 400.0;
        float param_4 = _261.smoothness;
        rgbRandXR = (((getRandomShake(param, param_1, param_2, param_3, param_4, _261) * _261.rgbRandomness) * _261.xRandAmp) * _261.amplitude) * 0.00999999977648258209228515625;
        float param_5 = rt;
        float param_6 = 1.0;
        float param_7 = 0.0;
        float param_8 = 410.0;
        float param_9 = _261.smoothness;
        rgbRandYR = (((getRandomShake(param_5, param_6, param_7, param_8, param_9, _261) * _261.rgbRandomness) * _261.yRandAmp) * _261.amplitude) * 0.00999999977648258209228515625;
        float param_10 = rt;
        float param_11 = 1.0;
        float param_12 = 0.0;
        float param_13 = 420.0;
        float param_14 = _261.smoothness;
        rgbRandZR = ((getRandomShake(param_10, param_11, param_12, param_13, param_14, _261) * _261.rgbRandomness) * _261.zRandAmp) * _261.amplitude;
        float param_15 = rt;
        float param_16 = 1.0;
        float param_17 = 0.0;
        float param_18 = 430.0;
        float param_19 = _261.smoothness;
        rgbRandTiltR = ((getRandomShake(param_15, param_16, param_17, param_18, param_19, _261) * _261.rgbRandomness) * _261.tiltRandAmp) * _261.amplitude;
        float param_20 = rt;
        float param_21 = 1.0;
        float param_22 = 0.0;
        float param_23 = 500.0;
        float param_24 = _261.smoothness;
        rgbRandXG = (((getRandomShake(param_20, param_21, param_22, param_23, param_24, _261) * _261.rgbRandomness) * _261.xRandAmp) * _261.amplitude) * 0.00999999977648258209228515625;
        float param_25 = rt;
        float param_26 = 1.0;
        float param_27 = 0.0;
        float param_28 = 510.0;
        float param_29 = _261.smoothness;
        rgbRandYG = (((getRandomShake(param_25, param_26, param_27, param_28, param_29, _261) * _261.rgbRandomness) * _261.yRandAmp) * _261.amplitude) * 0.00999999977648258209228515625;
        float param_30 = rt;
        float param_31 = 1.0;
        float param_32 = 0.0;
        float param_33 = 520.0;
        float param_34 = _261.smoothness;
        rgbRandZG = ((getRandomShake(param_30, param_31, param_32, param_33, param_34, _261) * _261.rgbRandomness) * _261.zRandAmp) * _261.amplitude;
        float param_35 = rt;
        float param_36 = 1.0;
        float param_37 = 0.0;
        float param_38 = 530.0;
        float param_39 = _261.smoothness;
        rgbRandTiltG = ((getRandomShake(param_35, param_36, param_37, param_38, param_39, _261) * _261.rgbRandomness) * _261.tiltRandAmp) * _261.amplitude;
        float param_40 = rt;
        float param_41 = 1.0;
        float param_42 = 0.0;
        float param_43 = 600.0;
        float param_44 = _261.smoothness;
        rgbRandXB = (((getRandomShake(param_40, param_41, param_42, param_43, param_44, _261) * _261.rgbRandomness) * _261.xRandAmp) * _261.amplitude) * 0.00999999977648258209228515625;
        float param_45 = rt;
        float param_46 = 1.0;
        float param_47 = 0.0;
        float param_48 = 610.0;
        float param_49 = _261.smoothness;
        rgbRandYB = (((getRandomShake(param_45, param_46, param_47, param_48, param_49, _261) * _261.rgbRandomness) * _261.yRandAmp) * _261.amplitude) * 0.00999999977648258209228515625;
        float param_50 = rt;
        float param_51 = 1.0;
        float param_52 = 0.0;
        float param_53 = 620.0;
        float param_54 = _261.smoothness;
        rgbRandZB = ((getRandomShake(param_50, param_51, param_52, param_53, param_54, _261) * _261.rgbRandomness) * _261.zRandAmp) * _261.amplitude;
        float param_55 = rt;
        float param_56 = 1.0;
        float param_57 = 0.0;
        float param_58 = 630.0;
        float param_59 = _261.smoothness;
        rgbRandTiltB = ((getRandomShake(param_55, param_56, param_57, param_58, param_59, _261) * _261.rgbRandomness) * _261.tiltRandAmp) * _261.amplitude;
    }
    bool _902 = abs(_261.redAmp - 1.0) > 9.9999997473787516355514526367188e-06;
    bool _912;
    if (!_902)
    {
        _912 = abs(_261.greenAmp - 1.0) > 9.9999997473787516355514526367188e-06;
    }
    else
    {
        _912 = _902;
    }
    bool _922;
    if (!_912)
    {
        _922 = abs(_261.blueAmp - 1.0) > 9.9999997473787516355514526367188e-06;
    }
    else
    {
        _922 = _912;
    }
    bool _931;
    if (!_922)
    {
        _931 = abs(_261.redPhase) > 9.9999997473787516355514526367188e-06;
    }
    else
    {
        _931 = _922;
    }
    bool _940;
    if (!_931)
    {
        _940 = abs(_261.greenPhase) > 9.9999997473787516355514526367188e-06;
    }
    else
    {
        _940 = _931;
    }
    bool _949;
    if (!_940)
    {
        _949 = abs(_261.bluePhase) > 9.9999997473787516355514526367188e-06;
    }
    else
    {
        _949 = _940;
    }
    bool _956;
    if (!_949)
    {
        _956 = _261.rgbRandomness > 9.9999997473787516355514526367188e-06;
    }
    else
    {
        _956 = _949;
    }
    bool needsSeparation = _956;
    float2 param_60 = uv;
    float4 original = texture2DCv(refInput, refInputSmplr, param_60);
    float3 fin;
    if (needsSeparation)
    {
        float2 param_61 = uv;
        float param_62 = t;
        float param_63 = _261.redAmp;
        float param_64 = _261.redPhase;
        float param_65 = rgbRandXR;
        float param_66 = rgbRandYR;
        float param_67 = rgbRandZR;
        float param_68 = rgbRandTiltR;
        float2 uvR = applyShakeToUV(param_61, param_62, param_63, param_64, param_65, param_66, param_67, param_68, _261);
        float2 param_69 = uv;
        float param_70 = t;
        float param_71 = _261.greenAmp;
        float param_72 = _261.greenPhase;
        float param_73 = rgbRandXG;
        float param_74 = rgbRandYG;
        float param_75 = rgbRandZG;
        float param_76 = rgbRandTiltG;
        float2 uvG = applyShakeToUV(param_69, param_70, param_71, param_72, param_73, param_74, param_75, param_76, _261);
        float2 param_77 = uv;
        float param_78 = t;
        float param_79 = _261.blueAmp;
        float param_80 = _261.bluePhase;
        float param_81 = rgbRandXB;
        float param_82 = rgbRandYB;
        float param_83 = rgbRandZB;
        float param_84 = rgbRandTiltB;
        float2 uvB = applyShakeToUV(param_77, param_78, param_79, param_80, param_81, param_82, param_83, param_84, _261);
        float2 param_85 = uvR;
        float param_86 = em;
        uvR = applyEdge(param_85, param_86);
        float2 param_87 = uvG;
        float param_88 = em;
        uvG = applyEdge(param_87, param_88);
        float2 param_89 = uvB;
        float param_90 = em;
        uvB = applyEdge(param_89, param_90);
        float outR = 1.0;
        float outG = 1.0;
        float outB = 1.0;
        if (em < 1.5)
        {
            bool _1050 = uvR.x < 0.0;
            bool _1057;
            if (!_1050)
            {
                _1057 = uvR.x > 1.0;
            }
            else
            {
                _1057 = _1050;
            }
            bool _1064;
            if (!_1057)
            {
                _1064 = uvR.y < 0.0;
            }
            else
            {
                _1064 = _1057;
            }
            bool _1071;
            if (!_1064)
            {
                _1071 = uvR.y > 1.0;
            }
            else
            {
                _1071 = _1064;
            }
            outR = _1071 ? 0.0 : 1.0;
            bool _1075 = uvG.x < 0.0;
            bool _1082;
            if (!_1075)
            {
                _1082 = uvG.x > 1.0;
            }
            else
            {
                _1082 = _1075;
            }
            bool _1089;
            if (!_1082)
            {
                _1089 = uvG.y < 0.0;
            }
            else
            {
                _1089 = _1082;
            }
            bool _1096;
            if (!_1089)
            {
                _1096 = uvG.y > 1.0;
            }
            else
            {
                _1096 = _1089;
            }
            outG = _1096 ? 0.0 : 1.0;
            bool _1100 = uvB.x < 0.0;
            bool _1107;
            if (!_1100)
            {
                _1107 = uvB.x > 1.0;
            }
            else
            {
                _1107 = _1100;
            }
            bool _1114;
            if (!_1107)
            {
                _1114 = uvB.y < 0.0;
            }
            else
            {
                _1114 = _1107;
            }
            bool _1121;
            if (!_1114)
            {
                _1121 = uvB.y > 1.0;
            }
            else
            {
                _1121 = _1114;
            }
            outB = _1121 ? 0.0 : 1.0;
        }
        uvR = fast::clamp(uvR, float2(0.0), float2(1.0));
        uvG = fast::clamp(uvG, float2(0.0), float2(1.0));
        uvB = fast::clamp(uvB, float2(0.0), float2(1.0));
        float2 param_91 = uvR;
        float r = texture2DCv(refInput, refInputSmplr, param_91).x * outR;
        float2 param_92 = uvG;
        float g = texture2DCv(refInput, refInputSmplr, param_92).y * outG;
        float2 param_93 = uvB;
        float b = texture2DCv(refInput, refInputSmplr, param_93).z * outB;
        fin = float3(r, g, b);
    }
    else
    {
        float2 param_94 = uv;
        float param_95 = t;
        float param_96 = 1.0;
        float param_97 = 0.0;
        float param_98 = 0.0;
        float param_99 = 0.0;
        float param_100 = 0.0;
        float param_101 = 0.0;
        float2 shakenUV = applyShakeToUV(param_94, param_95, param_96, param_97, param_98, param_99, param_100, param_101, _261);
        float outBounds = 1.0;
        if (em < 1.5)
        {
            bool _1183 = shakenUV.x < 0.0;
            bool _1190;
            if (!_1183)
            {
                _1190 = shakenUV.x > 1.0;
            }
            else
            {
                _1190 = _1183;
            }
            bool _1197;
            if (!_1190)
            {
                _1197 = shakenUV.y < 0.0;
            }
            else
            {
                _1197 = _1190;
            }
            bool _1204;
            if (!_1197)
            {
                _1204 = shakenUV.y > 1.0;
            }
            else
            {
                _1204 = _1197;
            }
            outBounds = _1204 ? 0.0 : 1.0;
        }
        float2 param_102 = shakenUV;
        float param_103 = em;
        shakenUV = applyEdge(param_102, param_103);
        shakenUV = fast::clamp(shakenUV, float2(0.0), float2(1.0));
        float2 param_104 = shakenUV;
        fin = texture2DCv(refInput, refInputSmplr, param_104).xyz * outBounds;
    }
    float dissolve = 1.0;
    if (_261.dissolveAmt > 9.9999997473787516355514526367188e-06)
    {
        float dRaw = _261.dissolveAmt;
        float dSpeed = _261.dissolveSpeed;
        float dCentered = (dRaw - 0.5) * dSpeed;
        dCentered = fast::clamp(dCentered + 0.5, 0.0, 1.0);
        dissolve = 1.0 - powr(dCentered, _261.dissolveCurve);
    }
    fin *= dissolve;
    float finalAlpha = original.w * dissolve;
    fin = mix(original.xyz, fin, float3(_261.globalMix));
    finalAlpha = mix(original.w, finalAlpha, _261.globalMix);
    fin = fast::clamp(fin, float3(0.0), float3(1.0));
    referenceColor = float4(fin, finalAlpha);
}

fragment refAM35_e821e62f4d00a_out refAM35_e821e62f4d00a(constant ReferenceUniformse821e62f4d00a& _261 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e821e62f4d00a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_261, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1289 = any(isnan(referenceColor));
    bool _1296;
    if (!_1289)
    {
        _1296 = any(isinf(referenceColor));
    }
    else
    {
        _1296 = _1289;
    }
    if (_1296)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1309 = referenceColor;
    float3 _1315 = fast::clamp(_1309.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1315.x;
    referenceColor.y = _1315.y;
    referenceColor.z = _1315.z;
    out.finalColor = referenceColor;
    return out;
}

