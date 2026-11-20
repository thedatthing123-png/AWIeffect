// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/starfield3.xml
// Original source comments and attribution:
//#define iterations 17
//#define formuparam 0.53
//
//#define volsteps 20
//#define stepsize 0.1
//
//#define zoom   0.800
//#define tile   0.850
//#define speed  0.010
//
//#define brightness 0.0015
//#define darkmatter 0.300
//#define distfading 0.730
//#define saturation 0.450
//#define zoom   0.300
//#define speed  0.010
//#define brightness 0.0015
//#define darkmatter 0.300
// --- Inputs ------------------------------------
//float iTime = acTime;
// --- Shader -------------------------------------
//get coords and direction
//vec2 uv=fragCoord.xy/iResolution.xy-.5;
//uv.y*=iResolution.y/iResolution.x;
//float time=iTime*speed+.25;
//mouse rotation
//volumetric rendering
//vec3 rgb = userColor.rgb;
// tiling fold
// the magic formula
// absolute sum of average change
//dark matter
// add contrast
// dark matter, don't render near
//v+=vec3(dm,dm*.5,0.);
//v+=vec3(pow(s,1. + rgb.r*3.),pow(s,1. + rgb.g*3.),pow(s,1. + rgb.b*3.))*a*brightness*fade; // coloring based on distance
// coloring based on distance
// distance fading
//color adjust
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

struct ReferenceUniformsedd6ad99801bb
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 offset;
    char _m6_pad[8];
    float zoom;
    char _m7_pad[12];
    float brightness;
    char _m8_pad[12];
    float darkmatter;
};

struct refAM35_edd6ad99801bb_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsedd6ad99801bb& _35, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _35.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    if (texColor.w <= 9.9999997473787516355514526367188e-05)
    {
        discard_fragment();
    }
    float2 fragCoord = gl_FragCoord.xy;
    float2 iResolution = _35.refScreen.xy;
    float2 iMouse = float2(0.5);
    float2 uv = ((float2((gl_FragCoord.xy / _35.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _35.refScreen.xy).y) * _35.refScreen.xy) - float2(_35.refLayer.x + (_35.refLayer.z * 0.5), (_35.refScreen.y - _35.refLayer.y) - (_35.refLayer.w * 0.5))) / _35.refLayer.zw;
    uv.y *= (_35.refLayer.w / _35.refLayer.z);
    float3 dir = float3(uv * _35.zoom, 1.0);
    float a1 = 0.5 + ((iMouse.x / iResolution.x) * 2.0);
    float a2 = 0.800000011920928955078125 + ((iMouse.y / iResolution.y) * 2.0);
    float2x2 rot1 = float2x2(float2(cos(a1), sin(a1)), float2(-sin(a1), cos(a1)));
    float2x2 rot2 = float2x2(float2(cos(a2), sin(a2)), float2(-sin(a2), cos(a2)));
    float3 _182 = dir;
    float2 _184 = _182.xz * rot1;
    dir.x = _184.x;
    dir.z = _184.y;
    float3 _190 = dir;
    float2 _192 = _190.xy * rot2;
    dir.x = _192.x;
    dir.y = _192.y;
    float3 from = float3(1.0, 0.5, 0.5);
    from += float3((-_35.offset) / float2(1000.0), -2.0);
    float3 _214 = from;
    float2 _216 = _214.xz * rot1;
    from.x = _216.x;
    from.z = _216.y;
    float3 _222 = from;
    float2 _224 = _222.xy * rot2;
    from.x = _224.x;
    from.y = _224.y;
    float s = 0.100000001490116119384765625;
    float fade = 1.0;
    float3 v = float3(0.0);
    for (int r = 0; r < 16; r++)
    {
        float3 p = from + ((dir * s) * 0.5);
        p = abs(float3(0.85000002384185791015625) - mod(p, float3(1.7000000476837158203125)));
        float pa = 0.0;
        float a = 0.0;
        for (int i = 0; i < 14; i++)
        {
            p = (abs(p) / float3(dot(p, p))) - float3(0.5299999713897705078125);
            a += abs(length(p) - pa);
            pa = length(p);
        }
        float dm = fast::max(0.0, _35.darkmatter - ((a * a) * 0.001000000047497451305389404296875));
        a *= (a * a);
        if (r > 6)
        {
            fade *= (1.0 - dm);
        }
        v += float3(fade);
        v += (((float3(s, s * s, ((s * s) * s) * s) * a) * _35.brightness) * fade);
        fade *= 0.730000019073486328125;
        s += 0.100000001490116119384765625;
    }
    v = mix(float3(0.0, v.y, length(v)), v, float3(0.449999988079071044921875));
    referenceColor = float4(v * 0.00999999977648258209228515625, 1.0);
}

fragment refAM35_edd6ad99801bb_out refAM35_edd6ad99801bb(constant ReferenceUniformsedd6ad99801bb& _35 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_edd6ad99801bb_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _35, referenceColor);
    bool _371 = any(isnan(referenceColor));
    bool _378;
    if (!_371)
    {
        _378 = any(isinf(referenceColor));
    }
    else
    {
        _378 = _371;
    }
    if (_378)
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

