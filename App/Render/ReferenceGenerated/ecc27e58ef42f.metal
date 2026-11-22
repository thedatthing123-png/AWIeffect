// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/glass2.xml
// Original source comments and attribution:
//float radius=max(max(innerBorderSize,outerBorderSize),centerBorderSize)*MULTISAMPLE;
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
// Final pass
// / (radius2/MULTISAMPLE);
//vec4 innerBorderColor = vec4(1.0,0.5,0.0,1.0);
//vec4 inColor = radius2<0.003 ? vec4(0.0)  : mix(innerBorderColor,  vec4(0.0), smoothstep(1.0-1.5/radius2,1.0,nearestInside/(radius2/MULTISAMPLE))) * original.a;
//vec4 inColor = vec4(nearestTopLeft/(radius2/MULTISAMPLE), nearestTopRight/(radius2/MULTISAMPLE), nearestBottomLeft/(radius2/MULTISAMPLE), 1.0 );
//vec4 inColor = vec4(vec2(0.5,0.5)+v, 0.5, 1.0 )*original.a;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsecc27e58ef42f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float radius;
    char _m6_pad[12];
    float angle;
    char _m7_pad[12];
    float elevation;
    char _m8_pad[12];
    float intensity;
    float4 color_d;
    float4 color_s;
    float _refract;
    char _m12_pad[12];
    float shine;
    char _m13_pad[12];
    float spec;
    char _m14_pad[12];
    float fill;
};

struct refAM35_ecc27e58ef42f_out
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
void referenceMain(constant ReferenceUniformsecc27e58ef42f& _71, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float angle_d = _71.angle;
    float angle_s = _71.angle;
    float elevation_d = _71.elevation;
    float elevation_s = _71.elevation;
    float intensity_d = _71.intensity * (1.0 - _71.shine);
    float intensity_s = _71.intensity * _71.shine;
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float radius2 = (_71.radius * length(getTexSize(param))) / 1448.1546630859375;
    int from = -max(1, int(radius2));
    int to = max(1, int(radius2));
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 imgSize = getTexSize(param_1);
    float px = 1.0 / imgSize.x;
    float py = 1.0 / imgSize.y;
    if (as_type<int>(_71.refComposition.z) == 0)
    {
        float nearestLeft = 16383.0;
        float nearestRight = 16383.0;
        float _202;
        for (int i = from; i < 0; i++)
        {
            float x = float(i);
            float2 param_2 = float2((gl_FragCoord.xy / _71.refScreen.xy).x + (x * (px / 1.0)), (gl_FragCoord.xy / _71.refScreen.xy).y);
            float4 ref_sample = texture2DCv(refInput, refInputSmplr, param_2);
            if (ref_sample.w < 0.0030000000260770320892333984375)
            {
                _202 = abs(x);
            }
            else
            {
                _202 = radius2 * 2.0;
            }
            float dist = _202;
            nearestLeft = fast::min(nearestLeft, dist);
        }
        float _256;
        for (int i_1 = 0; i_1 < to; i_1++)
        {
            float x_1 = float(i_1);
            float2 param_3 = float2((gl_FragCoord.xy / _71.refScreen.xy).x + (x_1 * (px / 1.0)), (gl_FragCoord.xy / _71.refScreen.xy).y);
            float4 ref_sample_1 = texture2DCv(refInput, refInputSmplr, param_3);
            if (ref_sample_1.w < 0.0030000000260770320892333984375)
            {
                _256 = abs(x_1);
            }
            else
            {
                _256 = radius2 * 2.0;
            }
            float dist_1 = _256;
            nearestRight = fast::min(nearestRight, dist_1);
        }
        float param_4 = nearestLeft / 16383.0;
        float param_5 = nearestRight / 16383.0;
        referenceColor = float4(encodeFloat(param_4), encodeFloat(param_5));
    }
    else
    {
        float as = angle_s * 0.01745329983532428741455078125;
        float ad = angle_d * 0.01745329983532428741455078125;
        float3 light_s = float3(cos(as), -sin(as), -elevation_s);
        float3 light_d = float3(cos(ad), -sin(ad), -elevation_d);
        float nearestTopLeft = 16383.0;
        float nearestTopRight = 16383.0;
        float nearestBottomLeft = 16383.0;
        float nearestBottomRight = 16383.0;
        for (int i_2 = from; i_2 < 0; i_2++)
        {
            float y = float(i_2);
            float2 param_6 = float2((gl_FragCoord.xy / _71.refScreen.xy).x, (gl_FragCoord.xy / _71.refScreen.xy).y + (y * (py / 1.0)));
            float4 ref_sample_2 = texture2DCv(refBuffer1, refBuffer1Smplr, param_6);
            float2 param_7 = ref_sample_2.xy;
            float nearestLeft_1 = decodeFloat(param_7) * 16383.0;
            float2 param_8 = ref_sample_2.zw;
            float nearestRight_1 = decodeFloat(param_8) * 16383.0;
            float ydist = abs(y);
            float ldist = length(float2(nearestLeft_1, ydist));
            float rdist = length(float2(nearestRight_1, ydist));
            nearestBottomLeft = fast::min(nearestBottomLeft, ldist);
            nearestBottomRight = fast::min(nearestBottomRight, rdist);
        }
        for (int i_3 = 0; i_3 < to; i_3++)
        {
            float y_1 = float(i_3);
            float2 param_9 = float2((gl_FragCoord.xy / _71.refScreen.xy).x, (gl_FragCoord.xy / _71.refScreen.xy).y + (y_1 * (py / 1.0)));
            float4 ref_sample_3 = texture2DCv(refBuffer1, refBuffer1Smplr, param_9);
            float2 param_10 = ref_sample_3.xy;
            float nearestLeft_2 = decodeFloat(param_10) * 16383.0;
            float2 param_11 = ref_sample_3.zw;
            float nearestRight_2 = decodeFloat(param_11) * 16383.0;
            float ydist_1 = abs(y_1);
            float ldist_1 = length(float2(nearestLeft_2, ydist_1));
            float rdist_1 = length(float2(nearestRight_2, ydist_1));
            nearestTopLeft = fast::min(nearestTopLeft, ldist_1);
            nearestTopRight = fast::min(nearestTopRight, rdist_1);
        }
        float nearestInside = nearestTopRight;
        float2 param_12 = gl_FragCoord.xy / _71.refScreen.xy;
        float4 original = texture2DCv(refInput, refInputSmplr, param_12);
        nearestTopLeft = smoothstep(0.0, 1.0, nearestTopLeft / (radius2 / 1.0));
        nearestTopRight = smoothstep(0.0, 1.0, nearestTopRight / (radius2 / 1.0));
        nearestBottomLeft = smoothstep(0.0, 1.0, nearestBottomLeft / (radius2 / 1.0));
        nearestBottomRight = smoothstep(0.0, 1.0, nearestBottomRight / (radius2 / 1.0));
        float3 v = ((((float3(-1.0) * nearestBottomLeft) + (float3(1.0, -1.0, -1.0) * nearestBottomRight)) + (float3(-1.0, 1.0, -1.0) * nearestTopLeft)) + (float3(1.0, 1.0, -1.0) * nearestTopRight)) / float3(4.0);
        float2 param_13 = (gl_FragCoord.xy / _71.refScreen.xy) + (v.xy * _71._refract);
        float4 refractColor = texture2DCv(refReference, refReferenceSmplr, param_13);
        float lum_s = powr(dot(fast::normalize(v), fast::normalize(light_s)), _71.spec);
        float lum_d = dot(fast::normalize(v), fast::normalize(light_d));
        float4 lit_color_s = ((_71.color_s * lum_s) * intensity_s) * original.w;
        float4 lit_color_d = ((_71.color_d * lum_d) * intensity_d) * original.w;
        float4 over_a = original * _71.fill;
        float4 result = refractColor * original.w;
        result = over_a + (result * (1.0 - over_a.w));
        result = lit_color_d + (result * (1.0 - lit_color_d.w));
        result = lit_color_s + (result * (1.0 - lit_color_s.w));
        referenceColor = result;
    }
}

fragment refAM35_ecc27e58ef42f_out refAM35_ecc27e58ef42f(constant ReferenceUniformsecc27e58ef42f& _71 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refReference [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refReferenceSmplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_ecc27e58ef42f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_71, refInput, refInputSmplr, gl_FragCoord, referenceColor, refBuffer1, refBuffer1Smplr, refReference, refReferenceSmplr);
    bool _599 = any(isnan(referenceColor));
    bool _606;
    if (!_599)
    {
        _606 = any(isinf(referenceColor));
    }
    else
    {
        _606 = _599;
    }
    if (_606)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _619 = referenceColor;
    float3 _625 = fast::clamp(_619.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _625.x;
    referenceColor.y = _625.y;
    referenceColor.z = _625.z;
    out.finalColor = referenceColor;
    return out;
}

