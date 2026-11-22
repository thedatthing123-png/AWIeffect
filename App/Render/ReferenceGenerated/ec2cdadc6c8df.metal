// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/channelmaphsv.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec2cdadc6c8df
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int hue;
    char _m6_pad[12];
    int sat;
    char _m7_pad[12];
    int val;
    char _m8_pad[12];
    int alpha;
};

struct refAM35_ec2cdadc6c8df_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 rgb2hsv(thread const float3& c)
{
    float4 K = float4(0.0, -0.3333333432674407958984375, 0.666666686534881591796875, -1.0);
    float4 p = mix(float4(c.zy, K.wz), float4(c.yz, K.xy), float4(step(c.z, c.y)));
    float4 q = mix(float4(p.xyw, c.x), float4(c.x, p.yzx), float4(step(p.x, c.x)));
    float d = q.x - fast::min(q.w, q.y);
    float e = 1.0000000133514319600180897396058e-10;
    return float3(abs(q.z + ((q.w - q.y) / ((6.0 * d) + e))), d / (q.x + e), q.x);
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsec2cdadc6c8df& _179, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _179.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float luminance = dot(texColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 s = step(float2(0.0), (gl_FragCoord.xy - _179.refLayer.xy) / _179.refLayer.zw) - step(float2(1.0), (gl_FragCoord.xy - _179.refLayer.xy) / _179.refLayer.zw);
    float maskFactor = s.x * s.y;
    float4 outColor = float4(0.0);
    if (texColor.w > 0.0)
    {
        float _238 = texColor.w;
        float4 _239 = texColor;
        float3 _242 = _239.xyz / float3(_238);
        texColor.x = _242.x;
        texColor.y = _242.y;
        texColor.z = _242.z;
    }
    float3 param_1 = texColor.xyz;
    float3 _252 = rgb2hsv(param_1);
    texColor.x = _252.x;
    texColor.y = _252.y;
    texColor.z = _252.z;
    if (_179.hue == 0)
    {
        outColor.x = texColor.x;
    }
    else
    {
        if (_179.hue == 1)
        {
            outColor.x = texColor.y;
        }
        else
        {
            if (_179.hue == 2)
            {
                outColor.x = texColor.z;
            }
            else
            {
                if (_179.hue == 3)
                {
                    outColor.x = texColor.w;
                }
                else
                {
                    if (_179.hue == 4)
                    {
                        outColor.x = luminance;
                    }
                    else
                    {
                        if (_179.hue == 5)
                        {
                            outColor.x = 0.0;
                        }
                        else
                        {
                            outColor.x = 1.0;
                        }
                    }
                }
            }
        }
    }
    if (_179.sat == 0)
    {
        outColor.y = texColor.x;
    }
    else
    {
        if (_179.sat == 1)
        {
            outColor.y = texColor.y;
        }
        else
        {
            if (_179.sat == 2)
            {
                outColor.y = texColor.z;
            }
            else
            {
                if (_179.sat == 3)
                {
                    outColor.y = texColor.w;
                }
                else
                {
                    if (_179.sat == 4)
                    {
                        outColor.y = luminance;
                    }
                    else
                    {
                        if (_179.sat == 5)
                        {
                            outColor.y = 0.0;
                        }
                        else
                        {
                            outColor.y = 1.0;
                        }
                    }
                }
            }
        }
    }
    if (_179.val == 0)
    {
        outColor.z = texColor.x;
    }
    else
    {
        if (_179.val == 1)
        {
            outColor.z = texColor.y;
        }
        else
        {
            if (_179.val == 2)
            {
                outColor.z = texColor.z;
            }
            else
            {
                if (_179.val == 3)
                {
                    outColor.z = texColor.w;
                }
                else
                {
                    if (_179.val == 4)
                    {
                        outColor.z = luminance;
                    }
                    else
                    {
                        if (_179.val == 5)
                        {
                            outColor.z = 0.0;
                        }
                        else
                        {
                            outColor.z = 1.0;
                        }
                    }
                }
            }
        }
    }
    if (_179.alpha == 0)
    {
        outColor.w = texColor.x;
    }
    else
    {
        if (_179.alpha == 1)
        {
            outColor.w = texColor.y;
        }
        else
        {
            if (_179.alpha == 2)
            {
                outColor.w = texColor.z;
            }
            else
            {
                if (_179.alpha == 3)
                {
                    outColor.w = texColor.w;
                }
                else
                {
                    if (_179.alpha == 4)
                    {
                        outColor.w = luminance;
                    }
                    else
                    {
                        if (_179.alpha == 5)
                        {
                            outColor.w = 0.0;
                        }
                        else
                        {
                            outColor.w = 1.0;
                        }
                    }
                }
            }
        }
    }
    float3 param_2 = outColor.xyz;
    float3 _478 = hsv2rgb(param_2);
    outColor.x = _478.x;
    outColor.y = _478.y;
    outColor.z = _478.z;
    float _486 = outColor.w;
    float4 _487 = outColor;
    float3 _489 = _487.xyz * _486;
    outColor.x = _489.x;
    outColor.y = _489.y;
    outColor.z = _489.z;
    referenceColor = outColor * maskFactor;
}

fragment refAM35_ec2cdadc6c8df_out refAM35_ec2cdadc6c8df(constant ReferenceUniformsec2cdadc6c8df& _179 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec2cdadc6c8df_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _179, referenceColor);
    bool _505 = any(isnan(referenceColor));
    bool _512;
    if (!_505)
    {
        _512 = any(isinf(referenceColor));
    }
    else
    {
        _512 = _505;
    }
    if (_512)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _525 = referenceColor;
    float3 _531 = fast::clamp(_525.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _531.x;
    referenceColor.y = _531.y;
    referenceColor.z = _531.z;
    out.finalColor = referenceColor;
    return out;
}

