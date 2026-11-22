// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsraindropsfloor.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
// #define MAX_RADIUS 2
// #define RANSIZE 0.7
// #define RAINSPEED 0.3
//////////////////////////
/////////////////////////
// circles += 0.5 * normalize(v) * ((p2 - p1) / (2.0 * h) * (1.0 - t) * (1.0 - t));
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse8302ca417075
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint autop;
    char _m6_pad[12];
    float MAX_RADIUS;
    char _m7_pad[12];
    float PROGRESS;
    char _m8_pad[12];
    float RAINSPEED;
    char _m9_pad[12];
    float RANSIZE;
    char _m10_pad[8];
    float2 position;
    char _m11_pad[8];
    float2 stretch;
    char _m12_pad[8];
    float alpha;
};

struct refAM35_e8302ca417075_out
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
float2 hash22(thread const float2& p)
{
    float3 p3 = fract(p.xyx * float3(0.103100001811981201171875, 0.10300000011920928955078125, 0.097300000488758087158203125));
    p3 += float3(dot(p3, p3.yzx + float3(19.1900005340576171875)));
    return fract((p3.xx + p3.yz) * p3.zy);
}

static inline __attribute__((always_inline))
float hash12(thread const float2& p)
{
    float3 p3 = fract(p.xyx * 0.103100001811981201171875);
    p3 += float3(dot(p3, p3.yzx + float3(19.1900005340576171875)));
    return fract((p3.x + p3.y) * p3.z);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse8302ca417075& _104, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_104.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _104.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_104.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _104.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_104.refScreen.x, _104.refScreen.y);
            float2 iMouse = float2(0.5);
            float _179;
            if (_104.autop != 0u)
            {
                _179 = _104.PROGRESS + (_104.refScreen.z * 0.5);
            }
            else
            {
                _179 = _104.PROGRESS;
            }
            float iTime = _179;
            float resolution = 10.0 * exp2((-3.0) * _104.RANSIZE);
            float2 uv = (gl_FragCoord.xy / _104.refScreen.xy) * resolution;
            uv += ((float2(0.0 + _104.position.x, 0.0 + _104.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(1.0 * _104.stretch.x, 1.0 * _104.stretch.y);
            uv /= scaleVec;
            float2 uv2 = (gl_FragCoord.xy / _104.refScreen.xy) * resolution;
            float2 p0 = floor(uv);
            float2 circles = float2(0.0);
            int _259 = -int(_104.MAX_RADIUS);
            for (int j = _259; j <= int(_104.MAX_RADIUS); j++)
            {
                int _274 = -int(_104.MAX_RADIUS);
                for (int i = _274; i <= int(_104.MAX_RADIUS); i++)
                {
                    float2 pi = p0 + float2(float(i), float(j));
                    float2 hsh = pi;
                    float2 param_3 = hsh;
                    float2 p = pi + hash22(param_3);
                    float2 param_4 = hsh;
                    float t = fract((_104.RAINSPEED * iTime) + hash12(param_4));
                    float2 v = p - uv;
                    float d = length(v) - ((_104.MAX_RADIUS + 1.0) * t);
                    float h = 0.001000000047497451305389404296875;
                    float d1 = d - h;
                    float d2 = d + h;
                    float p1 = (sin(31.0 * d1) * smoothstep(-0.60000002384185791015625, -0.300000011920928955078125, d1)) * smoothstep(0.0, -0.300000011920928955078125, d1);
                    float p2 = (sin(31.0 * d2) * smoothstep(-0.60000002384185791015625, -0.300000011920928955078125, d2)) * smoothstep(0.0, -0.300000011920928955078125, d2);
                    circles += ((fast::normalize(v) * _104.alpha) * ((((p2 - p1) / (2.0 * h)) * (1.0 - t)) * (1.0 - t)));
                }
            }
            circles /= float2(float(((int(_104.MAX_RADIUS) * 2) + 1) * ((int(_104.MAX_RADIUS) * 2) + 1)));
            float intensity = mix(0.00999999977648258209228515625, 0.1500000059604644775390625, smoothstep(0.100000001490116119384765625, 0.60000002384185791015625, abs((fract((0.0500000007450580596923828125 * iTime) + 0.5) * 2.0) - 1.0)));
            float3 n = float3(circles, sqrt(1.0 - dot(circles, circles)));
            float2 param_5 = (uv2 / float2(resolution)) - (n.xy * intensity);
            float3 color = texture2DCv(refInput, refInputSmplr, param_5).xyz + float3(5.0 * powr(fast::clamp(dot(n, float3(0.758098065853118896484375, 0.53066861629486083984375, 0.3790490329265594482421875)), 0.0, 1.0), 6.0));
            float4 fragColor = float4(color, 1.0);
            referenceColor = mix(texColor, fragColor, float4(1.0)) * texColor.w;
        }
    }
}

fragment refAM35_e8302ca417075_out refAM35_e8302ca417075(constant ReferenceUniformse8302ca417075& _104 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e8302ca417075_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_104, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _468 = any(isnan(referenceColor));
    bool _475;
    if (!_468)
    {
        _475 = any(isinf(referenceColor));
    }
    else
    {
        _475 = _468;
    }
    if (_475)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _488 = referenceColor;
    float3 _494 = fast::clamp(_488.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _494.x;
    referenceColor.y = _494.y;
    referenceColor.z = _494.z;
    out.finalColor = referenceColor;
    return out;
}

