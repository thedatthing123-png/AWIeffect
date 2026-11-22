// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/pinchbulgeinside.xml
// Original source comments and attribution:
//p *= damping * insideLayer;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse6a4f65d4030d
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 centerPoint;
    char _m6_pad[8];
    float strength;
    char _m7_pad[12];
    float radius;
    char _m8_pad[12];
    float feather;
    char _m9_pad[12];
    uint gaussian;
};

struct refAM35_e6a4f65d4030d_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float gsmooth(thread const float& low, thread const float& high, thread const float& value)
{
    float p = fast::clamp((value - low) / (high - low), 0.0, 1.0);
    p -= 1.0;
    return powr(2.7182800769805908203125, -((p * p) / 0.125));
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse6a4f65d4030d& _46)
{
    return (float4(v, 0.0, 1.0) * _46.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse6a4f65d4030d& _46, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 st = (gl_FragCoord.xy - _46.refLayer.xy) / _46.refLayer.zw;
    float2 center = (_46.centerPoint / float2(1000.0)) * float2(1.0, -1.0);
    float insideLayer = ((step(0.0, ((gl_FragCoord.xy - _46.refLayer.xy) / _46.refLayer.zw).x) * step(((gl_FragCoord.xy - _46.refLayer.xy) / _46.refLayer.zw).x, 1.0)) * step(0.0, ((gl_FragCoord.xy - _46.refLayer.xy) / _46.refLayer.zw).y)) * step(((gl_FragCoord.xy - _46.refLayer.xy) / _46.refLayer.zw).y, 1.0);
    float damping = ((smoothstep(0.0, _46.feather, ((gl_FragCoord.xy - _46.refLayer.xy) / _46.refLayer.zw).x) * smoothstep(0.0, _46.feather, ((gl_FragCoord.xy - _46.refLayer.xy) / _46.refLayer.zw).y)) * smoothstep(1.0, 1.0 - _46.feather, ((gl_FragCoord.xy - _46.refLayer.xy) / _46.refLayer.zw).x)) * smoothstep(1.0, 1.0 - _46.feather, ((gl_FragCoord.xy - _46.refLayer.xy) / _46.refLayer.zw).y);
    st -= float2(0.5);
    st.x *= (_46.refLayer.z / _46.refLayer.w);
    st -= center;
    float dist = length(st);
    float2 prevSt = st;
    if (dist < _46.radius)
    {
        float p = dist / _46.radius;
        if (_46.strength > 0.0)
        {
            if (_46.gaussian != 0u)
            {
                float param = 0.0;
                float param_1 = _46.radius / dist;
                float param_2 = p;
                st *= mix(1.0, gsmooth(param, param_1, param_2), _46.strength * 0.75);
            }
            else
            {
                st *= mix(1.0, smoothstep(0.0, _46.radius / dist, p), _46.strength * 0.75);
            }
        }
        else
        {
            st *= mix(1.0, (powr(p, 1.0 + (_46.strength * 0.75)) * _46.radius) / dist, 1.0 - p);
        }
        st = mix(prevSt, st, float2(damping * insideLayer));
    }
    st += center;
    st.x /= (_46.refLayer.z / _46.refLayer.w);
    st += float2(0.5);
    float2 param_3 = st;
    float2 param_4 = l2s(param_3, _46);
    referenceColor = texture2DCv(refInput, refInputSmplr, param_4);
}

fragment refAM35_e6a4f65d4030d_out refAM35_e6a4f65d4030d(constant ReferenceUniformse6a4f65d4030d& _46 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e6a4f65d4030d_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_46, gl_FragCoord, referenceColor, refInput, refInputSmplr);
    bool _351 = any(isnan(referenceColor));
    bool _358;
    if (!_351)
    {
        _358 = any(isinf(referenceColor));
    }
    else
    {
        _358 = _351;
    }
    if (_358)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _372 = referenceColor;
    float3 _378 = fast::clamp(_372.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _378.x;
    referenceColor.y = _378.y;
    referenceColor.z = _378.z;
    out.finalColor = referenceColor;
    return out;
}

