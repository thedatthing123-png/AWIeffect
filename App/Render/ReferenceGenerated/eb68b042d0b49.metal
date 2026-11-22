// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxnewlensflare.xml
// Original source comments and attribution:
/////////////////////////
//l is used for making rings.I get the length and pass it through a sinwave
//but I also use a pow function. pow function + sin function , from 0 and up, = a pulse, at least
//if you return the max of that and 0.0.
//l2 is used in the rings as well...somehow...
///these are circles, big, rings, and  tiny respectively
// color = cos(vec3(0.44, .24, .2)*8. + dist*4.)*0.5+.5;
/////////////////////////
// if (adaptive) { 
// }
// else { 
// syamjaidtz = ((vec2(acScreenNorm.x,1.0-acScreenNorm.y)*acScreenSize)-acLayerCenter)/acLayerSize;
// syamjaidtz.y*=acLayerSize.y/acLayerSize.x;
// }
// syamjaidtz *= rot2m((0.0+angle)*0.0174533);
/////////////////////////
// if(progressa <= 0.0) { gl_FragColor = texture2DCv(inputImg.texture,acScreenNorm); }
// else if(progressa >= 0.0001) { 
//uv=uv*2.-1.0;
// vec2 mm = mousee/syamjaidtz - 0.5;
// mm.x *= mousee/syamjaidtz.y;
// if(progressa<1.0)
// {
// }
//05
//now to make the sky not black
// vec3 color = mix(vec3(0.3, 0.2, 0.02)/0.9, vec3(0.2, 0.5, 0.8), uv.y)*progressb;
// vec3 color = mix(vec3(0.3, 0.2, 0.02)/0.9, vec3(0.2, 0.5, 0.8), uv.y)*3.-0.52*sin(progressb);
//this calls the function which adds three circle types every time through the loop based on parameters I
//got by trying things out. rnd i*2000. and rnd i*20 are just to help randomize things more
//get angle and length of the sun (uv - mouse)
//19
//+0.1/abs(sin(iTime/3.))/3.;//add 1.0ness based on how the sun moves so that it is 1.0est
//when it is lined up with the center
//add the sun with the frill things
//add another sun in the middle (to make it 1.0er)  with the20color I want, and 1.0 as the numerator.
// color += (max(bright/pow(length(uv-mm)*4., 1./2.), 0.0)*4.)*vec3(color2.rgb)*4.;
// * (0.5+.5*sin(vec3(0.4, 0.2, 0.1) + vec3(a*2., 00., a*3.)+1.3));
//multiply by the exponetial e^x ? of 1.0-length which kind of masks the 1.0ness more so that
//there is a sharper roll of of the light decay from the sun. 
// const vec3 luminanceWeighting = vec3(0.2126, 0.7152, 0.0722);
// vec4 gradmap;
// float luminance = dot(fragColor.rgb, luminanceWeighting);
// gradmap = mix(color1,color2,luminance)*fragColor.a;
// vec4 factorx = mix(fragColor,gradmap,alphab);
// normal
// multiply
// screen
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb68b042d0b49
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 position;
    float progressc;
    char _m7_pad[12];
    float progressd;
    char _m8_pad[12];
    float progresse;
    char _m9_pad[12];
    float progressa;
    char _m10_pad[12];
    float progressb;
    char _m11_pad[12];
    float alpha;
    float4 color1;
    float4 color3;
    float4 color4;
    int blendMode;
};

struct refAM35_eb68b042d0b49_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float rnd(thread const float& w)
{
    float f = fract(sin(w) * 1000.0);
    return f;
}

static inline __attribute__((always_inline))
float regShape(thread const float2& p, thread const int& N)
{
    float a = precise::atan2(p.x, p.y) + 0.20000000298023223876953125;
    float b = 6.2831897735595703125 / float(N);
    float f = smoothstep(0.5, 0.5099999904632568359375, cos((floor(0.5 + (a / b)) * b) - a) * length(p));
    return f;
}

static inline __attribute__((always_inline))
float3 circle(thread const float2& p, thread const float& size, thread const float& decay, thread float3& color, thread const float3& color2, thread const float& dist, thread const float2& mouse, constant ReferenceUniformseb68b042d0b49& _199)
{
    float l = length(p + (mouse * (dist * 4.0))) + (size / 2.0);
    float l2 = length(p + (mouse * (dist * 4.0))) + (size / 3.0);
    float c = fast::max(0.00999999977648258209228515625 - powr(length(p + (mouse * dist)), size * 1.39999997615814208984375), 0.0) * 50.0;
    float c1 = fast::max((0.001000000047497451305389404296875 - powr(l - 0.300000011920928955078125, 0.02500000037252902984619140625)) + sin(l * 30.0), 0.0) * 3.0;
    float c2 = fast::max(0.039999999105930328369140625 / powr(length((p - ((mouse * dist) / float2(2.0))) + float2(0.0900000035762786865234375)) * 1.0, 1.0), 0.0) / 20.0;
    float2 param = ((p * 5.0) + ((mouse * dist) * 5.0)) + float2(0.89999997615814208984375);
    int param_1 = 6;
    float s = fast::max(0.00999999977648258209228515625 - powr(regShape(param, param_1), 1.0), 0.0) * 5.0;
    color = float3(0.5) + (sin(color) * 0.5);
    color = (cos((_199.color1.xyz * 8.0) + float3(dist * 4.0)) * 0.5) + float3(0.5);
    float3 f = color * c;
    f += (color * c1);
    f += (color * c2);
    f += (color * s);
    return f - float3(0.00999999977648258209228515625);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseb68b042d0b49& _199, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _199.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = gl_FragCoord.xy / _199.refScreen.xy;
    syamjaidtz /= float2(_199.position.z / 100.0);
    syamjaidtz += ((float2(230.0 + _199.position.x, (-130.0) + _199.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 uv = syamjaidtz;
    uv.x *= (_199.refScreen.x / _199.refScreen.y);
    float2 mm = uv;
    mm = float2(sin(_199.progressc / 6.0) / 1.0, cos(_199.progressd / 4.0) / 2.0) / float2(2.0);
    float3 circColor = float3(0.89999997615814208984375, 0.20000000298023223876953125, 0.100000001490116119384765625);
    float3 circColor2 = float3(0.300000011920928955078125, 0.100000001490116119384765625, 0.89999997615814208984375);
    float3 color = mix(_199.color3.xyz / float3(0.89999997615814208984375), _199.color4.xyz, float3(uv.y)) * _199.progressb;
    for (float i = 0.0; i < 10.0; i += 1.0)
    {
        float param_1 = i * 2000.0;
        float param_2 = i * 20.0;
        float2 param_3 = uv;
        float param_4 = powr(rnd(param_1) * _199.progressa, 2.0) + 1.40999996662139892578125;
        float param_5 = 0.0;
        float3 param_6 = circColor + float3(i);
        float3 param_7 = circColor2 + float3(i);
        float param_8 = ((rnd(param_2) * 3.0) + 0.20000000298023223876953125) - 0.5;
        float2 param_9 = mm;
        float3 _391 = circle(param_3, param_4, param_5, param_6, param_7, param_8, param_9, _199);
        color += _391;
    }
    float a = precise::atan2(uv.y - mm.y, uv.x - mm.x);
    float l = fast::max((1.0 - length(uv - mm)) - 0.839999973773956298828125, 0.0);
    float bright = _199.progresse;
    color += float3((fast::max(0.100000001490116119384765625 / powr(length(uv - mm) * 5.0, 5.0), 0.0) * abs(sin((a * 5.0) + cos(a * 9.0)))) / 20.0);
    color += float3(fast::max(0.100000001490116119384765625 / powr(length(uv - mm) * 10.0, 0.0500000007450580596923828125), 0.0) + (((abs(sin((a * 3.0) + cos(a * 9.0))) / 8.0) * abs(sin(a * 9.0))) / 1.0));
    color += ((float3(0.20000000298023223876953125, 0.20999999344348907470703125, 0.300000011920928955078125) * (fast::max(bright / powr(length(uv - mm) * 4.0, 0.5), 0.0) * 4.0)) * 4.0);
    color *= (exp(1.0 - length(uv - mm)) / 5.0);
    float4 fragColor = float4(color, 1.0);
    float4 factor = mix(texColorX, fragColor, float4(_199.alpha));
    float4 resultfinal;
    if (_199.blendMode == 0)
    {
        resultfinal = (factor * 1.0) * texColor.w;
    }
    else
    {
        if (_199.blendMode == 1)
        {
            factor *= 1.0;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_199.blendMode == 2)
            {
                factor *= 1.0;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = resultfinal;
}

fragment refAM35_eb68b042d0b49_out refAM35_eb68b042d0b49(constant ReferenceUniformseb68b042d0b49& _199 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb68b042d0b49_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_199, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _595 = any(isnan(referenceColor));
    bool _602;
    if (!_595)
    {
        _602 = any(isinf(referenceColor));
    }
    else
    {
        _602 = _595;
    }
    if (_602)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _615 = referenceColor;
    float3 _621 = fast::clamp(_615.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _621.x;
    referenceColor.y = _621.y;
    referenceColor.z = _621.z;
    out.finalColor = referenceColor;
    return out;
}

