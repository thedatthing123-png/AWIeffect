// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/colorhot.xml
// Original source comments and attribution:
//float lowHue = hue;
//float highHue = hue2;
//vec3 lowColor = hsv2rgb(vec3(hue,sat,1.0));
//vec3 baseColor = hsv2rgb(vec3((lowHue+highHue)/2.0,sat,1.0));
//vec3 highColor = hsv2rgb(vec3(highHue,sat,1.0));
//if( abs(hue-lowHue) > abs(hue-highHue) ) {
//    lightColor = highColor;
//    darkColor = lowColor;
//} else {
//    lightColor = lowColor;
//    darkColor = highColor;
//}
//vec3 blendColor = luminance < cutoff ? mix( darkColor, baseColor, luminance*2.) :  mix( baseColor, lightColor, (luminance-cutoff)*(1./cutoff));
//vec3 darkColor = hsv2rgb(vec3(fract(hue+.95),sat,1.0)) * rgb2yuv;
//vec3 baseColor = hsv2rgb(vec3(hue,sat,1.0)) * rgb2yuv;
//vec3 brightColor = hsv2rgb(vec3(fract(hue+.05),sat,1.)) * rgb2yuv;
//
//vec3 outColor;
//if( luminance < 0.25 ) {
//    outColor = mix(vec3(0.),darkColor,(luminance*4.));
//} else if( luminance < 0.5 ) {
//    outColor = mix(darkColor,baseColor,((luminance-0.25)*4.));
//} else if( luminance < 0.75 ) {
//    outColor = mix(baseColor,brightColor,((luminance-0.5)*4.));
//} else {
//    outColor = brightColor; // mix(brightColor,vec3(1.,0.0,0.0),((luminance-0.75)*4.));
//}
//
//outColor.x = luminance;
//
//vec3 rgb = outColor * yuv2rgb;
//
//if( luminance >= 0.75 ) {
//    rgb = mix(rgb,vec3(1.),((luminance-0.75)*4.));
//}
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea8e0a421faa8
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 color;
    float3 tint;
};

struct refAM35_ea8e0a421faa8_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsea8e0a421faa8& _83, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _83.refScreen.xy;
    float4 source = texture2DCv(refInput, refInputSmplr, param);
    float luminance = dot(source.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float gamma = _83.color.z + 1.0;
    luminance = powr(luminance, 1.0 / gamma);
    float hue = _83.color.x / 360.0;
    float sat = _83.color.y;
    float hue2 = _83.tint.x / 360.0;
    float sat2 = _83.tint.y;
    float3 param_1 = float3(hue, sat, 1.0);
    float3 darkColor = hsv2rgb(param_1);
    float3 param_2 = float3(hue, sat, 1.0);
    float3 baseColor = hsv2rgb(param_2);
    float3 param_3 = float3(hue2, sat2, 1.0);
    float3 lightColor = hsv2rgb(param_3);
    float cutoff = (_83.tint.z / 2.0) + 0.5;
    float3 _158;
    if (luminance < cutoff)
    {
        _158 = mix(darkColor, baseColor, float3(luminance / cutoff));
    }
    else
    {
        _158 = mix(baseColor, lightColor, float3((luminance - cutoff) / (1.0 - cutoff)));
    }
    float3 blendColor = _158;
    float3 yuv = blendColor * float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    yuv.x = luminance;
    float3 _200 = yuv;
    float2 _202 = _200.yz * luminance;
    yuv.y = _202.x;
    yuv.z = _202.y;
    blendColor = yuv * float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float shineStart = 0.85000002384185791015625;
    float shineAmount = fast::max(0.0, luminance - shineStart) * (1.0 / (1.0 - shineStart));
    shineAmount = (shineAmount * shineAmount) * sat;
    blendColor = mix(blendColor, float3(1.0), float3(shineAmount));
    referenceColor = float4(blendColor, 1.0) * source.w;
}

fragment refAM35_ea8e0a421faa8_out refAM35_ea8e0a421faa8(constant ReferenceUniformsea8e0a421faa8& _83 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea8e0a421faa8_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _83, referenceColor);
    bool _254 = any(isnan(referenceColor));
    bool _261;
    if (!_254)
    {
        _261 = any(isinf(referenceColor));
    }
    else
    {
        _261 = _254;
    }
    if (_261)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _274 = referenceColor;
    float3 _280 = fast::clamp(_274.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _280.x;
    referenceColor.y = _280.y;
    referenceColor.z = _280.z;
    out.finalColor = referenceColor;
    return out;
}

