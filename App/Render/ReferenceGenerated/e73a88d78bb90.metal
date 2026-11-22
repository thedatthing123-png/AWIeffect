// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsvortextdust.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
// const int ITERATIONS = 5;
// const float SPEED = 0.25;
// const float PAN = 2.8;
// const float MASK_VIS = 0.0; // Set between 0-1 to visualize masks
//////////////////////////
/////////////////////////
// col = mix(vec3(0.,0.,0.),vec3(1.,1.,1.), mask);
// vec4 factor = mix(texColorX,fragColor,1.0);
// if(GMAP) { 
// resultfinal = (newLayer(texColor, factor) * hardness) * texColor.a; }
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse73a88d78bb90
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float ITERATIONS;
    char _m6_pad[12];
    float PROGRESS;
    char _m7_pad[12];
    float SEEDX;
    char _m8_pad[12];
    float PAN;
    char _m9_pad[12];
    float MASK_VIS;
    char _m10_pad[12];
    float SPEED;
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
    float4 color2;
    float4 color1;
    int blendMode;
};

struct refAM35_e73a88d78bb90_out
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
float vortex(thread const float2& uv, thread const float& dist, thread const float& seed, thread const float& bias0, thread const float& offset, constant ReferenceUniformse73a88d78bb90& _116)
{
    float ang = precise::atan2(uv.y, uv.x) + ((sin(dist + (0.100000001490116119384765625 * seed)) * (1.2000000476837158203125 - offset)) * 2.0);
    ang += (3.141590118408203125 * (0.00999999977648258209228515625 * seed));
    return fast::clamp((sin(ang * (3.0 + (offset * _116.ITERATIONS))) + bias0) / (1.0 + bias0), 0.0, 1.0);
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse73a88d78bb90& _116, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_116.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _116.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_116.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _116.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_116.refScreen.x, _116.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _116.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _116.refScreen.xy).y) * _116.refScreen.xy) - float2(_116.refLayer.x + (_116.refLayer.z * 0.5), (_116.refScreen.y - _116.refLayer.y) - (_116.refLayer.w * 0.5))) / _116.refLayer.zw;
            syamjaidtz.y *= (_116.refLayer.w / _116.refLayer.z);
            syamjaidtz /= float2(_116.scale);
            float param_3 = (0.0 + _116.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _116.position.x, 0.0 + _116.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_116.scale * _116.stretch.x, _116.scale * _116.stretch.y);
            syamjaidtz /= scaleVec;
            float2 uv = syamjaidtz;
            float texel = 1.0 / iResolution.y;
            float dist = length(uv);
            float3 col = float3(0.0);
            for (int i = 0; i < int(_116.ITERATIONS); i++)
            {
                float offset = float(i) / _116.ITERATIONS;
                float seed = 1000.0 * fract(3.13791370391845703125 * floor((_116.SEEDX * _116.SPEED) + offset));
                float time = fract((_116.PROGRESS * _116.SPEED) + offset);
                float2 pan = float2(0.0, time * _116.PAN);
                float2 param_4 = uv;
                float param_5 = dist;
                float param_6 = seed + (100.0 * float(i));
                float param_7 = (-0.99800002574920654296875) + texel;
                float param_8 = offset;
                float maskA = vortex(param_4, param_5, param_6, param_7, param_8, _116);
                float dist2 = length(uv + pan);
                float2 param_9 = uv + pan;
                float param_10 = dist2;
                float param_11 = seed + (42.0 * float(i));
                float param_12 = (-0.9900000095367431640625) + texel;
                float param_13 = offset;
                float maskB = vortex(param_9, param_10, param_11, param_12, param_13, _116);
                float radius = powr((maskA * maskA) + (maskB * maskB), 2.0);
                float fade = time * (1.0 - time);
                float mask = ((maskA * maskB) * fade) * radius;
                col = mix(col, float3(((1.0 + (1.0 * dist)) - (0.20000000298023223876953125 * offset)) - (0.100000001490116119384765625 * radius), (1.0 - (0.5 * offset)) - (0.5 * dist), 1.0 - (0.800000011920928955078125 * dist)), float3(mask));
                col = fast::max(float3(maskA * _116.MASK_VIS, (maskB * _116.MASK_VIS) + 0.100000001490116119384765625, fast::max((maskA * _116.MASK_VIS) * 2.0, maskB * _116.MASK_VIS) + 0.119999997317790985107421875) * fade, col);
            }
            float4 fragColor = float4(col * 4.0, 1.0);
            float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float4 gradmap = mix(_116.color1, _116.color2, float4(luminance)) * fragColor.w;
            float4 factor = mix(texColorX, gradmap, float4(1.0));
            float4 resultfinal;
            if (_116.blendMode == 0)
            {
                resultfinal = (factor * _116.hardness) * texColor.w;
            }
            else
            {
                if (_116.blendMode == 1)
                {
                    factor *= _116.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_116.blendMode == 2)
                    {
                        factor *= _116.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_116.blendMode == 3)
                        {
                            factor *= _116.hardness;
                            float4 param_14 = texColor;
                            float4 param_15 = factor;
                            resultfinal = (newLayer(param_14, param_15) * _116.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_116.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e73a88d78bb90_out refAM35_e73a88d78bb90(constant ReferenceUniformse73a88d78bb90& _116 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e73a88d78bb90_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_116, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _633 = any(isnan(referenceColor));
    bool _640;
    if (!_633)
    {
        _640 = any(isinf(referenceColor));
    }
    else
    {
        _640 = _633;
    }
    if (_640)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _653 = referenceColor;
    float3 _659 = fast::clamp(_653.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _659.x;
    referenceColor.y = _659.y;
    referenceColor.z = _659.z;
    out.finalColor = referenceColor;
    return out;
}

