// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxssharpenv3.xml
// Original source comments and attribution:
//////////////////////////
//////////////////////////
/////////////////////////
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef2dcaa1a1b11
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int TYPE;
    char _m6_pad[12];
    float radius;
    char _m7_pad[12];
    float sharpness;
    char _m8_pad[12];
    float alpha;
};

struct refAM35_ef2dcaa1a1b11_out
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
void referenceMain(thread float3& rgb2gray, constant ReferenceUniformsef2dcaa1a1b11& _43, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_43.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _43.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_43.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _43.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_43.refScreen.x, _43.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 param_3 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 _step = (float2(1.0) / getTexSize(param_3)) * _43.radius;
            float2 param_4 = gl_FragCoord.xy / _43.refScreen.xy;
            float4 srcColor = texture2DCv(refInput, refInputSmplr, param_4);
            float3 color = float3(0.0);
            float2 param_5 = (gl_FragCoord.xy / _43.refScreen.xy) + (_step * float2(-1.0));
            float p1 = dot(rgb2gray, texture2DCv(refInput, refInputSmplr, param_5).xyz);
            float2 param_6 = (gl_FragCoord.xy / _43.refScreen.xy) + (_step * float2(0.0, -1.0));
            float p2 = dot(rgb2gray, texture2DCv(refInput, refInputSmplr, param_6).xyz);
            float2 param_7 = (gl_FragCoord.xy / _43.refScreen.xy) + (_step * float2(1.0, -1.0));
            float p3 = dot(rgb2gray, texture2DCv(refInput, refInputSmplr, param_7).xyz);
            float2 param_8 = (gl_FragCoord.xy / _43.refScreen.xy) + (_step * float2(-1.0, 0.0));
            float p4 = dot(rgb2gray, texture2DCv(refInput, refInputSmplr, param_8).xyz);
            float p5 = dot(rgb2gray, srcColor.xyz);
            float2 param_9 = (gl_FragCoord.xy / _43.refScreen.xy) + (_step * float2(1.0, 0.0));
            float p6 = dot(rgb2gray, texture2DCv(refInput, refInputSmplr, param_9).xyz);
            float2 param_10 = (gl_FragCoord.xy / _43.refScreen.xy) + (_step * float2(-1.0, 1.0));
            float p7 = dot(rgb2gray, texture2DCv(refInput, refInputSmplr, param_10).xyz);
            float2 param_11 = (gl_FragCoord.xy / _43.refScreen.xy) + (_step * float2(0.0, 1.0));
            float p8 = dot(rgb2gray, texture2DCv(refInput, refInputSmplr, param_11).xyz);
            float2 param_12 = (gl_FragCoord.xy / _43.refScreen.xy) + (_step * float2(1.0));
            float p9 = dot(rgb2gray, texture2DCv(refInput, refInputSmplr, param_12).xyz);
            float f1 = ((2.0 * p5) - p4) - p6;
            float f2 = ((2.0 * p5) - p2) - p8;
            float f3 = ((2.0 * p5) - p3) - p7;
            float f4 = ((2.0 * p5) - p1) - p9;
            float maxf = fast::max(fast::max(fast::max(abs(f1), abs(f2)), abs(f3)), abs(f4));
            float3 ycbcr = float3x3(float3(0.2989999949932098388671875, -0.16873599588871002197265625, 0.5), float3(0.58700001239776611328125, -0.3312639892101287841796875, -0.418687999248504638671875), float3(0.114000000059604644775390625, 0.5, -0.081312000751495361328125)) * srcColor.xyz;
            float f;
            if (_43.TYPE == 0)
            {
                f = f1;
            }
            else
            {
                if (_43.TYPE == 1)
                {
                    f = f2;
                }
                else
                {
                    if (_43.TYPE == 2)
                    {
                        f = f3;
                    }
                    else
                    {
                        if (_43.TYPE == 3)
                        {
                            f = f4;
                        }
                    }
                }
            }
            color = float3x3(float3(1.0), float3(0.0, -0.3441359996795654296875, 1.77199995517730712890625), float3(1.401999950408935546875, -0.71413600444793701171875, 0.0)) * (ycbcr + float3((_43.sharpness * f) * 0.5, 0.0, 0.0));
            float4 fragColor = float4(color, srcColor.w);
            referenceColor = mix(texColor, fragColor, float4(_43.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_ef2dcaa1a1b11_out refAM35_ef2dcaa1a1b11(constant ReferenceUniformsef2dcaa1a1b11& _43 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef2dcaa1a1b11_out out = {};
    float3 rgb2gray = float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625);
    float4 referenceColor = float4(0.0);
    referenceMain(rgb2gray, _43, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _400 = any(isnan(referenceColor));
    bool _407;
    if (!_400)
    {
        _407 = any(isinf(referenceColor));
    }
    else
    {
        _407 = _400;
    }
    if (_407)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _420 = referenceColor;
    float3 _426 = fast::clamp(_420.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _426.x;
    referenceColor.y = _426.y;
    referenceColor.z = _426.z;
    out.finalColor = referenceColor;
    return out;
}

