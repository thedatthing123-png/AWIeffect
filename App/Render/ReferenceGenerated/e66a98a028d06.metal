// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxs2Dtunnelv2.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//////////////////////////
/////////////////////////
// angle of each pixel to the center of the screen
// modified distance metric (http://en.wikipedia.org/wiki/Minkowski_distance)
// interp between round & rect tunnels
// index texture by (animated inverse) radious and angle
// subdivide to grid
// pre-warp
// create grid
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse66a98a028d06
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
    uint newpath;
    char _m9_pad[12];
    float PROGRESS;
    char _m10_pad[12];
    float SPEED;
    char _m11_pad[8];
    float2 position;
    char _m12_pad[8];
    float xxj;
    char _m13_pad[12];
    float xxg;
    char _m14_pad[12];
    float xxi;
    char _m15_pad[12];
    float xxe;
    char _m16_pad[12];
    float xxc;
    char _m17_pad[12];
    float xxd;
    char _m18_pad[12];
    float xxb;
    char _m19_pad[8];
    float2 xxx;
    char _m20_pad[8];
    float scale;
    char _m21_pad[12];
    float angle;
    char _m22_pad[8];
    float2 stretch;
    char _m23_pad[8];
    float alpha;
    char _m24_pad[12];
    float hardness;
    char _m25_pad[12];
    int blendMode;
};

struct refAM35_e66a98a028d06_out
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
float cubicPulse(thread const float& c, thread const float& w, thread float& x)
{
    x = abs(x - c);
    if (x > w)
    {
        return 0.0;
    }
    x /= w;
    return 1.0 - ((x * x) * (3.0 - (2.0 * x)));
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse66a98a028d06& _109, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_109.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _109.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_109.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _109.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_109.refScreen.x, _109.refScreen.y);
            float2 iMouse = float2(0.5);
            float _181;
            if (_109.autop != 0u)
            {
                _181 = _109.PROGRESS + (_109.refScreen.z * _109.SPEED);
            }
            else
            {
                _181 = _109.PROGRESS;
            }
            float iTime = _181;
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _109.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _109.refScreen.xy).y) * _109.refScreen.xy) - float2(_109.refLayer.x + (_109.refLayer.z * 0.5), (_109.refScreen.y - _109.refLayer.y) - (_109.refLayer.w * 0.5))) / _109.refLayer.zw;
            syamjaidtz.y *= (_109.refLayer.w / _109.refLayer.z);
            syamjaidtz /= float2(_109.scale);
            float param_3 = (0.0 + _109.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _109.position.x, 0.0 + _109.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_109.scale * _109.stretch.x, _109.scale * _109.stretch.y);
            syamjaidtz /= scaleVec;
            float time = iTime;
            float2 p = syamjaidtz;
            float2 uvOrig = p;
            float rotZ = 1.0 - (0.23000000417232513427734375 * sin(1.0 * cos(length(p * 1.5))));
            p *= float2x2(float2(cos(rotZ), sin(rotZ)), float2(-sin(rotZ), cos(rotZ)));
            float a = precise::atan2(p.y, p.x);
            float rSquare = powr(powr(p.x * p.x, _109.xxx.x) + powr(p.y * p.y, _109.xxx.y), 0.125);
            float rRound = length(p);
            float r = mix(rSquare, rRound, 0.5 + (0.5 * sin(time * 2.0)));
            float2 uv = float2((0.300000011920928955078125 / r) + time, a / 3.1415927410125732421875);
            float _382;
            if (_109.newpath != 0u)
            {
                _382 = sin(time + (uv.x * _109.xxd));
            }
            else
            {
                _382 = time + (uv.x * _109.xxd);
            }
            float PAT = _382;
            uv += float2(_109.xxb, _109.xxc * PAT);
            uv /= float2(1.0 + (0.00019999999494757503271102905273438 * length(uvOrig)));
            float2 uvDraw = fract(uv * _109.xxe);
            float param_4 = 0.5;
            float param_5 = _109.xxg;
            float param_6 = uvDraw.x;
            float _438 = cubicPulse(param_4, param_5, param_6);
            float col = _438;
            float param_7 = 0.5;
            float param_8 = _109.xxi;
            float param_9 = uvDraw.y;
            float _448 = cubicPulse(param_7, param_8, param_9);
            col = fast::max(col, _448);
            col = (col * r) * _109.xxj;
            col += (0.0 * length(uvOrig));
            float4 fragColor = float4(float3(0.0, col, 0.0), 1.0);
            float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float4 gradmap = mix(_109.color1, _109.color2, float4(luminance)) * fragColor.w;
            float4 factor = mix(texColorX, gradmap, float4(1.0));
            float4 resultfinal;
            if (_109.blendMode == 0)
            {
                resultfinal = (factor * _109.hardness) * texColor.w;
            }
            else
            {
                if (_109.blendMode == 1)
                {
                    factor *= _109.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_109.blendMode == 2)
                    {
                        factor *= _109.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_109.blendMode == 3)
                        {
                            float4 param_10 = texColor;
                            float4 param_11 = factor;
                            resultfinal = (newLayer(param_10, param_11) * _109.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_109.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e66a98a028d06_out refAM35_e66a98a028d06(constant ReferenceUniformse66a98a028d06& _109 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e66a98a028d06_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_109, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _611 = any(isnan(referenceColor));
    bool _618;
    if (!_611)
    {
        _618 = any(isinf(referenceColor));
    }
    else
    {
        _618 = _611;
    }
    if (_618)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _631 = referenceColor;
    float3 _637 = fast::clamp(_631.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _637.x;
    referenceColor.y = _637.y;
    referenceColor.z = _637.z;
    out.finalColor = referenceColor;
    return out;
}

