// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxobjectevo.xml
// Original source comments and attribution:
//vec2 projectAndClamp(vec2 a, vec2 b) {
//    return clamp(dot(a,b)/dot(b,b),0.0,1.0) * b;
//}
//vec2 v = (vec4(normalize(vec2(cos(radwipe),-sin(radwipe))),0.0,1.0) * acLayerToScreen).xy;
//float p = length(projectAndClamp(acLayerNorm.st-vec2(0.5,0.5), v))/length(v)+0.5;
//////////////////////////
//////////////////////////
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse88d742244e73
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float posx;
    char _m6_pad[12];
    float posy;
    char _m7_pad[12];
    float posz;
    char _m8_pad[12];
    float angle;
    char _m9_pad[12];
    float alpha;
    char _m10_pad[12];
    float scale;
    char _m11_pad[12];
    float anglea;
    char _m12_pad[12];
    uint pinch;
    char _m13_pad[8];
    float2 centerPoint;
    char _m14_pad[8];
    float strength;
    char _m15_pad[12];
    float radius;
    char _m16_pad[12];
    uint syamjaidtz;
    char _m17_pad[12];
    float start;
    char _m18_pad[12];
    float end;
    char _m19_pad[12];
    float angleb;
    char _m20_pad[12];
    float feather;
    float4 color;
    float alphaa;
    char _m23_pad[12];
    int blendMode;
    char _m24_pad[12];
    uint zinv;
    char _m25_pad[12];
    uint xinv;
    char _m26_pad[12];
    uint yinv;
    char _m27_pad[12];
    uint ainv;
};

struct refAM35_e88d742244e73_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float smoothstepRev(thread const float& edge0, thread const float& edge1, thread const float& x)
{
    if (edge0 == edge1)
    {
        return step(edge0, x);
    }
    else
    {
        return smoothstep(edge0, edge1, x);
    }
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse88d742244e73& _55, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float adjStart = _55.start;
    float adjEnd = _55.end;
    float adjFeather = _55.feather / 100.0;
    float radwipe = _55.angleb * 0.01745329983532428741455078125;
    float2 v = fast::normalize(float2(cos(radwipe), -sin(radwipe)));
    float p = dot(((gl_FragCoord.xy - _55.refLayer.xy) / _55.refLayer.zw) - float2(0.5), v) + 0.5;
    float param = adjStart - adjFeather;
    float param_1 = adjStart;
    float param_2 = p;
    float p0 = smoothstepRev(param, param_1, param_2);
    float param_3 = adjEnd;
    float param_4 = adjEnd + adjFeather;
    float param_5 = p;
    float p1 = 1.0 - smoothstepRev(param_3, param_4, param_5);
    float rad = _55.anglea * 0.01745329983532428741455078125;
    float2x2 rot = float2x2(float2(cos(rad), -sin(rad)), float2(sin(rad), cos(rad)));
    float2x2 invrot = float2x2(float2(cos(-rad), -sin(-rad)), float2(sin(-rad), cos(-rad)));
    float2 sampleCoord = ((((((gl_FragCoord.xy - _55.refLayer.xy) / _55.refLayer.zw) - float2(0.5)) * rot) * float2(1.0 / _55.scale, 1.0)) * invrot) + float2(0.5);
    sampleCoord = (float4(sampleCoord, 0.0, 1.0) * _55.refLayerToScreen).xy;
    if (_55.pinch != 0u)
    {
        float2 center = (float2(_55.refLayer.x + (_55.refLayer.z * 0.5), (_55.refScreen.y - _55.refLayer.y) - (_55.refLayer.w * 0.5)) / _55.refScreen.xy) - ((_55.centerPoint / float2(1000.0)) * float2(-1.0, 1.0));
        sampleCoord -= center;
        sampleCoord.x *= (_55.refScreen.x / _55.refScreen.y);
        float dist = length(sampleCoord);
        if (dist < _55.radius)
        {
            float p_1 = dist / fast::max(abs(_55.radius), 9.9999997473787516355514526367188e-05);
            if (_55.strength > 0.0)
            {
                sampleCoord *= mix(1.0, smoothstep(0.0, _55.radius / fast::max(abs(dist), 9.9999997473787516355514526367188e-05), p_1), _55.strength * 0.75);
            }
            else
            {
                sampleCoord *= mix(1.0, (powr(p_1, 1.0 + (_55.strength * 0.75)) * _55.radius) / fast::max(abs(dist), 9.9999997473787516355514526367188e-05), 1.0 - p_1);
            }
        }
        sampleCoord.x /= (_55.refScreen.x / _55.refScreen.y);
        sampleCoord += center;
    }
    float4 texColor;
    if (_55.syamjaidtz != 0u)
    {
        float2 param_6 = sampleCoord;
        texColor = ((texture2DCv(refInput, refInputSmplr, param_6) * p0) * p1) * _55.alpha;
    }
    else
    {
        float2 param_7 = sampleCoord;
        texColor = texture2DCv(refInput, refInputSmplr, param_7) * _55.alpha;
    }
    float4 result;
    if (_55.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(texColor.w)) * _55.color.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_55.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - _55.color.xyz)), 1.0) * texColor.w;
        }
        else
        {
            result = float4(_55.color.xyz, 1.0) * texColor.w;
        }
    }
    referenceColor = mix(texColor, result, float4(_55.alphaa));
}

fragment refAM35_e88d742244e73_out refAM35_e88d742244e73(constant ReferenceUniformse88d742244e73& _55 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e88d742244e73_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_55, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _435 = any(isnan(referenceColor));
    bool _442;
    if (!_435)
    {
        _442 = any(isinf(referenceColor));
    }
    else
    {
        _442 = _435;
    }
    if (_442)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _455 = referenceColor;
    float3 _461 = fast::clamp(_455.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _461.x;
    referenceColor.y = _461.y;
    referenceColor.z = _461.z;
    out.finalColor = referenceColor;
    return out;
}

