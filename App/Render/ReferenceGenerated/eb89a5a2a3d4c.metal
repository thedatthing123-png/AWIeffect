// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/gaussianblur.xml
// Original source comments and attribution:
//To get gauss(x) <= gauss(0)*0.1
//x>=sigma*sqrt(2*ln10) = 2.14596602...
//If you want to get gauss(x) <= gauss(0)*0.01 to get more dedicated result,
//x>=2.0*sigma*sqrt(ln10) = 3.03485425....
//currently, in my thought, 0.1 of the center pixel will be enough.
//clamp(st - offsetL * texOffset, vec2(0.0, 0.0), vec2(1.0,1.0));
//clamp(st + offsetL * texOffset, vec2(0.0, 0.0), vec2(1.0, 1.0));
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb89a5a2a3d4c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
};

struct refAM35_eb89a5a2a3d4c_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 blurInternal(texture2d<float> _texture, sampler _textureSmplr, thread const float2& texOffset, thread const float2& st, thread const float& numBlurPixelsPerSide, constant ReferenceUniformseb89a5a2a3d4c& _36)
{
    if (_36.strength <= 0.0)
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
    float2 param = st;
    avgValue += (texture2DCv(_texture, _textureSmplr, param) * incrementalGaussian.x);
    coefficientSum += incrementalGaussian.x;
    for (float i = 1.0; i <= numBlurPixelsPerSide; i += 2.0)
    {
        float offset0 = i;
        float offset1 = i + 1.0;
        float3 _108 = incrementalGaussian;
        float3 _110 = incrementalGaussian;
        float2 _112 = _110.xy * _108.yz;
        incrementalGaussian.x = _112.x;
        incrementalGaussian.y = _112.y;
        coefficientSum += (2.0 * incrementalGaussian.x);
        float weight0 = incrementalGaussian.x;
        float3 _126 = incrementalGaussian;
        float3 _128 = incrementalGaussian;
        float2 _130 = _128.xy * _126.yz;
        incrementalGaussian.x = _130.x;
        incrementalGaussian.y = _130.y;
        coefficientSum += (2.0 * incrementalGaussian.x);
        float weight1 = incrementalGaussian.x;
        float weightL = weight0 + weight1;
        float offsetL = ((offset0 * weight0) + (offset1 * weight1)) / weightL;
        float2 stL = st - (texOffset * offsetL);
        float2 stR = st + (texOffset * offsetL);
        float2 param_1 = stL;
        avgValue += (texture2DCv(_texture, _textureSmplr, param_1) * weightL);
        float2 param_2 = stR;
        avgValue += (texture2DCv(_texture, _textureSmplr, param_2) * weightL);
    }
    return avgValue / float4(coefficientSum);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseb89a5a2a3d4c& _36, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr, texture2d<float> refBuffer3, sampler refBuffer3Smplr)
{
    if (as_type<int>(_36.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _36.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_36.refComposition.z) == 1)
        {
            float kernelSize = ((((_36.strength / 2.0) * 1.13999998569488525390625) / 4.0) / 3.0) * length(_36.refScreen.xy);
            float2 texOffset = float2(1.0 / fast::max(floor(float2(_36.refComposition.w, _36.refScreen.w) / float2(2.0)), float2(1.0)).x, 0.0);
            float2 param_1 = texOffset;
            float2 param_2 = gl_FragCoord.xy / _36.refScreen.xy;
            float param_3 = kernelSize;
            referenceColor = blurInternal(refBuffer1, refBuffer1Smplr, param_1, param_2, param_3, _36);
        }
        else
        {
            if (as_type<int>(_36.refComposition.z) == 2)
            {
                float kernelSize_1 = ((((_36.strength / 2.0) * 1.13999998569488525390625) / 4.0) / 3.0) * length(_36.refScreen.xy);
                float2 texOffset_1 = float2(0.0, 1.0 / fast::max(floor(float2(_36.refComposition.w, _36.refScreen.w) / float2(2.0)), float2(1.0)).y);
                float2 param_4 = texOffset_1;
                float2 param_5 = gl_FragCoord.xy / _36.refScreen.xy;
                float param_6 = kernelSize_1;
                float4 result = blurInternal(refBuffer2, refBuffer2Smplr, param_4, param_5, param_6, _36);
                float4 _313;
                if (_36.strength <= 0.0)
                {
                    float2 param_7 = gl_FragCoord.xy / _36.refScreen.xy;
                    _313 = texture2DCv(refInput, refInputSmplr, param_7);
                }
                else
                {
                    _313 = result;
                }
                referenceColor = _313;
            }
            else
            {
                float2 param_8 = gl_FragCoord.xy / _36.refScreen.xy;
                referenceColor = texture2DCv(refBuffer3, refBuffer3Smplr, param_8);
            }
        }
    }
}

fragment refAM35_eb89a5a2a3d4c_out refAM35_eb89a5a2a3d4c(constant ReferenceUniformseb89a5a2a3d4c& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refBuffer2 [[texture(2)]], texture2d<float> refBuffer3 [[texture(3)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refBuffer2Smplr [[sampler(2)]], sampler refBuffer3Smplr [[sampler(3)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb89a5a2a3d4c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_36, referenceColor, refInput, refInputSmplr, gl_FragCoord, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr, refBuffer3, refBuffer3Smplr);
    bool _341 = any(isnan(referenceColor));
    bool _348;
    if (!_341)
    {
        _348 = any(isinf(referenceColor));
    }
    else
    {
        _348 = _341;
    }
    if (_348)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _361 = referenceColor;
    float3 _367 = fast::clamp(_361.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _367.x;
    referenceColor.y = _367.y;
    referenceColor.z = _367.z;
    out.finalColor = referenceColor;
    return out;
}

