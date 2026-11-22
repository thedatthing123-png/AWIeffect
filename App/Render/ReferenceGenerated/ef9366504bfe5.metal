// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/chromatic-vortexblur.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef9366504bfe5
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
    char _m8_pad[12];
    float colorAberration;
    char _m9_pad[12];
    int centerChannel;
    char _m10_pad[12];
    int mode;
};

struct refAM35_ef9366504bfe5_out
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
float4 getBlurred(thread const float& channelStrength, texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformsef9366504bfe5& _55, thread float4& gl_FragCoord)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texelSize = float2(1.0) / getTexSize(param);
    float Radius = _55.radius;
    float T = channelStrength;
    float2 UV = gl_FragCoord.xy / _55.refScreen.xy;
    float2 CENTER = _55.centerPoint * float2(-1.0);
    float2 diff1 = float2(_55.refLayer.x + (_55.refLayer.z * 0.5), (_55.refScreen.y - _55.refLayer.y) - (_55.refLayer.w * 0.5)) - CENTER;
    diff1.y = _55.refScreen.y - diff1.y;
    float2 diff = diff1 / _55.refScreen.xy;
    UV -= diff;
    float2 convRate = float2(1.0);
    if (_55.refScreen.y > _55.refScreen.x)
    {
        convRate.y = _55.refScreen.y / _55.refScreen.x;
    }
    else
    {
        convRate.x = _55.refScreen.x / _55.refScreen.y;
    }
    UV *= convRate;
    float Dist = length(UV);
    float4 color = float4(0.0);
    if (Dist < Radius)
    {
        float speed = 0.0;
        float localPower = (Radius - Dist) / Radius;
        float _169;
        if (T <= 0.5)
        {
            _169 = mix(0.0, 1.0, T / 0.5);
        }
        else
        {
            _169 = mix(1.0, 0.0, (T - 0.5) / 0.5);
        }
        float A = _169;
        float Theta = (((localPower * localPower) * A) * 8.0) * 3.141590118408203125;
        float l = Dist * Theta;
        speed = abs((l / texelSize.x) * 10.0);
        float _206 = fast::clamp(speed, 1.0099999904632568359375, 2000.010009765625);
        float2 v = UV / float2(_206);
        float2 c = float2(0.0);
        float count = 0.0;
        float _225 = fast::max(Radius - (abs(_55.strength) * localPower), Dist);
        float _250;
        for (float nSamples = _206, d = _225; d <= Radius; d += (1.0 / nSamples))
        {
            float Percent = (Radius - d) / Radius;
            float2 cc = UV - c;
            c += v;
            if (T <= 0.5)
            {
                _250 = mix(0.0, 1.0, T / 0.5);
            }
            else
            {
                _250 = mix(1.0, 0.0, (T - 0.5) / 0.5);
            }
            float A_1 = _250;
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
    return color;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformsef9366504bfe5& _55, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float3 offset = float3(0.0);
    if (_55.centerChannel == 0)
    {
        offset = float3(0.0, -1.0, 1.0);
    }
    else
    {
        if (_55.centerChannel == 1)
        {
            offset = float3(-1.0, 0.0, 1.0);
        }
        else
        {
            offset = float3(-1.0, 1.0, 0.0);
        }
    }
    offset *= _55.colorAberration;
    float param = (1.0 + offset.x) * _55.strength;
    float4 redBlurred = getBlurred(param, refInput, refInputSmplr, _55, gl_FragCoord);
    float param_1 = (1.0 + offset.y) * _55.strength;
    float4 greenBlurred = getBlurred(param_1, refInput, refInputSmplr, _55, gl_FragCoord);
    float param_2 = (1.0 + offset.z) * _55.strength;
    float4 blueBlurred = getBlurred(param_2, refInput, refInputSmplr, _55, gl_FragCoord);
    float4 outColor = float4(redBlurred.x, greenBlurred.y, blueBlurred.z, ((redBlurred.w + greenBlurred.w) + blueBlurred.w) / 3.0);
    float4 colorMid;
    float4 colorLow;
    float4 colorHigh;
    if (_55.centerChannel == 0)
    {
        colorMid = redBlurred;
        colorLow = greenBlurred;
        colorHigh = blueBlurred;
    }
    else
    {
        if (_55.centerChannel == 1)
        {
            colorMid = greenBlurred;
            colorLow = redBlurred;
            colorHigh = blueBlurred;
        }
        else
        {
            colorMid = blueBlurred;
            colorLow = redBlurred;
            colorHigh = greenBlurred;
            offset = float3(-1.0, 1.0, 0.0);
        }
    }
    if (_55.mode == 0)
    {
        referenceColor = outColor * colorMid.w;
    }
    else
    {
        if (_55.mode == 1)
        {
            float4 r = float4(outColor.x, 0.0, 0.0, outColor.x);
            float4 g = float4(0.0, outColor.y, 0.0, outColor.y);
            float4 b = float4(0.0, 0.0, outColor.z, outColor.z);
            float4 m = ((r + g) + b) / float4(3.0);
            float4 c = float4(0.0);
            float4 l = float4(dot(float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875) * colorMid.xyz, float3(1.0)));
            c = m + (c * (1.0 - m.w));
            c = l + (c * (1.0 - l.w));
            referenceColor = c;
        }
        else
        {
            if (_55.mode == 2)
            {
                referenceColor = float4(outColor.xyz, colorMid.w);
            }
            else
            {
                referenceColor = outColor * (((colorLow.w + colorMid.w) + colorHigh.w) / 3.0);
            }
        }
    }
}

fragment refAM35_ef9366504bfe5_out refAM35_ef9366504bfe5(constant ReferenceUniformsef9366504bfe5& _55 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef9366504bfe5_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _55, gl_FragCoord, referenceColor);
    bool _520 = any(isnan(referenceColor));
    bool _527;
    if (!_520)
    {
        _527 = any(isinf(referenceColor));
    }
    else
    {
        _527 = _520;
    }
    if (_527)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _540 = referenceColor;
    float3 _546 = fast::clamp(_540.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _546.x;
    referenceColor.y = _546.y;
    referenceColor.z = _546.z;
    out.finalColor = referenceColor;
    return out;
}

