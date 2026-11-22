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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse1e32e5ce15e4& _51, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texelSize = float2(1.0) / getTexSize(param);
    float Radius = _51.radius;
    float T = _51.strength;
    float2 UV = gl_FragCoord.xy / _51.refScreen.xy;
    float2 CENTER = _51.centerPoint * float2(-1.0);
    float2 diff1 = float2(_51.refLayer.x + (_51.refLayer.z * 0.5), (_51.refScreen.y - _51.refLayer.y) - (_51.refLayer.w * 0.5)) - CENTER;
    diff1.y = _51.refScreen.y - diff1.y;
    float2 diff = diff1 / _51.refScreen.xy;
    UV -= diff;
    float2 convRate = float2(1.0);
    if (_51.refScreen.y > _51.refScreen.x)
    {
        convRate.y = _51.refScreen.y / _51.refScreen.x;
    }
    else
    {
        convRate.x = _51.refScreen.x / _51.refScreen.y;
    }
    UV *= convRate;
    float Dist = length(UV);
    float4 color = float4(0.0);
    if (Dist < Radius)
    {
        float speed = 0.0;
        float localPower = (Radius - Dist) / Radius;
        float _167;
        if (T <= 0.5)
        {
            _167 = mix(0.0, 1.0, T / 0.5);
        }
        else
        {
            _167 = mix(1.0, 0.0, (T - 0.5) / 0.5);
        }
        float A = _167;
        float Theta = (((localPower * localPower) * A) * 8.0) * 3.141590118408203125;
        float l = Dist * Theta;
        speed = abs((l / texelSize.x) * 10.0);
        float _204 = fast::clamp(speed, 1.0099999904632568359375, 2000.010009765625);
        float2 v = UV / float2(_204);
        float2 c = float2(0.0);
        float count = 0.0;
        float _222 = fast::max(Radius - (abs(_51.strength) * localPower), Dist);
        float _247;
        for (float nSamples = _204, d = _222; d <= Radius; d += (1.0 / nSamples))
        {
            float Percent = (Radius - d) / Radius;
            float2 cc = UV - c;
            c += v;
            if (T <= 0.5)
            {
                _247 = mix(0.0, 1.0, T / 0.5);
            }
            else
            {
                _247 = mix(1.0, 0.0, (T - 0.5) / 0.5);
            }
            float A_1 = _247;
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

fragment refAM35_e1e32e5ce15e4_out refAM35_e1e32e5ce15e4(constant ReferenceUniformse1e32e5ce15e4& _51 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e1e32e5ce15e4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _51, gl_FragCoord, referenceColor);
    bool _324 = any(isnan(referenceColor));
    bool _331;
    if (!_324)
    {
        _331 = any(isinf(referenceColor));
    }
    else
    {
        _331 = _324;
    }
    if (_331)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _345 = referenceColor;
    float3 _351 = fast::clamp(_345.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _351.x;
    referenceColor.y = _351.y;
    referenceColor.z = _351.z;
    out.finalColor = referenceColor;
    return out;
}

