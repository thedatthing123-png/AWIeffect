// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsnewcolorgrid.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
// Dave Hoskins - https://www.shadertoy.com/view/4djSRW
//noise
//////////////////////////
/////////////////////////
// vec2 d = abs(gv) - (abs(sin((acTime*scaleSpeed)*ran)*0.5)-0.05);
// vec3 col = vec3(1.-r)*vec3(abs(sin((acTime*satSpeed)*ran2))*.8);
// resultfinal = (newLayer(texColor, factor) * 1.0) * texColor.a; }
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse4923184f9377
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    uint autop;
    char _m8_pad[12];
    float xxa;
    char _m9_pad[12];
    float SPEED;
    char _m10_pad[12];
    float scale;
    char _m11_pad[12];
    float angle;
    char _m12_pad[8];
    float2 position;
    char _m13_pad[8];
    float2 stretch;
    char _m14_pad[8];
    float alpha;
    char _m15_pad[12];
    float hardness;
    char _m16_pad[12];
    int blendMode;
};

struct refAM35_e4923184f9377_out
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
float N2(thread const float2& p)
{
    float3 p3 = fract(p.xyx * float3(443.897003173828125, 441.423004150390625, 437.19500732421875));
    p3 += float3(dot(p3, p3.yzx + float3(19.1900005340576171875)));
    return fract((p3.x + p3.y) * p3.z);
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse4923184f9377& _116, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_116.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _116.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_116.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _116.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_116.refScreen.x, _116.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _116.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _116.refScreen.xy).y) * _116.refScreen.xy) - float2(_116.refLayer.x + (_116.refLayer.z * 0.5), (_116.refScreen.y - _116.refLayer.y) - (_116.refLayer.w * 0.5))) / _116.refLayer.zw;
            syamjaidtz.y *= (_116.refLayer.w / _116.refLayer.z);
            syamjaidtz /= float2(_116.scale);
            float param_3 = (0.0 + _116.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _116.position.x, 0.0 + _116.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_116.scale * _116.stretch.x, _116.scale * _116.stretch.y);
            syamjaidtz /= scaleVec;
            float2 uv = syamjaidtz;
            uv *= 40.0;
            float2 gv = fract(uv) - float2(0.5);
            float2 id = floor(uv);
            float2 param_4 = id;
            float ran = N2(param_4);
            float2 param_5 = id + float2(64.0);
            float ran2 = N2(param_5);
            float _309;
            if (_116.autop != 0u)
            {
                _309 = _116.xxa + (_116.refScreen.z * _116.SPEED);
            }
            else
            {
                _309 = _116.xxa;
            }
            float EVO = _309;
            float2 d = abs(gv) - float2(abs(sin(EVO * ran) * 0.5) - 0.0500000007450580596923828125);
            float rect = fast::min(fast::max(d.x, d.y), 0.0) + length(fast::max(d, float2(0.0)));
            float r = step(0.0, rect);
            float3 col = float3(1.0 - r) * float3(abs(sin(EVO * ran2)) * 0.800000011920928955078125);
            col *= float3(0.300000011920928955078125, 0.800000011920928955078125, 0.4000000059604644775390625);
            float4 fragColor = float4(col, 1.0);
            float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float4 gradmap = mix(_116.color1, _116.color2, float4(luminance)) * fragColor.w;
            float4 factor = mix(texColorX, gradmap, float4(1.0));
            float4 resultfinal;
            if (_116.blendMode == 0)
            {
                resultfinal = (factor * _116.hardness) * texColor.w;
            }
            else
            {
                if (_116.blendMode == 1)
                {
                    factor *= _116.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_116.blendMode == 2)
                    {
                        factor *= _116.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_116.blendMode == 3)
                        {
                            factor *= _116.hardness;
                            float4 param_6 = texColor;
                            float4 param_7 = factor;
                            resultfinal = (newLayer(param_6, param_7) * _116.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_116.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e4923184f9377_out refAM35_e4923184f9377(constant ReferenceUniformse4923184f9377& _116 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e4923184f9377_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_116, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _523 = any(isnan(referenceColor));
    bool _530;
    if (!_523)
    {
        _530 = any(isinf(referenceColor));
    }
    else
    {
        _530 = _523;
    }
    if (_530)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _543 = referenceColor;
    float3 _549 = fast::clamp(_543.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _549.x;
    referenceColor.y = _549.y;
    referenceColor.z = _549.z;
    out.finalColor = referenceColor;
    return out;
}

