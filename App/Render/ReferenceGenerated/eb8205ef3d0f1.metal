// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/simplestars2.xml
// Original source comments and attribution:
//const float layers = 25.;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb8205ef3d0f1
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 starParallax;
    float scale;
    char _m7_pad[12];
    float starSize;
    char _m8_pad[12];
    float starFeather;
    float4 color;
    float alpha;
    char _m11_pad[12];
    float starCount;
    char _m12_pad[12];
    float brightness;
    char _m13_pad[12];
    int blendMode;
};

struct refAM35_eb8205ef3d0f1_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float rand(thread const float2& co)
{
    return fract(sin(dot(co, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 rand2(thread const float2& co)
{
    float2 param = co;
    float2 param_1 = co + float2(26.5841217041015625, 64.185516357421875);
    return float2(rand(param), rand(param_1));
}

static inline __attribute__((always_inline))
float star(thread const float2& st, thread const float& size, thread const float& feather)
{
    float adjFeather = size * feather;
    return smoothstep((1.0 - size) - adjFeather, 1.0 - size, sin(st.x * 20.0) * sin(st.y * 20.0));
}

static inline __attribute__((always_inline))
float stars(thread const float2& st, thread const float2& parallax, thread const float& depth, thread float& size, thread const float& feather, constant ReferenceUniformseb8205ef3d0f1& _122)
{
    float p = 0.0;
    size *= 0.001000000047497451305389404296875;
    float f = fract(depth);
    float layer = floor(depth);
    for (float i = 1.0; i < _122.starCount; i += 1.0)
    {
        float2 uv = st;
        uv *= ((i - f) / 9.0);
        uv += parallax;
        float2 param = float2(i + layer, 2.9040000438690185546875);
        float2 param_1 = uv + rand2(param);
        float param_2 = size;
        float param_3 = feather;
        p += (star(param_1, param_2, param_3) * smoothstep(_122.starCount, 1.0, i - f));
    }
    return p;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseb8205ef3d0f1& _122, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _122.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _122.refLayer.xy) / _122.refLayer.zw;
    st.y = 1.0 - st.y;
    st -= float2(0.5);
    st.x *= (_122.refLayer.z / _122.refLayer.w);
    st /= float2(_122.scale);
    float2 param_1 = st;
    float2 param_2 = (-_122.starParallax.xy) / float2(1000.0);
    float param_3 = _122.starParallax.z / 45.0;
    float param_4 = _122.starSize;
    float param_5 = _122.starFeather;
    float _248 = stars(param_1, param_2, param_3, param_4, param_5, _122);
    float p = _248;
    float4 adjColor = fast::clamp(float4((mix(_122.color.xyz + float3(0.1500000059604644775390625), float3(1.0), float3(0.0500000007450580596923828125)) * p) * _122.brightness, 1.0), float4(0.0), float4(1.0)) * p;
    float4 result;
    if (_122.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(texColor.w)) * adjColor.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_122.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - adjColor.xyz)), 1.0) * texColor.w;
        }
        else
        {
            if (_122.blendMode == 3)
            {
                result = texColor * (1.0 - fast::min(p, 1.0));
            }
            else
            {
                result = adjColor * texColor.w;
                result = (texColor * (1.0 - result.w)) + result;
            }
        }
    }
    referenceColor = mix(texColor, result, float4(_122.alpha));
}

fragment refAM35_eb8205ef3d0f1_out refAM35_eb8205ef3d0f1(constant ReferenceUniformseb8205ef3d0f1& _122 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb8205ef3d0f1_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_122, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _367 = any(isnan(referenceColor));
    bool _374;
    if (!_367)
    {
        _374 = any(isinf(referenceColor));
    }
    else
    {
        _374 = _367;
    }
    if (_374)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _387 = referenceColor;
    float3 _393 = fast::clamp(_387.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _393.x;
    referenceColor.y = _393.y;
    referenceColor.z = _393.z;
    out.finalColor = referenceColor;
    return out;
}

