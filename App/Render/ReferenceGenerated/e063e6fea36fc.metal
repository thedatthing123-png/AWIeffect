// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/bcc_ripple.xml
// Original source comments and attribution:
// Vector from center (aspect-corrected)
// Ripple wave (animated with time)
// Decay (fade as distance increases)
// Offset in radial direction (convert back from aspect space)
// Sample displaced image
// --- Lighting calculation ---
// Derivative of ripple wave = acts like a "bump map"
// Add highlights and shadows
// highlights
// shadows
// Blend with original
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse063e6fea36fc
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float frequency;
    char _m7_pad[12];
    float speed;
    char _m8_pad[12];
    float radius;
    char _m9_pad[12];
    float decay;
    char _m10_pad[12];
    float centerX;
    char _m11_pad[12];
    float centerY;
    char _m12_pad[12];
    float lightIntensity;
    char _m13_pad[12];
    float lightSharpness;
    char _m14_pad[12];
    float blend;
};

struct refAM35_e063e6fea36fc_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse063e6fea36fc& _33, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _33.refLayer.xy) / _33.refLayer.zw;
    float2 center = float2(_33.centerX, _33.centerY);
    float aspect = _33.refLayer.z / _33.refLayer.w;
    float2 diff = uv - center;
    float2 diffA = float2(diff.x * aspect, diff.y);
    float dist = length(diffA) * _33.radius;
    float ripple = sin((dist * _33.frequency) - (_33.refScreen.z * _33.speed));
    ripple *= exp((-_33.decay) * dist);
    float2 dirA = diffA / float2(fast::max(length(diffA), 9.9999999747524270787835121154785e-07));
    float2 dirUV = float2(dirA.x / aspect, dirA.y);
    float2 displacedUV = uv + ((dirUV * ripple) * _33.strength);
    float2 param = displacedUV;
    float4 displacedColor = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = uv;
    float4 originalColor = texture2DCv(refInput, refInputSmplr, param_1);
    float light = cos((dist * _33.frequency) - (_33.refScreen.z * _33.speed)) * exp((-_33.decay) * dist);
    light = powr(abs(light), _33.lightSharpness) * _33.lightIntensity;
    float3 finalColor = displacedColor.xyz;
    finalColor += float3(light);
    finalColor -= float3(light * 0.5);
    float3 mixedColor = mix(originalColor.xyz, finalColor, float3(_33.blend));
    referenceColor = float4(mixedColor, displacedColor.w);
}

fragment refAM35_e063e6fea36fc_out refAM35_e063e6fea36fc(constant ReferenceUniformse063e6fea36fc& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e063e6fea36fc_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, refInput, refInputSmplr, referenceColor);
    bool _214 = any(isnan(referenceColor));
    bool _221;
    if (!_214)
    {
        _221 = any(isinf(referenceColor));
    }
    else
    {
        _221 = _214;
    }
    if (_221)
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

