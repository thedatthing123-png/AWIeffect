// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/psykostripes.xml
// Original source comments and attribution:
// Edge detection
// Distort wave based on edges and original luminance
// Apply "Find Edges" look: dark boundaries or glowing lines
// Darken edges
// Glow edges
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL radians() function
template<typename T>
inline T radians(T d)
{
    return d * T(0.01745329251);
}

struct ReferenceUniformseaf2f95b1ab6a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float stripeDirDeg;
    char _m6_pad[12];
    float stripeMag;
    char _m7_pad[12];
    float phaseStart;
    char _m8_pad[12];
    float phaseSpeed;
    char _m9_pad[12];
    float offset;
    char _m10_pad[12];
    float freqColors;
    char _m11_pad[12];
    float freqRed;
    char _m12_pad[12];
    float freqGreen;
    char _m13_pad[12];
    float freqBlue;
    char _m14_pad[12];
    float phaseRed;
    char _m15_pad[12];
    float phaseGreen;
    char _m16_pad[12];
    float phaseBlue;
    char _m17_pad[12];
    float brightness;
    float4 tintColor;
    float saturation;
    char _m20_pad[12];
    float edgeAmt;
    char _m21_pad[12];
    float edgeWarp;
    char _m22_pad[12];
    float edgeWidth;
    char _m23_pad[12];
    uint edgeInvert;
    char _m24_pad[12];
    float mixWithSource;
};

struct refAM35_eaf2f95b1ab6a_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float2 getResolution(constant ReferenceUniformseaf2f95b1ab6a& _61)
{
    float2 param = _61.refScreen.xy;
    float2 s = getTexSize(param);
    bool _75 = s.x <= 0.0;
    bool _83;
    if (!_75)
    {
        _83 = s.y <= 0.0;
    }
    else
    {
        _83 = _75;
    }
    if (_83)
    {
        s = float2(1920.0, 1080.0);
    }
    return s;
}

static inline __attribute__((always_inline))
float2x2 rot2(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float gray(thread const float4& c)
{
    return dot(c.xyz, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
}

static inline __attribute__((always_inline))
float getLuma(thread const float2& uv, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = uv;
    float4 param_1 = texture2DCv(refInput, refInputSmplr, param);
    return gray(param_1);
}

static inline __attribute__((always_inline))
float sobel(thread const float2& uv, thread const float2& pixel, thread const float& w, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 p = pixel * w;
    float2 param = uv + (p * float2(-1.0));
    float t00 = getLuma(param, refInput, refInputSmplr);
    float2 param_1 = uv + (p * float2(0.0, -1.0));
    float t10 = getLuma(param_1, refInput, refInputSmplr);
    float2 param_2 = uv + (p * float2(1.0, -1.0));
    float t20 = getLuma(param_2, refInput, refInputSmplr);
    float2 param_3 = uv + (p * float2(-1.0, 0.0));
    float t01 = getLuma(param_3, refInput, refInputSmplr);
    float2 param_4 = uv + (p * float2(1.0, 0.0));
    float t21 = getLuma(param_4, refInput, refInputSmplr);
    float2 param_5 = uv + (p * float2(-1.0, 1.0));
    float t02 = getLuma(param_5, refInput, refInputSmplr);
    float2 param_6 = uv + (p * float2(0.0, 1.0));
    float t12 = getLuma(param_6, refInput, refInputSmplr);
    float2 param_7 = uv + (p * float2(1.0));
    float t22 = getLuma(param_7, refInput, refInputSmplr);
    float gx = ((t00 + (2.0 * t01)) + t02) - ((t20 + (2.0 * t21)) + t22);
    float gy = ((t00 + (2.0 * t10)) + t20) - ((t02 + (2.0 * t12)) + t22);
    return length(float2(gx, gy));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseaf2f95b1ab6a& _61, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 res = getResolution(_61);
    float2 uv = gl_FragCoord.xy / _61.refScreen.xy;
    float2 pixel = float2(1.0) / res;
    float ang = radians(_61.stripeDirDeg);
    float param = ang;
    float2 dir = rot2(param) * float2(1.0, 0.0);
    float2 param_1 = uv;
    float2 param_2 = pixel;
    float param_3 = _61.edgeWidth;
    float edge = sobel(param_1, param_2, param_3, refInput, refInputSmplr) * _61.edgeAmt;
    float maskEdge = fast::clamp(edge, 0.0, 1.0);
    if (_61.edgeInvert != 0u)
    {
        maskEdge = 1.0 - maskEdge;
    }
    float2 param_4 = uv;
    float4 s0 = texture2DCv(refInput, refInputSmplr, param_4);
    float4 param_5 = s0;
    float amp = gray(param_5);
    float basePhase = (_61.phaseStart + (_61.refScreen.z * _61.phaseSpeed)) + _61.offset;
    float mag = _61.stripeMag;
    float wave = (dot(uv - float2(0.5), dir) * mag) + basePhase;
    wave += (edge * _61.edgeWarp);
    wave += ((amp * _61.edgeWarp) * 0.5);
    float fBase = _61.freqColors;
    float rC = 0.5 + (0.5 * sin(((wave * fBase) * _61.freqRed) + _61.phaseRed));
    float gC = 0.5 + (0.5 * sin(((wave * fBase) * _61.freqGreen) + _61.phaseGreen));
    float bC = 0.5 + (0.5 * sin(((wave * fBase) * _61.freqBlue) + _61.phaseBlue));
    float3 colS = float3(rC, gC, bC);
    float3 tint = _61.tintColor.xyz;
    float3 colT = colS * tint;
    if (!(_61.edgeInvert != 0u))
    {
        colT *= (1.0 - (maskEdge * 0.800000011920928955078125));
    }
    else
    {
        colT += float3(maskEdge * 0.5);
    }
    float g = dot(colT, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float3 colSat = mix(float3(g), colT, float3(fast::clamp(_61.saturation, 0.0, 2.0)));
    colSat *= _61.brightness;
    float3 srcCol = s0.xyz;
    float aIn = s0.w;
    float3 stripeBlend = mix(colSat, srcCol, float3(_61.mixWithSource));
    float3 outCol = mix(srcCol, stripeBlend, float3(aIn));
    referenceColor = float4(outCol, aIn);
}

fragment refAM35_eaf2f95b1ab6a_out refAM35_eaf2f95b1ab6a(constant ReferenceUniformseaf2f95b1ab6a& _61 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eaf2f95b1ab6a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_61, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _470 = any(isnan(referenceColor));
    bool _477;
    if (!_470)
    {
        _477 = any(isinf(referenceColor));
    }
    else
    {
        _477 = _470;
    }
    if (_477)
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

