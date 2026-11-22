// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/curl.xml
// Original source comments and attribution:
//vec4 texColor = texture2DCv(inputImg.texture,acScreenNorm);
//st.x *= acLayerSize.x/acLayerSize.y;
// = center/1000.;
//bool top = (origin==0 || origin==1);
//bool right = (origin==1 || origin==3);
// (center.y>=500.);
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

struct ReferenceUniformseb060c3395f8c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float offset;
    char _m6_pad[12];
    float radius;
    char _m7_pad[12];
    int curlFrom;
    char _m8_pad[12];
    int curlDirection;
    char _m9_pad[12];
    float stretch;
};

struct refAM35_eb060c3395f8c_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformseb060c3395f8c& _39)
{
    return (float4(v, 0.0, 1.0) * _39.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseb060c3395f8c& _39, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st = (gl_FragCoord.xy - _39.refLayer.xy) / _39.refLayer.zw;
    float2 adjCenter;
    if (_39.curlDirection == 0)
    {
        adjCenter = float2(_39.offset, -_39.radius);
    }
    else
    {
        adjCenter = float2(_39.offset, 1.0 + _39.radius);
    }
    adjCenter.y = 1.0 - adjCenter.y;
    float2 dd = st - adjCenter;
    dd.x *= (_39.refLayer.z / _39.refLayer.w);
    float circ = ((6.283185482025146484375 * _39.radius) / (_39.refLayer.z / _39.refLayer.w)) * _39.stretch;
    float a = 0.5 - (precise::atan2(dd.x, dd.y) / 6.283185482025146484375);
    float r = length(dd);
    bool top = _39.curlDirection == 1;
    bool right = _39.curlFrom == 0;
    float cline = smoothstep(1.0 - (2.0 / _39.refLayer.w), 1.0, 1.0 - abs(_39.radius - length(dd)));
    if (top)
    {
        float topY = adjCenter.y + _39.radius;
        a = mod(a - 0.5, 1.0);
        float arcDist = a * circ;
        if (right)
        {
            float2 v = float2(adjCenter.x - arcDist, topY + (r - _39.radius));
            bool _198 = st.x < adjCenter.x;
            bool _206;
            if (!_198)
            {
                _206 = st.y < topY;
            }
            else
            {
                _206 = _198;
            }
            if (_206)
            {
                st = v;
            }
        }
        else
        {
            float2 v_1 = float2((circ - arcDist) + adjCenter.x, topY + (r - _39.radius));
            bool _229 = st.x > adjCenter.x;
            bool _237;
            if (!_229)
            {
                _237 = st.y < topY;
            }
            else
            {
                _237 = _229;
            }
            if (_237)
            {
                st = v_1;
            }
        }
    }
    else
    {
        float bottomY = adjCenter.y - _39.radius;
        float arcDist_1 = a * circ;
        if (right)
        {
            float2 v_2 = float2(adjCenter.x - (circ - arcDist_1), bottomY - (r - _39.radius));
            bool _273 = st.x < adjCenter.x;
            bool _281;
            if (!_273)
            {
                _281 = st.y > bottomY;
            }
            else
            {
                _281 = _273;
            }
            if (_281)
            {
                st = v_2;
            }
        }
        else
        {
            float2 v_3 = float2(arcDist_1 + adjCenter.x, bottomY - (r - _39.radius));
            bool _302 = st.x > adjCenter.x;
            bool _310;
            if (!_302)
            {
                _310 = st.y > bottomY;
            }
            else
            {
                _310 = _302;
            }
            if (_310)
            {
                st = v_3;
            }
        }
    }
    float inside = (((step(0.0, st.x) * step(st.x, 1.0)) * step(0.0, st.y)) * step(st.y, 1.0)) * step(_39.radius, r);
    float2 param = st;
    float2 param_1 = l2s(param, _39);
    float4 result = texture2DCv(refInput, refInputSmplr, param_1) * inside;
    float4 circleColor = float4(0.20000000298023223876953125, 0.60000002384185791015625, 0.89999997615814208984375, 1.0);
    float circleAlpha = 0.0;
    referenceColor = mix(result, circleColor, float4(cline * circleAlpha));
}

fragment refAM35_eb060c3395f8c_out refAM35_eb060c3395f8c(constant ReferenceUniformseb060c3395f8c& _39 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb060c3395f8c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_39, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _365 = any(isnan(referenceColor));
    bool _372;
    if (!_365)
    {
        _372 = any(isinf(referenceColor));
    }
    else
    {
        _372 = _365;
    }
    if (_372)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _386 = referenceColor;
    float3 _392 = fast::clamp(_386.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _392.x;
    referenceColor.y = _392.y;
    referenceColor.z = _392.z;
    out.finalColor = referenceColor;
    return out;
}

