// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxswingsline.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//////////////////////////
/////////////////////////
// fragColor = vec4(0.,0.,0.,1.);
// vec3 blue = vec3(.5, .85, .99);
// resultfinal = (newLayer(texColor, factor) * hardness) * texColor.a; }
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse81af622a8da9
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color1;
    float4 color2;
    float2 position;
    char _m8_pad[8];
    float PROGRESS;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    float angle;
    char _m11_pad[8];
    float2 stretch;
    char _m12_pad[8];
    float alpha;
    char _m13_pad[12];
    float hardness;
    char _m14_pad[12];
    int blendMode;
};

struct refAM35_e81af622a8da9_out
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
float2 rotate(thread const float2& toRotate, thread const float& rad)
{
    return float2((toRotate.x * cos(rad)) - (toRotate.y * sin(rad)), (toRotate.y * cos(rad)) + (toRotate.x * sin(rad)));
}

static inline __attribute__((always_inline))
float drawSin(thread const float2& uv, constant ReferenceUniformse81af622a8da9& _122)
{
    return powr(1.10000002384185791015625 - sqrt(distance(uv, float2(uv.x, ((0.300000011920928955078125 * sin((uv.x * 10.0) - _122.PROGRESS)) * uv.x) + 0.25))), 6.0);
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse81af622a8da9& _122, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_122.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _122.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_122.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _122.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_122.refScreen.x, _122.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _122.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _122.refScreen.xy).y) * _122.refScreen.xy) - float2(_122.refLayer.x + (_122.refLayer.z * 0.5), (_122.refScreen.y - _122.refLayer.y) - (_122.refLayer.w * 0.5))) / _122.refLayer.zw;
            syamjaidtz.y *= (_122.refLayer.w / _122.refLayer.z);
            syamjaidtz /= float2(_122.scale);
            float param_3 = (0.0 + _122.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2((-400.0) + _122.position.x, 100.0 - _122.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_122.scale * (1.39999997615814208984375 + _122.stretch.x), _122.scale * (0.75 + _122.stretch.y));
            syamjaidtz /= scaleVec;
            float2 uv = syamjaidtz;
            float2 strand1uv = uv;
            float2 param_4 = uv;
            float param_5 = 0.5;
            float2 strand2uv = rotate(param_4, param_5) + float2(0.119999997317790985107421875, 0.0500000007450580596923828125);
            float2 param_6 = uv;
            float param_7 = -0.5;
            float2 strand3uv = (rotate(param_6, param_7) * 0.800000011920928955078125) + float2(0.0, 0.00999999977648258209228515625);
            float2 param_8 = uv;
            float param_9 = 0.300000011920928955078125;
            float2 strand4uv = (rotate(param_8, param_9) * 0.5) + float2(0.0, 0.100000001490116119384765625);
            float2 param_10 = uv;
            float param_11 = -0.20000000298023223876953125;
            float2 strand5uv = (rotate(param_10, param_11) * 1.10000002384185791015625) - float2(0.0, 0.100000001490116119384765625);
            float4 fragColor = _122.color1;
            float3 blue = _122.color2.xyz;
            float2 param_12 = strand1uv;
            float val = drawSin(param_12, _122);
            fragColor += (float4(float3(val), 1.0) * 0.64999997615814208984375);
            float2 param_13 = strand2uv;
            val = drawSin(param_13, _122);
            fragColor += (float4(float3(val), 1.0) * 0.64999997615814208984375);
            float2 param_14 = strand3uv;
            val = drawSin(param_14, _122);
            fragColor += (float4(float3(val), 1.0) * 0.64999997615814208984375);
            float2 param_15 = strand4uv;
            val = drawSin(param_15, _122);
            fragColor += (float4(float3(val), 1.0) * 0.64999997615814208984375);
            float2 param_16 = strand5uv;
            val = drawSin(param_16, _122);
            fragColor += (float4(float3(val), 1.0) * 0.64999997615814208984375);
            fragColor *= (1.0 - (exp(uv.x) / 2.71828174591064453125));
            float4 _434 = fragColor;
            float3 _436 = _434.xyz * blue;
            fragColor.x = _436.x;
            fragColor.y = _436.y;
            fragColor.z = _436.z;
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal;
            if (_122.blendMode == 0)
            {
                resultfinal = (factor * _122.hardness) * texColor.w;
            }
            else
            {
                if (_122.blendMode == 1)
                {
                    factor *= _122.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_122.blendMode == 2)
                    {
                        factor *= _122.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_122.blendMode == 3)
                        {
                            factor *= _122.hardness;
                            float4 param_17 = texColor;
                            float4 param_18 = factor;
                            resultfinal = (newLayer(param_17, param_18) * _122.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_122.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e81af622a8da9_out refAM35_e81af622a8da9(constant ReferenceUniformse81af622a8da9& _122 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e81af622a8da9_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_122, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _567 = any(isnan(referenceColor));
    bool _574;
    if (!_567)
    {
        _574 = any(isinf(referenceColor));
    }
    else
    {
        _574 = _567;
    }
    if (_574)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _587 = referenceColor;
    float3 _593 = fast::clamp(_587.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _593.x;
    referenceColor.y = _593.y;
    referenceColor.z = _593.z;
    out.finalColor = referenceColor;
    return out;
}

