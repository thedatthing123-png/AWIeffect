// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/metalballs.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse4dc1ec616108
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float ballCount;
    char _m6_pad[12];
    float ballRadius;
    char _m7_pad[12];
    float spread;
    char _m8_pad[12];
    float zSpread;
    float4 ballColor;
    float progress;
    char _m11_pad[12];
    uint randomSize;
    char _m12_pad[12];
    float sizeVar;
    char _m13_pad[12];
    float randSeed;
    char _m14_pad[12];
    float posX;
    char _m15_pad[12];
    float posY;
    char _m16_pad[12];
    float posZ;
    char _m17_pad[12];
    float ior;
    char _m18_pad[12];
    float shininess;
    char _m19_pad[12];
    float reflectMix;
    char _m20_pad[12];
    float refractScale;
    char _m21_pad[12];
    float reflectScale;
    char _m22_pad[12];
    float fov;
    char _m23_pad[12];
    float lightX;
    char _m24_pad[12];
    float lightY;
    char _m25_pad[12];
    float lightZ;
};

struct refAM35_e4dc1ec616108_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float2 getResolution(texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 s = getTexSize(param);
    bool _66 = s.x <= 0.0;
    bool _74;
    if (!_66)
    {
        _74 = s.y <= 0.0;
    }
    else
    {
        _74 = _66;
    }
    if (_74)
    {
        s = float2(1920.0, 1080.0);
    }
    return s;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 hash2(thread const float& n)
{
    return fract(sin(float2(n, n + 1.0)) * 43758.546875);
}

static inline __attribute__((always_inline))
float intersectSphere(thread const float3& ro, thread const float3& rd, thread const float3& center, thread const float& radius)
{
    float3 oc = ro - center;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - (radius * radius);
    float h = (b * b) - c;
    if (h < 0.0)
    {
        return -1.0;
    }
    return (-b) - sqrt(h);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse4dc1ec616108& _139, thread float4& referenceColor)
{
    float2 res = getResolution(refInput, refInputSmplr);
    float2 fragCoord = (gl_FragCoord.xy / _139.refScreen.xy) * res;
    float2 uv = gl_FragCoord.xy / _139.refScreen.xy;
    float2 p = (fragCoord - (res * 0.5)) / float2(res.y);
    float3 ro = float3(0.0, 0.0, -2.0);
    float3 rd = fast::normalize(float3(p, _139.fov));
    float3 lightPos = fast::normalize(float3(_139.lightX, _139.lightY, _139.lightZ));
    float2 param = uv;
    float4 sourcePixel = texture2DCv(refInput, refInputSmplr, param);
    float coverage = sourcePixel.w;
    float3 col = sourcePixel.xyz / float3(fast::max(sourcePixel.w, 9.9999997473787516355514526367188e-06));
    float minT = 10000.0;
    float3 hitCenter = float3(0.0);
    int maxBalls = int(_139.ballCount);
    float aspect = res.x / res.y;
    for (int i = 0; i < 400; i++)
    {
        if (i >= maxBalls)
        {
            break;
        }
        float param_1 = (float(i) * 56.700000762939453125) + _139.randSeed;
        float2 rnd = hash2(param_1);
        float t_anim = (_139.progress * 20.0) + (float(i) * 12.0);
        float3 center = float3(0.0);
        center.x = ((sin(t_anim + (rnd.x * 6.283185482025146484375)) * 0.800000011920928955078125) * aspect) * _139.spread;
        center.y = (cos((t_anim * 0.89999997615814208984375) + (rnd.y * 6.283185482025146484375)) * 0.4000000059604644775390625) * _139.spread;
        center.z = sin(t_anim * 0.5) * _139.zSpread;
        center += float3(_139.posX, _139.posY, _139.posZ);
        float rVar = 1.0;
        if (_139.randomSize != 0u)
        {
            rVar = 1.0 + (((rnd.x * 2.0) - 1.0) * _139.sizeVar);
        }
        float rBall = fast::clamp(_139.ballRadius * rVar, 0.001000000047497451305389404296875, 10.0);
        float3 param_2 = ro;
        float3 param_3 = rd;
        float3 param_4 = center;
        float param_5 = rBall;
        float t = intersectSphere(param_2, param_3, param_4, param_5);
        if ((t > 0.0) && (t < minT))
        {
            minT = t;
            hitCenter = center;
        }
    }
    if (minT < 10000.0)
    {
        float3 pos = ro + (rd * minT);
        float3 normal = fast::normalize(pos - hitCenter);
        float3 viewDir = -rd;
        float cosTheta = fast::clamp(dot(normal, viewDir), 0.0, 1.0);
        float fresnel = powr(1.0 - cosTheta, 4.0);
        float reflStrength = (0.100000001490116119384765625 + (0.89999997615814208984375 * fresnel)) * _139.reflectMix;
        float3 refrVec = refract(rd, normal, 1.0 / _139.ior);
        float2 refrUV = uv + (refrVec.xy * _139.refractScale);
        float2 param_6 = refrUV;
        float3 glassColor = texture2DCv(refInput, refInputSmplr, param_6).xyz;
        float3 absorb = _139.ballColor.xyz * (0.5 + (0.5 * cosTheta));
        glassColor *= (absorb * 1.5);
        float3 reflVec = reflect(rd, normal);
        float2 reflUV = uv + (reflVec.xy * _139.reflectScale);
        float2 param_7 = reflUV;
        float3 reflColor = texture2DCv(refInput, refInputSmplr, param_7).xyz;
        float3 halfVec = fast::normalize(lightPos + viewDir);
        float spec = powr(fast::max(dot(normal, halfVec), 0.0), _139.shininess);
        float3 sphereCol = mix(glassColor, reflColor, float3(reflStrength));
        sphereCol += (float3(1.0) * spec);
        sphereCol += ((float3(1.0, 0.20000000298023223876953125, 0.20000000298023223876953125) * fresnel) * 0.300000011920928955078125);
        coverage = _139.ballColor.w + (sourcePixel.w * (1.0 - _139.ballColor.w));
        col = ((sphereCol * _139.ballColor.w) + (sourcePixel.xyz * (1.0 - _139.ballColor.w))) / float3(fast::max(coverage, 9.9999997473787516355514526367188e-06));
    }
    referenceColor = float4(col * coverage, coverage);
}

fragment refAM35_e4dc1ec616108_out refAM35_e4dc1ec616108(constant ReferenceUniformse4dc1ec616108& _139 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e4dc1ec616108_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _139, referenceColor);
    bool _525 = any(isnan(referenceColor));
    bool _532;
    if (!_525)
    {
        _532 = any(isinf(referenceColor));
    }
    else
    {
        _532 = _525;
    }
    if (_532)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _545 = referenceColor;
    float3 _551 = fast::clamp(_545.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _551.x;
    referenceColor.y = _551.y;
    referenceColor.z = _551.z;
    out.finalColor = referenceColor;
    return out;
}

