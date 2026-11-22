// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/shapefield.xml
// Original source comments and attribution:
// Solid
// Random 1-color
// Random 2-color
// Random 3-color
// Depth 1-color
// Depth 2-color
// Depth 3-color
// Depth+Random
//return texture2DCv(inputImg.texture,l2s(uv)) * step(rand3(id),density);
//vec4 texColor = texture2DCv(inputImg.texture,acScreenNorm);
//vec2 st = (acScreenNorm - 0.5) * vec2(1., -1.);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse8c15bfe725c8
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 pos;
    float density;
    char _m7_pad[12];
    float evolution;
    char _m8_pad[12];
    float seed;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    float shapeSize;
    char _m11_pad[12];
    float shapeAngle;
    char _m12_pad[12];
    float sizeVariance;
    char _m13_pad[12];
    float angleVariance;
    char _m14_pad[12];
    float layerCount;
    char _m15_pad[12];
    float fade;
    char _m16_pad[12];
    float alpha;
    char _m17_pad[12];
    float slack;
    char _m18_pad[12];
    int blendMode;
    char _m19_pad[12];
    int coloring;
    float4 color1;
    float4 color2;
    float4 color3;
    uint lockLuminance;
    char _m24_pad[12];
    uint lockSaturation;
    char _m25_pad[12];
    uint interpHue;
};

struct refAM35_e8c15bfe725c8_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float rand4(thread const float4& v)
{
    return fract(sin(dot(v, float4(12.98980045318603515625, 78.233001708984375, 193.7100067138671875, 397.3179931640625))) * 43758.546875);
}

static inline __attribute__((always_inline))
float rand3(thread const float3& v)
{
    return fract(sin(dot(v, float3(12.98980045318603515625, 78.233001708984375, 193.7100067138671875))) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 randVec2(thread const float3& v)
{
    float4 param = float4(v, 5.124000072479248046875);
    float4 param_1 = float4(v, 3.0);
    return float2(rand4(param), rand4(param_1));
}

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse8c15bfe725c8& _125)
{
    return (float4(v, 0.0, 1.0) * _125.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 rgb2hsv(thread const float3& c)
{
    float4 K = float4(0.0, -0.3333333432674407958984375, 0.666666686534881591796875, -1.0);
    float4 p = mix(float4(c.zy, K.wz), float4(c.yz, K.xy), float4(step(c.z, c.y)));
    float4 q = mix(float4(p.xyw, c.x), float4(c.x, p.yzx), float4(step(p.x, c.x)));
    float d = q.x - fast::min(q.w, q.y);
    float e = 1.0000000133514319600180897396058e-10;
    return float3(abs(q.z + ((q.w - q.y) / ((6.0 * d) + e))), d / (q.x + e), q.x);
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
float4 mixColors(thread const float4& a, thread const float4& b, thread const float& t, constant ReferenceUniformse8c15bfe725c8& _125)
{
    float4 result;
    if (_125.interpHue != 0u)
    {
        float3 param = a.xyz;
        float3 param_1 = b.xyz;
        float3 param_2 = mix(rgb2hsv(param), rgb2hsv(param_1), float3(t));
        result = float4(hsv2rgb(param_2), mix(a.w, b.w, t));
    }
    else
    {
        result = mix(a, b, float4(t));
    }
    return result;
}

static inline __attribute__((always_inline))
float4 getColor(thread const float3& id, thread const float& layerDepth, constant ReferenceUniformse8c15bfe725c8& _125)
{
    float4 result;
    if (_125.coloring == 0)
    {
        result = float4(0.0);
    }
    else
    {
        if (_125.coloring == 1)
        {
            result = _125.color1;
        }
        else
        {
            if (_125.coloring == 2)
            {
                float4 param = float4(id, 0.1974000036716461181640625);
                result = _125.color1 * rand4(param);
            }
            else
            {
                if (_125.coloring == 3)
                {
                    float4 param_1 = float4(id, 0.1974000036716461181640625);
                    float4 param_2 = _125.color1;
                    float4 param_3 = _125.color2;
                    float param_4 = rand4(param_1);
                    result = mixColors(param_2, param_3, param_4, _125);
                }
                else
                {
                    if (_125.coloring == 4)
                    {
                        float3 param_5 = id;
                        float2 rr = randVec2(param_5);
                        float4 param_6 = _125.color1;
                        float4 param_7 = _125.color2;
                        float param_8 = rr.x;
                        float4 param_9 = mixColors(param_6, param_7, param_8, _125);
                        float4 param_10 = _125.color3;
                        float param_11 = rr.y;
                        result = mixColors(param_9, param_10, param_11, _125);
                    }
                    else
                    {
                        if (_125.coloring == 5)
                        {
                            result = _125.color1 * layerDepth;
                        }
                        else
                        {
                            if (_125.coloring == 6)
                            {
                                float4 param_12 = _125.color1;
                                float4 param_13 = _125.color2;
                                float param_14 = layerDepth;
                                result = mixColors(param_12, param_13, param_14, _125);
                            }
                            else
                            {
                                if (_125.coloring == 7)
                                {
                                    float4 _448;
                                    if (layerDepth < 0.5)
                                    {
                                        float4 param_15 = _125.color1;
                                        float4 param_16 = _125.color2;
                                        float param_17 = layerDepth * 2.0;
                                        _448 = mixColors(param_15, param_16, param_17, _125);
                                    }
                                    else
                                    {
                                        float4 param_18 = _125.color2;
                                        float4 param_19 = _125.color3;
                                        float param_20 = (layerDepth - 0.5) * 2.0;
                                        _448 = mixColors(param_18, param_19, param_20, _125);
                                    }
                                    result = _448;
                                }
                                else
                                {
                                    if (_125.coloring == 8)
                                    {
                                        float4 param_21 = float4(id, 0.1974000036716461181640625);
                                        float4 param_22 = _125.color1;
                                        float4 param_23 = _125.color2;
                                        float param_24 = rand4(param_21);
                                        float4 param_25 = _125.color3;
                                        float4 param_26 = mixColors(param_22, param_23, param_24, _125);
                                        float param_27 = layerDepth;
                                        result = mixColors(param_25, param_26, param_27, _125);
                                    }
                                    else
                                    {
                                        result = float4(0.0);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return result;
}

static inline __attribute__((always_inline))
float4 shapeGrid(thread float2& st, thread const float& layer, thread const float& layerDepth, constant ReferenceUniformse8c15bfe725c8& _125, texture2d<float> refInput, sampler refInputSmplr)
{
    st *= 10.0;
    float2 uv = fract(st);
    float3 id = float3(floor(st), layer);
    float _528;
    if (_125.sizeVariance < 9.9999997473787516355514526367188e-05)
    {
        _528 = _125.shapeSize;
    }
    else
    {
        float4 param = float4(id, 0.351000010967254638671875);
        _528 = fast::min(_125.shapeSize, _125.shapeSize * (1.0 + ((rand4(param) - 0.5) * _125.sizeVariance)));
    }
    float size = _528;
    float _560;
    if (_125.angleVariance < 9.9999997473787516355514526367188e-05)
    {
        _560 = 0.0;
    }
    else
    {
        float4 param_1 = float4(id, 0.2793000042438507080078125);
        _560 = ((rand4(param_1) - 0.5) * _125.angleVariance) * 12.5663604736328125;
    }
    float angle = _560;
    float3 param_2 = id;
    float rr = rand3(param_2);
    size *= smoothstep(rr, rr + 0.008000000379979610443115234375, _125.density);
    if (size < 9.9999997473787516355514526367188e-06)
    {
        return float4(0.0);
    }
    uv -= float2(0.5);
    float2 _606;
    if (_125.refLayer.z > _125.refLayer.w)
    {
        _606 = float2(1.0, _125.refLayer.z / _125.refLayer.w);
    }
    else
    {
        _606 = float2(_125.refLayer.w / _125.refLayer.z, 1.0);
    }
    uv *= _606;
    uv /= float2(size);
    float maxDisplace = (1.0 / size) - 1.0;
    float2 displace;
    if (abs(_125.evolution) > 0.001000000047497451305389404296875)
    {
        float3 param_3 = id + float3(floor(_125.evolution));
        float3 param_4 = id + float3(floor(_125.evolution + 1.0));
        displace = mix(randVec2(param_3), randVec2(param_4), float2(fract(_125.evolution)));
    }
    else
    {
        float3 param_5 = id;
        displace = randVec2(param_5);
    }
    uv += fast::clamp(((displace - float2(0.5)) * fast::max(1.0, maxDisplace)) * _125.slack, float2(-maxDisplace), float2(maxDisplace));
    float param_6 = angle + (_125.shapeAngle * 0.01745329238474369049072265625);
    uv *= rot(param_6);
    uv += float2(0.5);
    uv.y = 1.0 - uv.y;
    float2 param_7 = uv;
    float2 param_8 = l2s(param_7, _125);
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_8);
    float3 param_9 = id;
    float param_10 = layerDepth;
    float4 blendColor = getColor(param_9, param_10, _125);
    float4 result;
    if ((_125.lockLuminance != 0u) || (_125.lockSaturation != 0u))
    {
        float3 _731;
        if (texColor.w <= 0.0)
        {
            _731 = float3(0.0);
        }
        else
        {
            _731 = texColor.xyz / float3(texColor.w);
        }
        float3 param_11 = _731;
        float3 texHsv = rgb2hsv(param_11);
        float3 _749;
        if (blendColor.w <= 0.0)
        {
            _749 = float3(0.0);
        }
        else
        {
            _749 = blendColor.xyz / float3(blendColor.w);
        }
        float3 param_12 = _749;
        float3 blendHsv = rgb2hsv(param_12);
        if (_125.lockLuminance != 0u)
        {
            blendHsv.z = texHsv.z;
        }
        if (_125.lockSaturation != 0u)
        {
            blendHsv.y = texHsv.y;
        }
        float3 param_13 = mix(texHsv, blendHsv, float3(blendColor.w));
        result = float4(hsv2rgb(param_13), 1.0) * texColor.w;
    }
    else
    {
        float3 _798;
        if (texColor.w <= 0.0)
        {
            _798 = float3(0.0);
        }
        else
        {
            _798 = texColor.xyz / float3(texColor.w);
        }
        float3 _812;
        if (blendColor.w <= 0.0)
        {
            _812 = float3(0.0);
        }
        else
        {
            _812 = blendColor.xyz / float3(blendColor.w);
        }
        result = float4(mix(_798, _812, float3(blendColor.w)), 1.0) * texColor.w;
    }
    return result;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse8c15bfe725c8& _125, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 st = (gl_FragCoord.xy - _125.refLayer.xy) / _125.refLayer.zw;
    st.y = 1.0 - st.y;
    st -= float2(0.5);
    st.x *= (_125.refLayer.z / _125.refLayer.w);
    st /= float2(_125.scale * 6.0);
    float2 parallax = (_125.pos.xy / float2(1000.0)) + float2(25.3500003814697265625);
    float depth = _125.pos.z / 100.0;
    float4 result = float4(0.0);
    float f = fract(depth);
    float layer = floor(depth);
    float filteredSeed = _125.seed / 5.0;
    float _905 = _125.layerCount - 1.0;
    float3 _970;
    float3 _985;
    float3 _1023;
    float3 _1038;
    for (float i = _905; i >= 0.0; i -= 1.0)
    {
        float2 uv = st;
        uv *= (((1.0 + i) - f) / 9.0);
        uv += parallax;
        float layerDepth = smoothstep(_125.layerCount, _125.layerCount * (0.99989998340606689453125 - _125.fade), (i + 1.0) - f);
        float2 param = uv;
        float param_1 = (layer + i) + filteredSeed;
        float param_2 = layerDepth;
        float4 _953 = shapeGrid(param, param_1, param_2, _125, refInput, refInputSmplr);
        float4 color = (_953 * _125.alpha) * layerDepth;
        if (_125.blendMode == 1)
        {
            if (color.w < 9.9999997473787516355514526367188e-05)
            {
                _970 = float3(0.0);
            }
            else
            {
                _970 = color.xyz / float3(color.w);
            }
            float3 fg = _970;
            if (result.w < 9.9999997473787516355514526367188e-05)
            {
                _985 = float3(1.0);
            }
            else
            {
                _985 = result.xyz / float3(result.w);
            }
            float3 bg = _985;
            result = (result * (1.0 - color.w)) + (float4(fg * bg, 1.0) * color.w);
        }
        else
        {
            if (_125.blendMode == 2)
            {
                if (color.w < 9.9999997473787516355514526367188e-05)
                {
                    _1023 = float3(1.0);
                }
                else
                {
                    _1023 = color.xyz / float3(color.w);
                }
                float3 fg_1 = _1023;
                if (result.w < 9.9999997473787516355514526367188e-05)
                {
                    _1038 = float3(0.0);
                }
                else
                {
                    _1038 = result.xyz / float3(result.w);
                }
                float3 bg_1 = _1038;
                result = (result * (1.0 - color.w)) + (float4(float3(1.0) - ((float3(1.0) - fg_1) * (float3(1.0) - bg_1)), 1.0) * color.w);
            }
            else
            {
                result = (result * (1.0 - color.w)) + color;
            }
        }
    }
    referenceColor = result;
}

fragment refAM35_e8c15bfe725c8_out refAM35_e8c15bfe725c8(constant ReferenceUniformse8c15bfe725c8& _125 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8c15bfe725c8_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_125, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _1088 = any(isnan(referenceColor));
    bool _1095;
    if (!_1088)
    {
        _1095 = any(isinf(referenceColor));
    }
    else
    {
        _1095 = _1088;
    }
    if (_1095)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1108 = referenceColor;
    float3 _1114 = fast::clamp(_1108.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1114.x;
    referenceColor.y = _1114.y;
    referenceColor.z = _1114.z;
    out.finalColor = referenceColor;
    return out;
}

