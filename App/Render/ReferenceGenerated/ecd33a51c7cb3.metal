// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxisolinev2.xml
// Original source comments and attribution:
/////////////////////////
// replace this by something better
// (sqrt(3)-1)/2;
// (3-sqrt(3))/6;
/////////////////////////
// syamjaidtz = acScreenNorm; 
/////////////////////////
// ( fragCoord - 0.5*iResolution.xy ) / iResolution.y;
//uv = noised(uv*1.5 + iTime).rg;
//uv += iTime;
// vec3 col = vec3(mix(vec3(color1.rgb), vec3(color2.rgb), d));
// vec3 col = vec3(mix(vec3(0.1), vec3(0.2, 0.2, 0.6), d));
//col = vec3(noised(uv*10.)*0.5+0.5);
// vec4 xbuffer = texture2DCv(buff1.texture, acScreenNorm.st);
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsecd33a51c7cb3
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint autop;
    char _m6_pad[12];
    float PROGRESS;
    char _m7_pad[12];
    float SPEED;
    char _m8_pad[12];
    float scale;
    char _m9_pad[12];
    float angle;
    char _m10_pad[8];
    float2 position;
    char _m11_pad[8];
    float2 stretch;
    char _m12_pad[8];
    float alpha;
    char _m13_pad[12];
    float hardness;
    char _m14_pad[12];
    int blendMode;
    char _m15_pad[12];
    uint GRADMAP;
    float4 color1;
    float4 color2;
};

struct refAM35_ecd33a51c7cb3_out
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
float2 hash(thread float2& p)
{
    p = float2(dot(p, float2(127.09999847412109375, 311.70001220703125)), dot(p, float2(269.5, 183.3000030517578125)));
    return float2(-1.0) + (fract(sin(p) * 43758.546875) * 2.0);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p + float2((p.x + p.y) * 0.3660254180431365966796875));
    float2 a = (p - i) + float2((i.x + i.y) * 0.211324870586395263671875);
    float m = step(a.y, a.x);
    float2 o = float2(m, 1.0 - m);
    float2 b = (a - o) + float2(0.211324870586395263671875);
    float2 c = (a - float2(1.0)) + float2(0.42264974117279052734375);
    float3 h = fast::max(float3(0.5) - float3(dot(a, a), dot(b, b), dot(c, c)), float3(0.0));
    float2 param = i + float2(0.0);
    float2 _185 = hash(param);
    float2 param_1 = i + o;
    float2 _192 = hash(param_1);
    float2 param_2 = i + float2(1.0);
    float2 _199 = hash(param_2);
    float3 n = (((h * h) * h) * h) * float3(dot(a, _185), dot(b, _192), dot(c, _199));
    return dot(n, float3(70.0));
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsecd33a51c7cb3& _219, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _219.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param_1);
    float2 iResolution = float2(_219.refScreen.x, _219.refScreen.y);
    float2 iMouse = float2(0.5);
    float _257;
    if (_219.autop != 0u)
    {
        _257 = _219.PROGRESS + (_219.refScreen.z * _219.SPEED);
    }
    else
    {
        _257 = _219.PROGRESS;
    }
    float iTime = _257;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _219.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _219.refScreen.xy).y) * _219.refScreen.xy) - float2(_219.refLayer.x + (_219.refLayer.z * 0.5), (_219.refScreen.y - _219.refLayer.y) - (_219.refLayer.w * 0.5))) / _219.refLayer.zw;
    syamjaidtz.y *= (_219.refLayer.w / _219.refLayer.z);
    syamjaidtz /= float2(_219.scale);
    float param_2 = (0.0 + _219.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_2);
    syamjaidtz += ((float2(0.0 + _219.position.x, 0.0 + _219.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 scaleVec = float2(_219.scale * _219.stretch.x, _219.scale * _219.stretch.y);
    syamjaidtz /= scaleVec;
    float2 uv = syamjaidtz;
    float2 param_3 = uv + float2(iTime * 0.100000001490116119384765625);
    float2 param_4 = uv + float2(10.0);
    uv = float2(_noise(param_3), _noise(param_4));
    float d = uv.x - uv.y;
    d *= 20.0;
    d = sin(d);
    d = (d * 0.5) + 0.5;
    d = 1.0 - d;
    d = smoothstep(0.100000001490116119384765625, 0.100000001490116119384765625, d);
    float3 col = mix(float3(1.0), float3(0.0), float3(d));
    float4 fragColor = float4(col, 1.0);
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 gradmap = mix(_219.color1, _219.color2, float4(luminance)) * fragColor.w;
    if (_219.GRADMAP != 0u)
    {
        factor = mix(texColorX, gradmap, float4(1.0));
    }
    float4 resultfinal;
    if (_219.blendMode == 0)
    {
        resultfinal = (factor * _219.hardness) * texColor.w;
    }
    else
    {
        if (_219.blendMode == 1)
        {
            factor *= _219.hardness;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_219.blendMode == 2)
            {
                factor *= _219.hardness;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
            else
            {
                if (_219.blendMode == 3)
                {
                    factor *= _219.hardness;
                    float4 param_5 = texColor;
                    float4 param_6 = factor;
                    resultfinal = (newLayer(param_5, param_6) * _219.hardness) * texColor.w;
                }
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_219.alpha)) * texColor.w;
}

fragment refAM35_ecd33a51c7cb3_out refAM35_ecd33a51c7cb3(constant ReferenceUniformsecd33a51c7cb3& _219 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ecd33a51c7cb3_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _219, referenceColor);
    bool _579 = any(isnan(referenceColor));
    bool _586;
    if (!_579)
    {
        _586 = any(isinf(referenceColor));
    }
    else
    {
        _586 = _579;
    }
    if (_586)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _599 = referenceColor;
    float3 _605 = fast::clamp(_599.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _605.x;
    referenceColor.y = _605.y;
    referenceColor.z = _605.z;
    out.finalColor = referenceColor;
    return out;
}

