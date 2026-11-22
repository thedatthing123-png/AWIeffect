// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsbrushsketch.xml
// Original source comments and attribution:
//////////////////////////
//////////////////////////
/////////////////////////
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse6bbee04d6850
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float RADIUSS;
    char _m6_pad[12];
    float alpha;
};

struct refAM35_e6bbee04d6850_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse6bbee04d6850& _35, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_35.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _35.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_35.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _35.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_35.refScreen.x, _35.refScreen.y);
            float2 syamjaidtz = gl_FragCoord.xy / _35.refScreen.xy;
            int radius = int(_35.RADIUSS);
            float2 src_size = float2(1.0 / iResolution.x, 1.0 / iResolution.y);
            float2 uv = syamjaidtz;
            float n = float((radius + 1) * (radius + 1));
            float3 m0 = float3(0.0);
            float3 m1 = float3(0.0);
            float3 m2 = float3(0.0);
            float3 m3 = float3(0.0);
            float3 s0 = float3(0.0);
            float3 s1 = float3(0.0);
            float3 s2 = float3(0.0);
            float3 s3 = float3(0.0);
            int _149 = -radius;
            float3 c;
            for (int j = _149; j <= 0; j++)
            {
                int _159 = -radius;
                for (int i = _159; i <= 0; i++)
                {
                    float2 param_3 = uv + (float2(float(i), float(j)) * src_size);
                    c = texture2DCv(refInput, refInputSmplr, param_3).xyz;
                    m0 += c;
                    s0 += (c * c);
                }
            }
            int _194 = -radius;
            for (int j_1 = _194; j_1 <= 0; j_1++)
            {
                for (int i_1 = 0; i_1 <= radius; i_1++)
                {
                    float2 param_4 = uv + (float2(float(i_1), float(j_1)) * src_size);
                    c = texture2DCv(refInput, refInputSmplr, param_4).xyz;
                    m1 += c;
                    s1 += (c * c);
                }
            }
            for (int j_2 = 0; j_2 <= radius; j_2++)
            {
                for (int i_2 = 0; i_2 <= radius; i_2++)
                {
                    float2 param_5 = uv + (float2(float(i_2), float(j_2)) * src_size);
                    c = texture2DCv(refInput, refInputSmplr, param_5).xyz;
                    m2 += c;
                    s2 += (c * c);
                }
            }
            for (int j_3 = 0; j_3 <= radius; j_3++)
            {
                int _288 = -radius;
                for (int i_3 = _288; i_3 <= 0; i_3++)
                {
                    float2 param_6 = uv + (float2(float(i_3), float(j_3)) * src_size);
                    c = texture2DCv(refInput, refInputSmplr, param_6).xyz;
                    m3 += c;
                    s3 += (c * c);
                }
            }
            float min_sigma2 = 100.0;
            m0 /= float3(n);
            s0 = abs((s0 / float3(n)) - (m0 * m0));
            float sigma2 = (s0.x + s0.y) + s0.z;
            float4 fragColor;
            if (sigma2 < min_sigma2)
            {
                min_sigma2 = sigma2;
                fragColor = float4(m0, 1.0);
            }
            m1 /= float3(n);
            s1 = abs((s1 / float3(n)) - (m1 * m1));
            sigma2 = (s1.x + s1.y) + s1.z;
            if (sigma2 < min_sigma2)
            {
                min_sigma2 = sigma2;
                fragColor = float4(m1, 1.0);
            }
            m2 /= float3(n);
            s2 = abs((s2 / float3(n)) - (m2 * m2));
            sigma2 = (s2.x + s2.y) + s2.z;
            if (sigma2 < min_sigma2)
            {
                min_sigma2 = sigma2;
                fragColor = float4(m2, 1.0);
            }
            m3 /= float3(n);
            s3 = abs((s3 / float3(n)) - (m3 * m3));
            sigma2 = (s3.x + s3.y) + s3.z;
            if (sigma2 < min_sigma2)
            {
                min_sigma2 = sigma2;
                fragColor = float4(m3, 1.0);
            }
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            referenceColor = mix(texColor, factor, float4(_35.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e6bbee04d6850_out refAM35_e6bbee04d6850(constant ReferenceUniformse6bbee04d6850& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e6bbee04d6850_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_35, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _472 = any(isnan(referenceColor));
    bool _479;
    if (!_472)
    {
        _479 = any(isinf(referenceColor));
    }
    else
    {
        _479 = _472;
    }
    if (_479)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _492 = referenceColor;
    float3 _498 = fast::clamp(_492.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _498.x;
    referenceColor.y = _498.y;
    referenceColor.z = _498.z;
    out.finalColor = referenceColor;
    return out;
}

