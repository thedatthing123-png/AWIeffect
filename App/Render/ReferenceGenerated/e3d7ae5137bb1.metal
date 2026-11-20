// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxvcr.xml
// Original source comments and attribution:
/////////////////////////
// (3.0-sqrt(3.0))/6.0
// 0.5*(sqrt(3.0)-1.0)
// -1.0 + 2.0 * C.x
// 1.0 / 41.0
// First corner
// Avoid truncation effects in permutation
/////////////////////////
// if (adaptive) { syamjaidtz = acScreenNorm; }
// else { 
// }
// syamjaidtz += vec2((0.0+position.x), (0.0+position.y))*vec2(-1.,1.)/500.;
/////////////////////////
// Create large, incidental noise waves
// Offset by smaller, constant noise waves
// Apply the noise as x displacement for every line
// Mix in some random interference for lines
// Apply a line pattern every 4 pixels
// Shift green/blue channels (using the red channel)
// gl_FragColor = gradmap * texColor.a;
// gl_FragColor = resultfinal;
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

struct ReferenceUniformse3d7ae5137bb1
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color2;
    float progressa;
    char _m7_pad[12];
    float progressb;
    char _m8_pad[12];
    float lowThreshold;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    float alpha;
    char _m11_pad[12];
    float angle;
    char _m12_pad[12];
    uint mode;
};

struct refAM35_e3d7ae5137bb1_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

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
    float4 _155 = x12;
    float2 _157 = _155.xy - i1;
    x12.x = _157.x;
    x12.y = _157.y;
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
    float2 _272 = (a0.yz * x12.xz) + (h.yz * x12.yw);
    g.y = _272.x;
    g.z = _272.y;
    return 130.0 * dot(m, g);
}

static inline __attribute__((always_inline))
float rand(thread const float2& co)
{
    return fract(sin(dot(co, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse3d7ae5137bb1& _305, texture2d<float> refImage1, sampler refImage1Smplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _305.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _305.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _305.refScreen.xy).y) * _305.refScreen.xy) - float2(_305.refLayer.x + (_305.refLayer.z * 0.5), (_305.refScreen.y - _305.refLayer.y) - (_305.refLayer.w * 0.5))) / _305.refLayer.zw;
    syamjaidtz.y *= (_305.refLayer.w / _305.refLayer.z);
    syamjaidtz /= float2(_305.scale);
    float param_1 = (0.0 + _305.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    float2 uv = syamjaidtz;
    float time = _305.progressa * 2.0;
    float2 param_2 = float2(time, uv.y * 0.300000011920928955078125);
    float _noise = fast::max(0.0, snoise(param_2) - 0.300000011920928955078125) * 1.4285714626312255859375;
    float2 param_3 = float2(time * 10.0, uv.y * 2.400000095367431640625);
    _noise += ((snoise(param_3) - 0.5) * 0.1500000059604644775390625);
    float xpos = uv.x - ((_noise * _noise) * 0.25);
    float2 param_4 = float2(xpos, uv.y);
    float4 fragColor = texture2DCv(refImage1, refImage1Smplr, param_4);
    float4 _441 = fragColor;
    float2 param_5 = float2(uv.y * time);
    float3 _457 = mix(_441.xyz, float3(rand(param_5)), float3(_noise * _305.progressb));
    fragColor.x = _457.x;
    fragColor.y = _457.y;
    fragColor.z = _457.z;
    if (floor(mod(gl_FragCoord.y * 0.25, 2.0)) == 0.0)
    {
        float4 _476 = fragColor;
        float3 _478 = _476.xyz * (1.0 - (0.1500000059604644775390625 * _noise));
        fragColor.x = _478.x;
        fragColor.y = _478.y;
        fragColor.z = _478.z;
    }
    float2 param_6 = float2(xpos + (_noise * 0.0500000007450580596923828125), uv.y);
    fragColor.y = mix(fragColor.x, texture2DCv(refImage1, refImage1Smplr, param_6).y, 0.25);
    float2 param_7 = float2(xpos - (_noise * 0.0500000007450580596923828125), uv.y);
    fragColor.z = mix(fragColor.x, texture2DCv(refImage1, refImage1Smplr, param_7).z, 0.25);
    float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 gradmap = mix(float4(0.0500000007450580596923828125, 0.0500000007450580596923828125, 0.0500000007450580596923828125, 1.0), _305.color2, float4(luminance)) * fragColor.w;
    float4 targetLuma = gradmap;
    float luma = dot(targetLuma.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float lowThresholdB = (_305.lowThreshold * 2.0) - 0.001000000047497451305389404296875;
    float lowThresholdA = lowThresholdB - 1.0;
    float highThresholdA = 1.00100004673004150390625;
    float highThresholdB = highThresholdA + 1.0;
    float lowBlend = smoothstep(lowThresholdA, lowThresholdB, luma);
    float highBlend = 1.0 - smoothstep(highThresholdA, highThresholdB, luma);
    float lumafx = fast::min(lowBlend, highBlend);
    float4 fxLuma = targetLuma * lumafx;
    float4 _580;
    if (_305.mode != 0u)
    {
        _580 = fast::max(texColor, fxLuma);
    }
    else
    {
        float4 param_8 = texColor;
        float4 param_9 = fxLuma;
        _580 = newLayer(param_8, param_9);
    }
    referenceColor = _580 * texColor.w;
}

fragment refAM35_e3d7ae5137bb1_out refAM35_e3d7ae5137bb1(constant ReferenceUniformse3d7ae5137bb1& _305 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e3d7ae5137bb1_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _305, refImage1, refImage1Smplr, referenceColor);
    bool _601 = any(isnan(referenceColor));
    bool _608;
    if (!_601)
    {
        _608 = any(isinf(referenceColor));
    }
    else
    {
        _608 = _601;
    }
    if (_608)
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

