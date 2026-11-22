// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/internal-shadow.xml
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

struct ReferenceUniformsee2c49cfac5c8
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float sigma;
    char _m6_pad[12];
    float sdx;
    char _m7_pad[12];
    float sdy;
    float4 color;
    float alpha;
};

struct refAM35_ee2c49cfac5c8_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 blurInternal(texture2d<float> _texture, sampler _textureSmplr, thread const float2& texOffset, thread const float2& st, thread const float& rate, constant ReferenceUniformsee2c49cfac5c8& _36)
{
    if (_36.sigma <= 0.0)
    {
        bool _51 = st.x >= 0.0;
        bool _58;
        if (_51)
        {
            _58 = st.x <= 1.0;
        }
        else
        {
            _58 = _51;
        }
        bool _65;
        if (_58)
        {
            _65 = st.y >= 0.0;
        }
        else
        {
            _65 = _58;
        }
        bool _71;
        if (_65)
        {
            _71 = st.y <= 1.0;
        }
        else
        {
            _71 = _65;
        }
        if (_71)
        {
            float2 param = st;
            return texture2DCv(_texture, _textureSmplr, param);
        }
        else
        {
            return float4(0.0);
        }
    }
    float adjSigma = _36.sigma * rate;
    float numBlurPixelsPerSide = 2.145966053009033203125 * adjSigma;
    float3 incrementalGaussian;
    incrementalGaussian.x = 1.0 / (2.5066282749176025390625 * adjSigma);
    incrementalGaussian.y = exp((-0.5) / (adjSigma * adjSigma));
    incrementalGaussian.z = incrementalGaussian.y * incrementalGaussian.y;
    float4 avgValue = float4(0.0);
    float coefficientSum = 0.0;
    bool _117 = st.x >= 0.0;
    bool _123;
    if (_117)
    {
        _123 = st.x <= 1.0;
    }
    else
    {
        _123 = _117;
    }
    bool _129;
    if (_123)
    {
        _129 = st.y >= 0.0;
    }
    else
    {
        _129 = _123;
    }
    bool _135;
    if (_129)
    {
        _135 = st.y <= 1.0;
    }
    else
    {
        _135 = _129;
    }
    if (_135)
    {
        float2 param_1 = st;
        avgValue += (texture2DCv(_texture, _textureSmplr, param_1) * incrementalGaussian.x);
    }
    coefficientSum += incrementalGaussian.x;
    for (float i = 1.0; i <= numBlurPixelsPerSide; i += 2.0)
    {
        float offset0 = i;
        float offset1 = i + 1.0;
        float3 _164 = incrementalGaussian;
        float3 _166 = incrementalGaussian;
        float2 _168 = _166.xy * _164.yz;
        incrementalGaussian.x = _168.x;
        incrementalGaussian.y = _168.y;
        coefficientSum += (2.0 * incrementalGaussian.x);
        float weight0 = incrementalGaussian.x;
        float3 _182 = incrementalGaussian;
        float3 _184 = incrementalGaussian;
        float2 _186 = _184.xy * _182.yz;
        incrementalGaussian.x = _186.x;
        incrementalGaussian.y = _186.y;
        coefficientSum += (2.0 * incrementalGaussian.x);
        float weight1 = incrementalGaussian.x;
        float weightL = weight0 + weight1;
        float offsetL = ((offset0 * weight0) + (offset1 * weight1)) / weightL;
        float2 stL = st - (texOffset * offsetL);
        float2 stR = st + (texOffset * offsetL);
        bool _227 = stL.x >= 0.0;
        bool _233;
        if (_227)
        {
            _233 = stL.x <= 1.0;
        }
        else
        {
            _233 = _227;
        }
        bool _239;
        if (_233)
        {
            _239 = stL.y >= 0.0;
        }
        else
        {
            _239 = _233;
        }
        bool _245;
        if (_239)
        {
            _245 = stL.y <= 1.0;
        }
        else
        {
            _245 = _239;
        }
        if (_245)
        {
            float2 param_2 = stL;
            avgValue += (texture2DCv(_texture, _textureSmplr, param_2) * weightL);
        }
        bool _257 = stR.x >= 0.0;
        bool _263;
        if (_257)
        {
            _263 = stR.x <= 1.0;
        }
        else
        {
            _263 = _257;
        }
        bool _269;
        if (_263)
        {
            _269 = stR.y >= 0.0;
        }
        else
        {
            _269 = _263;
        }
        bool _275;
        if (_269)
        {
            _275 = stR.y <= 1.0;
        }
        else
        {
            _275 = _269;
        }
        if (_275)
        {
            float2 param_3 = stR;
            avgValue += (texture2DCv(_texture, _textureSmplr, param_3) * weightL);
        }
    }
    return avgValue / float4(coefficientSum);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsee2c49cfac5c8& _36, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refBuffer2, sampler refBuffer2Smplr)
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
            float2 texOffset = float2(1.0 / _36.refComposition.x, 0.0);
            float2 param_1 = texOffset;
            float2 param_2 = float2((gl_FragCoord.xy / _36.refScreen.xy).x - (_36.sdx * (texOffset.x / 1.0)), (gl_FragCoord.xy / _36.refScreen.xy).y);
            float param_3 = 0.5;
            referenceColor = blurInternal(refBuffer1, refBuffer1Smplr, param_1, param_2, param_3, _36);
        }
        else
        {
            float2 texOffset_1 = float2(0.0, 1.0 / _36.refComposition.y);
            float2 param_4 = texOffset_1;
            float2 param_5 = float2((gl_FragCoord.xy / _36.refScreen.xy).x, (gl_FragCoord.xy / _36.refScreen.xy).y + (_36.sdy * (texOffset_1.y / 1.0)));
            float param_6 = 0.5;
            float4 result = blurInternal(refBuffer2, refBuffer2Smplr, param_4, param_5, param_6, _36);
            float2 param_7 = gl_FragCoord.xy / _36.refScreen.xy;
            float4 original = texture2DCv(refInput, refInputSmplr, param_7);
            result = original + (((_36.color * result.w) * _36.alpha) * (1.0 - original.w));
            referenceColor = result;
        }
    }
}

fragment refAM35_ee2c49cfac5c8_out refAM35_ee2c49cfac5c8(constant ReferenceUniformsee2c49cfac5c8& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refBuffer2 [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refBuffer2Smplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_ee2c49cfac5c8_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_36, referenceColor, refInput, refInputSmplr, gl_FragCoord, refBuffer1, refBuffer1Smplr, refBuffer2, refBuffer2Smplr);
    bool _425 = any(isnan(referenceColor));
    bool _432;
    if (!_425)
    {
        _432 = any(isinf(referenceColor));
    }
    else
    {
        _432 = _425;
    }
    if (_432)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _445 = referenceColor;
    float3 _451 = fast::clamp(_445.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _451.x;
    referenceColor.y = _451.y;
    referenceColor.z = _451.z;
    out.finalColor = referenceColor;
    return out;
}

