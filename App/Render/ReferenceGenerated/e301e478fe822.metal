// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsinstantgrass.xml
// Original source comments and attribution:
//////////////////////////
//////////////////////////
// syamjaidtz = ((vec2(acScreenNorm.x,1.0-acScreenNorm.y)*acScreenSize)-acLayerCenter)/acLayerSize;
// syamjaidtz.y*=acLayerSize.y/acLayerSize.x;
/////////////////////////
// vec3 ct = xxx * 0.01;
// vec3 cp = yyy * 0.01;
// if(GRADMAP) { 
// }
// }
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse301e478fe822
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float AMOUNT;
    char _m6_pad[12];
    uint autop;
    char _m7_pad[12];
    float PROGRESS;
    char _m8_pad[12];
    float SPEED;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    float angle;
    char _m11_pad[8];
    float2 position;
    char _m12_pad[8];
    float2 stretch;
    char _m13_pad[8];
    float alpha;
    char _m14_pad[12];
    float hardness;
    float4 color1;
    float4 color2;
    int blendMode;
};

struct refAM35_e301e478fe822_out
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
float3 backg(thread const float3& ro, thread const float3& rd)
{
    float3 ground = float3(0.0);
    return ground;
}

static inline __attribute__((always_inline))
float4 grass(thread float2& p, thread const float& x, constant ReferenceUniformse301e478fe822& _90)
{
    float _98;
    if (_90.autop != 0u)
    {
        _98 = _90.PROGRESS + (_90.refScreen.z * _90.SPEED);
    }
    else
    {
        _98 = _90.PROGRESS;
    }
    float iTime = _98;
    float s = mix(0.89999997615814208984375, 1.39999997615814208984375, 0.5 + (sin(x * 11.0) * 0.20000000298023223876953125));
    p.x += ((powr(1.0 + p.y, 2.0) * 0.100000001490116119384765625) * cos((x * 0.5) + iTime));
    p.x *= s;
    p.y = ((1.0 + p.y) * s) - 1.0;
    float m = 1.0 - smoothstep(0.0, (fast::clamp(1.0 - (p.y * 1.5), 0.100000001490116119384765625, 0.89999997615814208984375) * 1.2999999523162841796875) * s, (powr(abs(p.x) * 80.0, 2.0) + p.y) - 0.100000001490116119384765625);
    return float4(1.0, 0.20000000298023223876953125, 0.89999997615814208984375, m * smoothstep(-1.0, -0.89999997615814208984375, p.y));
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse301e478fe822& _90, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_90.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _90.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_90.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _90.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_90.refScreen.x, _90.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = gl_FragCoord.xy / _90.refScreen.xy;
            syamjaidtz /= float2(_90.scale);
            float param_3 = (0.0 + _90.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _90.position.x, (-30.0) + _90.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_90.scale * _90.stretch.x, _90.scale * _90.stretch.y);
            syamjaidtz /= scaleVec;
            float3 ct = float3(0.0, 2.0, 5.0);
            float3 cp = float3(0.0, 0.60000002384185791015625, 0.0);
            float3 cw = fast::normalize(cp - ct);
            float3 cu = fast::normalize(cross(cw, float3(0.0, 1.0, 0.0)));
            float3 cv = fast::normalize(cross(cu, cw));
            float3x3 rm = float3x3(float3(cu), float3(cv), float3(cw));
            float2 uv = (syamjaidtz * 2.0) - float2(1.0);
            float2 t = uv;
            float3 ro = cp;
            float3 rd = rm * float3(t, -1.2999999523162841796875);
            float3 param_4 = ro;
            float3 param_5 = rd;
            float3 fcol = backg(param_4, param_5);
            for (int i = 0; i < int(_90.AMOUNT); i++)
            {
                float z = -((float(int(_90.AMOUNT) - i) * 0.100000001490116119384765625) + 1.0);
                float4 pln = float4(0.0, 0.0, -1.0, z);
                float t_1 = (pln.w - dot(pln.xyz, ro)) / dot(pln.xyz, rd);
                float2 tc = ro.xy + (rd.xy * t_1);
                tc.x += (cos(float(i) * 3.0) * 4.0);
                float cell = floor(tc.x);
                tc.x = (tc.x - cell) - 0.5;
                float2 param_6 = tc;
                float param_7 = float(i) + (cell * 10.0);
                float4 _457 = grass(param_6, param_7, _90);
                float4 c = _457;
                fcol = mix(fcol, c.xyz, float3(step(0.0, t_1) * c.w));
            }
            fcol = powr(fcol * 1.10000002384185791015625, float3(0.800000011920928955078125));
            float3 _478 = fcol + float3(0.0);
            float4 fragColor;
            fragColor.x = _478.x;
            fragColor.y = _478.y;
            fragColor.z = _478.z;
            fragColor.w = 1.0;
            float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float4 gradmap = mix(_90.color1, _90.color2, float4(luminance)) * fragColor.w;
            float4 gradmap2 = mix(float4(0.0), _90.color2, float4(luminance)) * fragColor.w;
            float4 factor = mix(texColorX, gradmap, float4(1.0));
            float4 factor2 = mix(texColorX, gradmap2, float4(1.0));
            float4 resultfinal;
            if (_90.blendMode == 0)
            {
                resultfinal = (factor * _90.hardness) * texColor.w;
            }
            else
            {
                if (_90.blendMode == 1)
                {
                    factor *= _90.hardness;
                    float4 c_1 = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c_1.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_90.blendMode == 2)
                    {
                        factor *= _90.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_90.blendMode == 3)
                        {
                            factor2 *= _90.hardness;
                            float4 param_8 = texColor;
                            float4 param_9 = factor2 * _90.hardness;
                            resultfinal = newLayer(param_8, param_9) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_90.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e301e478fe822_out refAM35_e301e478fe822(constant ReferenceUniformse301e478fe822& _90 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e301e478fe822_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_90, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _645 = any(isnan(referenceColor));
    bool _652;
    if (!_645)
    {
        _652 = any(isinf(referenceColor));
    }
    else
    {
        _652 = _645;
    }
    if (_652)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _665 = referenceColor;
    float3 _671 = fast::clamp(_665.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _671.x;
    referenceColor.y = _671.y;
    referenceColor.z = _671.z;
    out.finalColor = referenceColor;
    return out;
}

