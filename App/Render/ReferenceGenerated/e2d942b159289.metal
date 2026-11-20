// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/star.xml
// Original source comments and attribution:
//vec2 l2s( vec2 v ) {
//    return (vec4(v,0.,1.)*acLayerToScreen).xy;
//}
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse2d942b159289
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float radius;
    char _m7_pad[12];
    float brightness;
    char _m8_pad[12];
    float shine;
    float4 color;
    float pointCount;
    char _m11_pad[12];
    float alpha;
    char _m12_pad[12];
    int blendMode;
};

struct refAM35_e2d942b159289_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float star(thread const float2& st, thread const float2& center, thread const float& r, thread const float& insideRadiusScale, thread const float& points)
{
    float2 dc = st - center;
    float ir = r * insideRadiusScale;
    float a = (precise::atan2(dc.x, dc.y) + 3.141590118408203125) / 2.0;
    float p = smoothstep(r, ir, length(dc));
    a = smoothstep(p, ir, abs(sin(a * points)));
    return fast::clamp((((p * 1.26400005817413330078125) + a) * p) * p, 0.0, 1.0);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse2d942b159289& _94, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _94.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _94.refLayer.xy) / _94.refLayer.zw;
    st.y = 1.0 - st.y;
    st -= float2(0.5);
    st.x *= (_94.refLayer.z / _94.refLayer.w);
    float2 param_1 = st;
    float2 param_2 = _94.position / float2(1000.0);
    float param_3 = _94.radius;
    float param_4 = _94.shine * 0.99500000476837158203125;
    float param_5 = _94.pointCount;
    float p = star(param_1, param_2, param_3, param_4, param_5);
    float4 adjColor = fast::clamp(float4((mix(_94.color.xyz + float3(0.1500000059604644775390625), float3(1.0), float3(0.0500000007450580596923828125)) * p) * _94.brightness, 1.0), float4(0.0), float4(1.0)) * p;
    float4 result;
    if (_94.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(texColor.w)) * adjColor.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_94.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - adjColor.xyz)), 1.0) * texColor.w;
        }
        else
        {
            result = adjColor * texColor.w;
            result = (texColor * (1.0 - result.w)) + result;
        }
    }
    referenceColor = mix(texColor, result, float4(_94.alpha));
}

fragment refAM35_e2d942b159289_out refAM35_e2d942b159289(constant ReferenceUniformse2d942b159289& _94 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e2d942b159289_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _94, referenceColor);
    bool _269 = any(isnan(referenceColor));
    bool _276;
    if (!_269)
    {
        _276 = any(isinf(referenceColor));
    }
    else
    {
        _276 = _269;
    }
    if (_276)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    out.finalColor = referenceColor;
    return out;
}

