// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxlutreader.xml
// Original source comments and attribution:
/////////////////////////
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse06869eae4c9f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint enableLut;
    char _m6_pad[12];
    uint RAW;
    char _m7_pad[12];
    float lutLevel;
};

struct refAM35_e06869eae4c9f_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse06869eae4c9f& _43, texture2d<float> refReference, sampler refReferenceSmplr, texture2d<float> refImage1, sampler refImage1Smplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _43.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param_1);
    float2 iResolution = float2(_43.refScreen.x, _43.refScreen.y);
    float2 iMouse = float2(0.5);
    float2 syamjaidtz = float2(1.0) - ((gl_FragCoord.xy - _43.refLayer.xy) / _43.refLayer.zw);
    float2 param_2 = gl_FragCoord.xy / _43.refScreen.xy;
    float4 textureColor1 = texture2DCv(refReference, refReferenceSmplr, param_2);
    float2 param_3 = syamjaidtz;
    float4 RawText = texture2DCv(refImage1, refImage1Smplr, param_3);
    if (_43.RAW != 0u)
    {
        referenceColor = RawText * texColor.w;
        return;
    }
    if (!(_43.enableLut != 0u))
    {
        referenceColor = textureColor1;
        return;
    }
    float4 textureColor = float4(textureColor1.xyz * 0.870550572872161865234375, textureColor1.w);
    float blueColor = textureColor.z * 63.0;
    float2 quad1;
    quad1.y = floor(floor(blueColor) / 8.0);
    quad1.x = floor(blueColor) - (quad1.y * 8.0);
    float2 quad2;
    quad2.y = floor(ceil(blueColor) / 8.0);
    quad2.x = ceil(blueColor) - (quad2.y * 8.0);
    float2 texPos1;
    texPos1.x = ((quad1.x * 0.125) + 0.0009765625) + (0.123046875 * textureColor.x);
    texPos1.y = ((quad1.y * 0.125) + 0.0009765625) + (0.123046875 * textureColor.y);
    texPos1.y = 1.0 - texPos1.y;
    float2 texPos2;
    texPos2.x = ((quad2.x * 0.125) + 0.0009765625) + (0.123046875 * textureColor.x);
    texPos2.y = ((quad2.y * 0.125) + 0.0009765625) + (0.123046875 * textureColor.y);
    texPos2.y = 1.0 - texPos2.y;
    float2 param_4 = texPos1;
    float4 newColor1 = texture2DCv(refInput, refInputSmplr, param_4);
    float2 param_5 = texPos2;
    float4 newColor2 = texture2DCv(refInput, refInputSmplr, param_5);
    float4 newColor = mix(newColor1, newColor2, float4(fract(blueColor)));
    float4 fragColor = mix(textureColor, float4(newColor.xyz, textureColor.w), float4(_43.lutLevel));
    referenceColor = fragColor * texColor.w;
}

fragment refAM35_e06869eae4c9f_out refAM35_e06869eae4c9f(constant ReferenceUniformse06869eae4c9f& _43 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], texture2d<float> refReference [[texture(3)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], sampler refReferenceSmplr [[sampler(3)]], float4 gl_FragCoord [[position]])
{
    refAM35_e06869eae4c9f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _43, refReference, refReferenceSmplr, refImage1, refImage1Smplr, referenceColor);
    bool _268 = any(isnan(referenceColor));
    bool _275;
    if (!_268)
    {
        _275 = any(isinf(referenceColor));
    }
    else
    {
        _275 = _268;
    }
    if (_275)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _288 = referenceColor;
    float3 _294 = fast::clamp(_288.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _294.x;
    referenceColor.y = _294.y;
    referenceColor.z = _294.z;
    out.finalColor = referenceColor;
    return out;
}

