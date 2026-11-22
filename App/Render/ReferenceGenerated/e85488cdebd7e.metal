// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/mattefringe.xml
// Original source comments and attribution:
//float radius=max(max(innerBorderSize,outerBorderSize),centerBorderSize)*MULTISAMPLE;
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
// Final pass
//vec4 outColor = outerBorderSize<0.003 ? vec4(0.0)  : mix(outerBorderColor,  vec4(0.0), smoothstep(1.0-1.5/outerBorderSize,1.0,nearestOutside/(outerBorderSize/MULTISAMPLE)));
//vec4 inColor = innerBorderSize<0.003 ? vec4(0.0)   : mix(innerBorderColor,  vec4(0.0), smoothstep(1.0-1.5/innerBorderSize,1.0,nearestInside/(innerBorderSize/MULTISAMPLE))) * original.a;
//vec4 midColor = centerBorderSize<0.003 ? vec4(0.0) : mix(centerBorderColor, vec4(0.0), smoothstep(1.0-1.5/centerBorderSize,1.0,nearestMid/(centerBorderSize/MULTISAMPLE)));
//if(invert) {
//}
//vec4 result = outColor;
//result = original + result*(1.0-original.a);
//result = inColor + result*(1.0-inColor.a);
//result = midColor + result*(1.0-midColor.a);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse85488cdebd7e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float thickness;
    char _m6_pad[12];
    float feather;
    float4 excludeColor1;
    float threshold1;
    float4 excludeColor2;
    float threshold2;
    float4 excludeColor3;
    float threshold3;
};

struct refAM35_e85488cdebd7e_out
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
void referenceMain(constant ReferenceUniformse85488cdebd7e& _71, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float radius = _71.thickness * 1.0;
    int from = -max(1, int(radius));
    int to = max(1, int(radius));
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 imgSize = getTexSize(param);
    float px = 1.0 / imgSize.x;
    float py = 1.0 / imgSize.y;
    if (as_type<int>(_71.refComposition.z) == 0)
    {
        float nearestOutside = 16383.0;
        float nearestInside = 16383.0;
        float _165;
        float _180;
        for (int i = from; i < to; i++)
        {
            float x = float(i);
            float2 param_1 = float2((gl_FragCoord.xy / _71.refScreen.xy).x + (x * (px / 1.0)), (gl_FragCoord.xy / _71.refScreen.xy).y);
            float4 ref_sample = texture2DCv(refInput, refInputSmplr, param_1);
            if (ref_sample.w > 0.0)
            {
                _165 = abs(x);
            }
            else
            {
                _165 = radius * 2.0;
            }
            float xdistOut = _165;
            if (ref_sample.w < 0.0030000000260770320892333984375)
            {
                _180 = abs(x);
            }
            else
            {
                _180 = radius * 2.0;
            }
            float xdistIn = _180;
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
            float2 param_4 = float2((gl_FragCoord.xy / _71.refScreen.xy).x, (gl_FragCoord.xy / _71.refScreen.xy).y + (y * (py / 1.0)));
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
        float2 param_7 = gl_FragCoord.xy / _71.refScreen.xy;
        float4 original = texture2DCv(refInput, refInputSmplr, param_7);
        float _302;
        if (_71.thickness > 0.0)
        {
            _302 = smoothstep((1.0 - (1.5 / _71.thickness)) * (1.0 - _71.feather), 1.0, nearestInside_1 / (_71.thickness / 1.0));
        }
        else
        {
            _302 = 1.0;
        }
        float inAlpha = _302;
        inAlpha = 1.0 - inAlpha;
        float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
        float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
        float2 param_8 = gl_FragCoord.xy / _71.refScreen.xy;
        float4 bg = texture2DCv(refReference, refReferenceSmplr, param_8);
        float3 bgyuv = bg.xyz * rgb2yuv;
        float3 fgyuv = original.xyz * rgb2yuv;
        float3 exclyuv1 = _71.excludeColor1.xyz * rgb2yuv;
        float tt1 = smoothstep(0.0, _71.threshold1, length(exclyuv1.yz - fgyuv.yz));
        float3 exclyuv2 = _71.excludeColor2.xyz * rgb2yuv;
        float tt2 = smoothstep(0.0, _71.threshold2, length(exclyuv2.yz - fgyuv.yz));
        float3 exclyuv3 = _71.excludeColor3.xyz * rgb2yuv;
        float tt3 = smoothstep(0.0, _71.threshold3, length(exclyuv3.yz - fgyuv.yz));
        float3 adj = float3(fgyuv.x, mix(fgyuv.yz, bgyuv.yz, float2((((inAlpha * original.w) * tt1) * tt2) * tt3))) * yuv2rgb;
        referenceColor = float4(adj, original.w);
    }
}

fragment refAM35_e85488cdebd7e_out refAM35_e85488cdebd7e(constant ReferenceUniformse85488cdebd7e& _71 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refReference [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refReferenceSmplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_e85488cdebd7e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_71, refInput, refInputSmplr, gl_FragCoord, referenceColor, refBuffer1, refBuffer1Smplr, refReference, refReferenceSmplr);
    bool _462 = any(isnan(referenceColor));
    bool _469;
    if (!_462)
    {
        _469 = any(isinf(referenceColor));
    }
    else
    {
        _469 = _462;
    }
    if (_469)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _482 = referenceColor;
    float3 _488 = fast::clamp(_482.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _488.x;
    referenceColor.y = _488.y;
    referenceColor.z = _488.z;
    out.finalColor = referenceColor;
    return out;
}

