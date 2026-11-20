// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/irridescence2.xml
// Original source comments and attribution:
// 2D Noise based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
// Four corners in 2D of a tile
// Smooth Interpolation
// Cubic Hermine Curve.  Same as SmoothStep()
// u = smoothstep(0.,1.,f);
// Mix 4 coorners porcentages
//#define GAIN 0.452
//#define LACUNARITY 4.012
// --- Shader -------------------------------------
//float t = acTime * SPEED;
//vv = st;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse51de8cc7d47d
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 POS;
    char _m6_pad[8];
    float FREQ;
    char _m7_pad[12];
    float SMOOTHNESS;
    char _m8_pad[12];
    float LACUNARITY;
    char _m9_pad[12];
    float AMP;
    char _m10_pad[12];
    float LUMA;
};

struct refAM35_e51de8cc7d47d_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float random(thread const float2& st)
{
    return fract(sin(dot(st, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& st)
{
    float2 i = floor(st);
    float2 f = fract(st);
    float2 param = i;
    float a = random(param);
    float2 param_1 = i + float2(1.0, 0.0);
    float b = random(param_1);
    float2 param_2 = i + float2(0.0, 1.0);
    float c = random(param_2);
    float2 param_3 = i + float2(1.0);
    float d = random(param_3);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    return (mix(a, b, u.x) + (((c - a) * u.y) * (1.0 - u.x))) + (((d - b) * u.x) * u.y);
}

static inline __attribute__((always_inline))
float fbm(thread const float2& st, constant ReferenceUniformse51de8cc7d47d& _123)
{
    float luma = _123.LUMA + 0.17499999701976776123046875;
    float amplitude = _123.AMP;
    float frequency = _123.FREQ;
    for (int i = 0; i < 4; i++)
    {
        float2 param = st * frequency;
        luma += (amplitude * _noise(param));
        frequency *= _123.LACUNARITY;
        amplitude *= (0.4519999921321868896484375 - _123.SMOOTHNESS);
    }
    return luma;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse51de8cc7d47d& _123, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _123.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    if (texColor.w <= 9.9999997473787516355514526367188e-05)
    {
        discard_fragment();
    }
    float2 ADJPOS = (-_123.POS) / float2(500.0);
    float2 st = ((float2((gl_FragCoord.xy / _123.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _123.refScreen.xy).y) * _123.refScreen.xy) - float2(_123.refLayer.x + (_123.refLayer.z * 0.5), (_123.refScreen.y - _123.refLayer.y) - (_123.refLayer.w * 0.5))) / _123.refLayer.zw;
    st.y *= (_123.refLayer.w / _123.refLayer.z);
    float2 qq = float2(st.y * sin((st.x * 18.2800006866455078125) + ADJPOS.x), st.x * sin((st.y * 4.0) + ADJPOS.y));
    float2 vv = float2(st.y * sin((st.x * 18.2800006866455078125) + (qq.x * 2.0)), st.x * sin((st.y * 4.0) + (qq.y * 1.0)));
    qq = float2(st.y + ADJPOS.y, st.x + ADJPOS.x);
    float2 param_1 = qq * 2.099999904632568359375;
    float2 param_2 = qq * 3.400000095367431640625;
    vv = float2(st.x * fbm(param_1, _123), st.y * fbm(param_2, _123));
    float2 param_3 = vv * 3.099999904632568359375;
    float aa = fbm(param_3, _123);
    float2 param_4 = vv;
    float bb = fbm(param_4, _123);
    float2 param_5 = vv * 0.4000000059604644775390625;
    float cc = fbm(param_5, _123);
    referenceColor = float4(aa, bb, cc, 1.0);
}

fragment refAM35_e51de8cc7d47d_out refAM35_e51de8cc7d47d(constant ReferenceUniformse51de8cc7d47d& _123 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e51de8cc7d47d_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_123, refInput, refInputSmplr, gl_FragCoord, referenceColor);
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
    out.finalColor = referenceColor;
    return out;
}

