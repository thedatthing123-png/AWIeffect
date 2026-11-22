// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsnewtrails.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//From Dave_Hoskins (https://www.shadertoy.com/view/4djSRW)
//Very happy with this star function, cheap and smooth
// 47fps
// vec3 c = vec3(0.0);
// too small  and they will flicker
// more stars?
// float c2 = 1.0-smoothstep(0.0,0.6,length(q));
// c2 *= step(rn.x,0.0005+i*i*0.001);
// c += c2*(mix(vec3(1.0,0.49,0.1),vec3(0.75,0.9,1.0),rn.y)*0.25+0.75);
//////////////////////////
/////////////////////////
// const vec3 luminanceWeighting = vec3(0.2126, 0.7152, 0.0722);
// vec4 gradmap;
// float luminance = dot(fragColor.rgb, luminanceWeighting);
// gradmap = mix(color1,color2,luminance)*fragColor.a;
// vec4 factor = mix(texColorX,gradmap,1.0);
// resultfinal = (newLayer(texColor, factor) * hardness) * texColor.a; }
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsefa9cf9246771
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    float4 color3;
    uint autop;
    char _m9_pad[12];
    float ITER;
    char _m10_pad[12];
    float PROGRESS;
    char _m11_pad[12];
    float XXA;
    char _m12_pad[12];
    float XXB;
    char _m13_pad[12];
    float scale;
    char _m14_pad[12];
    float angle;
    char _m15_pad[8];
    float2 position;
    char _m16_pad[8];
    float2 stretch;
    char _m17_pad[8];
    float alpha;
    char _m18_pad[12];
    float hardness;
    char _m19_pad[12];
    int blendMode;
};

struct refAM35_efa9cf9246771_out
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
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float3 rotx(thread const float3& p, thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float3(p.x, (c * p.y) - (s * p.z), (s * p.y) + (c * p.z));
}

static inline __attribute__((always_inline))
float3 hash33(thread float3& p)
{
    p = fract(p * float3(443.897491455078125, 397.29730224609375, 491.187103271484375));
    p += float3(dot(p.zxy, p.yxz + float3(19.270000457763671875)));
    return fract(float3(p.x * p.y, p.z * p.x, p.y * p.z));
}

static inline __attribute__((always_inline))
float3 stars(thread float3& p, constant ReferenceUniformsefa9cf9246771& _148)
{
    float3 c = _148.color1.xyz;
    float res = _148.refScreen.x * 1.5;
    for (float i = 0.0; i < 2.0; i += 1.0)
    {
        float3 q = fract(p * (0.1500000059604644775390625 * res)) - float3(0.5);
        float3 id = floor(p * (0.1500000059604644775390625 * res));
        float3 param = id;
        float3 _190 = hash33(param);
        float2 rn = _190.xy;
        float c2 = 1.0 - smoothstep(0.0, _148.XXB, length(q));
        c2 *= step(rn.x, 0.0005000000237487256526947021484375 + ((i * i) * _148.XXA));
        c += (((mix(_148.color2.xyz, _148.color3.xyz, float3(rn.y)) * 0.25) + float3(0.75)) * c2);
        p *= 1.39999997615814208984375;
    }
    return (c * c) * 0.699999988079071044921875;
}

static inline __attribute__((always_inline))
float3 startrails(thread const float3& rd, constant ReferenceUniformsefa9cf9246771& _148)
{
    float _253;
    if (_148.autop != 0u)
    {
        _253 = _148.PROGRESS + (_148.refScreen.z * 0.5);
    }
    else
    {
        _253 = _148.PROGRESS;
    }
    float EVO = _253;
    float3 param = rd;
    float param_1 = EVO * 0.100000001490116119384765625;
    float3 param_2 = fast::normalize(rotx(param, param_1));
    float3 _277 = stars(param_2, _148);
    float3 col0 = _277;
    float3 col = col0;
    int _286 = -int(_148.ITER);
    for (int i = _286; i < 0; i++)
    {
        float3 param_3 = rd;
        float param_4 = (EVO * 0.100000001490116119384765625) + (float(i) * 0.00166666670702397823333740234375);
        float3 param_5 = fast::normalize(rotx(param_3, param_4));
        float3 _308 = stars(param_5, _148);
        float3 col1 = _308;
        col += col1;
    }
    return col;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsefa9cf9246771& _148, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_148.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _148.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_148.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _148.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_148.refScreen.x, _148.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _148.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _148.refScreen.xy).y) * _148.refScreen.xy) - float2(_148.refLayer.x + (_148.refLayer.z * 0.5), (_148.refScreen.y - _148.refLayer.y) - (_148.refLayer.w * 0.5))) / _148.refLayer.zw;
            syamjaidtz.y *= (_148.refLayer.w / _148.refLayer.z);
            syamjaidtz /= float2(_148.scale);
            float param_3 = (0.0 + _148.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _148.position.x, 0.0 - _148.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_148.scale * _148.stretch.x, _148.scale * _148.stretch.y);
            syamjaidtz /= scaleVec;
            float2 q = syamjaidtz;
            float2 p = q;
            p.x *= (iResolution.x / iResolution.y);
            float2 mo = q;
            float3 ro = float3(650.0, 10.0, 0.0);
            float3 eye = fast::normalize(float3(cos(mo.x), (-0.0) + mo.y, sin(mo.x)));
            float3 right = fast::normalize(float3(cos(mo.x + 1.57079994678497314453125), 0.0, sin(mo.x + 1.57079994678497314453125)));
            float3 up = fast::normalize(cross(right, eye));
            float3 rd = fast::normalize((((right * p.x) + (up * p.y)) * 1.0) + eye);
            float3 param_4 = rd;
            float3 col = startrails(param_4, _148);
            float4 fragColor = float4(col, _148.color1.w);
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal;
            if (_148.blendMode == 0)
            {
                resultfinal = (factor * _148.hardness) * texColor.w;
            }
            else
            {
                if (_148.blendMode == 1)
                {
                    factor *= _148.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_148.blendMode == 2)
                    {
                        factor *= _148.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_148.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_efa9cf9246771_out refAM35_efa9cf9246771(constant ReferenceUniformsefa9cf9246771& _148 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_efa9cf9246771_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_148, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _653 = any(isnan(referenceColor));
    bool _660;
    if (!_653)
    {
        _660 = any(isinf(referenceColor));
    }
    else
    {
        _660 = _653;
    }
    if (_660)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _673 = referenceColor;
    float3 _679 = fast::clamp(_673.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _679.x;
    referenceColor.y = _679.y;
    referenceColor.z = _679.z;
    out.finalColor = referenceColor;
    return out;
}

