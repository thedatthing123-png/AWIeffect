// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/Amimpact.xml
// Original source comments and attribution:
// Time since trigger (with optional repeat)
// Directional position delta in pixels
// Rotation (deg) and scale
// Convert pixel translation to UV
// Pivot and auto expand
// Apply inverse transform to find source uv
// undo translation
// undo rotation
// undo scale
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

struct ReferenceUniformseee91489e4221
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float triggerTime;
    char _m6_pad[12];
    float duration;
    char _m7_pad[12];
    float frequency;
    char _m8_pad[12];
    float damping;
    char _m9_pad[12];
    float strength;
    char _m10_pad[12];
    float ampPos;
    char _m11_pad[12];
    float angle;
    char _m12_pad[12];
    float ampRot;
    char _m13_pad[12];
    float ampScale;
    char _m14_pad[12];
    float pivotX;
    char _m15_pad[12];
    float pivotY;
    char _m16_pad[12];
    uint mirrorEdges;
    char _m17_pad[12];
    float expand;
    char _m18_pad[12];
    uint enableRepeat;
    char _m19_pad[12];
    float repeatPeriod;
};

struct refAM35_eee91489e4221_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float repeatTime(thread const float& time, thread const float& trig, thread const bool& en, thread const float& period)
{
    if (!en)
    {
        return time - trig;
    }
    float tau = time - trig;
    if (period <= 0.0)
    {
        return tau;
    }
    float m = floor(tau / period);
    float local = tau - (m * period);
    return local;
}

static inline __attribute__((always_inline))
float envelope(thread const float& t, thread const float& freq, thread const float& damp, thread const float& dur)
{
    if (t < 0.0)
    {
        return 0.0;
    }
    if (t > dur)
    {
        return 0.0;
    }
    float w = 6.283185482025146484375 * freq;
    return exp((-damp) * t) * sin(w * t);
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float2x2 rot2(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float2 mirror(thread const float2& uv)
{
    return abs((fract((uv * 0.5) + float2(0.5)) * 2.0) - float2(1.0));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 sampleTex(texture2d<float> t, sampler tSmplr, thread const float2& uv)
{
    float2 param = uv;
    return texture2DCv(t, tSmplr, param);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformseee91489e4221& _165, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _165.refScreen.xy;
    float param = _165.refScreen.z;
    float param_1 = _165.triggerTime;
    bool param_2 = _165.enableRepeat != 0u;
    float param_3 = _165.repeatPeriod;
    float tauBase = repeatTime(param, param_1, param_2, param_3);
    float param_4 = tauBase;
    float param_5 = _165.frequency;
    float param_6 = _165.damping;
    float param_7 = _165.duration;
    float env = envelope(param_4, param_5, param_6, param_7) * _165.strength;
    float ang = radians(_165.angle);
    float2 dir = float2(cos(ang), sin(ang));
    float2 posPx = (dir * _165.ampPos) * env;
    float rotDeg = _165.ampRot * env;
    float scl = 1.0 + (_165.ampScale * env);
    float2 param_8 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texSize = getTexSize(param_8);
    float2 posUV = posPx / fast::max(texSize, float2(1.0));
    float2 pivot = float2(_165.pivotX, _165.pivotY);
    float autoS = 1.0 + _165.expand;
    float rot = radians(rotDeg);
    float2 rel = uv - pivot;
    rel -= posUV;
    float param_9 = -rot;
    rel = rot2(param_9) * rel;
    rel /= float2(fast::max(scl * autoS, 9.9999999747524270787835121154785e-07));
    float2 srcUV = pivot + rel;
    float4 col;
    if (_165.mirrorEdges != 0u)
    {
        float2 param_10 = srcUV;
        float2 param_11 = mirror(param_10);
        col = sampleTex(refInput, refInputSmplr, param_11);
    }
    else
    {
        bool _321 = any(srcUV < float2(0.0));
        bool _328;
        if (!_321)
        {
            _328 = any(srcUV > float2(1.0));
        }
        else
        {
            _328 = _321;
        }
        if (_328)
        {
            col = float4(0.0);
        }
        else
        {
            float2 param_12 = srcUV;
            col = sampleTex(refInput, refInputSmplr, param_12);
        }
    }
    referenceColor = col;
}

fragment refAM35_eee91489e4221_out refAM35_eee91489e4221(constant ReferenceUniformseee91489e4221& _165 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eee91489e4221_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _165, refInput, refInputSmplr, referenceColor);
    bool _343 = any(isnan(referenceColor));
    bool _350;
    if (!_343)
    {
        _350 = any(isinf(referenceColor));
    }
    else
    {
        _350 = _343;
    }
    if (_350)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _365 = referenceColor;
    float3 _371 = fast::clamp(_365.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _371.x;
    referenceColor.y = _371.y;
    referenceColor.z = _371.z;
    out.finalColor = referenceColor;
    return out;
}

