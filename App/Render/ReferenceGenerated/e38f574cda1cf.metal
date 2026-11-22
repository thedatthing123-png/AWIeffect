// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/poseshake.xml
// Original source comments and attribution:
// Normal — no modification
// Handheld — organic drift + micro jitter + breathing
// Earthquake — heavy low freq rumble + sharp spikes
// Whip — fast directional snap
// Bounce — spring-like oscillation
// Jitter — fast random micro-snaps
// Drift — very slow organic wander
// Punch — single hit that decays
// Calculate X offset
// Calculate Y offset
// Apply shake mode
// Apply spring physics
// Apply envelope
// Apply global angle rotation
// Apply offset to UV
// Edge handling
// Sample
// Mix
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

struct ReferenceUniformse38f574cda1cf
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amplitude;
    char _m6_pad[12];
    float frequency;
    char _m7_pad[12];
    float seed;
    char _m8_pad[12];
    float smoothness;
    char _m9_pad[12];
    float globalAngle;
    char _m10_pad[12];
    int shakeMode;
    char _m11_pad[12];
    float modeIntensity;
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
    float xBias;
    char _m18_pad[12];
    float yRandAmp;
    char _m19_pad[12];
    float yRandFreq;
    char _m20_pad[12];
    float yWaveAmp;
    char _m21_pad[12];
    float yWaveFreq;
    char _m22_pad[12];
    float yPhase;
    char _m23_pad[12];
    float yBias;
    char _m24_pad[12];
    float decayAmount;
    char _m25_pad[12];
    float decaySpeed;
    char _m26_pad[12];
    float rampAmount;
    char _m27_pad[12];
    float rampSpeed;
    char _m28_pad[12];
    float lowFreqAmp;
    char _m29_pad[12];
    float midFreqAmp;
    char _m30_pad[12];
    float highFreqAmp;
    char _m31_pad[12];
    float springTension;
    char _m32_pad[12];
    float springDamping;
    char _m33_pad[12];
    float springMass;
    char _m34_pad[12];
    int edgeMode;
    char _m35_pad[12];
    float globalMix;
};

struct refAM35_e38f574cda1cf_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float getEnvelope(thread const float& time, constant ReferenceUniformse38f574cda1cf& _222)
{
    float env = 1.0;
    if (_222.decayAmount > 9.9999997473787516355514526367188e-06)
    {
        env *= mix(1.0, exp((-time) * _222.decaySpeed), _222.decayAmount);
    }
    if (_222.rampAmount > 9.9999997473787516355514526367188e-06)
    {
        env *= mix(1.0, 1.0 - exp((-time) * _222.rampSpeed), _222.rampAmount);
    }
    return fast::clamp(env, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float hash(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

static inline __attribute__((always_inline))
float catmullRom(thread const float& t, thread const float& s)
{
    float i = floor(t);
    float f = fract(t);
    float param = (i - 1.0) + s;
    float a = hash(param);
    float param_1 = i + s;
    float b = hash(param_1);
    float param_2 = (i + 1.0) + s;
    float c = hash(param_2);
    float param_3 = (i + 2.0) + s;
    float d = hash(param_3);
    float f2 = f * f;
    float f3 = f2 * f;
    return ((((((((-0.5) * a) + (1.5 * b)) - (1.5 * c)) + (0.5 * d)) * f3) + ((((a - (2.5 * b)) + (2.0 * c)) - (0.5 * d)) * f2)) + ((((-0.5) * a) + (0.5 * c)) * f)) + b;
}

static inline __attribute__((always_inline))
float bandedNoise(thread const float& t, thread const float& s, thread const float& sm, constant ReferenceUniformse38f574cda1cf& _222)
{
    float param = t * 0.699999988079071044921875;
    float param_1 = s;
    float low = (catmullRom(param, param_1) * 2.0) - 1.0;
    float param_2 = t * 2.099999904632568359375;
    float param_3 = s + 50.0;
    float mid = (catmullRom(param_2, param_3) * 2.0) - 1.0;
    float param_4 = t * 5.30000019073486328125;
    float param_5 = s + 100.0;
    float hi1 = (catmullRom(param_4, param_5) * 2.0) - 1.0;
    float param_6 = t * 11.69999980926513671875;
    float param_7 = s + 150.0;
    float hi2 = (catmullRom(param_6, param_7) * 2.0) - 1.0;
    float hiBlend = mix(hi1, hi2, 0.5) * mix(0.300000011920928955078125, 0.1500000059604644775390625, sm);
    return ((low * _222.lowFreqAmp) + ((mid * _222.midFreqAmp) * mix(0.5, 0.300000011920928955078125, sm))) + (hiBlend * _222.highFreqAmp);
}

static inline __attribute__((always_inline))
float getRand(thread const float& time, thread const float& freq, thread const float& ph, thread const float& seedOff, constant ReferenceUniformse38f574cda1cf& _222)
{
    float t = (time + ph) * freq;
    float s = _222.seed + seedOff;
    float param = t;
    float param_1 = s;
    float param_2 = _222.smoothness;
    return bandedNoise(param, param_1, param_2, _222);
}

static inline __attribute__((always_inline))
float getWave(thread const float& time, thread const float& freq, thread const float& ph)
{
    return sin((((time + ph) * freq) * 2.0) * 3.1415927410125732421875);
}

static inline __attribute__((always_inline))
float2 applyMode(thread float2& offset, thread const float& time, constant ReferenceUniformse38f574cda1cf& _222)
{
    float md = float(_222.shakeMode);
    float mi = _222.modeIntensity;
    if (md < 1.5)
    {
        return offset;
    }
    if (md < 2.5)
    {
        float param = time * 0.300000011920928955078125;
        float param_1 = _222.seed + 700.0;
        float driftX = (catmullRom(param, param_1) * 2.0) - 1.0;
        float param_2 = time * 0.25;
        float param_3 = _222.seed + 710.0;
        float driftY = (catmullRom(param_2, param_3) * 2.0) - 1.0;
        float param_4 = time * 8.0;
        float param_5 = _222.seed + 720.0;
        float microX = (catmullRom(param_4, param_5) * 2.0) - 1.0;
        float param_6 = time * 7.5;
        float param_7 = _222.seed + 730.0;
        float microY = (catmullRom(param_6, param_7) * 2.0) - 1.0;
        float breathX = sin((time * 0.800000011920928955078125) * 3.1415927410125732421875) * 0.07999999821186065673828125;
        float breathY = cos((time * 0.60000002384185791015625) * 3.1415927410125732421875) * 0.0599999986588954925537109375;
        offset.x = (offset.x * 0.5) + ((((((driftX * 0.300000011920928955078125) + (microX * 0.07999999821186065673828125)) + breathX) * mi) * _222.amplitude) * 0.00999999977648258209228515625);
        offset.y = (offset.y * 0.5) + ((((((driftY * 0.300000011920928955078125) + (microY * 0.07999999821186065673828125)) + breathY) * mi) * _222.amplitude) * 0.00999999977648258209228515625);
        return offset;
    }
    if (md < 3.5)
    {
        float param_8 = time * 1.5;
        float param_9 = _222.seed + 800.0;
        float rumbleX = (catmullRom(param_8, param_9) * 2.0) - 1.0;
        float param_10 = time * 1.2999999523162841796875;
        float param_11 = _222.seed + 810.0;
        float rumbleY = (catmullRom(param_10, param_11) * 2.0) - 1.0;
        float param_12 = time * 12.0;
        float param_13 = _222.seed + 820.0;
        float spikeX = (catmullRom(param_12, param_13) * 2.0) - 1.0;
        float param_14 = time * 11.0;
        float param_15 = _222.seed + 830.0;
        float spikeY = (catmullRom(param_14, param_15) * 2.0) - 1.0;
        spikeX = (spikeX * spikeX) * sign(spikeX);
        spikeY = (spikeY * spikeY) * sign(spikeY);
        offset.x = (offset.x * (1.0 + (mi * 0.5))) + (((((rumbleX * 0.4000000059604644775390625) + (spikeX * 0.1500000059604644775390625)) * mi) * _222.amplitude) * 0.00999999977648258209228515625);
        offset.y = (offset.y * (1.0 + (mi * 0.5))) + (((((rumbleY * 0.4000000059604644775390625) + (spikeY * 0.1500000059604644775390625)) * mi) * _222.amplitude) * 0.00999999977648258209228515625);
        return offset;
    }
    if (md < 4.5)
    {
        float whipBase = sin(((time * _222.frequency) * 3.1415927410125732421875) * 2.0);
        float whipSnap = powr(abs(whipBase), 3.0) * sign(whipBase);
        float param_16 = time * 6.0;
        float param_17 = _222.seed + 900.0;
        float whipNoiseX = (catmullRom(param_16, param_17) * 2.0) - 1.0;
        float param_18 = time * 5.5;
        float param_19 = _222.seed + 910.0;
        float whipNoiseY = (catmullRom(param_18, param_19) * 2.0) - 1.0;
        float angle = (_222.globalAngle * 3.1415927410125732421875) / 180.0;
        float whipX = (whipSnap * cos(angle)) + (whipNoiseX * 0.20000000298023223876953125);
        float whipY = (whipSnap * sin(angle)) + (whipNoiseY * 0.20000000298023223876953125);
        offset.x = ((whipX * mi) * _222.amplitude) * 0.014999999664723873138427734375;
        offset.y = ((whipY * mi) * _222.amplitude) * 0.014999999664723873138427734375;
        return offset;
    }
    if (md < 5.5)
    {
        float bounceT = (time * _222.frequency) * 1.5;
        float bounceX = abs(sin(bounceT * 3.1415927410125732421875)) * exp((-bounceT) * 0.300000011920928955078125);
        float bounceY = abs(sin(((bounceT * 3.1415927410125732421875) * 0.800000011920928955078125) + 0.5)) * exp((-bounceT) * 0.3499999940395355224609375);
        float dirX = (mod(floor(bounceT), 2.0) == 0.0) ? 1.0 : (-1.0);
        float dirY = (mod(floor(bounceT * 0.800000011920928955078125), 2.0) == 0.0) ? 1.0 : (-1.0);
        float param_20 = time * 4.0;
        float param_21 = _222.seed + 1000.0;
        float bnX = (catmullRom(param_20, param_21) * 2.0) - 1.0;
        float param_22 = time * 3.5;
        float param_23 = _222.seed + 1010.0;
        float bnY = (catmullRom(param_22, param_23) * 2.0) - 1.0;
        offset.x = ((((bounceX * dirX) * mi) + ((bnX * 0.100000001490116119384765625) * mi)) * _222.amplitude) * 0.00999999977648258209228515625;
        offset.y = ((((bounceY * dirY) * mi) + ((bnY * 0.100000001490116119384765625) * mi)) * _222.amplitude) * 0.00999999977648258209228515625;
        return offset;
    }
    if (md < 6.5)
    {
        float param_24 = (floor((time * _222.frequency) * 3.0) + _222.seed) + 1100.0;
        float jitX = (hash(param_24) * 2.0) - 1.0;
        float param_25 = (floor((time * _222.frequency) * 2.7999999523162841796875) + _222.seed) + 1110.0;
        float jitY = (hash(param_25) * 2.0) - 1.0;
        float param_26 = time * 15.0;
        float param_27 = _222.seed + 1120.0;
        float smooth1 = (catmullRom(param_26, param_27) * 2.0) - 1.0;
        float param_28 = time * 14.0;
        float param_29 = _222.seed + 1130.0;
        float smooth2 = (catmullRom(param_28, param_29) * 2.0) - 1.0;
        offset.x = ((mix(jitX, smooth1, _222.smoothness) * mi) * _222.amplitude) * 0.00999999977648258209228515625;
        offset.y = ((mix(jitY, smooth2, _222.smoothness) * mi) * _222.amplitude) * 0.00999999977648258209228515625;
        return offset;
    }
    if (md < 7.5)
    {
        float param_30 = time * 0.1500000059604644775390625;
        float param_31 = _222.seed + 1200.0;
        float d1 = (catmullRom(param_30, param_31) * 2.0) - 1.0;
        float param_32 = time * 0.119999997317790985107421875;
        float param_33 = _222.seed + 1210.0;
        float d2 = (catmullRom(param_32, param_33) * 2.0) - 1.0;
        float param_34 = time * 0.4000000059604644775390625;
        float param_35 = _222.seed + 1220.0;
        float d3 = (catmullRom(param_34, param_35) * 2.0) - 1.0;
        float param_36 = time * 0.3499999940395355224609375;
        float param_37 = _222.seed + 1230.0;
        float d4 = (catmullRom(param_36, param_37) * 2.0) - 1.0;
        offset.x = ((((d1 * 0.699999988079071044921875) + (d3 * 0.300000011920928955078125)) * mi) * _222.amplitude) * 0.00999999977648258209228515625;
        offset.y = ((((d2 * 0.699999988079071044921875) + (d4 * 0.300000011920928955078125)) * mi) * _222.amplitude) * 0.00999999977648258209228515625;
        return offset;
    }
    if (md < 8.5)
    {
        float punchDecay = exp(((-time) * 5.0) * mi);
        float punchX = sin(((time * _222.frequency) * 3.1415927410125732421875) * 4.0) * punchDecay;
        float punchY = cos((((time * _222.frequency) * 3.1415927410125732421875) * 3.0) + 0.5) * punchDecay;
        float param_38 = time * 10.0;
        float param_39 = _222.seed + 1300.0;
        float noiseX = (catmullRom(param_38, param_39) * 2.0) - 1.0;
        float param_40 = time * 9.0;
        float param_41 = _222.seed + 1310.0;
        float noiseY = (catmullRom(param_40, param_41) * 2.0) - 1.0;
        offset.x = (((punchX + ((noiseX * 0.1500000059604644775390625) * punchDecay)) * mi) * _222.amplitude) * 0.01200000010430812835693359375;
        offset.y = (((punchY + ((noiseY * 0.1500000059604644775390625) * punchDecay)) * mi) * _222.amplitude) * 0.01200000010430812835693359375;
        return offset;
    }
    return offset;
}

static inline __attribute__((always_inline))
float applySpring(thread const float& value, thread const float& time, thread const float& seedOff, constant ReferenceUniformse38f574cda1cf& _222)
{
    if (_222.springTension < 9.9999997473787516355514526367188e-06)
    {
        return value;
    }
    float omega = mix(5.0, 20.0, _222.springTension);
    float zeta = mix(0.100000001490116119384765625, 0.89999997615814208984375, _222.springDamping);
    float mass = fast::max(_222.springMass, 0.100000001490116119384765625);
    float dampedFreq = omega * sqrt(fast::max(1.0 - (zeta * zeta), 9.9999997473787516355514526367188e-06));
    float springOsc = exp((((-zeta) * omega) * time) / mass) * sin(dampedFreq * time);
    return value + (((value * springOsc) * _222.springTension) * 0.5);
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
            float _1101;
            if (mod(floor(r.x), 2.0) == 0.0)
            {
                _1101 = fract(r.x);
            }
            else
            {
                _1101 = 1.0 - fract(r.x);
            }
            r.x = _1101;
            float _1119;
            if (mod(floor(r.y), 2.0) == 0.0)
            {
                _1119 = fract(r.y);
            }
            else
            {
                _1119 = 1.0 - fract(r.y);
            }
            r.y = _1119;
            return r;
        }
    }
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse38f574cda1cf& _222, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _222.refScreen.xy;
    float t = _222.refScreen.z;
    float em = float(_222.edgeMode);
    float param = t;
    float env = getEnvelope(param, _222);
    float xOff = 0.0;
    if (_222.xRandAmp > 9.9999997473787516355514526367188e-06)
    {
        float param_1 = t;
        float param_2 = _222.frequency * _222.xRandFreq;
        float param_3 = _222.xPhase;
        float param_4 = 0.0;
        xOff += (getRand(param_1, param_2, param_3, param_4, _222) * _222.xRandAmp);
    }
    if (_222.xWaveAmp > 9.9999997473787516355514526367188e-06)
    {
        float param_5 = t;
        float param_6 = _222.xWaveFreq;
        float param_7 = _222.xPhase;
        xOff += (getWave(param_5, param_6, param_7) * _222.xWaveAmp);
    }
    xOff *= (_222.amplitude * 0.00999999977648258209228515625);
    xOff += ((_222.xBias * _222.amplitude) * 0.004999999888241291046142578125);
    float yOff = 0.0;
    if (_222.yRandAmp > 9.9999997473787516355514526367188e-06)
    {
        float param_8 = t;
        float param_9 = _222.frequency * _222.yRandFreq;
        float param_10 = _222.yPhase;
        float param_11 = 100.0;
        yOff += (getRand(param_8, param_9, param_10, param_11, _222) * _222.yRandAmp);
    }
    if (_222.yWaveAmp > 9.9999997473787516355514526367188e-06)
    {
        float param_12 = t;
        float param_13 = _222.yWaveFreq;
        float param_14 = _222.yPhase;
        yOff += (getWave(param_12, param_13, param_14) * _222.yWaveAmp);
    }
    yOff *= (_222.amplitude * 0.00999999977648258209228515625);
    yOff += ((_222.yBias * _222.amplitude) * 0.004999999888241291046142578125);
    float2 param_15 = float2(xOff, yOff);
    float param_16 = t;
    float2 _1291 = applyMode(param_15, param_16, _222);
    float2 offset = _1291;
    float param_17 = offset.x;
    float param_18 = t;
    float param_19 = 0.0;
    offset.x = applySpring(param_17, param_18, param_19, _222);
    float param_20 = offset.y;
    float param_21 = t;
    float param_22 = 50.0;
    offset.y = applySpring(param_20, param_21, param_22, _222);
    offset *= env;
    float angRad = (_222.globalAngle * 3.1415927410125732421875) / 180.0;
    float cosA = cos(angRad);
    float sinA = sin(angRad);
    float rX = (offset.x * cosA) - (offset.y * sinA);
    float rY = (offset.x * sinA) + (offset.y * cosA);
    offset = float2(rX, rY);
    float2 shakenUV = uv + offset;
    float outBounds = 1.0;
    if (em < 1.5)
    {
        bool _1356 = shakenUV.x < 0.0;
        bool _1363;
        if (!_1356)
        {
            _1363 = shakenUV.x > 1.0;
        }
        else
        {
            _1363 = _1356;
        }
        bool _1370;
        if (!_1363)
        {
            _1370 = shakenUV.y < 0.0;
        }
        else
        {
            _1370 = _1363;
        }
        bool _1377;
        if (!_1370)
        {
            _1377 = shakenUV.y > 1.0;
        }
        else
        {
            _1377 = _1370;
        }
        outBounds = _1377 ? 0.0 : 1.0;
    }
    float2 param_23 = shakenUV;
    float param_24 = em;
    shakenUV = applyEdge(param_23, param_24);
    shakenUV = fast::clamp(shakenUV, float2(0.0), float2(1.0));
    float2 param_25 = uv;
    float4 original = texture2DCv(refInput, refInputSmplr, param_25);
    float2 param_26 = shakenUV;
    float4 shaken = texture2DCv(refInput, refInputSmplr, param_26);
    float3 fin = shaken.xyz * outBounds;
    float finA = shaken.w * outBounds;
    fin = mix(original.xyz, fin, float3(_222.globalMix));
    finA = mix(original.w, finA, _222.globalMix);
    fin = fast::clamp(fin, float3(0.0), float3(1.0));
    referenceColor = float4(fin, finA);
}

fragment refAM35_e38f574cda1cf_out refAM35_e38f574cda1cf(constant ReferenceUniformse38f574cda1cf& _222 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e38f574cda1cf_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_222, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1442 = any(isnan(referenceColor));
    bool _1449;
    if (!_1442)
    {
        _1449 = any(isinf(referenceColor));
    }
    else
    {
        _1449 = _1442;
    }
    if (_1449)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1462 = referenceColor;
    float3 _1468 = fast::clamp(_1462.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1468.x;
    referenceColor.y = _1468.y;
    referenceColor.z = _1468.z;
    out.finalColor = referenceColor;
    return out;
}

