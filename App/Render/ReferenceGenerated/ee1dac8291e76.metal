// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/mattechoke2.xml
// Original source comments and attribution:
//float radius=max(max(innerBorderSize,outerBorderSize),centerBorderSize)*MULTISAMPLE;
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
// Final pass
//vec4 outColor = outerBorderSize<0.003 ? vec4(0.0)  : mix(outerBorderColor,  vec4(0.0), smoothstep(1.0-1.5/outerBorderSize,1.0,nearestOutside/(outerBorderSize/MULTISAMPLE)));
//vec4 inColor = innerBorderSize<0.003 ? vec4(0.0)   : mix(innerBorderColor,  vec4(0.0), smoothstep(1.0-1.5/innerBorderSize,1.0,nearestInside/(innerBorderSize/MULTISAMPLE))) * original.a;
//vec4 midColor = centerBorderSize<0.003 ? vec4(0.0) : mix(centerBorderColor, vec4(0.0), smoothstep(1.0-1.5/centerBorderSize,1.0,nearestMid/(centerBorderSize/MULTISAMPLE)));
//vec4 result = outColor;
//result = original + result*(1.0-original.a);
//result = inColor + result*(1.0-inColor.a);
//result = midColor + result*(1.0-midColor.a);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsee1dac8291e76
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float choke;
    char _m6_pad[12];
    float feather;
    char _m7_pad[12];
    uint invert;
};

struct refAM35_ee1dac8291e76_out
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
float2 encodeFloat(thread const float& v)
{
    float2 enc = fract(float2(1.0, 255.0) * v);
    enc.x -= (enc.y / 255.0);
    return enc;
}

static inline __attribute__((always_inline))
float decodeFloat(thread const float2& v)
{
    return dot(v, float2(1.0, 0.0039215688593685626983642578125));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformsee1dac8291e76& _82, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 imgSize = getTexSize(param);
    float chokeConv = (_82.choke * length(imgSize)) / 1448.1546630859375;
    float radius = chokeConv * 1.0;
    int from = -max(1, int(radius));
    int to = max(1, int(radius));
    float px = 1.0 / imgSize.x;
    float py = 1.0 / imgSize.y;
    if (as_type<int>(_82.refComposition.z) == 0)
    {
        float nearestOutside = 16383.0;
        float nearestInside = 16383.0;
        float _172;
        float _187;
        for (int i = from; i < to; i++)
        {
            float x = float(i);
            float2 param_1 = float2((gl_FragCoord.xy / _82.refScreen.xy).x + (x * (px / 1.0)), (gl_FragCoord.xy / _82.refScreen.xy).y);
            float4 ref_sample = texture2DCv(refInput, refInputSmplr, param_1);
            if (ref_sample.w > 0.0)
            {
                _172 = abs(x);
            }
            else
            {
                _172 = radius * 2.0;
            }
            float xdistOut = _172;
            if (ref_sample.w < 0.0030000000260770320892333984375)
            {
                _187 = abs(x);
            }
            else
            {
                _187 = radius * 2.0;
            }
            float xdistIn = _187;
            nearestOutside = fast::min(nearestOutside, xdistOut);
            nearestInside = fast::min(nearestInside, xdistIn);
        }
        float param_2 = nearestOutside / 16383.0;
        float param_3 = nearestInside / 16383.0;
        referenceColor = float4(encodeFloat(param_2), encodeFloat(param_3));
    }
    else
    {
        float nearestOutside_1 = 16383.0;
        float nearestInside_1 = 16383.0;
        for (int i_1 = from; i_1 < to; i_1++)
        {
            float y = float(i_1);
            float2 param_4 = float2((gl_FragCoord.xy / _82.refScreen.xy).x, (gl_FragCoord.xy / _82.refScreen.xy).y + (y * (py / 1.0)));
            float4 ref_sample_1 = texture2DCv(refBuffer1, refBuffer1Smplr, param_4);
            float2 param_5 = ref_sample_1.xy;
            float xdistOut_1 = decodeFloat(param_5) * 16383.0;
            float2 param_6 = ref_sample_1.zw;
            float xdistIn_1 = decodeFloat(param_6) * 16383.0;
            float ydist = abs(y);
            float distOut = length(float2(xdistOut_1, ydist));
            float distIn = length(float2(xdistIn_1, ydist));
            nearestInside_1 = fast::min(nearestInside_1, distIn);
            nearestOutside_1 = fast::min(nearestOutside_1, distOut);
        }
        float nearestMid = fast::max(nearestInside_1, nearestOutside_1);
        float2 param_7 = gl_FragCoord.xy / _82.refScreen.xy;
        float4 original = texture2DCv(refInput, refInputSmplr, param_7);
        float _308;
        if (chokeConv > 0.0)
        {
            _308 = smoothstep((1.0 - (1.5 / chokeConv)) * (1.0 - _82.feather), 1.0, nearestInside_1 / (chokeConv / 1.0));
        }
        else
        {
            _308 = 1.0;
        }
        float inAlpha = _308;
        if (_82.invert != 0u)
        {
            inAlpha = 1.0 - inAlpha;
        }
        referenceColor = original * inAlpha;
    }
}

fragment refAM35_ee1dac8291e76_out refAM35_ee1dac8291e76(constant ReferenceUniformsee1dac8291e76& _82 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ee1dac8291e76_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _82, gl_FragCoord, referenceColor, refBuffer1, refBuffer1Smplr);
    bool _344 = any(isnan(referenceColor));
    bool _351;
    if (!_344)
    {
        _351 = any(isinf(referenceColor));
    }
    else
    {
        _351 = _344;
    }
    if (_351)
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

