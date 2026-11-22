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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformsed2fdd321a8b0& _52, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texelSize = float2(1.0) / getTexSize(param);
    float2 center = float2(0.5 + (_52.centerPoint.x / 500.0), 0.5 - (_52.centerPoint.y / 500.0));
    float2 v = (gl_FragCoord.xy / _52.refScreen.xy) - (float4(center, 0.0, 1.0) * _52.refLayerToScreen).xy;
    float speed = length(float2(_52.strength / 2.0) / texelSize);
    if (_52.adaptive != 0u)
    {
        speed *= length(((gl_FragCoord.xy - _52.refLayer.xy) / _52.refLayer.zw) - center);
    }
    else
    {
        speed *= smoothstep(0.0, length(texelSize) * 5.0, length(((gl_FragCoord.xy - _52.refLayer.xy) / _52.refLayer.zw) - center));
    }
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
    float2 param_1 = gl_FragCoord.xy / _52.refScreen.xy;
    float4 originalColor = texture2DCv(refInput, refInputSmplr, param_1);
    float4 outColor = originalColor;
    float2 vnorm = (fast::normalize(v) * texelSize) * speed;
    float2 offsetScale = float2(1.0);
    if (_52.refScreen.y > _52.refScreen.x)
    {
        offsetScale.x *= (_52.refScreen.x / _52.refScreen.y);
    }
    else
    {
        offsetScale.y *= (_52.refScreen.y / _52.refScreen.x);
    }
    float3 _205;
    if (outColor.w > 0.0)
    {
        _205 = outColor.xyz / float3(outColor.w);
    }
    else
    {
        _205 = outColor.xyz;
    }
    outColor.x = _205.x;
    outColor.y = _205.y;
    outColor.z = _205.z;
    float r;
    float g;
    float b;
    float a;
    for (int i = 1; i < nSamples; i++)
    {
        float2 offset = vnorm * ((float(i) / float(nSamples - 1)) - (0.5 + (_52.bias0 / 2.0)));
        offset *= offsetScale;
        float2 param_2 = (gl_FragCoord.xy / _52.refScreen.xy) - offset;
        float4 c = texture2DCv(refInput, refInputSmplr, param_2);
        if (_52.rmode == 0)
        {
            r = fast::min(outColor.x, c.x);
        }
        else
        {
            if (_52.rmode == 1)
            {
                r = fast::max(outColor.x, c.x);
            }
            else
            {
                if (_52.rmode == 3)
                {
                    r = outColor.x + c.x;
                }
                else
                {
                    r = outColor.x;
                }
            }
        }
        if (_52.gmode == 0)
        {
            g = fast::min(outColor.y, c.y);
        }
        else
        {
            if (_52.gmode == 1)
            {
                g = fast::max(outColor.y, c.y);
            }
            else
            {
                if (_52.gmode == 3)
                {
                    g = outColor.y + c.y;
                }
                else
                {
                    g = outColor.y;
                }
            }
        }
        if (_52.bmode == 0)
        {
            b = fast::min(outColor.z, c.z);
        }
        else
        {
            if (_52.bmode == 1)
            {
                b = fast::max(outColor.z, c.z);
            }
            else
            {
                if (_52.bmode == 3)
                {
                    b = outColor.z + c.z;
                }
                else
                {
                    b = outColor.z;
                }
            }
        }
        if (_52.amode == 0)
        {
            a = fast::min(outColor.w, c.w);
        }
        else
        {
            if (_52.amode == 1)
            {
                a = fast::max(outColor.w, c.w);
            }
            else
            {
                if (_52.amode == 3)
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
    float _423;
    if (_52.rmode == 3)
    {
        _423 = float(nSamples);
    }
    else
    {
        _423 = 1.0;
    }
    float _433;
    if (_52.gmode == 3)
    {
        _433 = float(nSamples);
    }
    else
    {
        _433 = 1.0;
    }
    float _443;
    if (_52.bmode == 3)
    {
        _443 = float(nSamples);
    }
    else
    {
        _443 = 1.0;
    }
    float _453;
    if (_52.amode == 3)
    {
        _453 = float(nSamples);
    }
    else
    {
        _453 = 1.0;
    }
    outColor /= float4(_423, _433, _443, _453);
    float _463 = outColor.w;
    float4 _464 = outColor;
    float3 _466 = _464.xyz * _463;
    outColor.x = _466.x;
    outColor.y = _466.y;
    outColor.z = _466.z;
    referenceColor = mix(originalColor, outColor, float4(_52.alpha));
}

fragment refAM35_ed2fdd321a8b0_out refAM35_ed2fdd321a8b0(constant ReferenceUniformsed2fdd321a8b0& _52 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed2fdd321a8b0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _52, gl_FragCoord, referenceColor);
    bool _487 = any(isnan(referenceColor));
    bool _494;
    if (!_487)
    {
        _494 = any(isinf(referenceColor));
    }
    else
    {
        _494 = _487;
    }
    if (_494)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _507 = referenceColor;
    float3 _513 = fast::clamp(_507.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _513.x;
    referenceColor.y = _513.y;
    referenceColor.z = _513.z;
    out.finalColor = referenceColor;
    return out;
}

