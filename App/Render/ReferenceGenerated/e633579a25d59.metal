// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/internal-border-center.xml
// Original source comments and attribution:
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
// Final pass
//if( direction == -1 ) {
//    vec4 c = mix(b0color,  vec4(0.0), smoothstep(1.0-1.5/b0size,1.0,nearestInside/(b0size/MULTISAMPLE))) * original.a;
//    result = c + result*(1.0-c.a);
//} else if (direction == 0) {
//} else if (direction == 1) {
//    vec4 c = mix(b0color,  vec4(0.0), smoothstep(1.0-1.5/b0size,1.0,nearestOutside/(b0size/MULTISAMPLE))) * (1.-original.a);
//    result = result + c*(1.0-result.a);
//}
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse633579a25d59
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float b0size;
    float4 b0color;
};

struct refAM35_e633579a25d59_out
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
void referenceMain(constant ReferenceUniformse633579a25d59& _71, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
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
        float nearestOutside = 16383.0;
        float nearestInside = 16383.0;
        float _168;
        float _183;
        for (int i = from; i < to; i++)
        {
            float x = float(i);
            float2 param_1 = float2((gl_FragCoord.xy / _71.refScreen.xy).x + (x * (px / 1.0)), (gl_FragCoord.xy / _71.refScreen.xy).y);
            float4 ref_sample = texture2DCv(refInput, refInputSmplr, param_1);
            if (ref_sample.w > 0.0)
            {
                _168 = abs(x);
            }
            else
            {
                _168 = radius * 2.0;
            }
            float xdistOut = _168;
            if (ref_sample.w < 0.0030000000260770320892333984375)
            {
                _183 = abs(x);
            }
            else
            {
                _183 = radius * 2.0;
            }
            float xdistIn = _183;
            nearestOutside = fast::min(nearestOutside, xdistOut);
            nearestInside = fast::min(nearestInside, xdistIn);
        }
        float param_2 = nearestOutside / 16383.0;
        float param_3 = nearestInside / 16383.0;
        referenceColor = float4(encodeFloat(param_2), encodeFloat(param_3));
    }
    else
    {
        float nearestOutside_1 = 16383.0;
        float nearestInside_1 = 16383.0;
        for (int i_1 = from; i_1 < to; i_1++)
        {
            float y = float(i_1);
            float2 param_4 = float2((gl_FragCoord.xy / _71.refScreen.xy).x, (gl_FragCoord.xy / _71.refScreen.xy).y + (y * (py / 1.0)));
            float4 ref_sample_1 = texture2DCv(refBuffer1, refBuffer1Smplr, param_4);
            float2 param_5 = ref_sample_1.xy;
            float xdistOut_1 = decodeFloat(param_5) * 16383.0;
            float2 param_6 = ref_sample_1.zw;
            float xdistIn_1 = decodeFloat(param_6) * 16383.0;
            float ydist = abs(y);
            float distOut = length(float2(xdistOut_1, ydist));
            float distIn = length(float2(xdistIn_1, ydist));
            nearestInside_1 = fast::min(nearestInside_1, distIn);
            nearestOutside_1 = fast::min(nearestOutside_1, distOut);
        }
        float nearestMid = fast::max(nearestInside_1, nearestOutside_1);
        float2 param_7 = gl_FragCoord.xy / _71.refScreen.xy;
        float4 original = texture2DCv(refInput, refInputSmplr, param_7);
        float4 result = original;
        if (_71.b0size > 0.0030000000260770320892333984375)
        {
            float4 c = mix(_71.b0color, float4(0.0), float4(smoothstep(1.0 - (1.5 / _71.b0size), 1.0, nearestMid / (_71.b0size / 1.0))));
            result = c + (result * (1.0 - c.w));
        }
        referenceColor = result;
    }
}

fragment refAM35_e633579a25d59_out refAM35_e633579a25d59(constant ReferenceUniformse633579a25d59& _71 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e633579a25d59_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_71, refInput, refInputSmplr, gl_FragCoord, referenceColor, refBuffer1, refBuffer1Smplr);
    bool _338 = any(isnan(referenceColor));
    bool _345;
    if (!_338)
    {
        _345 = any(isinf(referenceColor));
    }
    else
    {
        _345 = _338;
    }
    if (_345)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _359 = referenceColor;
    float3 _365 = fast::clamp(_359.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _365.x;
    referenceColor.y = _365.y;
    referenceColor.z = _365.z;
    out.finalColor = referenceColor;
    return out;
}

