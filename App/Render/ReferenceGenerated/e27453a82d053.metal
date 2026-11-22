// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/radial_rays.xml
// Original source comments and attribution:
//float rt0 = abs(t-0.5)/halfWidth;
//float rt1 = 1.-clamp((outerRadius-r)/halfWidth,0.,1.);
//float rt = rt0*rt1;
//-((cos(rt))*rounding);
//float insideRound = smoothstep(ir-rounding, ir+rounding, r);
//float outsideRound = smoothstep(or+rounding, or-rounding, r);
//float lowRound = smoothstep(0.5-halfWidth-rounding,0.5-halfWidth+rounding,t);
//float highRound = smoothstep(0.5+halfWidth+rounding,0.5+halfWidth-rounding,t);
//
//float roundLimit = smoothstep(0.5,0.501,insideRound * outsideRound * lowRound * highRound);
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

struct ReferenceUniformse27453a82d053
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float pointCount;
    char _m7_pad[12];
    float rayWidth;
    char _m8_pad[12];
    float angle;
    float4 color;
    float alpha;
    char _m11_pad[12];
    int blendMode;
    char _m12_pad[12];
    float innerRadius;
    char _m13_pad[12];
    float outerRadius;
    char _m14_pad[12];
    float feather;
    char _m15_pad[12];
    float radialFeather;
    char _m16_pad[12];
    float bendStrength;
    char _m17_pad[12];
    float bendFrequency;
    char _m18_pad[12];
    float bendPhase;
};

struct refAM35_e27453a82d053_out
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
float rays(thread const float2& st, thread const float& pixelSize, thread const float& feather, thread const float& width, thread const float& count, thread const float& innerRadius, thread const float& outerRadius, thread const float& radialFeather, thread const float& bendStrength, thread const float& bendFrequency, thread const float& bendPhase, thread const float& angle)
{
    float r = length(st);
    float theta = (precise::atan2(st.x, st.y) + angle) / 6.283185482025146484375;
    theta += (sin((r * bendFrequency) + bendPhase) * bendStrength);
    float sweep = 1.0 / count;
    float t = mod(theta, sweep) / sweep;
    float h = ((feather / 2.0) * pixelSize) / r;
    float halfWidth = width / 2.0;
    float low = smoothstep((0.5 - halfWidth) - h, (0.5 - halfWidth) + h, t);
    float high = smoothstep((0.5 + halfWidth) + h, (0.5 + halfWidth) - h, t);
    float rf = (radialFeather / 2.0) * pixelSize;
    float orad = outerRadius;
    float ir = innerRadius;
    float inside = smoothstep(ir - rf, ir + rf, r);
    float outside = smoothstep(orad + rf, orad - rf, r);
    return ((low * high) * inside) * outside;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse27453a82d053& _165, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _165.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _165.refLayer.xy) / _165.refLayer.zw;
    st.y = 1.0 - st.y;
    st -= float2(0.5);
    st.x *= (_165.refLayer.z / _165.refLayer.w);
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float pixelSize = 1.0 / length(getTexSize(param_1));
    float2 param_2 = st - (_165.position / float2(1000.0));
    float param_3 = pixelSize;
    float param_4 = _165.feather;
    float param_5 = _165.rayWidth;
    float param_6 = _165.pointCount;
    float param_7 = _165.innerRadius;
    float param_8 = _165.outerRadius;
    float param_9 = _165.radialFeather;
    float param_10 = _165.bendStrength / 10.0;
    float param_11 = _165.bendFrequency;
    float param_12 = _165.bendPhase;
    float param_13 = _165.angle / 57.29579925537109375;
    float p = rays(param_2, param_3, param_4, param_5, param_6, param_7, param_8, param_9, param_10, param_11, param_12, param_13);
    float4 adjColor = float4(_165.color.xyz * _165.color.w, _165.color.w) * p;
    float4 result;
    if (_165.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(fast::max(texColor.w, 9.9999997473787516355514526367188e-06))) * adjColor.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_165.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(fast::max(texColor.w, 9.9999997473787516355514526367188e-06)))) * (float3(1.0) - adjColor.xyz)), 1.0) * texColor.w;
        }
        else
        {
            result = float4((adjColor.xyz * texColor.w) + (texColor.xyz * (1.0 - adjColor.w)), texColor.w);
        }
    }
    referenceColor = mix(texColor, result, float4(_165.alpha));
}

fragment refAM35_e27453a82d053_out refAM35_e27453a82d053(constant ReferenceUniformse27453a82d053& _165 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e27453a82d053_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _165, referenceColor);
    bool _381 = any(isnan(referenceColor));
    bool _388;
    if (!_381)
    {
        _388 = any(isinf(referenceColor));
    }
    else
    {
        _388 = _381;
    }
    if (_388)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _401 = referenceColor;
    float3 _407 = fast::clamp(_401.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _407.x;
    referenceColor.y = _407.y;
    referenceColor.z = _407.z;
    out.finalColor = referenceColor;
    return out;
}

