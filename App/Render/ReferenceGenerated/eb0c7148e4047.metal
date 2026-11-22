// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsplexusparticle.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
// vec2 n = N22(id+offs)* progressb;
// distance to the line segment
// cut out the line
// make them not all visible
// float t = progressc*20.0;
//////////////////////////
/////////////////////////
// vec4 factor = gradmap * alpha;
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wmissing-braces"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

template<typename T, size_t Num>
struct spvUnsafeArray
{
    T elements[Num ? Num : 1];
    
    thread T& operator [] (size_t pos) thread
    {
        return elements[pos];
    }
    constexpr const thread T& operator [] (size_t pos) const thread
    {
        return elements[pos];
    }
    
    device T& operator [] (size_t pos) device
    {
        return elements[pos];
    }
    constexpr const device T& operator [] (size_t pos) const device
    {
        return elements[pos];
    }
    
    constexpr const constant T& operator [] (size_t pos) const constant
    {
        return elements[pos];
    }
    
    threadgroup T& operator [] (size_t pos) threadgroup
    {
        return elements[pos];
    }
    constexpr const threadgroup T& operator [] (size_t pos) const threadgroup
    {
        return elements[pos];
    }
};

struct ReferenceUniformseb0c7148e4047
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float ITER;
    char _m6_pad[12];
    uint autop;
    char _m7_pad[12];
    uint autob;
    char _m8_pad[12];
    float progressb;
    char _m9_pad[12];
    float progressc;
    char _m10_pad[12];
    uint autor;
    char _m11_pad[12];
    uint autos;
    char _m12_pad[12];
    float progressa;
    char _m13_pad[12];
    float scale;
    char _m14_pad[12];
    float angle;
    char _m15_pad[8];
    float2 position;
    char _m16_pad[8];
    float2 stretch;
    char _m17_pad[8];
    float bright;
    char _m18_pad[12];
    float alpha;
    float4 color1;
    float4 color2;
    int blendMode;
};

struct refAM35_eb0c7148e4047_out
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
float N21(thread float2& p)
{
    p = fract(p * float2(233.339996337890625, 851.72998046875));
    p += float2(dot(p, p + float2(23.450000762939453125)));
    return fract(p.x * p.y);
}

static inline __attribute__((always_inline))
float2 N22(thread const float2& p)
{
    float2 param = p;
    float _130 = N21(param);
    float n = _130;
    float2 param_1 = p + float2(n);
    float _137 = N21(param_1);
    return float2(n, _137);
}

static inline __attribute__((always_inline))
float2 GetPos(thread const float2& id, thread const float2& offs, constant ReferenceUniformseb0c7148e4047& _146)
{
    float _153;
    if (_146.autop != 0u)
    {
        _153 = _146.progressb + (_146.refScreen.z * 2.0);
    }
    else
    {
        _153 = _146.progressb;
    }
    float xnxx = _153;
    float2 param = id + offs;
    float2 n = N22(param) * xnxx;
    return offs + (sin(n) * 0.4000000059604644775390625);
}

static inline __attribute__((always_inline))
float DistLine(thread const float2& p, thread const float2& a, thread const float2& b)
{
    float2 pa = p - a;
    float2 ba = b - a;
    float t = fast::clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - (ba * t));
}

static inline __attribute__((always_inline))
float Line(thread const float2& p, thread const float2& a, thread const float2& b)
{
    float2 param = p;
    float2 param_1 = a;
    float2 param_2 = b;
    float d = DistLine(param, param_1, param_2);
    float m = smoothstep(0.02999999932944774627685546875, 0.00999999977648258209228515625, d);
    float d2 = length(a - b);
    m *= ((smoothstep(1.2000000476837158203125, 0.800000011920928955078125, d2) * 0.5) + smoothstep(0.0500000007450580596923828125, 0.02999999932944774627685546875, abs(d2 - 0.75)));
    return m;
}

static inline __attribute__((always_inline))
float Layer(thread const float2& uv, constant ReferenceUniformseb0c7148e4047& _146)
{
    float m = 0.0;
    float2 gv = fract(uv) - float2(0.5);
    float2 id = floor(uv);
    int i = 0;
    spvUnsafeArray<float2, 9> p;
    for (float y = -1.0; y <= 1.0; y += 1.0)
    {
        for (float x = -1.0; x <= 1.0; x += 1.0)
        {
            int _255 = i;
            i = _255 + 1;
            float2 param = id;
            float2 param_1 = float2(x, y);
            p[_255] = GetPos(param, param_1, _146);
        }
    }
    float _275;
    if (_146.autob != 0u)
    {
        _275 = (_146.progressc + (_146.refScreen.z * 0.5)) * 10.0;
    }
    else
    {
        _275 = _146.progressc * 10.0;
    }
    float t = _275;
    for (int i_1 = 0; i_1 < 9; i_1++)
    {
        float2 param_2 = gv;
        float2 param_3 = p[4];
        float2 param_4 = p[i_1];
        m += Line(param_2, param_3, param_4);
        float2 j = (p[i_1] - gv) * 15.0;
        float sparkle = 1.0 / dot(j, j);
        m += (sparkle * ((sin(t + (fract(p[i_1].x) * 10.0)) * 0.5) + 0.5));
    }
    float2 param_5 = gv;
    float2 param_6 = p[1];
    float2 param_7 = p[3];
    m += Line(param_5, param_6, param_7);
    float2 param_8 = gv;
    float2 param_9 = p[1];
    float2 param_10 = p[5];
    m += Line(param_8, param_9, param_10);
    float2 param_11 = gv;
    float2 param_12 = p[5];
    float2 param_13 = p[7];
    m += Line(param_11, param_12, param_13);
    float2 param_14 = gv;
    float2 param_15 = p[7];
    float2 param_16 = p[3];
    m += Line(param_14, param_15, param_16);
    return m;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseb0c7148e4047& _146, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_146.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _146.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_146.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _146.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _146.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _146.refScreen.xy).y) * _146.refScreen.xy) - float2(_146.refLayer.x + (_146.refLayer.z * 0.5), (_146.refScreen.y - _146.refLayer.y) - (_146.refLayer.w * 0.5))) / _146.refLayer.zw;
            syamjaidtz.y *= (_146.refLayer.w / _146.refLayer.z);
            syamjaidtz /= float2(2.0 * _146.scale);
            float _497;
            if (_146.autor != 0u)
            {
                _497 = _146.angle + (_146.refScreen.z * 1.25);
            }
            else
            {
                _497 = _146.angle;
            }
            float param_2 = _497 * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_2);
            syamjaidtz += ((_146.position * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_146.scale * _146.stretch.x, _146.scale * _146.stretch.y);
            syamjaidtz /= scaleVec;
            float2 uv = syamjaidtz;
            float2 mouse = (float2(0.0) / uv) - float2(0.5);
            float m = 0.0;
            float _559;
            if (_146.autos != 0u)
            {
                _559 = (_146.progressa + (_146.refScreen.z * 0.5)) * 0.100000001490116119384765625;
            }
            else
            {
                _559 = _146.progressa * 0.100000001490116119384765625;
            }
            float t = _559;
            float s = sin(t);
            float c = cos(t);
            float2x2 rot = float2x2(float2(c, -s), float2(s, c));
            if (_146.autor != 0u)
            {
                uv *= rot;
            }
            for (float i = 0.0; i < 1.0; i += (21.0 - _146.ITER))
            {
                float z = fract(i + t);
                float size = mix(10.0, 0.5, z);
                float fade = smoothstep(0.0, 0.5, z) * smoothstep(1.0, 0.800000011920928955078125, z);
                float2 param_3 = ((uv * size) + float2(i * 20.0)) - mouse;
                m += (Layer(param_3, _146) * fade);
            }
            float3 col = float3(m);
            float4 result = float4(col, 1.0);
            float luminance = dot(result.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float4 gradmap = mix(_146.color1, _146.color2, float4(luminance)) * result.w;
            float4 factor = mix(texColorX, gradmap, float4(1.0));
            float4 resultfinal;
            if (_146.blendMode == 0)
            {
                resultfinal = (factor * _146.bright) * texColor.w;
            }
            else
            {
                if (_146.blendMode == 1)
                {
                    factor *= _146.bright;
                    float4 c_1 = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c_1.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_146.blendMode == 2)
                    {
                        factor *= _146.bright;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_146.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_eb0c7148e4047_out refAM35_eb0c7148e4047(constant ReferenceUniformseb0c7148e4047& _146 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb0c7148e4047_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_146, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _778 = any(isnan(referenceColor));
    bool _785;
    if (!_778)
    {
        _785 = any(isinf(referenceColor));
    }
    else
    {
        _785 = _778;
    }
    if (_785)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _798 = referenceColor;
    float3 _804 = fast::clamp(_798.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _804.x;
    referenceColor.y = _804.y;
    referenceColor.z = _804.z;
    out.finalColor = referenceColor;
    return out;
}

