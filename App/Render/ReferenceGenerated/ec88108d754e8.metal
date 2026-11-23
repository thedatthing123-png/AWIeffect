// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/waveloq-3.xml
// Original source comments and attribution:
// Rainbow color from position
// -----------------------------------------------
// Wave displacement — moves dots from grid position
// This is what creates the ripple/distortion look
// -----------------------------------------------
// Primary axis for wave
// Wave — smooth sine displaces perpendicular axis
// Signal — square wave
// Chaos — multi-freq both axes
// CRT LED — radial wave from center
// Raw LED — luma-driven, no displacement (handled below)
// Glitch — random block jumps
// Jagged — sawtooth
// Modular — layered
// Particle — random per dot burst
// Multiple generators: add shifted copies
// golden ratio offset
// -----------------------------------------------
// DOT GRID SETUP
// -----------------------------------------------
// Which cell this pixel is in
// 0..1 within cell
// -----------------------------------------------
// WAVE DISPLACEMENT
// Shift where we SAMPLE the source image
// This creates the distorted dot pattern
// -----------------------------------------------
// Add X/Y shift
// Compress: scale the displacement
// Displaced dot center in UV space
// -----------------------------------------------
// SAMPLE IMAGE at displaced dot center
// -----------------------------------------------
// Apply cutoff — dots below this luma disappear
// Fade: soft threshold at bottom of range
// Decay
// -----------------------------------------------
// DOT SIZE driven by luma
// Bright areas = large dots
// Dark areas = tiny/no dots
// -----------------------------------------------
// -----------------------------------------------
// DOT SHAPE — circular
// -----------------------------------------------
// Sharp dot with soft edge
// -----------------------------------------------
// DOT COLOR
// -----------------------------------------------
// Source image color
// Single color
// Rainbow neon based on position
// -----------------------------------------------
// GLOW around each dot
// Large soft halo = neon LED look
// -----------------------------------------------
// quadratic = more realistic
// -----------------------------------------------
// FINAL COMPOSITE
// Pure black background + colored dots + glow
// -----------------------------------------------
// BLACK background
// Add glow first (under dot)
// Add dot on top
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec88108d754e8
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int preset;
    char _m6_pad[12];
    float cutoff;
    char _m7_pad[12];
    float range;
    char _m8_pad[12];
    float fade;
    char _m9_pad[12];
    float distortion;
    char _m10_pad[12];
    float frequency;
    char _m11_pad[12];
    float phase;
    char _m12_pad[12];
    float animSpeed;
    char _m13_pad[12];
    float thickness;
    char _m14_pad[12];
    float pitch;
    char _m15_pad[12];
    float density;
    char _m16_pad[12];
    float decay;
    char _m17_pad[12];
    float glow;
    char _m18_pad[12];
    int orientation;
    char _m19_pad[12];
    float xShift;
    char _m20_pad[12];
    float yShift;
    char _m21_pad[12];
    float generators;
    char _m22_pad[12];
    float compress;
    char _m23_pad[12];
    int colorMode;
    char _m24_pad[12];
    float colorR;
    char _m25_pad[12];
    float colorG;
    char _m26_pad[12];
    float colorB;
    char _m27_pad[12];
    float blend;
};

struct refAM35_ec88108d754e8_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float hashV(thread const float2& p)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
float noiseV(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i;
    float2 param_1 = i + float2(1.0, 0.0);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 param_3 = i + float2(1.0);
    return mix(mix(hashV(param), hashV(param_1), f.x), mix(hashV(param_2), hashV(param_3), f.x), f.y);
}

static inline __attribute__((always_inline))
float2 getWaveDisplace(thread const float2& dotIdx, thread const float& t, constant ReferenceUniformsec88108d754e8& _140)
{
    float pr = float(_140.preset);
    float freq = _140.frequency * 9.9999997473787516355514526367188e-05;
    float ph = (_140.phase * 3.141590118408203125) / 180.0;
    float spd = t * _140.animSpeed;
    float col = dotIdx.x;
    float row = dotIdx.y;
    float ori = float(_140.orientation);
    float2 disp = float2(0.0);
    float axis = (ori < 0.5) ? col : row;
    if (pr < 0.5)
    {
        float w = sin((((axis * freq) * 50.0) + spd) + ph) * _140.distortion;
        float2 _209;
        if (ori < 0.5)
        {
            _209 = float2(0.0, w);
        }
        else
        {
            _209 = float2(w, 0.0);
        }
        disp = _209;
    }
    else
    {
        if (pr < 1.5)
        {
            float w_1 = (sign(sin((((axis * freq) * 50.0) + spd) + ph)) * _140.distortion) * 0.5;
            float2 _241;
            if (ori < 0.5)
            {
                _241 = float2(0.0, w_1);
            }
            else
            {
                _241 = float2(w_1, 0.0);
            }
            disp = _241;
        }
        else
        {
            if (pr < 2.5)
            {
                float2 param = float2((col * freq) * 10.0, spd * 0.300000011920928955078125);
                float wx = (((sin((((col * freq) * 80.0) + spd) + ph) * _140.distortion) * 0.5) + ((sin(((col * freq) * 130.0) + (spd * 1.2999999523162841796875)) * _140.distortion) * 0.300000011920928955078125)) + ((noiseV(param) * _140.distortion) * 0.20000000298023223876953125);
                float wy = ((sin((((row * freq) * 70.0) + (spd * 0.800000011920928955078125)) + ph) * _140.distortion) * 0.4000000059604644775390625) + ((sin(((row * freq) * 110.0) + (spd * 1.10000002384185791015625)) * _140.distortion) * 0.300000011920928955078125);
                disp = float2(wx, wy);
            }
            else
            {
                if (pr < 3.5)
                {
                    float2 center = float2(_140.refScreen.x / _140.pitch, _140.refScreen.y / _140.pitch) * 0.5;
                    float dist = length(dotIdx - center);
                    float w_2 = sin((((dist * freq) * 100.0) - spd) + ph) * _140.distortion;
                    float2 dir = fast::normalize((dotIdx - center) + float2(0.001000000047497451305389404296875));
                    disp = dir * w_2;
                }
                else
                {
                    if (pr < 4.5)
                    {
                        disp = float2(0.0);
                    }
                    else
                    {
                        if (pr < 5.5)
                        {
                            float gc = floor(col / fast::max(_140.density, 1.0));
                            float gt = floor(spd * 3.0);
                            float2 param_1 = float2(gc + gt, row);
                            float rnd = (hashV(param_1) * 2.0) - 1.0;
                            float2 param_2 = float2(gc, gt + 1.0);
                            float fired = step(0.60000002384185791015625, hashV(param_2));
                            disp = float2(((rnd * _140.distortion) * 2.0) * fired, 0.0);
                        }
                        else
                        {
                            if (pr < 6.5)
                            {
                                float w_3 = ((fract(((axis * freq) * 30.0) + spd) * 2.0) - 1.0) * _140.distortion;
                                float2 _463;
                                if (ori < 0.5)
                                {
                                    _463 = float2(0.0, w_3);
                                }
                                else
                                {
                                    _463 = float2(w_3, 0.0);
                                }
                                disp = _463;
                            }
                            else
                            {
                                if (pr < 7.5)
                                {
                                    float wx_1 = ((sin(((col * freq) * 40.0) + spd) * _140.distortion) * 0.4000000059604644775390625) + ((sin((((row * freq) * 30.0) + (spd * 0.699999988079071044921875)) + ph) * _140.distortion) * 0.300000011920928955078125);
                                    float wy_1 = ((sin(((row * freq) * 40.0) + (spd * 0.800000011920928955078125)) * _140.distortion) * 0.4000000059604644775390625) + ((sin((((col * freq) * 25.0) + (spd * 1.10000002384185791015625)) + ph) * _140.distortion) * 0.300000011920928955078125);
                                    disp = float2(wx_1, wy_1);
                                }
                                else
                                {
                                    float pt = floor(spd * 2.0);
                                    float2 param_3 = float2(col + pt, row + 0.100000001490116119384765625);
                                    float rdx = (hashV(param_3) * 2.0) - 1.0;
                                    float2 param_4 = float2(col + 0.20000000298023223876953125, row + pt);
                                    float rdy = (hashV(param_4) * 2.0) - 1.0;
                                    float2 param_5 = float2(col * 0.100000001490116119384765625, (row * 0.100000001490116119384765625) + pt);
                                    float burst = step(0.5, hashV(param_5));
                                    disp = (float2(rdx, rdy) * _140.distortion) * burst;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    for (int g = 1; g < 10; g++)
    {
        if (float(g) >= _140.generators)
        {
            break;
        }
        float gf = float(g);
        float gOff = gf * 0.617999970912933349609375;
        disp += (((disp * sin((gOff * 3.141590118408203125) + (_140.animSpeed * _140.refScreen.z))) * 0.20000000298023223876953125) / float2(gf));
    }
    return disp;
}

static inline __attribute__((always_inline))
float3 rainbow(thread float& t)
{
    t = fract(t);
    float r = abs((t * 6.0) - 3.0) - 1.0;
    float g = 2.0 - abs((t * 6.0) - 2.0);
    float b = 2.0 - abs((t * 6.0) - 4.0);
    return fast::clamp(float3(r, g, b), float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsec88108d754e8& _140, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _140.refScreen.xy;
    float t = _140.refScreen.z;
    float2 param = fast::clamp(uv, float2(0.0), float2(1.0));
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float cellSize = _140.pitch;
    float2 pixelPos = uv * _140.refScreen.xy;
    float2 dotIdx = floor(pixelPos / float2(cellSize));
    float2 cellUV = fract(pixelPos / float2(cellSize));
    float2 param_1 = dotIdx;
    float param_2 = t;
    float2 waveDisp = getWaveDisplace(param_1, param_2, _140);
    waveDisp += (float2(_140.xShift, _140.yShift) * 0.00999999977648258209228515625);
    waveDisp *= _140.compress;
    float2 dotCenter = (((dotIdx + float2(0.5)) + waveDisp) * cellSize) / _140.refScreen.xy;
    dotCenter = fast::clamp(dotCenter, float2(0.0), float2(1.0));
    float2 param_3 = dotCenter;
    float4 dotSource = texture2DCv(refInput, refInputSmplr, param_3);
    float3 srcCol = dotSource.xyz / float3(fast::max(dotSource.w, 9.9999997473787516355514526367188e-06));
    float luma = dot(srcCol, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float lumaAdj = (luma - _140.cutoff) / fast::max(_140.range, 0.001000000047497451305389404296875);
    lumaAdj = fast::clamp(lumaAdj, 0.0, 1.0);
    lumaAdj *= smoothstep(0.0, fast::max(_140.fade, 0.001000000047497451305389404296875), lumaAdj);
    lumaAdj = powr(lumaAdj, 1.0 + (_140.decay * 0.300000011920928955078125));
    float baseRad = (_140.thickness / cellSize) * 0.449999988079071044921875;
    baseRad = fast::clamp(baseRad, 0.00999999977648258209228515625, 0.4799999892711639404296875);
    float dotRadius = baseRad * lumaAdj;
    dotRadius = fast::clamp(dotRadius, 0.0, 0.4799999892711639404296875);
    float2 fromCenter = cellUV - float2(0.5);
    float dist = length(fromCenter);
    float dotMask = 1.0 - smoothstep(dotRadius * 0.699999988079071044921875, dotRadius, dist);
    float cm = float(_140.colorMode);
    float3 dotColor;
    if (cm < 0.5)
    {
        dotColor = srcCol;
    }
    else
    {
        if (cm < 1.5)
        {
            dotColor = float3(_140.colorR, _140.colorG, _140.colorB);
        }
        else
        {
            float rainbowT = (dotIdx.x + (dotIdx.y * 0.300000011920928955078125)) / (_140.refScreen.x / cellSize);
            float param_4 = rainbowT + ((t * _140.animSpeed) * 0.100000001490116119384765625);
            float3 _844 = rainbow(param_4);
            dotColor = _844;
        }
    }
    float glowRadius = dotRadius + ((_140.glow / cellSize) * 0.300000011920928955078125);
    glowRadius = fast::clamp(glowRadius, dotRadius, 0.800000011920928955078125);
    float glowFalloff = 1.0 - smoothstep(dotRadius, glowRadius, dist);
    glowFalloff *= glowFalloff;
    float3 result = float3(0.0);
    result += ((((dotColor * glowFalloff) * lumaAdj) * _140.glow) * 0.1500000059604644775390625);
    result += ((dotColor * dotMask) * lumaAdj);
    result = fast::clamp(result, float3(0.0), float3(1.0));
    referenceColor = float4(mix(src.xyz, result * src.w, float3(_140.blend)), src.w);
}

fragment refAM35_ec88108d754e8_out refAM35_ec88108d754e8(constant ReferenceUniformsec88108d754e8& _140 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec88108d754e8_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_140, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _915 = any(isnan(referenceColor));
    bool _922;
    if (!_915)
    {
        _922 = any(isinf(referenceColor));
    }
    else
    {
        _922 = _915;
    }
    if (_922)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _935 = referenceColor;
    float3 _941 = fast::clamp(_935.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _941.x;
    referenceColor.y = _941.y;
    referenceColor.z = _941.z;
    out.finalColor = referenceColor;
    return out;
}

