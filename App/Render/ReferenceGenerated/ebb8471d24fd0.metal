// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxtvanalogue.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
// if (adaptive) { 
// }
// else { 
// syamjaidtz = ((vec2(acScreenNorm.x,1.0-acScreenNorm.y)*acScreenSize)-acLayerCenter)/acLayerSize;
// syamjaidtz.y*=acLayerSize.y/acLayerSize.x;
// }
// syamjaidtz *= rot2m((0.0+angle)*0.0174533);
/////////////////////////
// const vec3 luminanceWeighting = vec3(0.2126, 0.7152, 0.0722);
// vec4 gradmap;
// float luminance = dot(fragColor.rgb, luminanceWeighting);
// gradmap = mix(color1,color2,luminance)*fragColor.a;
// vec4 factorx = mix(fragColor,gradmap,alphab);
// if( blendMode==0 ) {                // normal
// resultfinal = (factor * bright) * texColor.a;
// } else if( blendMode==1 ) {         // multiply
// factor *= bright;
// vec4 c = factor + vec4(1.)*(1.-factor.a);
// resultfinal = vec4((texColor.rgb/texColor.a)*c.rgb,1.0) * texColor.a;
// } else if( blendMode==2 ) {         // screen
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsebb8471d24fd0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float progressa;
    char _m7_pad[12];
    float scale;
    char _m8_pad[12];
    float bright;
    char _m9_pad[12];
    float alpha;
};

struct refAM35_ebb8471d24fd0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float hash2(thread const float2& p)
{
    float h = dot(p, float2(127.09999847412109375, 311.70001220703125));
    return fract(sin(h) * 43758.546875);
}

static inline __attribute__((always_inline))
float hash(thread const float2& p, constant ReferenceUniformsebb8471d24fd0& _41)
{
    float h = dot(p + float2(_41.progressa * 9.9999997473787516355514526367188e-05), float2(127.09999847412109375, 311.70001220703125));
    return fract(sin(h) * 43758.546875);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p, constant ReferenceUniformsebb8471d24fd0& _41)
{
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i + float2(0.0);
    float2 param_1 = i + float2(1.0, 0.0);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 param_3 = i + float2(1.0);
    return mix(mix(hash(param, _41), hash(param_1, _41), u.x), mix(hash(param_2, _41), hash(param_3, _41), u.x), u.y);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsebb8471d24fd0& _41, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _41.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = gl_FragCoord.xy / _41.refScreen.xy;
    syamjaidtz /= float2(_41.scale);
    syamjaidtz += ((float2(0.0 + _41.position.x, 0.0 + _41.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    if (_41.progressa <= 0.0)
    {
        float2 param_1 = gl_FragCoord.xy / _41.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param_1);
    }
    else
    {
        if (_41.progressa >= 9.9999997473787516355514526367188e-05)
        {
            float2 uv = syamjaidtz;
            float2 param_2 = floor(float2(_41.progressa * 4.0) - (uv * 20.0)) / float2(20.0);
            float glitch = hash2(param_2);
            uv += float2(powr(fract(glitch + (_41.progressa * 0.100000001490116119384765625)), 30.0));
            float2 param_3 = uv * 150.0;
            float2 param_4 = uv * 350.0;
            float n = powr((_noise(param_3, _41) + _noise(param_4, _41)) * 0.5, 3.0);
            n *= abs(sin((uv.y * 250.0) + (_41.progressa * 2.0)));
            float offset = sign(sin((uv.x * 6.0) + (_41.progressa * 3.0))) * 0.100000001490116119384765625;
            offset += (sign(sin(((uv.y * 10.0) + (uv.x * 14.5)) + (_41.progressa * 20.0))) * 0.100000001490116119384765625);
            offset += (sign(sin((((sin(_41.progressa) * uv.y) * 12.0) - (uv.x * 22.0)) - (_41.progressa * 40.0))) * 0.20000000298023223876953125);
            offset = powr(offset - 0.5, 4.0);
            n *= fast::min(1.0, floor(((1.5 - uv.y) + offset) * 3.0) / 3.0);
            float2 param_5 = float2(_41.progressa * 3.7000000476837158203125);
            float waver = abs(_noise(param_5, _41) * 2.0);
            n *= powr(((fract((floor(uv.y * 15.0) / 15.0) + (_41.progressa * 0.300000011920928955078125)) * waver) * 0.4000000059604644775390625) + 0.4000000059604644775390625, 0.64999997615814208984375);
            n *= (0.75 + (waver * 0.125));
            n = fast::clamp(n, 0.0, 1.0);
            float4 fragColor = float4(n);
            float4 factor = mix(texColorX, fragColor, float4(_41.alpha));
            factor *= _41.bright;
            float4 resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            referenceColor = resultfinal;
        }
    }
}

fragment refAM35_ebb8471d24fd0_out refAM35_ebb8471d24fd0(constant ReferenceUniformsebb8471d24fd0& _41 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ebb8471d24fd0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_41, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _407 = any(isnan(referenceColor));
    bool _414;
    if (!_407)
    {
        _414 = any(isinf(referenceColor));
    }
    else
    {
        _414 = _407;
    }
    if (_414)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _427 = referenceColor;
    float3 _433 = fast::clamp(_427.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _433.x;
    referenceColor.y = _433.y;
    referenceColor.z = _433.z;
    out.finalColor = referenceColor;
    return out;
}

