// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsplexustriangle.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//////////////////////////
// vec2 syamjaidtz;
// syamjaidtz = acScreenNorm; 
/////////////////////////
// vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
// uv *= rot;
// for(float i = 0.0; i < 1.0; i += 1.0 / 4.0){
// vec3 bases = vec3(1.0, 1.0, 1.0);
// vec3 col = autos?m * base : mm * bases;
// col *= color2.rgb;
// vec4 factorx = newLayer(color1,fragColor*(hardness-0.4));
// resultfinal = max(factor, texColor) * texColor.a; }
// else if( blendMode==3 ) { factorx *= 1.0; 
// resultfinal = (newLayer(texColor, factorx) * 1.0) * texColor.a; }
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

struct ReferenceUniformse1525a7897d86
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    uint autoe;
    char _m8_pad[12];
    uint autob;
    char _m9_pad[12];
    uint autor;
    char _m10_pad[12];
    float XXA;
    char _m11_pad[12];
    float XXB;
    char _m12_pad[12];
    float scale;
    char _m13_pad[12];
    float angle;
    char _m14_pad[8];
    float2 position;
    char _m15_pad[8];
    float2 stretch;
    char _m16_pad[8];
    float alpha;
    char _m17_pad[12];
    float hardness;
    char _m18_pad[12];
    int blendMode;
    char _m19_pad[12];
    uint invert;
    char _m20_pad[12];
    uint autos;
    char _m21_pad[12];
    uint autop;
    char _m22_pad[12];
    float XXC;
};

struct refAM35_e1525a7897d86_out
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
    float _372 = N21(param);
    float n = _372;
    float2 param_1 = p + float2(n);
    float _379 = N21(param_1);
    return float2(n, _379);
}

static inline __attribute__((always_inline))
float2 getPos(thread const float2& id, thread const float2& offset, constant ReferenceUniformse1525a7897d86& _388)
{
    float _395;
    if (_388.autoe != 0u)
    {
        _395 = _388.XXA + (_388.refScreen.z * 0.5);
    }
    else
    {
        _395 = _388.XXA;
    }
    float FEVO = _395;
    float2 param = id + offset;
    float2 n = N22(param) * FEVO;
    return offset + (sin(n) * 0.4000000059604644775390625);
}

static inline __attribute__((always_inline))
float distLine(thread const float2& p, thread const float2& a, thread const float2& b)
{
    float2 pa = p - a;
    float2 ba = b - a;
    float t = fast::clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - (ba * t));
}

static inline __attribute__((always_inline))
float line(thread const float2& p, thread const float2& a, thread const float2& b)
{
    float2 param = p;
    float2 param_1 = a;
    float2 param_2 = b;
    float d = distLine(param, param_1, param_2);
    float m = smoothstep(0.02999999932944774627685546875, 0.00999999977648258209228515625, d);
    float d2 = length(a - b);
    m *= ((smoothstep(1.2000000476837158203125, 0.800000011920928955078125, d2) * 0.5) + smoothstep(0.0500000007450580596923828125, 0.02999999932944774627685546875, abs(d2 - 0.75)));
    return m;
}

static inline __attribute__((always_inline))
float distTriangle(thread const float2& p, thread const float2& p0, thread const float2& p1, thread const float2& p2)
{
    float2 e0 = p1 - p0;
    float2 e1 = p2 - p1;
    float2 e2 = p0 - p2;
    float2 v0 = p - p0;
    float2 v1 = p - p1;
    float2 v2 = p - p2;
    float2 pq0 = v0 - (e0 * fast::clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0));
    float2 pq1 = v1 - (e1 * fast::clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0));
    float2 pq2 = v2 - (e2 * fast::clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0));
    float s = sign((e0.x * e2.y) - (e0.y * e2.x));
    float2 d = fast::min(fast::min(float2(dot(pq0, pq0), s * ((v0.x * e0.y) - (v0.y * e0.x))), float2(dot(pq1, pq1), s * ((v1.x * e1.y) - (v1.y * e1.x)))), float2(dot(pq2, pq2), s * ((v2.x * e2.y) - (v2.y * e2.x))));
    return (-sqrt(d.x)) * sign(d.y);
}

static inline __attribute__((always_inline))
float triangle(thread const float2& p, thread const float2& a, thread const float2& b, thread const float2& c)
{
    float2 param = p;
    float2 param_1 = a;
    float2 param_2 = b;
    float2 param_3 = c;
    float d = distTriangle(param, param_1, param_2, param_3);
    float m = smoothstep(0.02999999932944774627685546875, 0.00999999977648258209228515625, d);
    float d2 = length(a - b);
    m *= ((smoothstep(1.2000000476837158203125, 0.800000011920928955078125, d2) * 0.5) + smoothstep(0.0500000007450580596923828125, 0.02999999932944774627685546875, abs(d2 - 0.75)));
    return m;
}

static inline __attribute__((always_inline))
float layer(thread const float2& uv, constant ReferenceUniformse1525a7897d86& _388)
{
    float2 gv = fract(uv) - float2(0.5);
    float2 id = floor(uv);
    int i = 0;
    spvUnsafeArray<float2, 9> p;
    for (float y = -1.0; y <= 1.0; y += 1.0)
    {
        for (float x = -1.0; x <= 1.0; x += 1.0)
        {
            int _459 = i;
            i = _459 + 1;
            float2 param = id;
            float2 param_1 = float2(x, y);
            p[_459] = getPos(param, param_1, _388);
        }
    }
    float _479;
    if (_388.autob != 0u)
    {
        _479 = (_388.XXB + (_388.refScreen.z * 0.5)) * 10.0;
    }
    else
    {
        _479 = _388.XXB * 10.0;
    }
    float t = _479;
    float m = 0.0;
    for (int i_1 = 0; i_1 < 9; i_1++)
    {
        float2 param_2 = gv;
        float2 param_3 = p[4];
        float2 param_4 = p[i_1];
        m += line(param_2, param_3, param_4);
        float2 j = (p[i_1] - gv) * 20.0;
        float sparkle = 1.0 / dot(j, j);
        m += (sparkle * ((sin(t + (fract(p[i_1].x) * 10.0)) * 0.5) + 0.5));
        int _548 = i_1 + 1;
        for (int yi = _548; yi < 9; yi++)
        {
            int _558 = yi + 1;
            for (int zi = _558; zi < 9; zi++)
            {
                float len1 = abs(length(p[i_1] - p[yi]));
                float len2 = abs(length(p[yi] - p[zi]));
                float len3 = abs(length(p[i_1] - p[zi]));
                if (((len1 + len2) + len3) < 2.7999999523162841796875)
                {
                    float2 param_5 = gv;
                    float2 param_6 = p[i_1];
                    float2 param_7 = p[yi];
                    float2 param_8 = p[zi];
                    m += (triangle(param_5, param_6, param_7, param_8) * 0.800000011920928955078125);
                }
            }
        }
    }
    float2 param_9 = gv;
    float2 param_10 = p[1];
    float2 param_11 = p[3];
    m += line(param_9, param_10, param_11);
    float2 param_12 = gv;
    float2 param_13 = p[1];
    float2 param_14 = p[5];
    m += line(param_12, param_13, param_14);
    float2 param_15 = gv;
    float2 param_16 = p[7];
    float2 param_17 = p[3];
    m += line(param_15, param_16, param_17);
    float2 param_18 = gv;
    float2 param_19 = p[7];
    float2 param_20 = p[5];
    m += line(param_18, param_19, param_20);
    return m;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse1525a7897d86& _388, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_388.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _388.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_388.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _388.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_388.refScreen.x, _388.refScreen.y);
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _388.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _388.refScreen.xy).y) * _388.refScreen.xy) - float2(_388.refLayer.x + (_388.refLayer.z * 0.5), (_388.refScreen.y - _388.refLayer.y) - (_388.refLayer.w * 0.5))) / _388.refLayer.zw;
            syamjaidtz.y *= (_388.refLayer.w / _388.refLayer.z);
            syamjaidtz /= float2(_388.scale);
            float _795;
            if (_388.autor != 0u)
            {
                _795 = _388.angle + (_388.refScreen.z * 2.5);
            }
            else
            {
                _795 = _388.angle;
            }
            float ROTATE = _795;
            float param_3 = (0.0 + ROTATE) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _388.position.x, 0.0 + _388.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_388.scale * _388.stretch.x, _388.scale * _388.stretch.y);
            syamjaidtz /= scaleVec;
            float2 uv = syamjaidtz;
            float m = 0.0;
            float mm = 0.0;
            float _858;
            if (_388.autop != 0u)
            {
                _858 = (_388.XXC + (_388.refScreen.z * 0.5)) * 0.100000001490116119384765625;
            }
            else
            {
                _858 = _388.XXC * 0.100000001490116119384765625;
            }
            float t = _858;
            float s = sin(t);
            float c = cos(t);
            float2x2 rot = float2x2(float2(c, -s), float2(s, c));
            for (float i = 0.0; i < 1.0; i += 16.0)
            {
                float z = fract(i + t);
                float size = mix(10.0, 0.5, z);
                float fade = smoothstep(0.0, 0.5, z) * smoothstep(1.0, 0.800000011920928955078125, z);
                float2 param_4 = (uv * size) + float2(i * 20.0);
                m += (layer(param_4, _388) * fade);
                float2 param_5 = (uv * size) + float2(i * 20.0);
                mm += layer(param_5, _388);
            }
            float3 base = (sin(float3(0.3449999988079071044921875, 0.4560000002384185791015625, 0.566999971866607666015625) * (t * 5.0)) * 0.4000000059604644775390625) + float3(0.60000002384185791015625);
            float3 _961;
            if (_388.autos != 0u)
            {
                _961 = base * m;
            }
            else
            {
                _961 = _388.color2.xyz * mm;
            }
            float3 col = _961;
            float4 fragColor = float4(col, 0.0);
            if (_388.invert != 0u)
            {
                fragColor = float4(1.0) - fragColor;
            }
            float4 param_6 = _388.color1;
            float4 param_7 = fragColor;
            float4 factor = newLayer(param_6, param_7);
            float4 resultfinal;
            if (_388.blendMode == 0)
            {
                resultfinal = (factor * _388.hardness) * texColor.w;
            }
            else
            {
                if (_388.blendMode == 1)
                {
                    factor *= 1.0;
                    float4 c_1 = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c_1.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_388.blendMode == 2)
                    {
                        factor *= _388.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_388.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e1525a7897d86_out refAM35_e1525a7897d86(constant ReferenceUniformse1525a7897d86& _388 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e1525a7897d86_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_388, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _1092 = any(isnan(referenceColor));
    bool _1099;
    if (!_1092)
    {
        _1099 = any(isinf(referenceColor));
    }
    else
    {
        _1099 = _1092;
    }
    if (_1099)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1112 = referenceColor;
    float3 _1118 = fast::clamp(_1112.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1118.x;
    referenceColor.y = _1118.y;
    referenceColor.z = _1118.z;
    out.finalColor = referenceColor;
    return out;
}

