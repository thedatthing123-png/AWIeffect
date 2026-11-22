// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/streaks-linear.xml
// Original source comments and attribution:
//velocity *= acPreviewSize/getTexSize(inputImg.size);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea1a6411e3d41
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float angle;
    char _m7_pad[12];
    float alpha;
    char _m8_pad[12];
    float bias0;
    char _m9_pad[12];
    int rmode;
    char _m10_pad[12];
    int gmode;
    char _m11_pad[12];
    int bmode;
    char _m12_pad[12];
    int amode;
};

struct refAM35_ea1a6411e3d41_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformsea1a6411e3d41& _51, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texelSize = float2(1.0) / getTexSize(param);
    float rad = _51.angle * 0.01745329983532428741455078125;
    float2 velocity = float2(cos(rad) * _51.strength, (-sin(rad)) * _51.strength);
    velocity.x *= (_51.refScreen.y / _51.refScreen.x);
    float speed = length(velocity / texelSize);
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
    float2 param_1 = gl_FragCoord.xy / _51.refScreen.xy;
    float4 originalColor = texture2DCv(refInput, refInputSmplr, param_1);
    float4 outColor = originalColor;
    float3 _119;
    if (outColor.w > 0.0)
    {
        _119 = outColor.xyz / float3(outColor.w);
    }
    else
    {
        _119 = outColor.xyz;
    }
    outColor.x = _119.x;
    outColor.y = _119.y;
    outColor.z = _119.z;
    float r;
    float g;
    float b;
    float a;
    for (int i = 1; i < nSamples; i++)
    {
        float2 offset = velocity * ((float(i) / float(nSamples - 1)) - (0.5 + (_51.bias0 / 2.0)));
        float2 sampleCoord = (gl_FragCoord.xy / _51.refScreen.xy) - offset;
        float insideTexture = ((step(0.0, sampleCoord.x) * step(sampleCoord.x, 1.0)) * step(0.0, sampleCoord.y)) * step(sampleCoord.y, 1.0);
        float2 param_2 = sampleCoord;
        float4 c = texture2DCv(refInput, refInputSmplr, param_2) * insideTexture;
        if (_51.rmode == 0)
        {
            r = fast::min(outColor.x, c.x);
        }
        else
        {
            if (_51.rmode == 1)
            {
                r = fast::max(outColor.x, c.x);
            }
            else
            {
                if (_51.rmode == 3)
                {
                    r = outColor.x + c.x;
                }
                else
                {
                    r = outColor.x;
                }
            }
        }
        if (_51.gmode == 0)
        {
            g = fast::min(outColor.y, c.y);
        }
        else
        {
            if (_51.gmode == 1)
            {
                g = fast::max(outColor.y, c.y);
            }
            else
            {
                if (_51.gmode == 3)
                {
                    g = outColor.y + c.y;
                }
                else
                {
                    g = outColor.y;
                }
            }
        }
        if (_51.bmode == 0)
        {
            b = fast::min(outColor.z, c.z);
        }
        else
        {
            if (_51.bmode == 1)
            {
                b = fast::max(outColor.z, c.z);
            }
            else
            {
                if (_51.bmode == 3)
                {
                    b = outColor.z + c.z;
                }
                else
                {
                    b = outColor.z;
                }
            }
        }
        if (_51.amode == 0)
        {
            a = fast::min(outColor.w, c.w);
        }
        else
        {
            if (_51.amode == 1)
            {
                a = fast::max(outColor.w, c.w);
            }
            else
            {
                if (_51.amode == 3)
                {
                    a = outColor.w + c.w;
                }
                else
                {
                    a = outColor.w;
                }
            }
        }
        outColor = float4(r, g, b, a);
    }
    float _358;
    if (_51.rmode == 3)
    {
        _358 = float(nSamples);
    }
    else
    {
        _358 = 1.0;
    }
    float _368;
    if (_51.gmode == 3)
    {
        _368 = float(nSamples);
    }
    else
    {
        _368 = 1.0;
    }
    float _378;
    if (_51.bmode == 3)
    {
        _378 = float(nSamples);
    }
    else
    {
        _378 = 1.0;
    }
    float _388;
    if (_51.amode == 3)
    {
        _388 = float(nSamples);
    }
    else
    {
        _388 = 1.0;
    }
    outColor /= float4(_358, _368, _378, _388);
    float _398 = outColor.w;
    float4 _399 = outColor;
    float3 _401 = _399.xyz * _398;
    outColor.x = _401.x;
    outColor.y = _401.y;
    outColor.z = _401.z;
    referenceColor = mix(originalColor, outColor, float4(_51.alpha));
}

fragment refAM35_ea1a6411e3d41_out refAM35_ea1a6411e3d41(constant ReferenceUniformsea1a6411e3d41& _51 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea1a6411e3d41_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _51, gl_FragCoord, referenceColor);
    bool _422 = any(isnan(referenceColor));
    bool _429;
    if (!_422)
    {
        _429 = any(isinf(referenceColor));
    }
    else
    {
        _429 = _422;
    }
    if (_429)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _442 = referenceColor;
    float3 _448 = fast::clamp(_442.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _448.x;
    referenceColor.y = _448.y;
    referenceColor.z = _448.z;
    out.finalColor = referenceColor;
    return out;
}

