// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxssswirl.xml
// Original source comments and attribution:
// -- layer coordinates boilerplate --
// This get 0.0~1.0 coordinates inside layer (if layer is not square, one axis will be 1.0 and one will be larger)
//vec2 st = (acScreenNorm.xy*acScreenSize-acLayerCenter)/acLayerSize;
//vec2 ctr = acLayerCenter/acScreenSize;
//vec2 st = ((vec2(acScreenNorm.x,1.0-acScreenNorm.y)*acScreenSize)-acLayerCenter)/acLayerSize;
//st.y*=acLayerSize.y/acLayerSize.x;
// -- end boilerplate --
//-acLayerCenterNorm; //acScreenNorm.xy;
//UV /= 2.0;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsefccbd7a6588a
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

struct refAM35_efccbd7a6588a_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsefccbd7a6588a& _30, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float Radius = _30.radius;
    float T = _30.strength;
    float2 UV = gl_FragCoord.xy / _30.refScreen.xy;
    float2 CENTER = _30.centerPoint * float2(-1.0, 1.0);
    float2 diff1 = float2(_30.refLayer.x + (_30.refLayer.z * 0.5), (_30.refScreen.y - _30.refLayer.y) - (_30.refLayer.w * 0.5)) - CENTER;
    diff1.y = _30.refScreen.y - diff1.y;
    float2 diff = diff1 / _30.refScreen.xy;
    UV -= diff;
    float2 convRate = float2(1.0);
    if (_30.refScreen.y > _30.refScreen.x)
    {
        convRate.y = _30.refScreen.y / _30.refScreen.x;
    }
    else
    {
        convRate.x = _30.refScreen.x / _30.refScreen.y;
    }
    UV *= convRate;
    float Dist = length(UV);
    if (Dist < Radius)
    {
        float Percent = (Radius - Dist) / Radius;
        float _144;
        if (T <= 0.5)
        {
            _144 = mix(0.0, 1.0, T / 0.5);
        }
        else
        {
            _144 = mix(1.0, 0.0, (T - 0.5) / 0.5);
        }
        float A = _144;
        float Theta = (((Percent * Percent) * A) * 8.0) * 3.141590118408203125;
        float S = sin(Theta);
        float C = cos(Theta);
        UV = float2(dot(UV, float2(C, -S)), dot(UV, float2(S, C)));
    }
    UV /= convRate;
    UV += diff;
    float2 param = UV;
    referenceColor = texture2DCv(refInput, refInputSmplr, param);
}

fragment refAM35_efccbd7a6588a_out refAM35_efccbd7a6588a(constant ReferenceUniformsefccbd7a6588a& _30 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_efccbd7a6588a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_30, gl_FragCoord, referenceColor, refInput, refInputSmplr);
    bool _202 = any(isnan(referenceColor));
    bool _209;
    if (!_202)
    {
        _209 = any(isinf(referenceColor));
    }
    else
    {
        _209 = _202;
    }
    if (_209)
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

