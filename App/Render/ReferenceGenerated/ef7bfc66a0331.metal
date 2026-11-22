// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxfloorgrid.xml
// Original source comments and attribution:
/////////////////////////
// Created by Per Bloksgaard/2020
// if (adaptive) { syamjaidtz = acScreenNorm; }
// else { 
// }
// syamjaidtz /= scale;
/////////////////////////
// vec3 tot = texture2DCv(inputImg.texture,syamjaidtz).rgb;
// vec2 s = (-acScreenNorm + 2.0*(acScreenNorm+o));
// vec2 s = (-acScreenNorm + 2.0*(acScreenNorm+o))/acScreenSize.y;
// tot += mix(vec3(.79,.88,1.), vec3(1.-max(bV,sV)), exp2(-.12*length(vCamPos.xz - vHitPos.xz)));
// normal
// resultfinal = (factor * bright) * texColor.a;
// multiply
// factor *= bright;
// screen
// factor *= bright;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef7bfc66a0331
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 colora;
    float3 position;
    float progressa;
    char _m8_pad[12];
    float progressb;
    char _m9_pad[12];
    float angle;
    char _m10_pad[12];
    float progressh;
    char _m11_pad[12];
    float progressg;
    char _m12_pad[12];
    float bright;
    char _m13_pad[12];
    float alpha;
    char _m14_pad[12];
    uint gradient;
    float4 color1;
    float4 color2;
    int blendMode;
};

struct refAM35_ef7bfc66a0331_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float derivative(thread const float2& p, constant ReferenceUniformsef7bfc66a0331& _67)
{
    float2 dx = float2(0.0);
    float2 dy = float2(0.0);
    float2 d = p - floor(p);
    return exp2(((-_67.progressh) * fast::min((1.0 - d.x) * d.x, (1.0 - d.y) * d.y)) / ((dot(dx, dy) + dot(dy, dy)) + 0.00200000009499490261077880859375));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsef7bfc66a0331& _67, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _67.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _67.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _67.refScreen.xy).y) * _67.refScreen.xy) - float2(_67.refLayer.x + (_67.refLayer.z * 0.5), (_67.refScreen.y - _67.refLayer.y) - (_67.refLayer.w * 0.5))) / _67.refLayer.zw;
    syamjaidtz.y *= (_67.refLayer.w / _67.refLayer.z);
    syamjaidtz /= float2(_67.position.z / 100.0);
    float param_1 = ((-180.0) + _67.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((float2(_67.position.x, _67.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float3 tot = float3(0.0);
    float u = _67.progressa * 0.20000000298023223876953125;
    float v = -2.199099063873291015625;
    float f = 0.877582550048828125 * _67.progressb;
    float3 vCamTarget = float3(0.0, 0.20000000298023223876953125, 0.0);
    float3 vCamPos = float3((cos(u) * sin(v)) * 2.0, 0.4000000059604644775390625 + f, sin(u) * sin(v));
    float3 vCamForward = fast::normalize(vCamTarget - vCamPos);
    float3 vCamRight = fast::normalize(cross(vCamForward, float3(0.0, 1.0, 0.0)));
    float3 vCamUp = fast::normalize(cross(vCamRight, vCamForward));
    for (int m = -1; m < 2; m++)
    {
        for (int n = -1; n < 2; n++)
        {
            float2 o = float2(float(m), float(n)) * 0.5;
            float2 s = syamjaidtz;
            float3 vRayDir = fast::normalize(((vCamRight * s.x) + (vCamUp * s.y)) + (vCamForward * 1.5));
            float d = (-vCamPos.y) / fast::min(vRayDir.y, -9.9999999747524270787835121154785e-07);
            float3 vHitPos = vCamPos + (vRayDir * d);
            float2 param_2 = vHitPos.xz * 2.0;
            float sV = _67.progressg * derivative(param_2, _67);
            float2 param_3 = vHitPos.xz;
            float bV = derivative(param_3, _67);
            tot += mix(_67.colora.xyz, float3(1.0 - fast::max(bV, sV)), float3(exp2((-0.119999997317790985107421875) * length(vCamPos.xz - vHitPos.xz))));
        }
    }
    tot *= 0.111111111938953399658203125;
    float4 result = float4(tot, 1.0);
    float luminance = dot(result.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 gradmap = mix(_67.color1, _67.color2, float4(luminance)) * result.w;
    float4 factor;
    if (_67.gradient != 0u)
    {
        factor = mix(texColorX, gradmap, float4(1.0)) * _67.bright;
    }
    else
    {
        factor = mix(texColorX, result, float4(1.0)) * _67.bright;
    }
    float4 oriTex = mix(texColor, factor, float4(_67.alpha));
    float4 resultfinal;
    if (_67.blendMode == 0)
    {
        resultfinal = oriTex * texColor.w;
    }
    else
    {
        if (_67.blendMode == 1)
        {
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_67.blendMode == 2)
            {
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - oriTex.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = resultfinal;
}

fragment refAM35_ef7bfc66a0331_out refAM35_ef7bfc66a0331(constant ReferenceUniformsef7bfc66a0331& _67 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef7bfc66a0331_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_67, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _500 = any(isnan(referenceColor));
    bool _507;
    if (!_500)
    {
        _507 = any(isinf(referenceColor));
    }
    else
    {
        _507 = _500;
    }
    if (_507)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _520 = referenceColor;
    float3 _526 = fast::clamp(_520.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _526.x;
    referenceColor.y = _526.y;
    referenceColor.z = _526.z;
    out.finalColor = referenceColor;
    return out;
}

