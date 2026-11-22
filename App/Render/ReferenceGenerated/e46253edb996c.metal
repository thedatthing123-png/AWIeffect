// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/clouds3d.xml
// Original source comments and attribution:
// Adapted from https://www.shadertoy.com/view/4sXGRM
// Uses AfterMotion seascape-style parameters and conventions only
// AfterMotion patch: use acScreenNorm and acScreenSize for coordinates
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse46253edb996c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint nmode;
    char _m6_pad[12];
    float camprog;
    char _m7_pad[12];
    float camx;
    char _m8_pad[12];
    float camy;
    char _m9_pad[12];
    float progressa;
    char _m10_pad[12];
    float CLOUD_HEIGHT;
    char _m11_pad[12];
    float CLOUD_DENSITY;
    char _m12_pad[12];
    float CLOUD_FREQ;
    float4 CLOUD_BASE;
    float4 CLOUD_COLOR;
    float4 CSKY;
    float4 SKYCOLOR;
    float NUM_STEPS;
    char _m18_pad[12];
    float ITER_FRAGMENT;
    char _m19_pad[12];
    float scale;
    char _m20_pad[12];
    float progressc;
    char _m21_pad[12];
    float alpha;
    char _m22_pad[12];
    uint adaptive;
};

struct refAM35_e46253edb996c_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash(thread const float& n)
{
    return fract(cos(n) * 114514.1953125);
}

static inline __attribute__((always_inline))
float _noise(thread const float3& x)
{
    float3 p = floor(x);
    float3 f = smoothstep(float3(0.0), float3(1.0), fract(x));
    float n = (p.x + (p.y * 10.0)) + (p.z * 100.0);
    float param = n + 0.0;
    float param_1 = n + 1.0;
    float param_2 = n + 10.0;
    float param_3 = n + 11.0;
    float param_4 = n + 100.0;
    float param_5 = n + 101.0;
    float param_6 = n + 110.0;
    float param_7 = n + 111.0;
    return mix(mix(mix(hash(param), hash(param_1), f.x), mix(hash(param_2), hash(param_3), f.x), f.y), mix(mix(hash(param_4), hash(param_5), f.x), mix(hash(param_6), hash(param_7), f.x), f.y), f.z);
}

static inline __attribute__((always_inline))
float fbm(thread float3& p)
{
    float3 param = p;
    float f = 0.5 * _noise(param);
    p = float3x3(float3(0.0, 1.60000002384185791015625, 1.2000000476837158203125), float3(-1.60000002384185791015625, 0.7200000286102294921875, -0.959999978542327880859375), float3(-1.2000000476837158203125, -0.959999978542327880859375, 1.2799999713897705078125)) * p;
    float3 param_1 = p;
    f += (0.25 * _noise(param_1));
    p = float3x3(float3(0.0, 1.60000002384185791015625, 1.2000000476837158203125), float3(-1.60000002384185791015625, 0.7200000286102294921875, -0.959999978542327880859375), float3(-1.2000000476837158203125, -0.959999978542327880859375, 1.2799999713897705078125)) * p;
    float3 param_2 = p;
    f += (0.16660000383853912353515625 * _noise(param_2));
    p = float3x3(float3(0.0, 1.60000002384185791015625, 1.2000000476837158203125), float3(-1.60000002384185791015625, 0.7200000286102294921875, -0.959999978542327880859375), float3(-1.2000000476837158203125, -0.959999978542327880859375, 1.2799999713897705078125)) * p;
    float3 param_3 = p;
    f += (0.083400003612041473388671875 * _noise(param_3));
    return f;
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse46253edb996c& _176, thread float4& referenceColor)
{
    float2 uv = ((gl_FragCoord.xy / _176.refScreen.xy) * 2.0) - float2(1.0);
    uv.x *= (_176.refScreen.x / _176.refScreen.y);
    float t = ((_176.progressa + 13.5) + 44.0) * 1.0;
    float3 campos = float3(5000.0 * sin((1.0 * t) + _176.camx), 5000.0 + (1500.0 * sin((0.5 * t) + _176.camy)), (6000.0 * t) + _176.camprog);
    float3 camtar = float3(5000.0 * sin((1.0 * (t + 0.4000000059604644775390625)) + _176.camx), 5000.0 + (1500.0 * sin((0.5 * (t + 0.4000000059604644775390625)) + _176.camy)), (6000.0 * (t + 0.4000000059604644775390625)) + _176.camprog);
    float3 front = fast::normalize(camtar - campos);
    float3 right = fast::normalize(cross(front, float3(0.0, 1.0, 0.0)));
    float3 up = fast::normalize(cross(right, front));
    float3 fragAt = fast::normalize(((right * uv.x) + (up * uv.y)) + front);
    float4 sum = float4(0.0);
    for (float depth = 0.0; depth < 100000.0; depth += 200.0)
    {
        float3 ray = campos + (fragAt * depth);
        bool _310 = 0.0 < ray.y;
        bool _317;
        if (_310)
        {
            _317 = ray.y < 10000.0;
        }
        else
        {
            _317 = _310;
        }
        if (_317)
        {
            float3 param = (ray * 0.00025000001187436282634735107421875) * _176.CLOUD_DENSITY;
            float _329 = fbm(param);
            float a = smoothstep(0.5, 1.0, _329);
            float3 localcolor = mix(float3(1.10000002384185791015625, 1.0499999523162841796875, 1.0), float3(0.300000011920928955078125, 0.300000011920928955078125, 0.20000000298023223876953125), float3(a));
            a = (1.0 - sum.w) * a;
            sum += float4(localcolor * a, a);
        }
    }
    float a_1 = smoothstep(0.699999988079071044921875, 1.0, sum.w);
    float _366 = sum.w;
    float4 _369 = sum;
    float3 _372 = _369.xyz / float3(_366 + 9.9999997473787516355514526367188e-05);
    sum.x = _372.x;
    sum.y = _372.y;
    sum.z = _372.z;
    float sundot = fast::clamp(dot(fragAt, float3(0.10644926130771636962890625, 0.2661231458187103271484375, 0.9580433368682861328125)), 0.0, 1.0);
    float3 col = _176.SKYCOLOR.xyz * 0.800000011920928955078125;
    col += (float3(0.75199997425079345703125, 0.65799999237060546875, 0.4699999988079071044921875) * powr(sundot, 350.0));
    col += (float3(0.319999992847442626953125, 0.36000001430511474609375, 0.4000000059604644775390625) * powr(sundot, 2.0));
    float4 _422 = sum;
    float3 _424 = _422.xyz - ((float3(0.4799999892711639404296875, 0.449999988079071044921875, 0.4199999868869781494140625) * powr(sundot, 13.0)) * a_1);
    sum.x = _424.x;
    sum.y = _424.y;
    sum.z = _424.z;
    float4 _441 = sum;
    float3 _443 = _441.xyz + ((float3(0.2599999904632568359375, 0.23999999463558197021484375, 0.20000000298023223876953125) * powr(sundot, 5.0)) * (1.0 - a_1));
    sum.x = _443.x;
    sum.y = _443.y;
    sum.z = _443.z;
    col = mix(col, sum.xyz, float3(sum.w));
    if (_176.nmode != 0u)
    {
        col *= 0.20000000298023223876953125;
    }
    referenceColor = float4(col, _176.alpha);
}

fragment refAM35_e46253edb996c_out refAM35_e46253edb996c(constant ReferenceUniformse46253edb996c& _176 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e46253edb996c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _176, referenceColor);
    bool _480 = any(isnan(referenceColor));
    bool _487;
    if (!_480)
    {
        _487 = any(isinf(referenceColor));
    }
    else
    {
        _487 = _480;
    }
    if (_487)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _500 = referenceColor;
    float3 _506 = fast::clamp(_500.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _506.x;
    referenceColor.y = _506.y;
    referenceColor.z = _506.z;
    out.finalColor = referenceColor;
    return out;
}

