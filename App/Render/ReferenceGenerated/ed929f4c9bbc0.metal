// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxxrgb.xml
// Original source comments and attribution:
//c = colorMid + (c*(1.0-colorMid.a));
//c = (colorMid + m)/2.;
//c = r + (c*(1.0-r.a));
//c = g + (c*(1.0-g.a));
//c = b + (c*(1.0-b.a));
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsed929f4c9bbc0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strengthh;
    char _m6_pad[12];
    float strength;
    char _m7_pad[12];
    float angle;
    char _m8_pad[12];
    int centerChannel;
    char _m9_pad[12];
    int mode;
};

struct refAM35_ed929f4c9bbc0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsed929f4c9bbc0& _31, thread float4& gl_FragCoord, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float rad = _31.angle * 0.01745329983532428741455078125;
    float adjStrength = _31.strengthh / 8.0;
    float2 offset = float2(cos(rad) * adjStrength, (-sin(rad)) * adjStrength);
    float2 sampleLow = (float4(((gl_FragCoord.xy - _31.refLayer.xy) / _31.refLayer.zw) - offset, 0.0, 1.0) * _31.refLayerToScreen).xy;
    float2 sampleHigh = (float4(((gl_FragCoord.xy - _31.refLayer.xy) / _31.refLayer.zw) + offset, 0.0, 1.0) * _31.refLayerToScreen).xy;
    float2 param = sampleLow;
    float4 colorLow = texture2DCv(refBuffer1, refBuffer1Smplr, param);
    float2 param_1 = sampleHigh;
    float4 colorHigh = texture2DCv(refBuffer1, refBuffer1Smplr, param_1);
    float2 param_2 = gl_FragCoord.xy / _31.refScreen.xy;
    float4 colorMid = texture2DCv(refInput, refInputSmplr, param_2);
    float4 outColor;
    if (_31.centerChannel == 0)
    {
        outColor = float4(colorMid.x, colorLow.y, colorHigh.z, 1.0);
    }
    else
    {
        if (_31.centerChannel == 1)
        {
            outColor = float4(colorLow.x, colorMid.y, colorHigh.z, 1.0);
        }
        else
        {
            outColor = float4(colorLow.x, colorHigh.y, colorMid.z, 1.0);
        }
    }
    if (_31.mode == 0)
    {
        referenceColor = outColor * colorMid.w;
    }
    else
    {
        if (_31.mode == 1)
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
            if (_31.mode == 2)
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

fragment refAM35_ed929f4c9bbc0_out refAM35_ed929f4c9bbc0(constant ReferenceUniformsed929f4c9bbc0& _31 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed929f4c9bbc0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_31, gl_FragCoord, refBuffer1, refBuffer1Smplr, refInput, refInputSmplr, referenceColor);
    bool _271 = any(isnan(referenceColor));
    bool _278;
    if (!_271)
    {
        _278 = any(isinf(referenceColor));
    }
    else
    {
        _278 = _271;
    }
    if (_278)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _291 = referenceColor;
    float3 _297 = fast::clamp(_291.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _297.x;
    referenceColor.y = _297.y;
    referenceColor.z = _297.z;
    out.finalColor = referenceColor;
    return out;
}

