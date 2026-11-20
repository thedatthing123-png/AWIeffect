// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/findedges.xml
// Original source comments and attribution:
//mat3 m = mat3( nw, n, ne,
//               w, 0., e,
//               sw, s, se );
//mat3 v = mat3( 3., 10., 3.,
//               0., 0., 0.,
//               -3., -10., -3.);
//mat3 h = mat3( -3., 0., 3.,
//               -10., 0., 10.,
//               -3., 0., 3.);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse48da38194e65
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float smoothing;
    char _m6_pad[12];
    float threshold;
    char _m7_pad[12];
    uint invert;
};

struct refAM35_e48da38194e65_out
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
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse48da38194e65& _41, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st = gl_FragCoord.xy / _41.refScreen.xy;
    float2 param = _41.refScreen.xy;
    float2 fragSize = (float2(1.0) / getTexSize(param)) * _41.smoothing;
    float2 param_1 = float2((gl_FragCoord.xy / _41.refScreen.xy).x - fragSize.x, (gl_FragCoord.xy / _41.refScreen.xy).y);
    float w = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_1).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_2 = float2((gl_FragCoord.xy / _41.refScreen.xy).x + fragSize.x, (gl_FragCoord.xy / _41.refScreen.xy).y);
    float e = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_2).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_3 = float2((gl_FragCoord.xy / _41.refScreen.xy).x, (gl_FragCoord.xy / _41.refScreen.xy).y + fragSize.y);
    float n = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_3).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_4 = float2((gl_FragCoord.xy / _41.refScreen.xy).x, (gl_FragCoord.xy / _41.refScreen.xy).y - fragSize.y);
    float s = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_4).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_5 = float2((gl_FragCoord.xy / _41.refScreen.xy).x - fragSize.x, (gl_FragCoord.xy / _41.refScreen.xy).y + fragSize.y);
    float nw = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_5).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_6 = float2((gl_FragCoord.xy / _41.refScreen.xy).x + fragSize.x, (gl_FragCoord.xy / _41.refScreen.xy).y + fragSize.y);
    float ne = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_6).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_7 = float2((gl_FragCoord.xy / _41.refScreen.xy).x - fragSize.x, (gl_FragCoord.xy / _41.refScreen.xy).y - fragSize.y);
    float sw = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_7).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_8 = float2((gl_FragCoord.xy / _41.refScreen.xy).x + fragSize.x, (gl_FragCoord.xy / _41.refScreen.xy).y - fragSize.y);
    float se = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_8).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float v = (((((nw * 3.0) + (n * 10.0)) + (ne * 3.0)) + (sw * (-3.0))) + (s * (-10.0))) + (se * (-3.0));
    float h = (((((nw * (-3.0)) + (w * (-10.0))) + (sw * (-3.0))) + (ne * 3.0)) + (e * 10.0)) + (se * 3.0);
    float g = fast::clamp(sqrt((h * h) + (v * v)) - _41.threshold, 0.0, 1.0);
    float2 param_9 = gl_FragCoord.xy / _41.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_9);
    if (_41.invert != 0u)
    {
        referenceColor = float4(g, g, g, 1.0) * texColor;
    }
    else
    {
        referenceColor = float4(1.0 - g, 1.0 - g, 1.0 - g, 1.0) * texColor.w;
    }
}

fragment refAM35_e48da38194e65_out refAM35_e48da38194e65(constant ReferenceUniformse48da38194e65& _41 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e48da38194e65_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _41, refInput, refInputSmplr, referenceColor);
    bool _373 = any(isnan(referenceColor));
    bool _380;
    if (!_373)
    {
        _380 = any(isinf(referenceColor));
    }
    else
    {
        _380 = _373;
    }
    if (_380)
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

