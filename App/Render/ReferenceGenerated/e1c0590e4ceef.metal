// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/internal-border-outside.xml
// Original source comments and attribution:
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
//float nearestInside = MAX_RADIUS;
//float xdistIn = sample.a < 0.003 ? abs(x) : radius*2.0;
//nearestInside = min(nearestInside,xdistIn);
// Final pass
//float nearestInside = MAX_RADIUS;
//float xdistIn = decodeFloat(sample.ba) * MAX_RADIUS;
//float distIn = length(vec2(xdistIn,ydist));
//nearestInside = min(nearestInside,distIn);
//float nearestMid = max(nearestInside, nearestOutside);
//if( direction == -1 ) {
//    vec4 c = mix(b0color,  vec4(0.0), smoothstep(1.0-1.5/b0size,1.0,nearestInside/(b0size/MULTISAMPLE))) * original.a;
//    result = c + result*(1.0-c.a);
//} else if (direction == 0) {
//    vec4 c = mix(b0color, vec4(0.0), smoothstep(1.0-1.5/b0size,1.0,nearestMid/(b0size/MULTISAMPLE)));;
//    result = c + result*(1.0-c.a);
//} else if (direction == 1) {
//}
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse1c0590e4ceef
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float b0size;
    float4 b0color;
};

struct refAM35_e1c0590e4ceef_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 encodeFloat(thread const float& v)
{
    float2 enc = fract(float2(1.0, 255.0) * v);
    enc.x -= (enc.y / 255.0);
    return enc;
}

static inline __attribute__((always_inline))
float decodeFloat(thread const float2& v)
{
    return dot(v, float2(1.0, 0.0039215688593685626983642578125));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse1c0590e4ceef& _71, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float radius = _71.b0size * 1.0;
    int from = -max(1, int(radius));
    int to = max(1, int(radius));
    int incr = clamp(abs(to - from) / 30, 1, 3);
    float px = 0.00048828125;
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 fullViewSize = getTexSize(param);
    float py = 1.0 / (2048.0 / (fullViewSize.x / fullViewSize.y));
    if (as_type<int>(_71.refComposition.z) == 0)
    {
        float nearestOutside = 16383.0;
        float _176;
        for (int i = from; i < to; i += incr)
        {
            float x = float(i);
            float2 param_1 = float2((gl_FragCoord.xy / _71.refScreen.xy).x + (x * (px / 1.0)), (gl_FragCoord.xy / _71.refScreen.xy).y);
            float4 ref_sample = texture2DCv(refInput, refInputSmplr, param_1);
            if (ref_sample.w > 0.0)
            {
                _176 = abs(x);
            }
            else
            {
                _176 = radius * 2.0;
            }
            float xdistOut = _176;
            nearestOutside = fast::min(nearestOutside, xdistOut);
        }
        float param_2 = nearestOutside / 16383.0;
        referenceColor = float4(encodeFloat(param_2), 0.0, 0.0);
    }
    else
    {
        float nearestOutside_1 = 16383.0;
        for (int i_1 = from; i_1 < to; i_1 += incr)
        {
            float y = float(i_1);
            float2 param_3 = float2((gl_FragCoord.xy / _71.refScreen.xy).x, (gl_FragCoord.xy / _71.refScreen.xy).y + (y * (py / 1.0)));
            float4 ref_sample_1 = texture2DCv(refBuffer1, refBuffer1Smplr, param_3);
            float2 param_4 = ref_sample_1.xy;
            float xdistOut_1 = decodeFloat(param_4) * 16383.0;
            float ydist = abs(y);
            float distOut = length(float2(xdistOut_1, ydist));
            nearestOutside_1 = fast::min(nearestOutside_1, distOut);
        }
        float2 param_5 = gl_FragCoord.xy / _71.refScreen.xy;
        float4 original = texture2DCv(refInput, refInputSmplr, param_5);
        float4 result = original;
        if (_71.b0size > 0.0030000000260770320892333984375)
        {
            float4 c = mix(_71.b0color, float4(0.0), float4(smoothstep(1.0 - (1.5 / _71.b0size), 1.0, nearestOutside_1 / (_71.b0size / 1.0)))) * (1.0 - original.w);
            result += (c * (1.0 - result.w));
        }
        referenceColor = result;
    }
}

fragment refAM35_e1c0590e4ceef_out refAM35_e1c0590e4ceef(constant ReferenceUniformse1c0590e4ceef& _71 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e1c0590e4ceef_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_71, refInput, refInputSmplr, gl_FragCoord, referenceColor, refBuffer1, refBuffer1Smplr);
    bool _311 = any(isnan(referenceColor));
    bool _318;
    if (!_311)
    {
        _318 = any(isinf(referenceColor));
    }
    else
    {
        _318 = _311;
    }
    if (_318)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _332 = referenceColor;
    float3 _338 = fast::clamp(_332.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _338.x;
    referenceColor.y = _338.y;
    referenceColor.z = _338.z;
    out.finalColor = referenceColor;
    return out;
}

