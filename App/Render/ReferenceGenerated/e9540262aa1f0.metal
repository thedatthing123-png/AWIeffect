// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsnoisefade.xml
// Original source comments and attribution:
//////////////////////////
//////////////////////////
/////////////////////////
// const vec3 luminanceWeighting = vec3(0.2126, 0.7152, 0.0722);
// float luminance = dot(fragColor.rgb, luminanceWeighting);
// vec4 gradmap = mix(color1,color2,luminance)*fragColor.a;
// if(GRADMAP) { factor = mix(texColorX,gradmap,1.0); }
// vec4 xbuffer = texture2DCv(buff1.texture, acScreenNorm.st);
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9540262aa1f0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float PROGRESS;
    char _m6_pad[12];
    float scale;
    char _m7_pad[12];
    float angle;
    char _m8_pad[8];
    float2 position;
    char _m9_pad[8];
    float2 stretch;
    char _m10_pad[8];
    float alpha;
    char _m11_pad[12];
    float hardness;
    char _m12_pad[12];
    int blendMode;
};

struct refAM35_e9540262aa1f0_out
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
float r(thread const float2& p)
{
    return fract(cos((p.x * 42.979999542236328125) + (p.y * 43.229999542236328125)) * 1127.530029296875);
}

static inline __attribute__((always_inline))
float n(thread const float2& p)
{
    float2 fn = floor(p);
    float2 sn = smoothstep(float2(0.0), float2(1.0), fract(p));
    float2 param = fn;
    float2 param_1 = fn + float2(1.0, 0.0);
    float h1 = mix(r(param), r(param_1), sn.x);
    float2 param_2 = fn + float2(0.0, 1.0);
    float2 param_3 = fn + float2(1.0);
    float h2 = mix(r(param_2), r(param_3), sn.x);
    return mix(h1, h2, sn.y);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 param = p / float2(32.0);
    float2 param_1 = p / float2(16.0);
    float2 param_2 = p / float2(8.0);
    float2 param_3 = p / float2(4.0);
    float2 param_4 = p / float2(2.0);
    float2 param_5 = p;
    return (((((n(param) * 0.579999983310699462890625) + (n(param_1) * 0.20000000298023223876953125)) + (n(param_2) * 0.100000001490116119384765625)) + (n(param_3) * 0.0500000007450580596923828125)) + (n(param_4) * 0.0199999995529651641845703125)) + (n(param_5) * 0.012500000186264514923095703125);
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse9540262aa1f0& _197, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_197.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _197.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_197.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _197.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_197.refScreen.x, _197.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = gl_FragCoord.xy;
            syamjaidtz /= float2(_197.scale);
            float param_3 = (0.0 + _197.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _197.position.x, 0.0 + _197.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_197.scale * _197.stretch.x, _197.scale * _197.stretch.y);
            syamjaidtz /= scaleVec;
            float2 uv = gl_FragCoord.xy / _197.refScreen.xy;
            float2 p = syamjaidtz;
            float t = abs(_197.PROGRESS);
            float2 param_4 = p * 0.4000000059604644775390625;
            float4 fragColor = mix(texColor, float4(0.0), float4(smoothstep(t + 0.100000001490116119384765625, t - 0.100000001490116119384765625, _noise(param_4))));
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal;
            if (_197.blendMode == 0)
            {
                resultfinal = (factor * _197.hardness) * texColor.w;
            }
            else
            {
                if (_197.blendMode == 1)
                {
                    factor *= _197.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_197.blendMode == 2)
                    {
                        factor *= _197.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_197.blendMode == 3)
                        {
                            factor *= _197.hardness;
                            float4 param_5 = texColor;
                            float4 param_6 = factor;
                            resultfinal = (newLayer(param_5, param_6) * _197.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, fragColor, float4(_197.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e9540262aa1f0_out refAM35_e9540262aa1f0(constant ReferenceUniformse9540262aa1f0& _197 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9540262aa1f0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_197, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _466 = any(isnan(referenceColor));
    bool _473;
    if (!_466)
    {
        _473 = any(isinf(referenceColor));
    }
    else
    {
        _473 = _466;
    }
    if (_473)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _486 = referenceColor;
    float3 _492 = fast::clamp(_486.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _492.x;
    referenceColor.y = _492.y;
    referenceColor.z = _492.z;
    out.finalColor = referenceColor;
    return out;
}

