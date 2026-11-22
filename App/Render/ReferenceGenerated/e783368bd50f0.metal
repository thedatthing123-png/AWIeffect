// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/highlight-shadow.xml
// Original source comments and attribution:
//const vec3 luminanceWeighting = vec3(0.3, 0.3, 0.3);
//(shadows+1.0) changed to just shadows:
// blend toward white if highlights is more than 1
// blend toward black if shadows is less than 1
//float luminance = dot(source.rgb, luminanceWeighting);
//
//float shadow = clamp((pow(luminance, 1.0/(shadows+1.0)) + (-0.76)*pow(luminance, 2.0/(shadows+1.0))) - luminance, 0.0, 1.0);
//float highlight = clamp((1.0 - (pow(1.0-luminance, 1.0/(2.0-highlights)) + (-0.8)*pow(1.0-luminance, 2.0/(2.0-highlights)))) - luminance, -1.0, 0.0);
//vec3 result = vec3(0.0, 0.0, 0.0) + ((luminance + shadow + highlight) - 0.0) * ((source.rgb - vec3(0.0, 0.0, 0.0))/(luminance - 0.0));
//
//gl_FragColor = vec4(result.rgb, source.a);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse783368bd50f0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float highlights;
    char _m6_pad[12];
    float shadows;
};

struct refAM35_e783368bd50f0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse783368bd50f0& _35, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 source = texture2DCv(refInput, refInputSmplr, param);
    if (source.w <= 0.0)
    {
        referenceColor = float4(0.0);
        return;
    }
    float _60 = source.w;
    float4 _62 = source;
    float3 _65 = _62.xyz / float3(_60);
    source.x = _65.x;
    source.y = _65.y;
    source.z = _65.z;
    float luminance = fast::clamp(dot(source.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)), 9.9999997473787516355514526367188e-06, 0.999989986419677734375);
    float clampedShadows = fast::clamp(_35.shadows, 1.0, 2.0);
    float shadow = fast::clamp((powr(luminance, 1.0 / clampedShadows) + ((-0.7599999904632568359375) * powr(luminance, 2.0 / clampedShadows))) - luminance, 0.0, 1.0);
    float highlight = fast::clamp((1.0 - (powr(1.0 - luminance, 1.0 / fast::max(2.0 - _35.highlights, 9.9999997473787516355514526367188e-06)) + ((-0.800000011920928955078125) * powr(1.0 - luminance, 2.0 / fast::max(2.0 - _35.highlights, 9.9999997473787516355514526367188e-06))))) - luminance, -1.0, 0.0);
    float3 result = float3(0.0) + (((source.xyz - float3(0.0)) / float3(luminance - 0.0)) * (((luminance + shadow) + highlight) - 0.0));
    float contrastedLuminance = ((luminance - 0.5) * 1.5) + 0.5;
    float whiteInterp = (contrastedLuminance * contrastedLuminance) * contrastedLuminance;
    float whiteTarget = fast::clamp(_35.highlights, 1.0, 2.0) - 1.0;
    result = mix(result, float3(1.0), float3(whiteInterp * whiteTarget));
    float invContrastedLuminance = 1.0 - contrastedLuminance;
    float blackInterp = (invContrastedLuminance * invContrastedLuminance) * invContrastedLuminance;
    float blackTarget = 1.0 - fast::clamp(_35.shadows, 0.0, 1.0);
    result = mix(result, float3(0.0), float3(blackInterp * blackTarget));
    referenceColor = float4(result * source.w, source.w);
}

fragment refAM35_e783368bd50f0_out refAM35_e783368bd50f0(constant ReferenceUniformse783368bd50f0& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e783368bd50f0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, referenceColor);
    bool _212 = any(isnan(referenceColor));
    bool _219;
    if (!_212)
    {
        _219 = any(isinf(referenceColor));
    }
    else
    {
        _219 = _212;
    }
    if (_219)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _232 = referenceColor;
    float3 _238 = fast::clamp(_232.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _238.x;
    referenceColor.y = _238.y;
    referenceColor.z = _238.z;
    out.finalColor = referenceColor;
    return out;
}

