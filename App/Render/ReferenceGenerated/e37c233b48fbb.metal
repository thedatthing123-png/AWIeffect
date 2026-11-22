// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/rippledisto.xml
// Original source comments and attribution:
// Ring Distortion Fade
// 0..1
// Time 0..1
// Convert offset from chosen center to pixel-normalized space (preserving circularity)
// Direction toward center; if zero length, no offset
// Band logic
// fades out over time
// fades in initially
// Apply offset in texels, clamp sampling inside valid area
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformse37c233b48fbb
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint autoTime;
    char _m6_pad[12];
    float duration;
    char _m7_pad[12];
    float progress;
    char _m8_pad[12];
    float effectWidth;
    char _m9_pad[12];
    float fadeInTimeFactor;
    char _m10_pad[12];
    float maxTexelOffset;
    char _m11_pad[12];
    float centerX;
    char _m12_pad[12];
    float centerY;
};

struct refAM35_e37c233b48fbb_out
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
void referenceMain(constant ReferenceUniformse37c233b48fbb& _37, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 res = _37.refScreen.xy;
    float2 uv = gl_FragCoord.xy / _37.refScreen.xy;
    float _62;
    if (_37.autoTime != 0u)
    {
        _62 = mod(_37.refScreen.z, _37.duration) / fast::max(9.9999997473787516355514526367188e-05, _37.duration);
    }
    else
    {
        _62 = fast::clamp(_37.progress, 0.0, 1.0);
    }
    float pr = _62;
    float2 center = float2(_37.centerX, _37.centerY);
    float minDim = fast::min(res.x, res.y);
    float2 offsetFromCenter = ((uv - center) * res) / float2(fast::max(1.0, minDim));
    float lenO = length(offsetFromCenter);
    float2 _118;
    if (lenO > 9.9999999747524270787835121154785e-07)
    {
        _118 = fast::normalize(-offsetFromCenter);
    }
    else
    {
        _118 = float2(0.0);
    }
    float2 offsetDir = _118;
    float halfWidth = _37.effectWidth * 0.5;
    float lower = 1.0 - smoothstep(pr - halfWidth, pr, lenO);
    float upper = smoothstep(pr, pr + halfWidth, lenO);
    float band = 1.0 - (upper + lower);
    float strength = 1.0 - pr;
    float fadeStrength = smoothstep(0.0, _37.fadeInTimeFactor, pr);
    float distortion = (band * strength) * fadeStrength;
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texelSize = float2(1.0) / getTexSize(param);
    float2 uvOff = uv + (texelSize * ((offsetDir * _37.maxTexelOffset) * distortion));
    float2 halfTex = texelSize * 0.5;
    uvOff = fast::clamp(uvOff, halfTex, float2(1.0) - halfTex);
    float2 param_1 = uvOff;
    float4 col = texture2DCv(refInput, refInputSmplr, param_1);
    referenceColor = col;
}

fragment refAM35_e37c233b48fbb_out refAM35_e37c233b48fbb(constant ReferenceUniformse37c233b48fbb& _37 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e37c233b48fbb_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_37, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _213 = any(isnan(referenceColor));
    bool _220;
    if (!_213)
    {
        _220 = any(isinf(referenceColor));
    }
    else
    {
        _220 = _213;
    }
    if (_220)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _235 = referenceColor;
    float3 _241 = fast::clamp(_235.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _241.x;
    referenceColor.y = _241.y;
    referenceColor.z = _241.z;
    out.finalColor = referenceColor;
    return out;
}

