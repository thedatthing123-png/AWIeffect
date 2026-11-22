// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/vignette.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse7c9356e79187
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float scale;
    char _m6_pad[12];
    float roundness;
    char _m7_pad[12];
    float feather;
    char _m8_pad[12];
    float strength;
    char _m9_pad[12];
    float tint;
    float4 overlaycolor;
    uint punchout;
};

struct refAM35_e7c9356e79187_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse7c9356e79187& _34, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st = (gl_FragCoord.xy - _34.refLayer.xy) / _34.refLayer.zw;
    st -= float2(0.5);
    st *= 2.0;
    st /= float2(_34.scale + (_34.feather / 4.0));
    float n = _34.roundness + 1.0;
    float d = powr(abs(st.x), n) + powr(abs(st.y), n);
    float p = smoothstep(1.0 - _34.feather, 1.0, d);
    float2 param = gl_FragCoord.xy / _34.refScreen.xy;
    float4 color = texture2DCv(refInput, refInputSmplr, param);
    float4 darkColor = color;
    float4 _108 = darkColor;
    float4 _110 = darkColor;
    float3 _112 = _110.xyz * _108.xyz;
    darkColor.x = _112.x;
    darkColor.y = _112.y;
    darkColor.z = _112.z;
    float4 _120 = darkColor;
    float3 _134 = mix(_120.xyz, _34.overlaycolor.xyz * color.w, float3(_34.tint));
    darkColor.x = _134.x;
    darkColor.y = _134.y;
    darkColor.z = _134.z;
    if (_34.punchout != 0u)
    {
        referenceColor = mix(color, float4(0.0), float4(p * _34.strength));
    }
    else
    {
        referenceColor = mix(color, darkColor, float4(p * _34.strength));
    }
}

fragment refAM35_e7c9356e79187_out refAM35_e7c9356e79187(constant ReferenceUniformse7c9356e79187& _34 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e7c9356e79187_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _34, refInput, refInputSmplr, referenceColor);
    bool _174 = any(isnan(referenceColor));
    bool _181;
    if (!_174)
    {
        _181 = any(isinf(referenceColor));
    }
    else
    {
        _181 = _174;
    }
    if (_181)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _194 = referenceColor;
    float3 _200 = fast::clamp(_194.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _200.x;
    referenceColor.y = _200.y;
    referenceColor.z = _200.z;
    out.finalColor = referenceColor;
    return out;
}

