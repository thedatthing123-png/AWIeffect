// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsnowreal.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
// vec2 uv = MOUSE.xy/u_resolution.xy + vec2(1.,u_resolution.y/u_resolution.x)*fragCoord.xy / u_resolution.xy;
// normal
// resultfinal = (newLayer(texColor, factor) * bright) * texColor.a;
// multiply
// screen
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformsea3dde846bc3a
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint autop;
    float4 color1;
    float LAYERS;
    char _m8_pad[12];
    float EVO;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    float angle;
    char _m11_pad[8];
    float2 position;
    char _m12_pad[8];
    float2 stretch;
    char _m13_pad[8];
    float bright;
    char _m14_pad[12];
    float alpha;
    char _m15_pad[12];
    int blendMode;
};

struct refAM35_ea3dde846bc3a_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsea3dde846bc3a& _68, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _68.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 iRes = float2(_68.refScreen.x, _68.refScreen.y);
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param_1);
    float maxF = fast::max(_68.refScreen.x, _68.refScreen.y);
    float2 texelSize = float2(1.0) / float2(maxF);
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _68.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _68.refScreen.xy).y) * _68.refScreen.xy) - float2(_68.refLayer.x + (_68.refLayer.z * 0.5), (_68.refScreen.y - _68.refLayer.y) - (_68.refLayer.w * 0.5))) / _68.refLayer.zw;
    syamjaidtz.y *= (_68.refLayer.w / _68.refLayer.z);
    syamjaidtz /= float2(_68.scale);
    float param_2 = ((-180.0) + _68.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_2);
    syamjaidtz += ((float2(0.0 + _68.position.x, 0.0 + _68.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 scaleVec = float2(_68.scale * _68.stretch.x, _68.scale * _68.stretch.y);
    syamjaidtz /= scaleVec;
    float2 MOUSE = float2(0.0);
    float2 uv = syamjaidtz;
    float _225;
    if (_68.autop != 0u)
    {
        _225 = _68.EVO * (_68.refScreen.z * 0.100000001490116119384765625);
    }
    else
    {
        _225 = _68.EVO;
    }
    float PROGRESS = _225;
    float3 acc = float3(0.0);
    float dof = 5.0 * sin(PROGRESS * 0.100000001490116119384765625);
    for (float i = 0.0; i < _68.LAYERS; i += 1.0)
    {
        float fi = i;
        float2 q = uv * (1.0 + (fi * 0.20000000298023223876953125));
        q += float2(q.y * (((PROGRESS / 10.0) * mod(fi * 7.238916873931884765625, 1.0)) - ((PROGRESS / 10.0) * 0.5)), (0.800000011920928955078125 * PROGRESS) / (1.0 + ((fi * 0.20000000298023223876953125) * 0.02999999932944774627685546875)));
        float3 n = float3(floor(q), 31.188999176025390625 + fi);
        float3 m = (floor(n) * 9.9999997473787516355514526367188e-06) + fract(n);
        float3 mp = (float3(31415.900390625) + m) / fract(float3x3(float3(13.3231220245361328125, 23.511199951171875, 21.7112293243408203125), float3(21.1212005615234375, 28.7311992645263671875, 11.9312000274658203125), float3(21.811199188232421875, 14.72119998931884765625, 61.393398284912109375)) * m);
        float3 r = fract(mp);
        float2 s = abs(((mod(q, float2(1.0)) - float2(0.5)) + (r.xy * 0.89999997615814208984375)) - float2(0.449999988079071044921875));
        s += (abs((fract(q.yx * 10.0) * 2.0) - float2(1.0)) * 0.00999999977648258209228515625);
        float d = ((0.60000002384185791015625 * fast::max(s.x - s.y, s.x + s.y)) + fast::max(s.x, s.y)) - 0.00999999977648258209228515625;
        float edge = 0.004999999888241291046142578125 + (0.0500000007450580596923828125 * fast::min(0.5 * abs((fi - 5.0) - dof), 1.0));
        acc += float3(smoothstep(edge, -edge, d) * (r.x / (1.0 + ((0.0199999995529651641845703125 * fi) * 0.20000000298023223876953125))));
    }
    acc *= _68.color1.xyz;
    float4 fragColor = float4(acc, 1.0);
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_68.blendMode == 0)
    {
        resultfinal = (factor * _68.bright) * texColor.w;
    }
    else
    {
        if (_68.blendMode == 1)
        {
            factor *= _68.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_68.blendMode == 2)
            {
                factor *= _68.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_68.alpha));
}

fragment refAM35_ea3dde846bc3a_out refAM35_ea3dde846bc3a(constant ReferenceUniformsea3dde846bc3a& _68 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea3dde846bc3a_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _68, referenceColor);
    bool _534 = any(isnan(referenceColor));
    bool _541;
    if (!_534)
    {
        _541 = any(isinf(referenceColor));
    }
    else
    {
        _541 = _534;
    }
    if (_541)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _554 = referenceColor;
    float3 _560 = fast::clamp(_554.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _560.x;
    referenceColor.y = _560.y;
    referenceColor.z = _560.z;
    out.finalColor = referenceColor;
    return out;
}

