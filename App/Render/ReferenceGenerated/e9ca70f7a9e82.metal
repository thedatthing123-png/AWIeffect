// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/internal-border-inside.xml
// Original source comments and attribution:
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
//float nearestOutside = MAX_RADIUS;
//float xdistOut = sample.a > 0.0 ? abs(x) : radius*2.0;
//nearestOutside = min(nearestOutside,xdistOut);
// Final pass
//float nearestOutside = MAX_RADIUS;
//float xdistOut = decodeFloat(sample.rg) * MAX_RADIUS;
//float distOut = length(vec2(xdistOut,ydist));
//nearestOutside = min(nearestOutside,distOut);
//float nearestMid = max(nearestInside, nearestOutside);
//if( direction == -1 ) {
//} else if (direction == 0) {
//    vec4 c = mix(b0color, vec4(0.0), smoothstep(1.0-1.5/b0size,1.0,nearestMid/(b0size/MULTISAMPLE)));;
//    result = c + result*(1.0-c.a);
//} else if (direction == 1) {
//    vec4 c = mix(b0color,  vec4(0.0), smoothstep(1.0-1.5/b0size,1.0,nearestOutside/(b0size/MULTISAMPLE))) * (1.-original.a);
//    result = result + c*(1.0-result.a);
//}
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9ca70f7a9e82
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float b0size;
    float4 b0color;
};

struct refAM35_e9ca70f7a9e82_out
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
void referenceMain(constant ReferenceUniformse9ca70f7a9e82& _71, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float radius = _71.b0size * 1.0;
    int from = -max(1, int(radius));
    int to = max(1, int(radius));
    float px = 0.00048828125;
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 fullViewSize = getTexSize(param);
    float py = 1.0 / (2048.0 / (fullViewSize.x / fullViewSize.y));
    if (as_type<int>(_71.refComposition.z) == 0)
    {
        float nearestInside = 16383.0;
        float _167;
        for (int i = from; i < to; i++)
        {
            float x = float(i);
            float2 param_1 = float2((gl_FragCoord.xy / _71.refScreen.xy).x + (x * (px / 1.0)), (gl_FragCoord.xy / _71.refScreen.xy).y);
            float4 ref_sample = texture2DCv(refInput, refInputSmplr, param_1);
            if (ref_sample.w < 0.0030000000260770320892333984375)
            {
                _167 = abs(x);
            }
            else
            {
                _167 = radius * 2.0;
            }
            float xdistIn = _167;
            nearestInside = fast::min(nearestInside, xdistIn);
        }
        float param_2 = nearestInside / 16383.0;
        referenceColor = float4(0.0, 0.0, encodeFloat(param_2));
    }
    else
    {
        float nearestInside_1 = 16383.0;
        for (int i_1 = from; i_1 < to; i_1++)
        {
            float y = float(i_1);
            float2 param_3 = float2((gl_FragCoord.xy / _71.refScreen.xy).x, (gl_FragCoord.xy / _71.refScreen.xy).y + (y * (py / 1.0)));
            float4 ref_sample_1 = texture2DCv(refBuffer1, refBuffer1Smplr, param_3);
            float2 param_4 = ref_sample_1.zw;
            float xdistIn_1 = decodeFloat(param_4) * 16383.0;
            float ydist = abs(y);
            float distIn = length(float2(xdistIn_1, ydist));
            nearestInside_1 = fast::min(nearestInside_1, distIn);
        }
        float2 param_5 = gl_FragCoord.xy / _71.refScreen.xy;
        float4 original = texture2DCv(refInput, refInputSmplr, param_5);
        float4 result = original;
        if (_71.b0size > 0.0030000000260770320892333984375)
        {
            float4 c = mix(_71.b0color, float4(0.0), float4(smoothstep(1.0 - (1.5 / _71.b0size), 1.0, nearestInside_1 / (_71.b0size / 1.0)))) * original.w;
            result = c + (result * (1.0 - c.w));
        }
        referenceColor = result;
    }
}

fragment refAM35_e9ca70f7a9e82_out refAM35_e9ca70f7a9e82(constant ReferenceUniformse9ca70f7a9e82& _71 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9ca70f7a9e82_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_71, refInput, refInputSmplr, gl_FragCoord, referenceColor, refBuffer1, refBuffer1Smplr);
    bool _299 = any(isnan(referenceColor));
    bool _306;
    if (!_299)
    {
        _306 = any(isinf(referenceColor));
    }
    else
    {
        _306 = _299;
    }
    if (_306)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _320 = referenceColor;
    float3 _326 = fast::clamp(_320.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _326.x;
    referenceColor.y = _326.y;
    referenceColor.z = _326.z;
    out.finalColor = referenceColor;
    return out;
}

