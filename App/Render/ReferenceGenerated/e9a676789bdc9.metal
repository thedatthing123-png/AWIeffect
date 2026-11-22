// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxrgbglitch.xml
// Original source comments and attribution:
/////////////////////////
// return 1 if v inside 1d range
//inputs
// float AMT = progressb; //0 - 1 glitch amount
// float SPEED = 0.6; //0 - 1 speed
// vec4 texColor = texture2DCv(inputImg.texture,acScreenNorm);
// syamjaidtz *= rot2m(angle*0.0174533);
// syamjaidtz += position*vec2(-1.,1.)/500.;
/////////////////////////
//copy orig
//randomly offset slices horizontally
//do slight offset on one entire channel
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9a676789bdc9
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progressd;
    char _m6_pad[12];
    float progressb;
    char _m7_pad[12];
    float progressa;
    char _m8_pad[12];
    float progressc;
};

struct refAM35_e9a676789bdc9_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse9a676789bdc9& _55)
{
    return (float4(v, 0.0, 1.0) * _55.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float random2d(thread const float2& n)
{
    return fract(sin(dot(n, float2(12.98980045318603515625, 4.141399860382080078125))) * 43758.546875);
}

static inline __attribute__((always_inline))
float randomRange(thread const float2& seed, thread const float& _min, thread const float& _max)
{
    float2 param = seed;
    return _min + (random2d(param) * (_max - _min));
}

static inline __attribute__((always_inline))
float insideRange(thread const float& v, thread const float& bottom, thread const float& top)
{
    return step(bottom, v) - step(top, v);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse9a676789bdc9& _55, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (_55.progressb <= 0.0)
    {
        float2 param = gl_FragCoord.xy / _55.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (_55.progressb >= 9.9999997473787516355514526367188e-05)
        {
            float2 syamjaidtz = (gl_FragCoord.xy - _55.refLayer.xy) / _55.refLayer.zw;
            syamjaidtz -= float2(0.5);
            syamjaidtz += float2(0.5);
            syamjaidtz.x *= (_55.refLayer.z / _55.refLayer.w);
            syamjaidtz.x /= (_55.refLayer.z / _55.refLayer.w);
            syamjaidtz /= float2(1.0);
            float2 param_1 = syamjaidtz;
            float2 sampleCoord = l2s(param_1, _55);
            float2 param_2 = sampleCoord;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_2);
            float time = floor((_55.progressa * 0.60000002384185791015625) * 60.0);
            float2 uv = sampleCoord;
            float2 param_3 = uv;
            float3 outCol = texture2DCv(refInput, refInputSmplr, param_3).xyz;
            float maxOffset = _55.progressb / 2.0;
            for (float i = 0.0; i < (10.0 * _55.progressb); i += 1.0)
            {
                float2 param_4 = float2(time, 2345.0 + i);
                float sliceY = random2d(param_4);
                float2 param_5 = float2(time, 9035.0 + i);
                float sliceH = random2d(param_5) * _55.progressd;
                float2 param_6 = float2(time, 9625.0 + i);
                float param_7 = -maxOffset;
                float param_8 = maxOffset;
                float hOffset = randomRange(param_6, param_7, param_8);
                float2 uvOff = uv;
                uvOff.x += hOffset;
                float param_9 = uv.y;
                float param_10 = sliceY;
                float param_11 = fract(sliceY + sliceH);
                if (insideRange(param_9, param_10, param_11) == 1.0)
                {
                    float2 param_12 = uvOff;
                    outCol = texture2DCv(refInput, refInputSmplr, param_12).xyz;
                }
            }
            float maxColOffset = _55.progressc / 6.0;
            float2 param_13 = float2(time, 9545.0);
            float rnd = random2d(param_13);
            float2 param_14 = float2(time, 9545.0);
            float param_15 = -maxColOffset;
            float param_16 = maxColOffset;
            float2 param_17 = float2(time, 7205.0);
            float param_18 = -maxColOffset;
            float param_19 = maxColOffset;
            float2 colOffset = float2(randomRange(param_14, param_15, param_16), randomRange(param_17, param_18, param_19));
            if (rnd < 0.3300000131130218505859375)
            {
                float2 param_20 = uv + colOffset;
                outCol.x = texture2DCv(refInput, refInputSmplr, param_20).x;
            }
            else
            {
                if (rnd < 0.660000026226043701171875)
                {
                    float2 param_21 = uv + colOffset;
                    outCol.y = texture2DCv(refInput, refInputSmplr, param_21).y;
                }
                else
                {
                    float2 param_22 = uv + colOffset;
                    outCol.z = texture2DCv(refInput, refInputSmplr, param_22).z;
                }
            }
            float4 result = float4(outCol, 1.0);
            float4 factor = result * texColor.w;
            referenceColor = mix(texColor, factor, float4(1.0));
        }
    }
}

fragment refAM35_e9a676789bdc9_out refAM35_e9a676789bdc9(constant ReferenceUniformse9a676789bdc9& _55 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9a676789bdc9_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_55, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _361 = any(isnan(referenceColor));
    bool _368;
    if (!_361)
    {
        _368 = any(isinf(referenceColor));
    }
    else
    {
        _368 = _361;
    }
    if (_368)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _381 = referenceColor;
    float3 _387 = fast::clamp(_381.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _387.x;
    referenceColor.y = _387.y;
    referenceColor.z = _387.z;
    out.finalColor = referenceColor;
    return out;
}

