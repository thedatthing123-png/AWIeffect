// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxslightsaber.xml
// Original source comments and attribution:
//////////////////////////
//////////////////////////
/////////////////////////
// vec4 factor = mix(texColorX,fragColor,1.0);
// resultfinal = (newLayer(texColor, factor) * hardness) * texColor.a; }
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseed3b0af3caab
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    float AMOUNT;
    char _m8_pad[12];
    float SPREAD;
    char _m9_pad[12];
    float EVO;
    char _m10_pad[12];
    float EVO2;
    char _m11_pad[12];
    float scale;
    char _m12_pad[12];
    float angle;
    char _m13_pad[8];
    float2 position;
    char _m14_pad[8];
    float2 stretch;
    char _m15_pad[8];
    float alpha;
    char _m16_pad[12];
    float hardness;
    char _m17_pad[12];
    int blendMode;
};

struct refAM35_eed3b0af3caab_out
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
float rand(thread const float& _seed)
{
    return fract(sin(_seed + 137.0) * 43758.546875);
}

static inline __attribute__((always_inline))
float min_dist(thread const float2& v, thread const float2& w, thread const float2& p)
{
    float t = (((p.x - v.x) * (w.x - v.x)) + ((p.y - v.y) * (w.y - v.y))) / (((w.x - v.x) * (w.x - v.x)) + ((w.y - v.y) * (w.y - v.y)));
    if (t < 0.0)
    {
        return distance(p, v);
    }
    else
    {
        if (t > 1.0)
        {
            return distance(p, w);
        }
    }
    float2 op = v + ((w - v) * t);
    return distance(p, op);
}

static inline __attribute__((always_inline))
float ll3(thread const float2& p1, thread const float2& p2, thread const float2& uv, constant ReferenceUniformseed3b0af3caab& _192)
{
    float mind = 1000000.0;
    float2 plast = p1;
    float param = floor(_192.refScreen.z * 40.0);
    float seed = rand(param);
    for (int i = 0; i < 2; i++)
    {
        float tt = float(i + 1) / 3.0;
        float2 pt = p1 + ((p2 - p1) * tt);
        float param_1 = seed;
        float a = (rand(param_1) * 3.1415920257568359375) * 2.0;
        float param_2 = seed;
        float2 pn = pt + ((float2(cos(a), sin(a)) * rand(param_2)) / float2((abs(tt - 0.5) + 1.0) * 90.0));
        float2 param_3 = plast;
        float2 param_4 = pn;
        float2 param_5 = uv;
        float d = min_dist(param_3, param_4, param_5);
        if (d < mind)
        {
            mind = d;
        }
        plast = pn;
        float param_6 = seed;
        seed = rand(param_6);
    }
    float2 param_7 = plast;
    float2 param_8 = p2;
    float2 param_9 = uv;
    float d_1 = min_dist(param_7, param_8, param_9);
    if (d_1 < mind)
    {
        return d_1 * 3.0;
    }
    else
    {
        return mind * 5.0;
    }
}

static inline __attribute__((always_inline))
float ll2(thread const float2& p1, thread const float2& p2, thread const float2& uv, constant ReferenceUniformseed3b0af3caab& _192)
{
    float mind = 1000000.0;
    float2 plast = p1;
    float param = floor(_192.EVO2 * 15.0);
    float seed = rand(param);
    for (int i = 0; i < int(_192.SPREAD); i++)
    {
        float tt = float(i + 1) / 4.0;
        float2 pt = p1 + ((p2 - p1) * tt);
        float param_1 = seed;
        float a = (rand(param_1) * 3.1415920257568359375) * 2.0;
        float param_2 = seed;
        float2 pn = pt + ((float2(cos(a), sin(a)) * rand(param_2)) / float2((abs(tt - 0.5) + 1.0) * 30.0));
        float2 param_3 = plast;
        float2 param_4 = pn;
        float2 param_5 = uv;
        float d = min_dist(param_3, param_4, param_5);
        if (d < mind)
        {
            mind = d;
        }
        float param_6 = seed;
        float param_7 = seed;
        float2 pn2 = pn + ((float2(cos(a), sin(a)) * rand(param_6)) / float2(((abs(tt - 0.5) + 1.0) * rand(param_7)) * 30.0));
        float2 param_8 = pn;
        float2 param_9 = pn2;
        float2 param_10 = uv;
        d = ll3(param_8, param_9, param_10, _192);
        if (d < mind)
        {
            mind = d;
        }
        plast = pn;
        float param_11 = seed;
        seed = rand(param_11);
    }
    float2 param_12 = plast;
    float2 param_13 = p2;
    float2 param_14 = uv;
    float d_1 = min_dist(param_12, param_13, param_14);
    if (d_1 < mind)
    {
        return d_1 * 3.0;
    }
    else
    {
        return mind * 3.0;
    }
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseed3b0af3caab& _192, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_192.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _192.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_192.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _192.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_192.refScreen.x, _192.refScreen.y);
            float2 iMouse = float2(0.5);
            float iTime = _192.refScreen.z;
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _192.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _192.refScreen.xy).y) * _192.refScreen.xy) - float2(_192.refLayer.x + (_192.refLayer.z * 0.5), (_192.refScreen.y - _192.refLayer.y) - (_192.refLayer.w * 0.5))) / _192.refLayer.zw;
            syamjaidtz.y *= (_192.refLayer.w / _192.refLayer.z);
            syamjaidtz /= float2(_192.scale);
            float param_3 = (0.0 + _192.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2((-250.0) + _192.position.x, 140.0 - _192.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_192.scale * _192.stretch.x, _192.scale * _192.stretch.y);
            syamjaidtz /= scaleVec;
            float2 uv = syamjaidtz;
            float2 p1 = float2(0.100000001490116119384765625, 0.300000011920928955078125);
            float2 p2 = float2(0.89999997615814208984375, 0.300000011920928955078125);
            float mind = 1000000.0;
            float2 plast = p1;
            float param_4 = floor(_192.EVO * 10.0);
            float seed = rand(param_4);
            for (int i = 0; i < int(_192.AMOUNT); i++)
            {
                float tt = float(i + 1) / 15.0;
                float2 pt = p1 + ((p2 - p1) * tt);
                float param_5 = seed;
                float a = (rand(param_5) * 3.1415920257568359375) * 2.0;
                float param_6 = seed;
                float2 pn = pt + ((float2(cos(a), sin(a)) * rand(param_6)) / float2((abs(tt - 0.5) + 1.0) * 9.0));
                float2 param_7 = plast;
                float2 param_8 = pn;
                float2 param_9 = uv;
                float d = min_dist(param_7, param_8, param_9);
                if (d < mind)
                {
                    mind = d;
                }
                float param_10 = seed;
                float param_11 = seed;
                float2 pn2 = pn + ((float2(cos(a), sin(a)) * rand(param_10)) / float2(((abs(tt - 0.5) + 1.0) * rand(param_11)) * 6.0));
                float2 param_12 = pn;
                float2 param_13 = pn2;
                float2 param_14 = uv;
                d = ll2(param_12, param_13, param_14, _192);
                if (d < mind)
                {
                    mind = d;
                }
                plast = pn;
                float param_15 = seed;
                seed = rand(param_15);
            }
            float2 param_16 = plast;
            float2 param_17 = p2;
            float2 param_18 = uv;
            float d_1 = min_dist(param_16, param_17, param_18);
            if (d_1 < mind)
            {
                mind = d_1;
            }
            mind *= 10.0;
            mind += 1.0;
            mind = 1.0 / (((mind * mind) * mind) * mind);
            float4 fragColor = float4(1.0) * mind;
            fragColor.x *= mind;
            fragColor.y *= mind;
            float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float4 gradmap = mix(_192.color1, _192.color2, float4(luminance)) * fragColor.w;
            float4 factor = mix(texColorX, gradmap, float4(1.0));
            float4 resultfinal;
            if (_192.blendMode == 0)
            {
                resultfinal = (factor * _192.hardness) * texColor.w;
            }
            else
            {
                if (_192.blendMode == 1)
                {
                    factor *= _192.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_192.blendMode == 2)
                    {
                        factor *= _192.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_192.blendMode == 3)
                        {
                            factor *= _192.hardness;
                            float4 param_19 = texColor;
                            float4 param_20 = factor;
                            resultfinal = (newLayer(param_19, param_20) * _192.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_192.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_eed3b0af3caab_out refAM35_eed3b0af3caab(constant ReferenceUniformseed3b0af3caab& _192 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eed3b0af3caab_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_192, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _915 = any(isnan(referenceColor));
    bool _922;
    if (!_915)
    {
        _922 = any(isinf(referenceColor));
    }
    else
    {
        _922 = _915;
    }
    if (_922)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _935 = referenceColor;
    float3 _941 = fast::clamp(_935.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _941.x;
    referenceColor.y = _941.y;
    referenceColor.z = _941.z;
    out.finalColor = referenceColor;
    return out;
}

