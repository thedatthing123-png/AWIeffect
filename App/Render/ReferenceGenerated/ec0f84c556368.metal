// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/lightglow.xml
// Original source comments and attribution:
//To get gauss(x) <= gauss(0)*0.1
//x>=sigma*sqrt(2*ln10) = 2.14596602...
//If you want to get gauss(x) <= gauss(0)*0.01 to get more dedicated result,
//x>=2.0*sigma*sqrt(ln10) = 3.03485425....
//currently, in my thought, 0.1 of the center pixel will be enough.
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec0f84c556368
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float threshold;
    char _m7_pad[12];
    float intensity;
    float4 color;
    float blend;
    char _m10_pad[12];
    float halo;
    char _m11_pad[12];
    float alpha;
};

struct refAM35_ec0f84c556368_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 blurInternal(thread const float2& texOffset, thread const float2& st, thread const float& numBlurPixelsPerSide, constant ReferenceUniformsec0f84c556368& _53, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr)
{
    if (_53.strength <= 0.0)
    {
        return float4(0.0);
    }
    float adjSigma = numBlurPixelsPerSide / 2.145966053009033203125;
    float3 incrementalGaussian;
    incrementalGaussian.x = 1.0 / (2.5066282749176025390625 * adjSigma);
    incrementalGaussian.y = exp((-0.5) / (adjSigma * adjSigma));
    incrementalGaussian.z = incrementalGaussian.y * incrementalGaussian.y;
    float4 avgValue = float4(0.0);
    float coefficientSum = 0.0;
    float4 _102;
    if (as_type<int>(_53.refComposition.z) == 1)
    {
        float2 param = st;
        _102 = texture2DCv(refBuffer1, refBuffer1Smplr, param);
    }
    else
    {
        float2 param_1 = st;
        _102 = texture2DCv(refBuffer2, refBuffer2Smplr, param_1);
    }
    avgValue += (_102 * incrementalGaussian.x);
    coefficientSum += incrementalGaussian.x;
    float4 _207;
    float4 _226;
    for (float i = 1.0; i <= numBlurPixelsPerSide; i += 2.0)
    {
        float offset0 = i;
        float offset1 = i + 1.0;
        float3 _138 = incrementalGaussian;
        float3 _140 = incrementalGaussian;
        float2 _142 = _140.xy * _138.yz;
        incrementalGaussian.x = _142.x;
        incrementalGaussian.y = _142.y;
        coefficientSum += (2.0 * incrementalGaussian.x);
        float weight0 = incrementalGaussian.x;
        float3 _156 = incrementalGaussian;
        float3 _158 = incrementalGaussian;
        float2 _160 = _158.xy * _156.yz;
        incrementalGaussian.x = _160.x;
        incrementalGaussian.y = _160.y;
        coefficientSum += (2.0 * incrementalGaussian.x);
        float weight1 = incrementalGaussian.x;
        float weightL = weight0 + weight1;
        float offsetL = ((offset0 * weight0) + (offset1 * weight1)) / weightL;
        float2 stL = fast::clamp(st - (texOffset * offsetL), float2(0.0), float2(1.0));
        float2 stR = fast::clamp(st + (texOffset * offsetL), float2(0.0), float2(1.0));
        if (as_type<int>(_53.refComposition.z) == 1)
        {
            float2 param_2 = stL;
            _207 = texture2DCv(refBuffer1, refBuffer1Smplr, param_2);
        }
        else
        {
            float2 param_3 = stL;
            _207 = texture2DCv(refBuffer2, refBuffer2Smplr, param_3);
        }
        avgValue += (_207 * weightL);
        if (as_type<int>(_53.refComposition.z) == 1)
        {
            float2 param_4 = stR;
            _226 = texture2DCv(refBuffer1, refBuffer1Smplr, param_4);
        }
        else
        {
            float2 param_5 = stR;
            _226 = texture2DCv(refBuffer2, refBuffer2Smplr, param_5);
        }
        avgValue += (_226 * weightL);
    }
    return avgValue / float4(coefficientSum);
}

static inline __attribute__((always_inline))
float4 composite(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsec0f84c556368& _53, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer3, sampler refBuffer3Smplr)
{
    if (as_type<int>(_53.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _53.refScreen.xy;
        float4 c = texture2DCv(refInput, refInputSmplr, param);
        float luminance = dot(c.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        float4 _284;
        if (luminance > _53.threshold)
        {
            _284 = mix(c, _53.color * c.w, float4(_53.blend));
        }
        else
        {
            _284 = float4(0.0);
        }
        referenceColor = _284;
    }
    else
    {
        if (as_type<int>(_53.refComposition.z) == 1)
        {
            float kernelSize = ((((_53.strength / 2.0) * 1.13999998569488525390625) / 4.0) / 3.0) * length(_53.refScreen.xy);
            float2 texOffset = float2(1.0 / fast::max(floor(float2(_53.refComposition.w, _53.refScreen.w) / float2(2.0)), float2(1.0)).x, 0.0);
            float2 param_1 = texOffset;
            float2 param_2 = gl_FragCoord.xy / _53.refScreen.xy;
            float param_3 = kernelSize;
            referenceColor = blurInternal(param_1, param_2, param_3, _53, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr);
        }
        else
        {
            if (as_type<int>(_53.refComposition.z) == 2)
            {
                float kernelSize_1 = ((((_53.strength / 2.0) * 1.13999998569488525390625) / 4.0) / 3.0) * length(_53.refScreen.xy);
                float2 texOffset_1 = float2(0.0, 1.0 / fast::max(floor(float2(_53.refComposition.w, _53.refScreen.w) / float2(2.0)), float2(1.0)).y);
                float2 param_4 = gl_FragCoord.xy / _53.refScreen.xy;
                float4 base = texture2DCv(refInput, refInputSmplr, param_4);
                float4 result;
                if (_53.strength <= 0.0)
                {
                    float luminance_1 = dot(base.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
                    float4 _403;
                    if (luminance_1 > _53.threshold)
                    {
                        _403 = mix(base, _53.color * base.w, float4(_53.blend));
                    }
                    else
                    {
                        _403 = float4(0.0);
                    }
                    result = _403;
                }
                else
                {
                    float2 param_5 = texOffset_1;
                    float2 param_6 = gl_FragCoord.xy / _53.refScreen.xy;
                    float param_7 = kernelSize_1;
                    result = blurInternal(param_5, param_6, param_7, _53, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr);
                }
                float3 aa = (result.xyz / float3(fast::max(result.w, 9.9999997473787516355514526367188e-05))) * _53.intensity;
                float hsqueeze = 0.1500000059604644775390625;
                float h = (1.0 - smoothstep(0.0, hsqueeze, abs(result.w - hsqueeze))) * _53.halo;
                float3 hh = mix((aa / float3(hsqueeze)) * _53.halo, _53.color.xyz * _53.halo, float3(_53.blend));
                aa += (hh * h);
                float3 bb = base.xyz / float3(fast::max(base.w, 9.9999997473787516355514526367188e-05));
                float3 rgb = float3(1.0) - ((float3(1.0) - aa) * (float3(1.0) - bb));
                float4 param_8 = base;
                float4 param_9 = (float4(rgb, 1.0) * fast::min(base.w, result.w)) * _53.alpha;
                referenceColor = composite(param_8, param_9);
            }
            else
            {
                float2 param_10 = gl_FragCoord.xy / _53.refScreen.xy;
                referenceColor = texture2DCv(refBuffer3, refBuffer3Smplr, param_10);
            }
        }
    }
}

fragment refAM35_ec0f84c556368_out refAM35_ec0f84c556368(constant ReferenceUniformsec0f84c556368& _53 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refBuffer2 [[texture(2)]], texture2d<float> refBuffer3 [[texture(3)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refBuffer2Smplr [[sampler(2)]], sampler refBuffer3Smplr [[sampler(3)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec0f84c556368_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_53, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr, refInput, refInputSmplr, gl_FragCoord, referenceColor, refBuffer3, refBuffer3Smplr);
    bool _533 = any(isnan(referenceColor));
    bool _540;
    if (!_533)
    {
        _540 = any(isinf(referenceColor));
    }
    else
    {
        _540 = _533;
    }
    if (_540)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _553 = referenceColor;
    float3 _559 = fast::clamp(_553.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _559.x;
    referenceColor.y = _559.y;
    referenceColor.z = _559.z;
    out.finalColor = referenceColor;
    return out;
}

