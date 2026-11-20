// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/vortexblur.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse1e32e5ce15e4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 centerPoint;
    char _m6_pad[8];
    float strength;
    char _m7_pad[12];
    float radius;
};

struct refAM35_e1e32e5ce15e4_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse1e32e5ce15e4& _37, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 param = _37.refScreen.xy;
    float2 texelSize = float2(1.0) / getTexSize(param);
    float Radius = _37.radius;
    float T = _37.strength;
    float2 UV = gl_FragCoord.xy / _37.refScreen.xy;
    float2 CENTER = _37.centerPoint * float2(-1.0);
    float2 diff1 = float2(_37.refLayer.x + (_37.refLayer.z * 0.5), (_37.refScreen.y - _37.refLayer.y) - (_37.refLayer.w * 0.5)) - CENTER;
    diff1.y = _37.refScreen.y - diff1.y;
    float2 diff = diff1 / _37.refScreen.xy;
    UV -= diff;
    float2 convRate = float2(1.0);
    if (_37.refScreen.y > _37.refScreen.x)
    {
        convRate.y = _37.refScreen.y / _37.refScreen.x;
    }
    else
    {
        convRate.x = _37.refScreen.x / _37.refScreen.y;
    }
    UV *= convRate;
    float Dist = length(UV);
    float4 color = float4(0.0);
    if (Dist < Radius)
    {
        float speed = 0.0;
        float localPower = (Radius - Dist) / Radius;
        float _164;
        if (T <= 0.5)
        {
            _164 = mix(0.0, 1.0, T / 0.5);
        }
        else
        {
            _164 = mix(1.0, 0.0, (T - 0.5) / 0.5);
        }
        float A = _164;
        float Theta = (((localPower * localPower) * A) * 8.0) * 3.141590118408203125;
        float l = Dist * Theta;
        speed = abs((l / texelSize.x) * 10.0);
        float _201 = fast::clamp(speed, 1.0099999904632568359375, 2000.010009765625);
        float2 v = UV / float2(_201);
        float2 c = float2(0.0);
        float count = 0.0;
        float _219 = fast::max(Radius - (abs(_37.strength) * localPower), Dist);
        float _244;
        for (float nSamples = _201, d = _219; d <= Radius; d += (1.0 / nSamples))
        {
            float Percent = (Radius - d) / Radius;
            float2 cc = UV - c;
            c += v;
            if (T <= 0.5)
            {
                _244 = mix(0.0, 1.0, T / 0.5);
            }
            else
            {
                _244 = mix(1.0, 0.0, (T - 0.5) / 0.5);
            }
            float A_1 = _244;
            float Theta_1 = (((Percent * Percent) * A_1) * 8.0) * 3.141590118408203125;
            float S = sin(Theta_1);
            float C = cos(Theta_1);
            float2 res = float2(dot(cc, float2(C, -S)), dot(cc, float2(S, C)));
            res /= convRate;
            res += diff;
            float2 param_1 = res;
            color += texture2DCv(refInput, refInputSmplr, param_1);
            count += 1.0;
        }
        color /= float4(count);
    }
    else
    {
        UV /= convRate;
        UV += diff;
        float2 param_2 = UV;
        color = texture2DCv(refInput, refInputSmplr, param_2);
    }
    referenceColor = color;
}

fragment refAM35_e1e32e5ce15e4_out refAM35_e1e32e5ce15e4(constant ReferenceUniformse1e32e5ce15e4& _37 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e1e32e5ce15e4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_37, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _322 = any(isnan(referenceColor));
    bool _329;
    if (!_322)
    {
        _329 = any(isinf(referenceColor));
    }
    else
    {
        _329 = _322;
    }
    if (_329)
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

