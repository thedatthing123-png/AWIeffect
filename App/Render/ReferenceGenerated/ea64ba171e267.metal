// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/spectralmap.xml
// Original source comments and attribution:
//float mapChannelSmooth(float p, float f) {
//    float t = mod(p+10.,1.);
//    return (smoothstep(f*2.0,0.,t) + smoothstep(f,1.,t) - f)*2.;
//    //return smoothstep(0.5,0.,t) + smoothstep(0.5,1.,t);
//}
//vec4 aa;
//vec4 bb;
//vec4 cc;
//
//float f = mix(0.333, 0.1, squeeze );
//
//if(smooth) {
//    aa = mapChannelSmooth(luminance,f)*redColor;
//    bb = mapChannelSmooth(luminance-1./3.0,f)*greenColor;
//    cc = mapChannelSmooth(luminance-2./3.0,f)*blueColor;
//} else {
//    aa = mapChannel(luminance,f)*redColor;
//    bb = mapChannel(luminance-1./3.0,f)*greenColor;
//    cc = mapChannel(luminance-2./3.0,f)*blueColor;
//}
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

struct ReferenceUniformsea64ba171e267
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float phase;
    char _m6_pad[12];
    float repeat;
    char _m7_pad[12];
    float alpha;
    char _m8_pad[12];
    float squeeze;
    char _m9_pad[12];
    float saturation;
    float4 redColor;
    float4 greenColor;
    float4 blueColor;
    uint reverse;
    char _m14_pad[12];
    uint scaleBrightness;
};

struct refAM35_ea64ba171e267_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float mapChannel(thread const float& p, thread const float& f)
{
    float t = mod(p + 10.0, 1.0);
    return fast::clamp((abs(t - 0.5) * 4.0) - f, 0.0, 1.0);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsea64ba171e267& _86, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float2 param = gl_FragCoord.xy / _86.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float luminance = dot(texColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float bscale = (_86.scaleBrightness != 0u) ? luminance : 1.0;
    if (_86.reverse != 0u)
    {
        luminance = 1.0 - luminance;
    }
    luminance = (luminance * _86.repeat) + _86.phase;
    float f = mix(0.333000004291534423828125, 0.100000001490116119384765625, _86.squeeze);
    float param_1 = luminance;
    float param_2 = f;
    float4 aa = _86.redColor * mapChannel(param_1, param_2);
    float param_3 = luminance - 0.3333333432674407958984375;
    float param_4 = f;
    float4 bb = _86.greenColor * mapChannel(param_3, param_4);
    float param_5 = luminance - 0.666666686534881591796875;
    float param_6 = f;
    float4 cc = _86.blueColor * mapChannel(param_5, param_6);
    float4 result = (aa + bb) + cc;
    float3 yuv = result.xyz * rgb2yuv;
    float3 _185 = yuv;
    float2 _191 = _185.yz * (_86.saturation + 1.0);
    yuv.y = _191.x;
    yuv.z = _191.y;
    float3 _200 = yuv * yuv2rgb;
    result.x = _200.x;
    result.y = _200.y;
    result.z = _200.z;
    referenceColor = mix(texColor, (result * float4(bscale, bscale, bscale, 1.0)) * texColor.w, float4(_86.alpha));
}

fragment refAM35_ea64ba171e267_out refAM35_ea64ba171e267(constant ReferenceUniformsea64ba171e267& _86 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea64ba171e267_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _86, referenceColor);
    bool _228 = any(isnan(referenceColor));
    bool _235;
    if (!_228)
    {
        _235 = any(isinf(referenceColor));
    }
    else
    {
        _235 = _228;
    }
    if (_235)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _248 = referenceColor;
    float3 _254 = fast::clamp(_248.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _254.x;
    referenceColor.y = _254.y;
    referenceColor.z = _254.z;
    out.finalColor = referenceColor;
    return out;
}

