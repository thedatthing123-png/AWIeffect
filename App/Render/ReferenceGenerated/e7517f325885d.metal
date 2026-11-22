// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxvhstape.xml
// Original source comments and attribution:
/////////////////////////
//random hash
//tape noise
//v*= n( vec3( (fragCoord.xy + vec2(s,0.))*100.,1.0) );
//threshold
/////////////////////////
/////////////////////////
//fields per seconds
//field line
// normal
// multiply
// screen
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse7517f325885d
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progressa;
    char _m6_pad[12];
    float progressc;
    char _m7_pad[12];
    float scale;
    char _m8_pad[8];
    float2 position;
    char _m9_pad[8];
    float2 stretch;
    char _m10_pad[8];
    float bright;
    char _m11_pad[12];
    float alpha;
    char _m12_pad[12];
    float angle;
    float4 color1;
    float4 color2;
    int blendMode;
};

struct refAM35_e7517f325885d_out
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
float hash(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

static inline __attribute__((always_inline))
float n(thread const float3& x)
{
    float3 p = floor(x);
    float3 f = fract(x);
    f = (f * f) * (float3(3.0) - (f * 2.0));
    float n_1 = (p.x + (p.y * 57.0)) + (113.0 * p.z);
    float param = n_1 + 0.0;
    float param_1 = n_1 + 1.0;
    float param_2 = n_1 + 57.0;
    float param_3 = n_1 + 58.0;
    float param_4 = n_1 + 113.0;
    float param_5 = n_1 + 114.0;
    float param_6 = n_1 + 170.0;
    float param_7 = n_1 + 171.0;
    float res = mix(mix(mix(hash(param), hash(param_1), f.x), mix(hash(param_2), hash(param_3), f.x), f.y), mix(mix(hash(param_4), hash(param_5), f.x), mix(hash(param_6), hash(param_7), f.x), f.y), f.z);
    return res;
}

static inline __attribute__((always_inline))
float4 hash42(thread const float2& p)
{
    float4 p4 = fract(p.xyxy * float4(443.897491455078125, 397.29730224609375, 491.187103271484375, 470.78271484375));
    p4 += float4(dot(p4.wzxy, p4 + float4(19.1900005340576171875)));
    return fract(float4(p4.x * p4.y, p4.x * p4.z, p4.y * p4.w, p4.x * p4.w));
}

static inline __attribute__((always_inline))
float nn(thread const float2& p, constant ReferenceUniformse7517f325885d& _236)
{
    float y = p.y;
    float s = _236.progressa * 2.0;
    float3 param = float3((y * 0.00999999977648258209228515625) + s, 1.0, 1.0);
    float3 param_1 = float3(((y * 0.010999999940395355224609375) + 1000.0) + s, 1.0, 1.0);
    float3 param_2 = float3(((y * 0.5099999904632568359375) + 421.0) + s, 1.0, 1.0);
    float v = ((n(param) + 0.0) * (n(param_1) + 0.0)) * (n(param_2) + 0.0);
    float2 param_3 = float2(p.x + (_236.progressa * 0.00999999977648258209228515625), p.y);
    v *= (hash42(param_3).x + 0.300000011920928955078125);
    v = powr(v + 0.300000011920928955078125, 1.0);
    if (v < 0.699999988079071044921875)
    {
        v = 0.0;
    }
    return v;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse7517f325885d& _236, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _236.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _236.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _236.refScreen.xy).y) * _236.refScreen.xy) - float2(_236.refLayer.x + (_236.refLayer.z * 0.5), (_236.refScreen.y - _236.refLayer.y) - (_236.refLayer.w * 0.5))) / _236.refLayer.zw;
    syamjaidtz.y *= (_236.refLayer.w / _236.refLayer.z);
    syamjaidtz /= float2(_236.scale);
    float param_1 = (0.0 + _236.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((float2(0.0 + _236.position.x, 0.0 + _236.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 scaleVec = float2(_236.scale * _236.stretch.x, _236.scale * _236.stretch.y);
    syamjaidtz /= scaleVec;
    float2 uv = syamjaidtz;
    float linesN = _236.progressc;
    float one_y = _236.refScreen.y / linesN;
    uv = floor((uv * float2(_236.refScreen.x, _236.refScreen.y)) / float2(one_y)) * one_y;
    float2 param_2 = uv;
    float col = nn(param_2, _236);
    float4 bcol = mix(_236.color1, _236.color2, float4(col));
    float4 fragColor = bcol;
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_236.blendMode == 0)
    {
        float4 param_3 = texColor;
        float4 param_4 = factor;
        resultfinal = (newLayer(param_3, param_4) * _236.bright) * texColor.w;
    }
    else
    {
        if (_236.blendMode == 1)
        {
            factor *= _236.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_236.blendMode == 2)
            {
                factor *= _236.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_236.alpha));
}

fragment refAM35_e7517f325885d_out refAM35_e7517f325885d(constant ReferenceUniformse7517f325885d& _236 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e7517f325885d_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_236, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _570 = any(isnan(referenceColor));
    bool _577;
    if (!_570)
    {
        _577 = any(isinf(referenceColor));
    }
    else
    {
        _577 = _570;
    }
    if (_577)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _590 = referenceColor;
    float3 _596 = fast::clamp(_590.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _596.x;
    referenceColor.y = _596.y;
    referenceColor.z = _596.z;
    out.finalColor = referenceColor;
    return out;
}

