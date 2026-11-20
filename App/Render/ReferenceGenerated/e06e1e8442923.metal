// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/neural_network.xml
// Original source comments and attribution:
// Apply effect alpha masking based on layer alpha
// Standard mix for transparency
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse06e1e8442923
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 center;
    char _m6_pad[8];
    float speed;
    char _m7_pad[12];
    float complexity;
    float4 lineColor;
    float intensity;
    char _m10_pad[12];
    float softness;
    char _m11_pad[12];
    uint followLayer;
    char _m12_pad[12];
    float blend;
};

struct refAM35_e06e1e8442923_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash(thread const float2& p)
{
    return fract(sin(dot(p, float2(127.09999847412109375, 311.70001220703125))) * 43758.546875);
}

static inline __attribute__((always_inline))
float dfLine(thread const float2& start, thread const float2& end, thread const float2& uv)
{
    float2 line = end - start;
    float frac = dot(uv - start, line) / dot(line, line);
    return distance(start + (line * fast::clamp(frac, 0.0, 1.0)), uv);
}

static inline __attribute__((always_inline))
float map(thread const float2& uv, thread const float2& mouse, thread const float& t, thread const float& time, thread const float& iterCount, constant ReferenceUniformse06e1e8442923& _239)
{
    float col = 0.0;
    float2 end = float2(0.300000011920928955078125);
    float2 p = mouse;
    float2 p1 = end;
    float2 oldP = p;
    float2 oldP1 = p1;
    for (int i = 0; i < 500; i++)
    {
        if (float(i) >= iterCount)
        {
            break;
        }
        float fi = float(i);
        float p1Angle = precise::atan2(p.y - p1.y, p.x - p1.x);
        float pAngle = precise::atan2(p1.y - p.y, p1.x - p.x);
        float2 param = (p1 + float2(fi)) + float2(time * t);
        p1Angle += ((hash(param) - 0.5) * 2.0);
        float2 param_1 = (p + float2(fi)) + float2(time * t);
        pAngle += ((hash(param_1) - 0.5) * 2.0);
        float2 param_2 = (((p * p1) * time) * fi) + float2(t);
        p += (float2(cos(pAngle), sin(pAngle)) / float2(fast::max(hash(param_2) * 100.0, 60.0)));
        float2 param_3 = ((((p * p1) * time) * fi) * 43.324001312255859375) * t;
        p1 += (float2(cos(p1Angle), sin(p1Angle)) / float2(fast::max(hash(param_3) * 100.0, 60.0)));
        float2 param_4 = p;
        float2 param_5 = oldP;
        float2 param_6 = uv;
        float2 param_7 = ((p * fi) * time) + float2(t * t);
        col += (((1.0 - smoothstep(dfLine(param_4, param_5, param_6), (-_239.softness) * 0.5, _239.softness)) * fast::max(hash(param_7) * 2.0, 0.300000011920928955078125)) / t);
        float2 param_8 = p1;
        float2 param_9 = oldP1;
        float2 param_10 = uv;
        float2 param_11 = ((p1 * fi) * time) / float2(t);
        col += (((1.0 - smoothstep(dfLine(param_8, param_9, param_10), (-_239.softness) * 0.5, _239.softness)) * fast::max(hash(param_11) * 2.0, 0.300000011920928955078125)) / t);
        if (distance(p, p1) < 0.0500000007450580596923828125)
        {
            float2 param_12 = p;
            float2 param_13 = p1;
            float2 param_14 = uv;
            col += (1.0 - smoothstep(dfLine(param_12, param_13, param_14), (-_239.softness) * 0.5, _239.softness));
            break;
        }
        oldP = p;
        oldP1 = p1;
    }
    return col;
}

static inline __attribute__((always_inline))
float4 tanh_approx(thread const float4& x)
{
    float4 e = exp(x * 2.0);
    return (e - float4(1.0)) / (e + float4(1.0));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse06e1e8442923& _239, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 luv = (gl_FragCoord.xy - _239.refLayer.xy) / _239.refLayer.zw;
    float2 suv = gl_FragCoord.xy / _239.refScreen.xy;
    float2 uv;
    float2 aspect;
    if (_239.followLayer != 0u)
    {
        uv = luv;
        aspect = float2(_239.refLayer.z / _239.refLayer.w, 1.0);
    }
    else
    {
        uv = suv;
        aspect = float2(_239.refScreen.x / _239.refScreen.y, 1.0);
    }
    uv = ((uv * 2.0) - float2(1.0)) * aspect;
    float2 mouse = ((_239.center * 2.0) - float2(1.0)) * aspect;
    float time = _239.refScreen.z * _239.speed;
    float2 param = uv;
    float2 param_1 = mouse;
    float param_2 = 1.0;
    float param_3 = time;
    float param_4 = _239.complexity;
    float2 param_5 = uv;
    float2 param_6 = mouse;
    float param_7 = 3.0;
    float param_8 = time;
    float param_9 = _239.complexity;
    float v = map(param, param_1, param_2, param_3, param_4, _239) + map(param_5, param_6, param_7, param_8, param_9, _239);
    float4 param_10 = float4(v * _239.intensity) * _239.lineColor;
    float4 effectCol = tanh_approx(param_10);
    effectCol.w = fast::clamp(v * _239.intensity, 0.0, 1.0);
    float2 param_11 = suv;
    float4 base = texture2DCv(refInput, refInputSmplr, param_11);
    effectCol.w *= base.w;
    referenceColor = mix(base, effectCol, float4(_239.blend * effectCol.w));
}

fragment refAM35_e06e1e8442923_out refAM35_e06e1e8442923(constant ReferenceUniformse06e1e8442923& _239 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e06e1e8442923_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_239, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _490 = any(isnan(referenceColor));
    bool _497;
    if (!_490)
    {
        _497 = any(isinf(referenceColor));
    }
    else
    {
        _497 = _490;
    }
    if (_497)
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

