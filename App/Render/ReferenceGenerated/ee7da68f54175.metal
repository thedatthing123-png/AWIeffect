// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsparticlev2.xml
// Original source comments and attribution:
//////////////////////////
//////////////////////////
// syamjaidtz = acScreenNorm; 
/////////////////////////
///// particles
//\\\ END particles
// if(GRADMAP) { 
// }
// vec4 xbuffer = texture2DCv(buff1.texture, acScreenNorm.st);
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
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

struct ReferenceUniformsee7da68f54175
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float AMOUNT;
    float4 color1;
    float4 color2;
    uint autop;
    char _m9_pad[12];
    float PROGRESS;
    char _m10_pad[12];
    float SPEED;
    char _m11_pad[12];
    float MBS;
    char _m12_pad[12];
    float TS;
    char _m13_pad[12];
    float TIMEAMP;
    char _m14_pad[12];
    float scale;
    char _m15_pad[12];
    float angle;
    char _m16_pad[8];
    float2 position;
    char _m17_pad[8];
    float2 stretch;
    char _m18_pad[8];
    float alpha;
    char _m19_pad[12];
    float hardness;
    char _m20_pad[12];
    int blendMode;
};

struct refAM35_ee7da68f54175_out
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
float2 rotatevec2(thread const float2& vec, thread const float& ang)
{
    return float2((vec.x * cos(ang)) - (vec.y * sin(ang)), (vec.x * sin(ang)) + (vec.y * cos(ang)));
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsee7da68f54175& _109, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, texture2d<float> refImage1, sampler refImage1Smplr)
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
            float _180;
            if (_109.autop != 0u)
            {
                _180 = _109.PROGRESS + (_109.refScreen.z * _109.SPEED);
            }
            else
            {
                _180 = _109.PROGRESS;
            }
            float iTime = _180;
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _109.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _109.refScreen.xy).y) * _109.refScreen.xy) - float2(_109.refLayer.x + (_109.refLayer.z * 0.5), (_109.refScreen.y - _109.refLayer.y) - (_109.refLayer.w * 0.5))) / _109.refLayer.zw;
            syamjaidtz.y *= (_109.refLayer.w / _109.refLayer.z);
            syamjaidtz /= float2(_109.scale);
            float param_3 = (0.0 + _109.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _109.position.x, 0.0 + _109.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_109.scale * _109.stretch.x, _109.scale * _109.stretch.y);
            syamjaidtz /= scaleVec;
            float2 uv = syamjaidtz;
            float moBlurStrength = _109.MBS / 0.00999999977648258209228515625;
            float tangentStrength = _109.TS;
            float texHeight = 256.0;
            float timeSpeed = _109.TIMEAMP * 0.00999999977648258209228515625;
            float time = iTime * timeSpeed;
            float timeB = (iTime * timeSpeed) - 0.00019999999494757503271102905273438;
            float3 particles = float3(0.0);
            float2 p3;
            float2 p4;
            float2 p3B;
            float2 p4B;
            for (float i = 0.0; i < 1.0; i += (1.0 / _109.AMOUNT))
            {
                time += (i * 16.651599884033203125);
                timeB += (i * 16.651599884033203125);
                float2 param_4 = float2(i, 0.0) + float2(fract(floor((time / texHeight) / 2.0) * 2.0), fract(time));
                float2 p1 = texture2DCv(refImage1, refImage1Smplr, param_4).xy - float2(0.5);
                float2 param_5 = float2(i, 0.0) + float2(fract(floor((time / texHeight) / 2.0) * 2.0), fract(time + (1.0 / texHeight)));
                float2 p2 = texture2DCv(refImage1, refImage1Smplr, param_5).xy - float2(0.5);
                float2 param_6 = float2(i, 0.0) + float2(fract((floor((time / texHeight) / 2.0) * 2.0) + (1.0 / texHeight)), fract(time));
                float2 t1 = texture2DCv(refImage1, refImage1Smplr, param_6).xy - float2(0.5);
                float2 param_7 = float2(i, 0.0) + float2(fract((floor((time / texHeight) / 2.0) * 2.0) + (1.0 / texHeight)), fract(time + (1.0 / texHeight)));
                float2 t2 = texture2DCv(refImage1, refImage1Smplr, param_7).xy - float2(0.5);
                float2 param_8 = float2(i, 0.0) + float2(fract(floor((timeB / texHeight) / 2.0) * 2.0), fract(timeB));
                float2 p1B = texture2DCv(refImage1, refImage1Smplr, param_8).xy - float2(0.5);
                float2 param_9 = float2(i, 0.0) + float2(fract(floor((timeB / texHeight) / 2.0) * 2.0), fract(timeB + (1.0 / texHeight)));
                float2 p2B = texture2DCv(refImage1, refImage1Smplr, param_9).xy - float2(0.5);
                float2 param_10 = float2(i, 0.0) + float2(fract((floor((timeB / texHeight) / 2.0) * 2.0) + (1.0 / texHeight)), fract(timeB));
                float2 t1B = texture2DCv(refImage1, refImage1Smplr, param_10).xy - float2(0.5);
                float2 param_11 = float2(i, 0.0) + float2(fract((floor((timeB / texHeight) / 2.0) * 2.0) + (1.0 / texHeight)), fract(timeB + (1.0 / texHeight)));
                float2 t2B = texture2DCv(refImage1, refImage1Smplr, param_11).xy - float2(0.5);
                t1 = fast::normalize(p1 - t1) * tangentStrength;
                t2 = fast::normalize(p2 - t2) * tangentStrength;
                t1B = fast::normalize(p1B - t1B) * tangentStrength;
                t2B = fast::normalize(p2B - t2B) * tangentStrength;
                if (mod(floor(time * texHeight), 2.0) == 1.0)
                {
                    p3 = mix(p1, p1 - t1, float2(fract(time * texHeight)));
                    p4 = mix(p2 - t2, p2, float2(fract(time * texHeight)));
                }
                else
                {
                    p3 = mix(p1, p1 + t1, float2(fract(time * texHeight)));
                    p4 = mix(p2 + t2, p2, float2(fract(time * texHeight)));
                }
                if (mod(floor(timeB * texHeight), 2.0) == 1.0)
                {
                    p3B = mix(p1B, p1B - t1B, float2(fract(timeB * texHeight)));
                    p4B = mix(p2B - t2B, p2B, float2(fract(timeB * texHeight)));
                }
                else
                {
                    p3B = mix(p1B, p1B + t1B, float2(fract(timeB * texHeight)));
                    p4B = mix(p2B + t2B, p2B, float2(fract(timeB * texHeight)));
                }
                float2 finPos = uv + mix(p3, p4, float2(smoothstep(0.0, 1.0, fract(time * texHeight))));
                float2 finPos2 = uv + mix(p3B, p4B, float2(smoothstep(0.0, 1.0, fract(timeB * texHeight))));
                float2 finSpeed = finPos2 - finPos;
                float2 param_12 = float2(i);
                finPos += ((texture2DCv(refImage1, refImage1Smplr, param_12).xy - float2(0.5)) * float2(2.599999904632568359375, 1.0));
                float2 param_13 = float2(0.0, i);
                float pSize = 1.0 + (3.0 * texture2DCv(refImage1, refImage1Smplr, param_13).x);
                particles += (float3(0.07999999821186065673828125, 0.07999999821186065673828125, 0.0) * float3(0.180000007152557373046875 / (pSize * length(finPos))));
                float2 param_14 = finPos;
                float param_15 = atan(finSpeed.x / finSpeed.y);
                finPos = rotatevec2(param_14, param_15);
                finPos.y *= (1.0 - fast::clamp((length(abs(finSpeed)) * moBlurStrength) * timeSpeed, 0.0, 0.800000011920928955078125));
                finPos.y *= (1.0 - fast::clamp(((length(abs(finSpeed)) * moBlurStrength) * pSize) * timeSpeed, 0.0, 0.800000011920928955078125));
                particles += (float3(1.0) * float3(smoothstep(0.02999999932944774627685546875, 0.0040000001899898052215576171875, pSize * length(finPos))));
            }
            float4 fragColor = float4(particles, 1.0);
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float4 gradmap = mix(_109.color1, _109.color2, float4(luminance)) * fragColor.w;
            factor = mix(texColorX, gradmap, float4(1.0));
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
                            factor *= _109.hardness;
                            float4 param_16 = texColor;
                            float4 param_17 = factor;
                            resultfinal = (newLayer(param_16, param_17) * _109.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_109.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_ee7da68f54175_out refAM35_ee7da68f54175(constant ReferenceUniformsee7da68f54175& _109 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ee7da68f54175_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_109, referenceColor, refInput, refInputSmplr, gl_FragCoord, refImage1, refImage1Smplr);
    bool _914 = any(isnan(referenceColor));
    bool _921;
    if (!_914)
    {
        _921 = any(isinf(referenceColor));
    }
    else
    {
        _921 = _914;
    }
    if (_921)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _934 = referenceColor;
    float3 _940 = fast::clamp(_934.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _940.x;
    referenceColor.y = _940.y;
    referenceColor.z = _940.z;
    out.finalColor = referenceColor;
    return out;
}

