// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/colortune2.xml
// Original source comments and attribution:
//float hue = lift.x;
//float strength = lift.y;
// -- Do work here in YUV space ----
// -- Back to RGB and return result ---
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse0993d9baf897
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 lift;
    float3 gamma;
    float3 gain;
    float3 offset;
};

struct refAM35_e0993d9baf897_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse0993d9baf897& _108, thread float4& referenceColor)
{
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float2 param = gl_FragCoord.xy / _108.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float3 rgb = texColor.xyz;
    float a = texColor.w;
    float3 yuv = rgb * rgb2yuv;
    float3 param_1 = float3(_108.lift.x / 360.0, 1.0, 0.5);
    float3 liftYUV = (hsv2rgb(param_1) * rgb2yuv) * _108.lift.y;
    float3 param_2 = float3(_108.gamma.x / 360.0, 1.0, 0.5);
    float3 gammaYUV = (hsv2rgb(param_2) * rgb2yuv) * _108.gamma.y;
    float3 param_3 = float3(_108.gain.x / 360.0, 1.0, 0.5);
    float3 gainYUV = (hsv2rgb(param_3) * rgb2yuv) * _108.gain.y;
    float3 param_4 = float3(_108.offset.x / 360.0, 1.0, 0.5);
    float3 offsetYUV = (hsv2rgb(param_4) * rgb2yuv) * _108.offset.y;
    float y = yuv.x;
    float ygamma = 1.0 - powr(abs((y - 0.5) * 2.0), 2.0);
    float3 _206 = yuv;
    float2 _208 = _206.yz + ((liftYUV.yz * ((1.0 - y) * (1.0 - y))) * a);
    yuv.y = _208.x;
    yuv.z = _208.y;
    yuv.x += ((((1.0 - y) * (1.0 - y)) * _108.lift.z) * a);
    float3 _233 = yuv;
    float2 _235 = _233.yz + ((gammaYUV.yz * ygamma) * a);
    yuv.y = _235.x;
    yuv.z = _235.y;
    yuv.x += ((_108.gamma.z * ygamma) * a);
    float3 _258 = yuv;
    float2 _260 = _258.yz + ((gainYUV.yz * (y * y)) * a);
    yuv.y = _260.x;
    yuv.z = _260.y;
    yuv.x += ((_108.gain.z * (y * y)) * a);
    float3 _281 = yuv;
    float2 _283 = _281.yz + (offsetYUV.yz * a);
    yuv.y = _283.x;
    yuv.z = _283.y;
    yuv.x += (_108.offset.z * a);
    rgb = yuv * yuv2rgb;
    referenceColor = float4(rgb, a);
}

fragment refAM35_e0993d9baf897_out refAM35_e0993d9baf897(constant ReferenceUniformse0993d9baf897& _108 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e0993d9baf897_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _108, referenceColor);
    bool _313 = any(isnan(referenceColor));
    bool _320;
    if (!_313)
    {
        _320 = any(isinf(referenceColor));
    }
    else
    {
        _320 = _313;
    }
    if (_320)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _333 = referenceColor;
    float3 _339 = fast::clamp(_333.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _339.x;
    referenceColor.y = _339.y;
    referenceColor.z = _339.z;
    out.finalColor = referenceColor;
    return out;
}

