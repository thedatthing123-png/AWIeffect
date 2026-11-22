// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/internal-border.xml
// Original source comments and attribution:
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
// Final pass
#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wmissing-braces"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

template<typename T, size_t Num>
struct spvUnsafeArray
{
    T elements[Num ? Num : 1];
    
    thread T& operator [] (size_t pos) thread
    {
        return elements[pos];
    }
    constexpr const thread T& operator [] (size_t pos) const thread
    {
        return elements[pos];
    }
    
    device T& operator [] (size_t pos) device
    {
        return elements[pos];
    }
    constexpr const device T& operator [] (size_t pos) const device
    {
        return elements[pos];
    }
    
    constexpr const constant T& operator [] (size_t pos) const constant
    {
        return elements[pos];
    }
    
    threadgroup T& operator [] (size_t pos) threadgroup
    {
        return elements[pos];
    }
    constexpr const threadgroup T& operator [] (size_t pos) const threadgroup
    {
        return elements[pos];
    }
};

struct ReferenceUniformse9493bb625413
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
    char _m12_pad[12];
    float b2size;
    float4 b2color;
    int b2direction;
    char _m15_pad[12];
    float b3size;
    float4 b3color;
    int b3direction;
    char _m18_pad[12];
    float b4size;
    float4 b4color;
    int b4direction;
    char _m21_pad[12];
    float b5size;
    float4 b5color;
    int b5direction;
    char _m24_pad[12];
    float b6size;
    float4 b6color;
    int b6direction;
    char _m27_pad[12];
    float b7size;
    float4 b7color;
    int b7direction;
    char _m30_pad[12];
    float b8size;
    float4 b8color;
    int b8direction;
};

struct Border
{
    int direction;
    float size;
    float4 color;
};

struct refAM35_e9493bb625413_out
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
void referenceMain(constant ReferenceUniformse9493bb625413& _72, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float radius = _72.maxsize * 1.0;
    int from = -max(1, int(radius));
    int to = max(1, int(radius));
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 fullViewSize = getTexSize(param);
    float px = 1.0 / fullViewSize.x;
    float py = 1.0 / fullViewSize.y;
    if (as_type<int>(_72.refComposition.z) == 0)
    {
        float nearestOutside = 16383.0;
        float nearestInside = 16383.0;
        float _165;
        float _180;
        for (int i = from; i < to; i++)
        {
            float x = float(i);
            float2 param_1 = float2((gl_FragCoord.xy / _72.refScreen.xy).x + (x * (px / 1.0)), (gl_FragCoord.xy / _72.refScreen.xy).y);
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
        spvUnsafeArray<Border, 8> borders;
        borders[0].direction = _72.b0direction;
        borders[0].size = _72.b0size;
        borders[0].color = _72.b0color;
        borders[1].direction = _72.b1direction;
        borders[1].size = _72.b1size;
        borders[1].color = _72.b1color;
        borders[2].direction = _72.b2direction;
        borders[2].size = _72.b2size;
        borders[2].color = _72.b2color;
        borders[3].direction = _72.b3direction;
        borders[3].size = _72.b3size;
        borders[3].color = _72.b3color;
        borders[4].direction = _72.b4direction;
        borders[4].size = _72.b4size;
        borders[4].color = _72.b4color;
        borders[5].direction = _72.b5direction;
        borders[5].size = _72.b5size;
        borders[5].color = _72.b5color;
        borders[6].direction = _72.b6direction;
        borders[6].size = _72.b6size;
        borders[6].color = _72.b6color;
        borders[7].direction = _72.b7direction;
        borders[7].size = _72.b7size;
        borders[7].color = _72.b7color;
        float4 result = original;
        for (int i_2 = 0; i_2 < 8; i_2++)
        {
            int direction = borders[i_2].direction;
            float4 color = borders[i_2].color;
            float size = borders[i_2].size;
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
        }
        referenceColor = result;
    }
}

fragment refAM35_e9493bb625413_out refAM35_e9493bb625413(constant ReferenceUniformse9493bb625413& _72 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9493bb625413_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_72, refInput, refInputSmplr, gl_FragCoord, referenceColor, refBuffer1, refBuffer1Smplr);
    bool _516 = any(isnan(referenceColor));
    bool _523;
    if (!_516)
    {
        _523 = any(isinf(referenceColor));
    }
    else
    {
        _523 = _516;
    }
    if (_523)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _537 = referenceColor;
    float3 _543 = fast::clamp(_537.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _543.x;
    referenceColor.y = _543.y;
    referenceColor.z = _543.z;
    out.finalColor = referenceColor;
    return out;
}

