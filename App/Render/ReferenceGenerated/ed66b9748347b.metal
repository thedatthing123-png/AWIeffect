// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxhdr.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
// vec4 compCol = texture2DCv(comp.texture,acScreenNorm);
//Gamma 
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsed66b9748347b
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float strength;
    char _m6_pad[12];
    float exposure;
    char _m7_pad[12];
    float alpha;
    char _m8_pad[12];
    float iter;
};

struct refAM35_ed66b9748347b_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformsed66b9748347b& _48, thread float4& gl_FragCoord, texture2d<float> refBuffer1, sampler refBuffer1Smplr, thread float4& referenceColor)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param);
    float maxF = fast::max(_48.refScreen.x, _48.refScreen.y);
    float2 texelSize = float2(1.0) / float2(maxF);
    float2 syamjaidtz = gl_FragCoord.xy / _48.refScreen.xy;
    float2 param_1 = gl_FragCoord.xy / _48.refScreen.xy;
    float4 texColorOri = texture2DCv(refInput, refInputSmplr, param_1);
    float2 param_2 = gl_FragCoord.xy / _48.refScreen.xy;
    float4 blurCol = texture2DCv(refBuffer1, refBuffer1Smplr, param_2);
    float3x3 rgb2yuv = float3x3(float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625), float3(-0.14712999761104583740234375, -0.2888599932193756103515625, 0.43599998950958251953125), float3(0.6150000095367431640625, -0.51498997211456298828125, -0.100010000169277191162109375));
    float3x3 yuv2rgb = float3x3(float3(1.0, 0.0, 1.13982999324798583984375), float3(1.0, -0.3946500122547149658203125, -0.5806000232696533203125), float3(1.0, 2.0321099758148193359375, 0.0));
    float4 expCol = blurCol;
    float3 rgb = expCol.xyz;
    float a = expCol.w;
    rgb += (float3(0.0) * a);
    rgb = powr(rgb, float3(1.0));
    rgb *= powr(2.0, -_48.exposure);
    float4 _exp = float4(rgb, a);
    float4 subb = float4(texColorOri.xyz - _exp.xyz, texColorOri.w);
    float3 bot = subb.xyz;
    float3 top = float3(1.0) * _exp.w;
    float3 t = smoothstep(float3(0.5), float3(0.5), bot);
    float3 result = (t * (float3(1.0) - ((float3(1.0) - ((bot - float3(0.5)) * 2.0)) * (float3(1.0) - top)))) + ((float3(1.0) - t) * ((bot * 2.0) * top));
    float4 fragColor = float4(result, subb.w);
    referenceColor = mix(texColorOri, fragColor, float4(_48.alpha));
}

fragment refAM35_ed66b9748347b_out refAM35_ed66b9748347b(constant ReferenceUniformsed66b9748347b& _48 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed66b9748347b_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _48, gl_FragCoord, refBuffer1, refBuffer1Smplr, referenceColor);
    bool _226 = any(isnan(referenceColor));
    bool _233;
    if (!_226)
    {
        _233 = any(isinf(referenceColor));
    }
    else
    {
        _233 = _226;
    }
    if (_233)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _246 = referenceColor;
    float3 _252 = fast::clamp(_246.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _252.x;
    referenceColor.y = _252.y;
    referenceColor.z = _252.z;
    out.finalColor = referenceColor;
    return out;
}

