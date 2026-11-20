// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/anoiseline.xml
// Original source comments and attribution:
// Ported from Ashima simplex noise snippet + Shadertoy glitch logic
// normalized [0..1]
// pixel coords
// Large incidental waves
// Smaller constant waves
// Horizontal displacement
// Random line interference
// Line pattern every ~4px (controlled by LINE_SCALE)
// Channel shifts (using red as base)
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

struct ReferenceUniformsed6d467b0b2fc
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float SPEED;
    char _m6_pad[12];
    float DISPLACE;
    char _m7_pad[12];
    float INTERF;
    char _m8_pad[12];
    float SHIFT;
    char _m9_pad[12];
    float LINE_SCALE;
};

struct refAM35_ed6d467b0b2fc_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 mod289(thread const float2& x)
{
    return x - (floor(x * 0.00346020772121846675872802734375) * 289.0);
}

static inline __attribute__((always_inline))
float3 mod289(thread const float3& x)
{
    return x - (floor(x * 0.00346020772121846675872802734375) * 289.0);
}

static inline __attribute__((always_inline))
float3 permute(thread const float3& x)
{
    float3 param = ((x * 34.0) + float3(1.0)) * x;
    return mod289(param);
}

static inline __attribute__((always_inline))
float snoise(thread const float2& v)
{
    float2 i = floor(v + float2(dot(v, float2(0.3660254180431365966796875))));
    float2 x0 = (v - i) + float2(dot(i, float2(0.211324870586395263671875)));
    float2 i1 = select(float2(0.0, 1.0), float2(1.0, 0.0), bool2(x0.x > x0.y));
    float4 x12 = x0.xyxy + float4(0.211324870586395263671875, 0.211324870586395263671875, -0.57735025882720947265625, -0.57735025882720947265625);
    float4 _119 = x12;
    float2 _121 = _119.xy - i1;
    x12.x = _121.x;
    x12.y = _121.y;
    float2 param = i;
    i = mod289(param);
    float3 param_1 = float3(i.y) + float3(0.0, i1.y, 1.0);
    float3 param_2 = (permute(param_1) + float3(i.x)) + float3(0.0, i1.x, 1.0);
    float3 p = permute(param_2);
    float3 m = fast::max(float3(0.5) - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), float3(0.0));
    m *= m;
    m *= m;
    float3 x = (fract(p * float3(0.024390242993831634521484375)) * 2.0) - float3(1.0);
    float3 h = abs(x) - float3(0.5);
    float3 ox = floor(x + float3(0.5));
    float3 a0 = x - ox;
    m *= (float3(1.792842864990234375) - (((a0 * a0) + (h * h)) * 0.8537347316741943359375));
    float3 g;
    g.x = (a0.x * x0.x) + (h.x * x0.y);
    float2 _236 = (a0.yz * x12.xz) + (h.yz * x12.yw);
    g.y = _236.x;
    g.z = _236.y;
    return 130.0 * dot(m, g);
}

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
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsed6d467b0b2fc& _268, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _268.refScreen.xy;
    float2 fragCoord = uv * _268.refScreen.xy;
    float time = _268.refScreen.z * _268.SPEED;
    float2 param = float2(time, uv.y * 0.300000011920928955078125);
    float n = fast::max(0.0, snoise(param) - 0.300000011920928955078125) * 1.4285714626312255859375;
    float2 param_1 = float2(time * 10.0, uv.y * 2.400000095367431640625);
    n += ((snoise(param_1) - 0.5) * 0.1500000059604644775390625);
    float xpos = uv.x - ((n * n) * _268.DISPLACE);
    float2 sUV = float2(xpos, uv.y);
    float2 param_2 = fast::clamp(sUV, float2(0.0), float2(1.0));
    float4 c = texture2DCv(refInput, refInputSmplr, param_2);
    float4 _342 = c;
    float2 param_3 = float2(uv.y * time);
    float3 _358 = mix(_342.xyz, float3(rand(param_3)), float3(n * _268.INTERF));
    c.x = _358.x;
    c.y = _358.y;
    c.z = _358.z;
    if (floor(mod(fragCoord.y * _268.LINE_SCALE, 2.0)) == 0.0)
    {
        float4 _379 = c;
        float3 _381 = _379.xyz * (1.0 - (0.1500000059604644775390625 * n));
        c.x = _381.x;
        c.y = _381.y;
        c.z = _381.z;
    }
    float sh = n * _268.SHIFT;
    float gx = fast::clamp(xpos + sh, 0.0, 1.0);
    float bx = fast::clamp(xpos - sh, 0.0, 1.0);
    float2 param_4 = float2(gx, uv.y);
    c.y = mix(c.x, texture2DCv(refInput, refInputSmplr, param_4).y, 0.25);
    float2 param_5 = float2(bx, uv.y);
    c.z = mix(c.x, texture2DCv(refInput, refInputSmplr, param_5).z, 0.25);
    referenceColor = c;
}

fragment refAM35_ed6d467b0b2fc_out refAM35_ed6d467b0b2fc(constant ReferenceUniformsed6d467b0b2fc& _268 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed6d467b0b2fc_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _268, refInput, refInputSmplr, referenceColor);
    bool _435 = any(isnan(referenceColor));
    bool _442;
    if (!_435)
    {
        _442 = any(isinf(referenceColor));
    }
    else
    {
        _442 = _435;
    }
    if (_442)
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

