// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxmeteor.xml
// Original source comments and attribution:
/////////////////////////
// Drop Colour
// vec3 col = vec3(.55,0.35,1.225);    // Drop Colour
// uv.x += sin(0.2+uv.y*0.8)*0.5;
// H-Count
// stretch
// uv.y *= 0.15;             // stretch
// offset
// speed
// trail length
/////////////////////////
/////////////////////////
// vec2 resolution = syamjaidtz;
// camera matrix
// vec2 ppp = xnxx;
// vec2 ppp = (-iRes.xy + 2.*(fragCoord.xy))/iRes.y;
// vec2 p = xnxx;
// vec2 p = (-iRes.xy + 2.0*fragCoord.xy)/iRes.y;
//vec3(v*0.1);
// normal
// resultfinal = (factor * bright) * texColor.a;
// multiply
// screen
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb8f8ae278481
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
    float xxa;
    char _m8_pad[12];
    float xxx;
    char _m9_pad[12];
    float xxc;
    char _m10_pad[12];
    float scale;
    char _m11_pad[8];
    float2 position;
    char _m12_pad[8];
    float2 stretch;
    char _m13_pad[8];
    float bright;
    char _m14_pad[12];
    float alpha;
    char _m15_pad[12];
    float angle;
    float4 color1;
    float4 color2;
    uint mirrx;
    char _m19_pad[12];
    uint mirry;
    char _m20_pad[12];
    int blendMode;
};

struct refAM35_eb8f8ae278481_out
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
float3 spunk(thread float2& uv, constant ReferenceUniformseb8f8ae278481& _84)
{
    float3 col = _84.color1.xyz;
    uv.x += (sin(0.20000000298023223876953125 + (uv.y * 0.800000011920928955078125)) * _84.xxa);
    uv.y += (sin(0.20000000298023223876953125 + (uv.x * 0.800000011920928955078125)) * _84.xxx);
    uv.x *= 50.0;
    float dx = fract(uv.x);
    uv.x = floor(uv.x);
    float _141;
    if (_84.autop != 0u)
    {
        _141 = _84.PROGRESS + (_84.refScreen.z * 0.5);
    }
    else
    {
        _141 = _84.PROGRESS * 0.5;
    }
    float t = _141;
    uv.y *= _84.xxc;
    float o = sin(uv.x * 215.399993896484375);
    float s = (cos(uv.x * 33.09999847412109375) * 0.300000011920928955078125) + 0.699999988079071044921875;
    float trail = mix(95.0, 35.0, s);
    float yv = fract((uv.y + (t * s)) + o) * trail;
    yv = 1.0 / yv;
    yv = smoothstep(0.0, 1.0, yv * yv);
    yv = sin(yv * 3.141590118408203125) * (s * 5.0);
    float d2 = sin(dx * 3.141590118408203125);
    yv *= (d2 * d2);
    col *= yv;
    return col;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseb8f8ae278481& _84, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _84.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param_1);
    float2 iRes = float2(_84.refScreen.x, _84.refScreen.y);
    float maxF = fast::max(_84.refScreen.x, _84.refScreen.y);
    float2 texelSize = float2(1.0) / float2(maxF);
    float2 xnxx = gl_FragCoord.xy / _84.refScreen.xy;
    float2 nxnn = ((float2((gl_FragCoord.xy / _84.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _84.refScreen.xy).y) * _84.refScreen.xy) - float2(_84.refLayer.x + (_84.refLayer.z * 0.5), (_84.refScreen.y - _84.refLayer.y) - (_84.refLayer.w * 0.5))) / _84.refLayer.zw;
    nxnn.y *= (_84.refLayer.w / _84.refLayer.z);
    nxnn /= float2(10.0);
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _84.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _84.refScreen.xy).y) * _84.refScreen.xy) - float2(_84.refLayer.x + (_84.refLayer.z * 0.5), (_84.refScreen.y - _84.refLayer.y) - (_84.refLayer.w * 0.5))) / _84.refLayer.zw;
    syamjaidtz.y *= (_84.refLayer.w / _84.refLayer.z);
    syamjaidtz /= float2(_84.scale);
    float param_2 = (0.0 + _84.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_2);
    syamjaidtz += ((float2(0.0 + _84.position.x, 0.0 + _84.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 scaleVec = float2(_84.scale * _84.stretch.x, _84.scale * _84.stretch.y);
    syamjaidtz /= scaleVec;
    if (_84.mirrx != 0u)
    {
        syamjaidtz.x = 1.0 - syamjaidtz.x;
    }
    if (_84.mirry != 0u)
    {
        syamjaidtz.y = 1.0 - syamjaidtz.y;
    }
    float _456;
    if (_84.autop != 0u)
    {
        _456 = _84.PROGRESS + (_84.refScreen.z * 0.5);
    }
    else
    {
        _456 = _84.PROGRESS / 10.0;
    }
    float time = _456;
    float2 resolution = xnxx;
    float _476;
    if (_84.autop != 0u)
    {
        _476 = sin(_84.PROGRESS + ((_84.refScreen.z * 0.5) * 64564.80078125));
    }
    else
    {
        _476 = sin(_84.PROGRESS * 64564.80078125);
    }
    float an = _476;
    float3 ro = float3(16.0 * cos(an), 0.0, 16.0 * sin(an));
    float3 ta = float3(0.0);
    float3 ww = fast::normalize(ta - ro);
    float3 uu = fast::normalize(cross(ww, float3(0.0, 1.0, 0.0)));
    float3 vv = fast::normalize(cross(uu, ww));
    float3 tot = float3(0.0);
    float2 ppp = syamjaidtz;
    float2 param_3 = ppp;
    float3 _526 = spunk(param_3, _84);
    float3 bbk = _526;
    float2 p = nxnn;
    float3 rd = fast::normalize(((uu * p.x) + (vv * p.y)) + (ww * 1.5));
    float v = 1.0 - abs(p.y);
    float3 col = ((bbk * v) * 2.0) * 3.0;
    col = sqrt(col);
    tot += col;
    float4 fragColor = float4(tot, 0.0);
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_84.blendMode == 0)
    {
        float4 param_4 = _84.color2;
        float4 param_5 = factor;
        resultfinal = (newLayer(param_4, param_5) * _84.bright) * texColor.w;
    }
    else
    {
        if (_84.blendMode == 1)
        {
            factor *= _84.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_84.blendMode == 2)
            {
                factor *= _84.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_84.alpha));
}

fragment refAM35_eb8f8ae278481_out refAM35_eb8f8ae278481(constant ReferenceUniformseb8f8ae278481& _84 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb8f8ae278481_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_84, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _676 = any(isnan(referenceColor));
    bool _683;
    if (!_676)
    {
        _683 = any(isinf(referenceColor));
    }
    else
    {
        _683 = _676;
    }
    if (_683)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _696 = referenceColor;
    float3 _702 = fast::clamp(_696.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _702.x;
    referenceColor.y = _702.y;
    referenceColor.z = _702.z;
    out.finalColor = referenceColor;
    return out;
}

