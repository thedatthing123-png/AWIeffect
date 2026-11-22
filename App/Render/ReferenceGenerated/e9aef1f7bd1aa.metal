// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxfrosted.xml
// Original source comments and attribution:
/////////////////////////
// float dist = 4.0; // how far to sample from
// float progressa = 6.; // how many times to sample, more = smoother
/////////////////////////
// vec2 uv = fragCoord/iResolution.xy;
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9aef1f7bd1aa
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progressa;
    char _m6_pad[12];
    float alpha;
};

struct refAM35_e9aef1f7bd1aa_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float rand(thread const float2& uv)
{
    return fract(sin(dot(uv, float2(12.98980045318603515625, 78.233001708984375))) * 43578.546875);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse9aef1f7bd1aa& _50, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _50.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = gl_FragCoord.xy / _50.refScreen.xy;
    float2 uv = syamjaidtz;
    float4 t = float4(0.0);
    float2 texel = float2(1.0) / float2(int2(refInput.get_width(), refInput.get_height()));
    float2 d = texel * _50.progressa;
    for (float i = 0.0; i < 3.0; i += 1.0)
    {
        float2 param_1 = uv * i;
        float r1 = fast::clamp((rand(param_1) * 2.0) - 1.0, -d.x, d.x);
        float2 param_2 = uv * (i + 3.0);
        float r2 = fast::clamp((rand(param_2) * 2.0) - 1.0, -d.y, d.y);
        float2 param_3 = uv + float2(r1, r2);
        t += texture2DCv(refInput, refInputSmplr, param_3);
    }
    t /= float4(3.0);
    float4 fragColor = t;
    referenceColor = mix(texColor, fragColor, float4(_50.alpha)) * texColor.w;
}

fragment refAM35_e9aef1f7bd1aa_out refAM35_e9aef1f7bd1aa(constant ReferenceUniformse9aef1f7bd1aa& _50 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9aef1f7bd1aa_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _50, referenceColor);
    bool _170 = any(isnan(referenceColor));
    bool _177;
    if (!_170)
    {
        _177 = any(isinf(referenceColor));
    }
    else
    {
        _177 = _170;
    }
    if (_177)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _191 = referenceColor;
    float3 _197 = fast::clamp(_191.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _197.x;
    referenceColor.y = _197.y;
    referenceColor.z = _197.z;
    out.finalColor = referenceColor;
    return out;
}

