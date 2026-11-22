// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsbonfire.xml
// Original source comments and attribution:
//////////////////////////
// Taken from https://www.shadertoy.com/view/4ts3z2
//p.xz*= m2;
//////////////////////////
/////////////////////////
// const vec3 luminanceWeighting = vec3(0.2126, 0.7152, 0.0722);
// float luminance = dot(fragColor.rgb, luminanceWeighting);
// vec4 gradmap = mix(color1,1.-color2,luminance)*fragColor.a;
// if(GRADMAP) { factor = mix(texColorX,gradmap,1.0); }
// vec4 xbuffer = texture2DCv(buff1.texture, acScreenNorm.st);
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse624154b0ab99
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint autop;
    char _m6_pad[12];
    float AMOUNT;
    char _m7_pad[12];
    float PROGRESS;
    char _m8_pad[12];
    float SPEED;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    float angle;
    char _m11_pad[8];
    float2 position;
    char _m12_pad[8];
    float2 stretch;
    char _m13_pad[8];
    float alpha;
    char _m14_pad[12];
    float hardness;
    char _m15_pad[12];
    uint UVNEW;
    float4 COLOR;
    int blendMode;
};

struct refAM35_e624154b0ab99_out
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
float tri(thread const float& x)
{
    return abs(fract(x) - 0.5);
}

static inline __attribute__((always_inline))
float3 tri3(thread const float3& p)
{
    float param = p.y * 1.0;
    float param_1 = p.z + tri(param);
    float param_2 = p.x * 1.0;
    float param_3 = p.z + tri(param_2);
    float param_4 = p.x * 1.0;
    float param_5 = p.y + tri(param_4);
    return float3(tri(param_1), tri(param_3), tri(param_5));
}

static inline __attribute__((always_inline))
float triNoise3D(thread float3& p, thread const float& spd, constant ReferenceUniformse624154b0ab99& _144)
{
    float z = 1.39999997615814208984375;
    float _151;
    if (_144.autop != 0u)
    {
        _151 = _144.PROGRESS + (_144.refScreen.z * _144.SPEED);
    }
    else
    {
        _151 = _144.PROGRESS;
    }
    float iTimex = _151;
    float rz = 0.0;
    float3 bp = p;
    for (float i = 0.0; i <= _144.AMOUNT; i += 1.0)
    {
        float3 param = bp * 2.0;
        float3 dg = tri3(param);
        p += (dg + float3((iTimex * 0.100000001490116119384765625) * spd));
        bp *= 1.7999999523162841796875;
        z *= 1.5;
        p *= 1.2000000476837158203125;
        float param_1 = p.y;
        float param_2 = p.x + tri(param_1);
        float param_3 = p.z + tri(param_2);
        rz += (tri(param_3) / z);
        bp += float3(0.14000000059604644775390625);
    }
    return rz;
}

static inline __attribute__((always_inline))
float3 hsv(thread const float& h, thread const float& s, thread const float& v)
{
    return mix(float3(1.0), fast::clamp(abs((fract(float3(h) + float3(1.0, 0.666666686534881591796875, 0.3333333432674407958984375)) * 6.0) - float3(3.0)) - float3(1.0), float3(0.0), float3(1.0)), float3(s)) * v;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse624154b0ab99& _144, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_144.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _144.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_144.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _144.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_144.refScreen.x, _144.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = gl_FragCoord.xy / _144.refScreen.xy;
            if (_144.UVNEW != 0u)
            {
                syamjaidtz = ((float2((gl_FragCoord.xy / _144.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _144.refScreen.xy).y) * _144.refScreen.xy) - float2(_144.refLayer.x + (_144.refLayer.z * 0.5), (_144.refScreen.y - _144.refLayer.y) - (_144.refLayer.w * 0.5))) / _144.refLayer.zw;
                syamjaidtz.y *= (_144.refLayer.w / _144.refLayer.z);
            }
            syamjaidtz /= float2(_144.scale);
            float param_3 = (0.0 + _144.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _144.position.x, 0.0 + _144.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_144.scale * _144.stretch.x, _144.scale * _144.stretch.y);
            syamjaidtz /= scaleVec;
            float2 uv = syamjaidtz;
            float fadeLR = 0.5 - abs(uv.x - 0.5);
            float fadeTB = 1.0 - uv.y;
            float _448;
            if (_144.autop != 0u)
            {
                _448 = _144.PROGRESS + (_144.refScreen.z * _144.SPEED);
            }
            else
            {
                _448 = _144.PROGRESS;
            }
            float iTime = _448;
            float3 pos = float3((uv * float2(3.0, 1.0)) - float2(0.0, iTime * 0.02999999932944774627685546875), 1.0);
            float3 param_4 = pos;
            float param_5 = 0.4000000059604644775390625;
            float _485 = triNoise3D(param_4, param_5, _144);
            float n = (powr(fadeLR * fadeTB, 1.0) * 0.4000000059604644775390625) * _485;
            float3 param_6 = pos * 0.20000000298023223876953125;
            float param_7 = 0.4000000059604644775390625;
            float _496 = triNoise3D(param_6, param_7, _144);
            n += (powr(fadeLR * fadeTB, 2.0) * _496);
            float param_8 = (n * 1.39999997615814208984375) + 0.89999997615814208984375;
            float param_9 = 0.60000002384185791015625;
            float param_10 = 0.89999997615814208984375;
            float3 col = hsv(param_8, param_9, param_10);
            col *= _144.COLOR.xyz;
            float4 fragColor = float4((col * powr(n, 2.0)) * 200.0, powr(fadeLR * fadeTB, 2.0));
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal;
            if (_144.blendMode == 0)
            {
                resultfinal = (factor * _144.hardness) * texColor.w;
            }
            else
            {
                if (_144.blendMode == 1)
                {
                    factor *= _144.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_144.blendMode == 2)
                    {
                        factor *= _144.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_144.blendMode == 3)
                        {
                            factor *= _144.hardness;
                            float4 param_11 = texColor;
                            float4 param_12 = factor;
                            resultfinal = (newLayer(param_11, param_12) * _144.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_144.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e624154b0ab99_out refAM35_e624154b0ab99(constant ReferenceUniformse624154b0ab99& _144 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e624154b0ab99_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_144, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _655 = any(isnan(referenceColor));
    bool _662;
    if (!_655)
    {
        _662 = any(isinf(referenceColor));
    }
    else
    {
        _662 = _655;
    }
    if (_662)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _675 = referenceColor;
    float3 _681 = fast::clamp(_675.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _681.x;
    referenceColor.y = _681.y;
    referenceColor.z = _681.z;
    out.finalColor = referenceColor;
    return out;
}

