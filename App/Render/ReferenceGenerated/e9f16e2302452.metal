// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/fourcolorgradient.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9f16e2302452
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float2 offset1;
    float4 color2;
    float2 offset2;
    float4 color3;
    float2 offset3;
    float4 color4;
    float2 offset4;
    char _m13_pad[8];
    float blend;
    char _m14_pad[12];
    float alpha;
    char _m15_pad[12];
    int blendMode;
};

struct refAM35_e9f16e2302452_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float gradientNoise(thread const float2& uv)
{
    return fract(52.98291778564453125 * fract(dot(uv, float2(0.067110560834407806396484375, 0.005837149918079376220703125))));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse9f16e2302452& _51, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _51.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _51.refLayer.xy) / _51.refLayer.zw;
    float2 pos = (_51.offset1 * float2(1.0, -1.0)) / float2(500.0);
    float t1 = length(st - pos);
    pos = (_51.offset2 * float2(1.0, -1.0)) / float2(500.0);
    float t2 = length(st - pos);
    pos = (_51.offset3 * float2(1.0, -1.0)) / float2(500.0);
    float t3 = length(st - pos);
    pos = (_51.offset4 * float2(1.0, -1.0)) / float2(500.0);
    float t4 = length(st - pos);
    float4 color = float4(0.0);
    float sw_t1 = smoothstep(0.0, 1.0, fast::clamp(1.0 - t1, 0.0, 1.0));
    float sw_t2 = smoothstep(0.0, 1.0, fast::clamp(1.0 - t2, 0.0, 1.0));
    float sw_t3 = smoothstep(0.0, 1.0, fast::clamp(1.0 - t3, 0.0, 1.0));
    float sw_t4 = smoothstep(0.0, 1.0, fast::clamp(1.0 - t4, 0.0, 1.0));
    color += (_51.color1 * powr(sw_t1, 1.0 / _51.blend));
    color += (_51.color2 * powr(sw_t2, 1.0 / _51.blend));
    color += (_51.color3 * powr(sw_t3, 1.0 / _51.blend));
    color += (_51.color4 * powr(sw_t4, 1.0 / _51.blend));
    color /= float4(((sw_t1 + sw_t2) + sw_t3) + sw_t4);
    color.w = 1.0;
    float2 param_1 = st;
    color += float4((0.0039215688593685626983642578125 * gradientNoise(param_1)) - 0.00196078442968428134918212890625);
    float4 result;
    if (_51.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(texColor.w)) * color.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_51.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - color.xyz)), 1.0) * texColor.w;
        }
        else
        {
            result = float4(color.xyz, 1.0) * texColor.w;
        }
    }
    referenceColor = mix(texColor, result, float4(_51.alpha));
}

fragment refAM35_e9f16e2302452_out refAM35_e9f16e2302452(constant ReferenceUniformse9f16e2302452& _51 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9f16e2302452_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _51, referenceColor);
    bool _293 = any(isnan(referenceColor));
    bool _300;
    if (!_293)
    {
        _300 = any(isinf(referenceColor));
    }
    else
    {
        _300 = _293;
    }
    if (_300)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _313 = referenceColor;
    float3 _319 = fast::clamp(_313.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _319.x;
    referenceColor.y = _319.y;
    referenceColor.z = _319.z;
    out.finalColor = referenceColor;
    return out;
}

