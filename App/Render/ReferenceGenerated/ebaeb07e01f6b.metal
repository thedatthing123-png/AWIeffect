// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsmoothbevelnew.xml
// Original source comments and attribution:
//float radius=max(max(innerBorderSize,outerBorderSize),centerBorderSize)*MULTISAMPLE;
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
// float as = angle.y * 0.0174533;
// float ad = angle.x * 0.0174533;
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

struct ReferenceUniformsebaeb07e01f6b
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float radius;
    char _m6_pad[12];
    float angle_d;
    char _m7_pad[12];
    float angle_s;
    char _m8_pad[8];
    float2 intensity;
    char _m9_pad[8];
    float2 elevation;
    char _m10_pad[8];
    float spec;
    float4 color_d;
    float4 color_s;
    float iter;
};

struct refAM35_ebaeb07e01f6b_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformsebaeb07e01f6b& _82, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 imgSize = getTexSize(param);
    float radius2 = (_82.radius * length(imgSize)) / 1448.1546630859375;
    int from = -max(1, int(radius2));
    int to = max(1, int(radius2));
    float px = 1.0 / imgSize.x;
    float py = 1.0 / imgSize.y;
    if (as_type<int>(_82.refComposition.z) == 0)
    {
        float nearestLeft = 16383.0;
        float nearestRight = 16383.0;
        float _168;
        for (int i = from; i < 0; i++)
        {
            float x = float(i);
            float2 param_1 = float2((gl_FragCoord.xy / _82.refScreen.xy).x + (x * (px / 1.0)), (gl_FragCoord.xy / _82.refScreen.xy).y);
            float4 ref_sample = texture2DCv(refInput, refInputSmplr, param_1);
            if (ref_sample.w < 0.0030000000260770320892333984375)
            {
                _168 = abs(x);
            }
            else
            {
                _168 = radius2 * 2.0;
            }
            float dist = _168;
            nearestLeft = fast::min(nearestLeft, dist);
        }
        float _222;
        for (int i_1 = 0; i_1 < to; i_1++)
        {
            float x_1 = float(i_1);
            float2 param_2 = float2((gl_FragCoord.xy / _82.refScreen.xy).x + (x_1 * (px / 1.0)), (gl_FragCoord.xy / _82.refScreen.xy).y);
            float4 ref_sample_1 = texture2DCv(refInput, refInputSmplr, param_2);
            if (ref_sample_1.w < 0.0030000000260770320892333984375)
            {
                _222 = abs(x_1);
            }
            else
            {
                _222 = radius2 * 2.0;
            }
            float dist_1 = _222;
            nearestRight = fast::min(nearestRight, dist_1);
        }
        float param_3 = nearestLeft / 16383.0;
        float param_4 = nearestRight / 16383.0;
        referenceColor = float4(encodeFloat(param_3), encodeFloat(param_4));
    }
    else
    {
        float as = _82.angle_s * 0.01745329983532428741455078125;
        float ad = _82.angle_d * 0.01745329983532428741455078125;
        float3 light_s = float3(cos(as), -sin(as), -_82.elevation.y);
        float3 light_d = float3(cos(ad), -sin(ad), -_82.elevation.x);
        float nearestTopLeft = 16383.0;
        float nearestTopRight = 16383.0;
        float nearestBottomLeft = 16383.0;
        float nearestBottomRight = 16383.0;
        for (int i_2 = from; i_2 < 0; i_2++)
        {
            float y = float(i_2);
            float2 param_5 = float2((gl_FragCoord.xy / _82.refScreen.xy).x, (gl_FragCoord.xy / _82.refScreen.xy).y + (y * (py / 1.0)));
            float4 ref_sample_2 = texture2DCv(refBuffer1, refBuffer1Smplr, param_5);
            float2 param_6 = ref_sample_2.xy;
            float nearestLeft_1 = decodeFloat(param_6) * 16383.0;
            float2 param_7 = ref_sample_2.zw;
            float nearestRight_1 = decodeFloat(param_7) * 16383.0;
            float ydist = abs(y);
            float ldist = length(float2(nearestLeft_1, ydist));
            float rdist = length(float2(nearestRight_1, ydist));
            nearestBottomLeft = fast::min(nearestBottomLeft, ldist);
            nearestBottomRight = fast::min(nearestBottomRight, rdist);
        }
        for (int i_3 = 0; i_3 < to; i_3++)
        {
            float y_1 = float(i_3);
            float2 param_8 = float2((gl_FragCoord.xy / _82.refScreen.xy).x, (gl_FragCoord.xy / _82.refScreen.xy).y + (y_1 * (py / 1.0)));
            float4 ref_sample_3 = texture2DCv(refBuffer1, refBuffer1Smplr, param_8);
            float2 param_9 = ref_sample_3.xy;
            float nearestLeft_2 = decodeFloat(param_9) * 16383.0;
            float2 param_10 = ref_sample_3.zw;
            float nearestRight_2 = decodeFloat(param_10) * 16383.0;
            float ydist_1 = abs(y_1);
            float ldist_1 = length(float2(nearestLeft_2, ydist_1));
            float rdist_1 = length(float2(nearestRight_2, ydist_1));
            nearestTopLeft = fast::min(nearestTopLeft, ldist_1);
            nearestTopRight = fast::min(nearestTopRight, rdist_1);
        }
        float nearestInside = nearestTopRight;
        float2 param_11 = gl_FragCoord.xy / _82.refScreen.xy;
        float4 original = texture2DCv(refInput, refInputSmplr, param_11);
        nearestTopLeft = smoothstep(0.0, 1.0, nearestTopLeft / (radius2 / 1.0));
        nearestTopRight = smoothstep(0.0, 1.0, nearestTopRight / (radius2 / 1.0));
        nearestBottomLeft = smoothstep(0.0, 1.0, nearestBottomLeft / (radius2 / 1.0));
        nearestBottomRight = smoothstep(0.0, 1.0, nearestBottomRight / (radius2 / 1.0));
        float3 bl = float3(-1.0) * nearestBottomLeft;
        float3 br = float3(1.0, -1.0, -1.0) * nearestBottomRight;
        float3 tl = float3(-1.0, 1.0, -1.0) * nearestTopLeft;
        float3 tr = float3(1.0, 1.0, -1.0) * nearestTopRight;
        float3 v = (((bl + br) + tl) + tr) / float3(4.0);
        float lum_s = powr(dot(fast::normalize(v), fast::normalize(light_s)), _82.spec);
        float lum_d = dot(fast::normalize(v), fast::normalize(light_d));
        float4 lit_color_s = ((_82.color_s * lum_s) * _82.intensity.y) * original.w;
        float4 lit_color_d = ((_82.color_d * lum_d) * _82.intensity.x) * original.w;
        float4 result = original;
        result = lit_color_d + (result * (1.0 - lit_color_d.w));
        result = lit_color_s + (result * (1.0 - lit_color_s.w));
        referenceColor = result;
    }
}

fragment refAM35_ebaeb07e01f6b_out refAM35_ebaeb07e01f6b(constant ReferenceUniformsebaeb07e01f6b& _82 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ebaeb07e01f6b_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _82, gl_FragCoord, referenceColor, refBuffer1, refBuffer1Smplr);
    bool _550 = any(isnan(referenceColor));
    bool _557;
    if (!_550)
    {
        _557 = any(isinf(referenceColor));
    }
    else
    {
        _557 = _550;
    }
    if (_557)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _570 = referenceColor;
    float3 _576 = fast::clamp(_570.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _576.x;
    referenceColor.y = _576.y;
    referenceColor.z = _576.z;
    out.finalColor = referenceColor;
    return out;
}

