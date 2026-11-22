// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxssmallringswater.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//////////////////////////
/////////////////////////
// maybe plug in ddx and ddy here to mimic mip-mapping (avoid artifacts at long distances)
// float expansionSpeed = 4.0;
// float rainSpeed = 0.6;
// float numRings = 3.0;
// const float numIterations = 4.0;
// float strength = 0.3;
// other numbers:
// uv = (2.*fragCoord.xy - iResolution.xy) / iResolution.y;
// Variables:
/// Creating ringMap:
//float ringMap = sharpness*9.*distance(uv, randVec(0.)*0.);
// Rings and result
// resultfinal = (newLayer(texColor, factor) * hardness) * texColor.a; }
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse7264ea0961dc
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float numIterations;
    char _m6_pad[12];
    uint autop;
    char _m7_pad[12];
    float PROGRESS;
    char _m8_pad[12];
    float rainSpeed;
    char _m9_pad[12];
    float sharpnessx;
    char _m10_pad[12];
    float expansionSpeed;
    char _m11_pad[12];
    float numRings;
    char _m12_pad[12];
    float strength;
    char _m13_pad[12];
    float scale;
    char _m14_pad[12];
    float angle;
    char _m15_pad[8];
    float2 position;
    char _m16_pad[8];
    float2 stretch;
    char _m17_pad[8];
    float alpha;
    char _m18_pad[12];
    float hardness;
    char _m19_pad[12];
    int blendMode;
};

struct refAM35_e7264ea0961dc_out
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
float randFloat(thread const float2& inVal)
{
    return fract(sin(dot(float2(inVal.x, inVal.y), float2(89.45159912109375, 35.51599884033203125))) * 13554.365234375);
}

static inline __attribute__((always_inline))
float2 randVec(thread const float& inVal)
{
    return float2(fract(sin(dot(float2(inVal * 1.10000002384185791015625, 2352.75048828125), float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875) - 0.5, fract(sin(dot(float2(715.23516845703125, inVal), float2(27.2311000823974609375, 31.6509990692138671875))) * 65161.65234375) - 0.5);
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse7264ea0961dc& _132, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_132.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _132.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_132.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _132.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_132.refScreen.x, _132.refScreen.y);
            float2 iMouse = float2(0.5);
            float iTime = _132.refScreen.z;
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _132.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _132.refScreen.xy).y) * _132.refScreen.xy) - float2(_132.refLayer.x + (_132.refLayer.z * 0.5), (_132.refScreen.y - _132.refLayer.y) - (_132.refLayer.w * 0.5))) / _132.refLayer.zw;
            syamjaidtz.y *= (_132.refLayer.w / _132.refLayer.z);
            syamjaidtz /= float2(_132.scale);
            float param_3 = (0.0 + _132.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _132.position.x, 0.0 - _132.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_132.scale * _132.stretch.x, _132.scale * _132.stretch.y);
            syamjaidtz /= scaleVec;
            float _304;
            if (_132.autop != 0u)
            {
                _304 = sin(_132.PROGRESS + (iTime * 0.5));
            }
            else
            {
                _304 = sin(_132.PROGRESS * 0.100000001490116119384765625);
            }
            float zoom = _304;
            zoom = 0.89999997615814208984375 + powr(((iMouse.x + iMouse.y) / iResolution.x) * 1.0, 3.0);
            float sharpness = _132.sharpnessx * zoom;
            float _344;
            if (_132.autop != 0u)
            {
                _344 = _132.PROGRESS + (iTime * _132.rainSpeed);
            }
            else
            {
                _344 = _132.PROGRESS * _132.rainSpeed;
            }
            float newTime = _344;
            float4 fragColor = float4(0.0);
            for (float iterations = 0.0; iterations < _132.numIterations; iterations += 1.0)
            {
                for (float xpos = -1.0; xpos <= 1.0; xpos += 1.0)
                {
                    for (float ypos = -1.0; ypos <= 1.0; ypos += 1.0)
                    {
                        float2 uv = syamjaidtz;
                        uv /= float2(zoom);
                        uv += (float2(3.21000003814697265625, 2.5610001087188720703125) * iterations);
                        uv += float2(xpos * 0.33329999446868896484375, ypos * 0.33329999446868896484375);
                        float2 uvStep = ceil((uv * 1.0) - float2(0.5)) / float2(1.0);
                        uvStep += (float2(xpos, ypos) * 100.0);
                        uv = float2(fract(uv.x + 0.5) - 0.5, fract(uv.y + 0.5) - 0.5);
                        float2 param_4 = uvStep;
                        float timeRand = randFloat(param_4);
                        float timeLoop = fract(newTime + timeRand);
                        float timeIter = floor(newTime + timeRand);
                        float param_5 = (timeIter + uvStep.x) + uvStep.y;
                        float ringMap = (sharpness * 9.0) * distance(uv, randVec(param_5) * 0.5);
                        float clampMinimum = -(1.0 + ((_132.numRings - 1.0) * 2.0));
                        ringMap = fast::clamp((ringMap - ((_132.expansionSpeed * sharpness) * timeLoop)) + 1.0, clampMinimum, 1.0);
                        float rings = (cos((ringMap + newTime) * 3.1415920257568359375) + 1.0) / 2.0;
                        rings *= powr(1.0 - timeLoop, 2.0);
                        float bigRing = sin(((ringMap - clampMinimum) / (1.0 - clampMinimum)) * 3.1415920257568359375);
                        float result = rings * bigRing;
                        fragColor += (float4(result) * _132.strength);
                    }
                }
            }
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal;
            if (_132.blendMode == 0)
            {
                resultfinal = (factor * _132.hardness) * texColor.w;
            }
            else
            {
                if (_132.blendMode == 1)
                {
                    factor *= _132.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_132.blendMode == 2)
                    {
                        factor *= _132.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_132.blendMode == 3)
                        {
                            factor *= _132.hardness;
                            float4 param_6 = texColor;
                            float4 param_7 = factor;
                            resultfinal = (newLayer(param_6, param_7) * _132.hardness) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_132.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e7264ea0961dc_out refAM35_e7264ea0961dc(constant ReferenceUniformse7264ea0961dc& _132 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e7264ea0961dc_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_132, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _654 = any(isnan(referenceColor));
    bool _661;
    if (!_654)
    {
        _661 = any(isinf(referenceColor));
    }
    else
    {
        _661 = _654;
    }
    if (_661)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _674 = referenceColor;
    float3 _680 = fast::clamp(_674.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _680.x;
    referenceColor.y = _680.y;
    referenceColor.z = _680.z;
    out.finalColor = referenceColor;
    return out;
}

