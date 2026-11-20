// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/streaks-zoom.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsed2fdd321a8b0
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
    float alpha;
    char _m8_pad[12];
    float bias0;
    char _m9_pad[12];
    uint adaptive;
    char _m10_pad[12];
    int rmode;
    char _m11_pad[12];
    int gmode;
    char _m12_pad[12];
    int bmode;
    char _m13_pad[12];
    int amode;
};

struct refAM35_ed2fdd321a8b0_out
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
void referenceMain(constant ReferenceUniformsed2fdd321a8b0& _39, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 param = _39.refScreen.xy;
    float2 texelSize = float2(1.0) / getTexSize(param);
    float2 center = float2(0.5 + (_39.centerPoint.x / 500.0), 0.5 - (_39.centerPoint.y / 500.0));
    float2 v = (gl_FragCoord.xy / _39.refScreen.xy) - (float4(center, 0.0, 1.0) * _39.refLayerToScreen).xy;
    float speed = length(float2(_39.strength / 2.0) / texelSize);
    if (_39.adaptive != 0u)
    {
        speed *= length(((gl_FragCoord.xy - _39.refLayer.xy) / _39.refLayer.zw) - center);
    }
    else
    {
        speed *= smoothstep(0.0, length(texelSize) * 5.0, length(((gl_FragCoord.xy - _39.refLayer.xy) / _39.refLayer.zw) - center));
    }
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
    float2 param_1 = gl_FragCoord.xy / _39.refScreen.xy;
    float4 originalColor = texture2DCv(refInput, refInputSmplr, param_1);
    float4 outColor = originalColor;
    float2 vnorm = (fast::normalize(v) * texelSize) * speed;
    float2 offsetScale = float2(1.0);
    if (_39.refScreen.y > _39.refScreen.x)
    {
        offsetScale.x *= (_39.refScreen.x / _39.refScreen.y);
    }
    else
    {
        offsetScale.y *= (_39.refScreen.y / _39.refScreen.x);
    }
    float3 _203;
    if (outColor.w > 0.0)
    {
        _203 = outColor.xyz / float3(outColor.w);
    }
    else
    {
        _203 = outColor.xyz;
    }
    outColor.x = _203.x;
    outColor.y = _203.y;
    outColor.z = _203.z;
    float r;
    float g;
    float b;
    float a;
    for (int i = 1; i < nSamples; i++)
    {
        float2 offset = vnorm * ((float(i) / float(nSamples - 1)) - (0.5 + (_39.bias0 / 2.0)));
        offset *= offsetScale;
        float2 param_2 = (gl_FragCoord.xy / _39.refScreen.xy) - offset;
        float4 c = texture2DCv(refInput, refInputSmplr, param_2);
        if (_39.rmode == 0)
        {
            r = fast::min(outColor.x, c.x);
        }
        else
        {
            if (_39.rmode == 1)
            {
                r = fast::max(outColor.x, c.x);
            }
            else
            {
                if (_39.rmode == 3)
                {
                    r = outColor.x + c.x;
                }
                else
                {
                    r = outColor.x;
                }
            }
        }
        if (_39.gmode == 0)
        {
            g = fast::min(outColor.y, c.y);
        }
        else
        {
            if (_39.gmode == 1)
            {
                g = fast::max(outColor.y, c.y);
            }
            else
            {
                if (_39.gmode == 3)
                {
                    g = outColor.y + c.y;
                }
                else
                {
                    g = outColor.y;
                }
            }
        }
        if (_39.bmode == 0)
        {
            b = fast::min(outColor.z, c.z);
        }
        else
        {
            if (_39.bmode == 1)
            {
                b = fast::max(outColor.z, c.z);
            }
            else
            {
                if (_39.bmode == 3)
                {
                    b = outColor.z + c.z;
                }
                else
                {
                    b = outColor.z;
                }
            }
        }
        if (_39.amode == 0)
        {
            a = fast::min(outColor.w, c.w);
        }
        else
        {
            if (_39.amode == 1)
            {
                a = fast::max(outColor.w, c.w);
            }
            else
            {
                if (_39.amode == 3)
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
    float _421;
    if (_39.rmode == 3)
    {
        _421 = float(nSamples);
    }
    else
    {
        _421 = 1.0;
    }
    float _431;
    if (_39.gmode == 3)
    {
        _431 = float(nSamples);
    }
    else
    {
        _431 = 1.0;
    }
    float _441;
    if (_39.bmode == 3)
    {
        _441 = float(nSamples);
    }
    else
    {
        _441 = 1.0;
    }
    float _451;
    if (_39.amode == 3)
    {
        _451 = float(nSamples);
    }
    else
    {
        _451 = 1.0;
    }
    outColor /= float4(_421, _431, _441, _451);
    float _461 = outColor.w;
    float4 _462 = outColor;
    float3 _464 = _462.xyz * _461;
    outColor.x = _464.x;
    outColor.y = _464.y;
    outColor.z = _464.z;
    referenceColor = mix(originalColor, outColor, float4(_39.alpha));
}

fragment refAM35_ed2fdd321a8b0_out refAM35_ed2fdd321a8b0(constant ReferenceUniformsed2fdd321a8b0& _39 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed2fdd321a8b0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_39, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _485 = any(isnan(referenceColor));
    bool _492;
    if (!_485)
    {
        _492 = any(isinf(referenceColor));
    }
    else
    {
        _492 = _485;
    }
    if (_492)
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

