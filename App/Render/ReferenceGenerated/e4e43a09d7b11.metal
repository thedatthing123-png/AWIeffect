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
void referenceMain(constant ReferenceUniformse4e43a09d7b11& _37, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 param = _37.refScreen.xy;
    float2 image_size = getTexSize(param);
    float2 texelSize = float2(1.0) / image_size;
    float2 relCenter = float2(0.5 + (_37.centerPoint.x / 500.0), 0.5 - (_37.centerPoint.y / 500.0));
    float2 center = (float4(relCenter, 0.0, 1.0) * _37.refLayerToScreen).xy;
    float2 v = (gl_FragCoord.xy / _37.refScreen.xy) - center;
    v.y *= (image_size.y / image_size.x);
    float r = length(v);
    float d = 6.28318500518798828125 * r;
    float l = (d * _37.angle) / 360.0;
    float a = _37.angle * 0.01745329983532428741455078125;
    float amin = (a / 2.0) + ((a * _37.bias0) / 2.0);
    float speed = l / texelSize.x;
    int nSamples = int(fast::clamp(speed, 1.0099999904632568359375, 100.01000213623046875));
    float2 param_1 = gl_FragCoord.xy / _37.refScreen.xy;
    float4 originalColor = texture2DCv(refInput, refInputSmplr, param_1);
    float4 outColor = originalColor;
    float3 _163;
    if (outColor.w > 0.0)
    {
        _163 = outColor.xyz / float3(outColor.w);
    }
    else
    {
        _163 = outColor.xyz;
    }
    outColor.x = _163.x;
    outColor.y = _163.y;
    outColor.z = _163.z;
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
        if (_37.rmode == 0)
        {
            r_1 = fast::min(outColor.x, c.x);
        }
        else
        {
            if (_37.rmode == 1)
            {
                r_1 = fast::max(outColor.x, c.x);
            }
            else
            {
                if (_37.rmode == 3)
                {
                    r_1 = outColor.x + c.x;
                }
                else
                {
                    r_1 = outColor.x;
                }
            }
        }
        if (_37.gmode == 0)
        {
            g = fast::min(outColor.y, c.y);
        }
        else
        {
            if (_37.gmode == 1)
            {
                g = fast::max(outColor.y, c.y);
            }
            else
            {
                if (_37.gmode == 3)
                {
                    g = outColor.y + c.y;
                }
                else
                {
                    g = outColor.y;
                }
            }
        }
        if (_37.bmode == 0)
        {
            b = fast::min(outColor.z, c.z);
        }
        else
        {
            if (_37.bmode == 1)
            {
                b = fast::max(outColor.z, c.z);
            }
            else
            {
                if (_37.bmode == 3)
                {
                    b = outColor.z + c.z;
                }
                else
                {
                    b = outColor.z;
                }
            }
        }
        if (_37.amode == 0)
        {
            a_1 = fast::min(outColor.w, c.w);
        }
        else
        {
            if (_37.amode == 1)
            {
                a_1 = fast::max(outColor.w, c.w);
            }
            else
            {
                if (_37.amode == 3)
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
    float _400;
    if (_37.rmode == 3)
    {
        _400 = float(nSamples);
    }
    else
    {
        _400 = 1.0;
    }
    float _410;
    if (_37.gmode == 3)
    {
        _410 = float(nSamples);
    }
    else
    {
        _410 = 1.0;
    }
    float _420;
    if (_37.bmode == 3)
    {
        _420 = float(nSamples);
    }
    else
    {
        _420 = 1.0;
    }
    float _430;
    if (_37.amode == 3)
    {
        _430 = float(nSamples);
    }
    else
    {
        _430 = 1.0;
    }
    outColor /= float4(_400, _410, _420, _430);
    float _440 = outColor.w;
    float4 _441 = outColor;
    float3 _443 = _441.xyz * _440;
    outColor.x = _443.x;
    outColor.y = _443.y;
    outColor.z = _443.z;
    referenceColor = mix(originalColor, outColor, float4(_37.alpha));
}

fragment refAM35_e4e43a09d7b11_out refAM35_e4e43a09d7b11(constant ReferenceUniformse4e43a09d7b11& _37 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e4e43a09d7b11_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_37, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _464 = any(isnan(referenceColor));
    bool _471;
    if (!_464)
    {
        _471 = any(isinf(referenceColor));
    }
    else
    {
        _471 = _464;
    }
    if (_471)
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

