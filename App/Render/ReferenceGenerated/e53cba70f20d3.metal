// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsmokeparticle.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
// if(progressa <= 0.0) { gl_FragColor = texture2DCv(inputImg.texture,acScreenNorm); }
// else if(progressa >= 0.0001) { 
// vec2 uv = (fragCoord.xy-.5* iResolution.xy)/iResolution.y;
// col = mix(vec3(.1,.01,.02),vec3(.8,.4,.2),col);
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

struct ReferenceUniformse53cba70f20d3
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    float2 position;
    char _m8_pad[8];
    float progressa;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    float bright;
    char _m11_pad[12];
    float alpha;
    char _m12_pad[12];
    float angle;
    char _m13_pad[12];
    int blendMode;
};

struct refAM35_e53cba70f20d3_out
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
float2x2 r(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float fig(thread float2& uv, constant ReferenceUniformse53cba70f20d3& _94)
{
    float param = -2.8273499011993408203125;
    uv *= r(param);
    return fast::min(1.0, 0.100000001490116119384765625 / abs(((precise::atan2(uv.x, uv.y) / 2.0) * 3.141499996185302734375) - sin((((-_94.progressa) * 128.0) / 60.0) + ((fast::min(0.60000002384185791015625, length(uv)) * 3.1415920257568359375) * 8.0))));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse53cba70f20d3& _94, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _94.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _94.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _94.refScreen.xy).y) * _94.refScreen.xy) - float2(_94.refLayer.x + (_94.refLayer.z * 0.5), (_94.refScreen.y - _94.refLayer.y) - (_94.refLayer.w * 0.5))) / _94.refLayer.zw;
    syamjaidtz.y *= (_94.refLayer.w / _94.refLayer.z);
    syamjaidtz /= float2(_94.scale);
    float param_1 = (0.0 + _94.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((float2(0.0 + _94.position.x, 0.0 + _94.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 uv = syamjaidtz;
    uv += float2(cos(_94.progressa * 0.100000001490116119384765625), sin(_94.progressa * 0.100000001490116119384765625));
    float param_2 = _94.progressa * 0.00999999977648258209228515625;
    uv *= r(param_2);
    float3 col = float3(-0.0);
    for (float y = -1.0; y <= 1.0; y += 1.0)
    {
        for (float x = -1.0; x <= 1.0; x += 1.0)
        {
            float2 offset = float2(x, y);
            float param_3 = length(uv + offset);
            float2 id = floor((uv + offset) * r(param_3));
            float param_4 = length(uv + offset);
            float2 gv = fract((uv + offset) * r(param_4)) - float2(0.5);
            float param_5 = cos(length(id) * 10.0);
            gv *= r(param_5);
            float2 param_6 = gv;
            float _312 = fig(param_6, _94);
            float d = _312;
            float2 param_7 = gv + float2(sin(((_94.progressa * 128.0) / 60.0) + length(id)) * 0.100000001490116119384765625, cos(_94.progressa) * 0.100000001490116119384765625);
            float _330 = fig(param_7, _94);
            col += (float3(d) / float3(exp(length(gv) * 6.0)));
        }
    }
    col = mix(_94.color1.xyz, _94.color2.xyz, col);
    float4 fragColor = float4(col, 1.0);
    float4 factor = mix(texColorX, fragColor, float4(_94.alpha));
    float4 resultfinal;
    if (_94.blendMode == 0)
    {
        resultfinal = (factor * _94.bright) * texColor.w;
    }
    else
    {
        if (_94.blendMode == 1)
        {
            factor *= _94.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_94.blendMode == 2)
            {
                factor *= _94.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = resultfinal;
}

fragment refAM35_e53cba70f20d3_out refAM35_e53cba70f20d3(constant ReferenceUniformse53cba70f20d3& _94 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e53cba70f20d3_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_94, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _461 = any(isnan(referenceColor));
    bool _468;
    if (!_461)
    {
        _468 = any(isinf(referenceColor));
    }
    else
    {
        _468 = _461;
    }
    if (_468)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _481 = referenceColor;
    float3 _487 = fast::clamp(_481.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _487.x;
    referenceColor.y = _487.y;
    referenceColor.z = _487.z;
    out.finalColor = referenceColor;
    return out;
}

