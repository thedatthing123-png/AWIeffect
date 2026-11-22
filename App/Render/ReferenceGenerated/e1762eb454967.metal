// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/internal-border-two.xml
// Original source comments and attribution:
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
// Final pass
// 0
// 1
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse1762eb454967
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float maxsize;
    char _m6_pad[12];
    float b0size;
    float4 b0color;
    int b0direction;
    char _m9_pad[12];
    float b1size;
    float4 b1color;
    int b1direction;
};

struct refAM35_e1762eb454967_out
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
void referenceMain(constant ReferenceUniformse1762eb454967& _72, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float radius = _72.maxsize * 1.0;
    int from = -max(1, int(radius));
    int to = max(1, int(radius));
    float px = 0.00048828125;
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 fullViewSize = getTexSize(param);
    float py = 1.0 / (2048.0 / (fullViewSize.x / fullViewSize.y));
    if (as_type<int>(_72.refComposition.z) == 0)
    {
        float nearestOutside = 16383.0;
        float nearestInside = 16383.0;
        float _168;
        float _183;
        for (int i = from; i < to; i++)
        {
            float x = float(i);
            float2 param_1 = float2((gl_FragCoord.xy / _72.refScreen.xy).x + (x * (px / 1.0)), (gl_FragCoord.xy / _72.refScreen.xy).y);
            float4 ref_sample = texture2DCv(refInput, refInputSmplr, param_1);
            if (ref_sample.w > 0.0)
            {
                _168 = abs(x);
            }
            else
            {
                _168 = radius * 2.0;
            }
            float xdistOut = _168;
            if (ref_sample.w < 0.0030000000260770320892333984375)
            {
                _183 = abs(x);
            }
            else
            {
                _183 = radius * 2.0;
            }
            float xdistIn = _183;
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
            float2 param_4 = float2((gl_FragCoord.xy / _72.refScreen.xy).x, (gl_FragCoord.xy / _72.refScreen.xy).y + (y * (py / 1.0)));
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
        float2 param_7 = gl_FragCoord.xy / _72.refScreen.xy;
        float4 original = texture2DCv(refInput, refInputSmplr, param_7);
        float4 result = original;
        int direction = _72.b0direction;
        float4 color = _72.b0color;
        float size = _72.b0size;
        if (size > 0.0030000000260770320892333984375)
        {
            if (direction == (-1))
            {
                float4 c = mix(color, float4(0.0), float4(smoothstep(1.0 - (1.5 / size), 1.0, nearestInside_1 / (size / 1.0)))) * original.w;
                result = c + (result * (1.0 - c.w));
            }
            else
            {
                if (direction == 0)
                {
                    float4 c_1 = mix(color, float4(0.0), float4(smoothstep(1.0 - (1.5 / size), 1.0, nearestMid / (size / 1.0))));
                    result = c_1 + (result * (1.0 - c_1.w));
                }
                else
                {
                    if (direction == 1)
                    {
                        float4 c_2 = mix(color, float4(0.0), float4(smoothstep(1.0 - (1.5 / size), 1.0, nearestOutside_1 / (size / 1.0)))) * (1.0 - original.w);
                        result += (c_2 * (1.0 - result.w));
                    }
                }
            }
        }
        direction = _72.b1direction;
        color = _72.b1color;
        size = _72.b1size;
        if (size > 0.0030000000260770320892333984375)
        {
            if (direction == (-1))
            {
                float4 c_3 = mix(color, float4(0.0), float4(smoothstep(1.0 - (1.5 / size), 1.0, nearestInside_1 / (size / 1.0)))) * original.w;
                result = c_3 + (result * (1.0 - c_3.w));
            }
            else
            {
                if (direction == 0)
                {
                    float4 c_4 = mix(color, float4(0.0), float4(smoothstep(1.0 - (1.5 / size), 1.0, nearestMid / (size / 1.0))));
                    result = c_4 + (result * (1.0 - c_4.w));
                }
                else
                {
                    if (direction == 1)
                    {
                        float4 c_5 = mix(color, float4(0.0), float4(smoothstep(1.0 - (1.5 / size), 1.0, nearestOutside_1 / (size / 1.0)))) * (1.0 - original.w);
                        result += (c_5 * (1.0 - result.w));
                    }
                }
            }
        }
        referenceColor = result;
    }
}

fragment refAM35_e1762eb454967_out refAM35_e1762eb454967(constant ReferenceUniformse1762eb454967& _72 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e1762eb454967_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_72, refInput, refInputSmplr, gl_FragCoord, referenceColor, refBuffer1, refBuffer1Smplr);
    bool _497 = any(isnan(referenceColor));
    bool _504;
    if (!_497)
    {
        _504 = any(isinf(referenceColor));
    }
    else
    {
        _504 = _497;
    }
    if (_504)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _518 = referenceColor;
    float3 _524 = fast::clamp(_518.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _524.x;
    referenceColor.y = _524.y;
    referenceColor.z = _524.z;
    out.finalColor = referenceColor;
    return out;
}

