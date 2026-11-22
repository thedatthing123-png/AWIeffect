// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/streaks-spin.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse4e43a09d7b11
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 centerPoint;
    char _m6_pad[8];
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

struct refAM35_e4e43a09d7b11_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse4e43a09d7b11& _53, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param);
    float2 texelSize = float2(1.0) / image_size;
    float2 relCenter = float2(0.5 + (_53.centerPoint.x / 500.0), 0.5 - (_53.centerPoint.y / 500.0));
    float2 center = (float4(relCenter, 0.0, 1.0) * _53.refLayerToScreen).xy;
    float2 v = (gl_FragCoord.xy / _53.refScreen.xy) - center;
    v.y *= (image_size.y / image_size.x);
    float r = length(v);
    float d = 6.28318500518798828125 * r;
    float l = (d * _53.angle) / 360.0;
    float a = _53.angle * 0.01745329983532428741455078125;
    float amin = (a / 2.0) + ((a * _53.bias0) / 2.0);
    float speed = l / texelSize.x;
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
    float2 param_1 = gl_FragCoord.xy / _53.refScreen.xy;
    float4 originalColor = texture2DCv(refInput, refInputSmplr, param_1);
    float4 outColor = originalColor;
    float3 _165;
    if (outColor.w > 0.0)
    {
        _165 = outColor.xyz / float3(outColor.w);
    }
    else
    {
        _165 = outColor.xyz;
    }
    outColor.x = _165.x;
    outColor.y = _165.y;
    outColor.z = _165.z;
    float r_1;
    float g;
    float b;
    float a_1;
    for (int i = 1; i < nSamples; i++)
    {
        float sampleAngle = (-amin) + ((a * float(i)) / float(nSamples));
        float s = sin(sampleAngle);
        float cs = cos(sampleAngle);
        float2x2 rot = float2x2(float2(cs, -s), float2(s, cs));
        float2 temp = v * rot;
        temp.y = (temp.y * image_size.x) / image_size.y;
        float2 param_2 = center + temp;
        float4 c = texture2DCv(refInput, refInputSmplr, param_2);
        if (_53.rmode == 0)
        {
            r_1 = fast::min(outColor.x, c.x);
        }
        else
        {
            if (_53.rmode == 1)
            {
                r_1 = fast::max(outColor.x, c.x);
            }
            else
            {
                if (_53.rmode == 3)
                {
                    r_1 = outColor.x + c.x;
                }
                else
                {
                    r_1 = outColor.x;
                }
            }
        }
        if (_53.gmode == 0)
        {
            g = fast::min(outColor.y, c.y);
        }
        else
        {
            if (_53.gmode == 1)
            {
                g = fast::max(outColor.y, c.y);
            }
            else
            {
                if (_53.gmode == 3)
                {
                    g = outColor.y + c.y;
                }
                else
                {
                    g = outColor.y;
                }
            }
        }
        if (_53.bmode == 0)
        {
            b = fast::min(outColor.z, c.z);
        }
        else
        {
            if (_53.bmode == 1)
            {
                b = fast::max(outColor.z, c.z);
            }
            else
            {
                if (_53.bmode == 3)
                {
                    b = outColor.z + c.z;
                }
                else
                {
                    b = outColor.z;
                }
            }
        }
        if (_53.amode == 0)
        {
            a_1 = fast::min(outColor.w, c.w);
        }
        else
        {
            if (_53.amode == 1)
            {
                a_1 = fast::max(outColor.w, c.w);
            }
            else
            {
                if (_53.amode == 3)
                {
                    a_1 = outColor.w + c.w;
                }
                else
                {
                    a_1 = outColor.w;
                }
            }
        }
        outColor = float4(r_1, g, b, a_1);
    }
    float _402;
    if (_53.rmode == 3)
    {
        _402 = float(nSamples);
    }
    else
    {
        _402 = 1.0;
    }
    float _412;
    if (_53.gmode == 3)
    {
        _412 = float(nSamples);
    }
    else
    {
        _412 = 1.0;
    }
    float _422;
    if (_53.bmode == 3)
    {
        _422 = float(nSamples);
    }
    else
    {
        _422 = 1.0;
    }
    float _432;
    if (_53.amode == 3)
    {
        _432 = float(nSamples);
    }
    else
    {
        _432 = 1.0;
    }
    outColor /= float4(_402, _412, _422, _432);
    float _442 = outColor.w;
    float4 _443 = outColor;
    float3 _445 = _443.xyz * _442;
    outColor.x = _445.x;
    outColor.y = _445.y;
    outColor.z = _445.z;
    referenceColor = mix(originalColor, outColor, float4(_53.alpha));
}

fragment refAM35_e4e43a09d7b11_out refAM35_e4e43a09d7b11(constant ReferenceUniformse4e43a09d7b11& _53 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e4e43a09d7b11_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _53, gl_FragCoord, referenceColor);
    bool _466 = any(isnan(referenceColor));
    bool _473;
    if (!_466)
    {
        _473 = any(isinf(referenceColor));
    }
    else
    {
        _473 = _466;
    }
    if (_473)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _486 = referenceColor;
    float3 _492 = fast::clamp(_486.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _492.x;
    referenceColor.y = _492.y;
    referenceColor.z = _492.z;
    out.finalColor = referenceColor;
    return out;
}

