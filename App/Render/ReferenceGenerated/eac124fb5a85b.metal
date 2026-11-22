// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/dots2.xml
// Original source comments and attribution:
//float rand(vec2 co)
//{
//    float a = 719.310;
//    float b = 178.233;
//    float c = 33758.5453;
//    float dt= dot(co.xy ,vec2(a,b));
//    float sn= mod(dt,3.14);
//    return fract(sin(sn) * c);
//}
//
//float rand_alt(vec2 co)
//{
//    float a = 317.541;
//    float b = 142.123;
//    float c = 31758.5362;
//    float dt= dot(co.xy ,vec2(a,b));
//    float sn= mod(dt,3.14);
//    return fract(sin(sn) * c);
//}
//
//vec2 rand2v(vec2 co) {
//    return vec2(rand(co),rand_alt(co));
//}
// Based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
// Four corners in 2D of a tile
// Initial values
//
// Loop of octaves
//intensity *= random(nearestTile + vec2(nearest_k,-nearest_k) + vec2(541.117,163.713)*seed) > threshold ? 0.0 : 1.0;
//gl_FragColor = result+(over*(1.0-result.a));
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseac124fb5a85b
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float scale;
    char _m6_pad[12];
    float phase;
    char _m7_pad[12];
    float radius;
    char _m8_pad[12];
    float feather;
    float4 color;
    float4 color2;
    float density;
    char _m12_pad[8];
    float2 position;
    char _m13_pad[8];
    float fill;
    char _m14_pad[12];
    float alpha;
    char _m15_pad[12];
    int blendMode;
    char _m16_pad[12];
    float seed;
    char _m17_pad[12];
    float slack;
};

struct refAM35_eac124fb5a85b_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float random(thread const float2& st)
{
    return fract(sin(dot(st, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& st)
{
    float2 i = floor(st);
    float2 f = fract(st);
    float2 param = i;
    float a = random(param);
    float2 param_1 = i + float2(1.0, 0.0);
    float b = random(param_1);
    float2 param_2 = i + float2(0.0, 1.0);
    float c = random(param_2);
    float2 param_3 = i + float2(1.0);
    float d = random(param_3);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    return (mix(a, b, u.x) + (((c - a) * u.y) * (1.0 - u.x))) + (((d - b) * u.x) * u.y);
}

static inline __attribute__((always_inline))
float2 rand2v(thread const float2& co)
{
    float2 param = co;
    float2 param_1 = co + float2(613.31201171875, 736.01898193359375);
    return float2(_noise(param), _noise(param_1));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformseac124fb5a85b& _144, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _144.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _144.refLayer.xy) / _144.refLayer.zw;
    st.x *= (_144.refLayer.z / _144.refLayer.w);
    st -= float2(0.5);
    st -= ((_144.position * float2(1.0, -1.0)) / float2(1000.0));
    st /= float2(_144.scale * 0.070000000298023223876953125);
    float2 tile = floor(st);
    float2 tpart = fract(st);
    float maxDist = 100.0;
    float2 nearestTile = float2(0.0);
    float nearest_k = 0.0;
    int densitySteps = int(fast::max(1.0, _144.density - 10.0));
    float threshold = fast::min(1.0, _144.density / 11.0);
    float actualPhase = _144.phase * 6.28318023681640625;
    for (int i = -1; i <= 1; i++)
    {
        for (int j = -1; j <= 1; j++)
        {
            float2 checkTileOffs = float2(float(i), float(j));
            for (int k = 0; k < densitySteps; k++)
            {
                float2 param_1 = ((tile + (float2(523.135009765625, 621.2650146484375) * float(k))) + checkTileOffs) + (float2(123.214996337890625, 272.05499267578125) * _144.seed);
                float2 p = rand2v(param_1);
                p = float2(0.5) + ((sin(float2(actualPhase) + (p * 6.283100128173828125)) * 0.5) * fast::max(9.9999997473787516355514526367188e-06, _144.slack));
                float dist = length((checkTileOffs + p) - tpart);
                float2 tileId = checkTileOffs + tile;
                float flk = float(k);
                float2 param_2 = (tileId + float2(flk, -flk)) + (float2(541.11700439453125, 163.7129974365234375) * (_144.seed + 0.100000001490116119384765625));
                float ck = random(param_2);
                if ((dist < maxDist) && (ck <= threshold))
                {
                    maxDist = dist;
                    nearest_k = float(k);
                    nearestTile = tileId;
                }
            }
        }
    }
    float2 param_3 = (nearestTile + float2(nearest_k, -nearest_k)) + (float2(721.11700439453125, 433.214996337890625) * _144.seed);
    float colorPct = random(param_3);
    float intensity = smoothstep(1.0 - _144.radius, 1.0 - (_144.radius * (1.0 - _144.feather)), 1.0 - maxDist);
    float4 over = texColor * _144.fill;
    float4 rcolor = (mix(_144.color, _144.color2, float4(colorPct)) * intensity) * texColor.w;
    float4 result;
    if (_144.blendMode == 1)
    {
        result = (float4((texColor.xyz / float3(texColor.w)) * (rcolor.xyz / float3(rcolor.w)), 1.0) * rcolor.w) * texColor.w;
        result = fast::clamp(result, float4(0.0), float4(1.0));
        result += (over * (1.0 - result.w));
        result = fast::clamp(result, float4(0.0), float4(1.0));
    }
    else
    {
        if (_144.blendMode == 2)
        {
            result = (float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - (rcolor.xyz / float3(rcolor.w)))), 1.0) * rcolor.w) * texColor.w;
            result = fast::clamp(result, float4(0.0), float4(1.0));
            result += (over * (1.0 - result.w));
            result = fast::clamp(result, float4(0.0), float4(1.0));
        }
        else
        {
            result = rcolor + (over * (1.0 - rcolor.w));
        }
    }
    referenceColor = mix(over, result, float4(_144.alpha));
}

fragment refAM35_eac124fb5a85b_out refAM35_eac124fb5a85b(constant ReferenceUniformseac124fb5a85b& _144 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eac124fb5a85b_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _144, referenceColor);
    bool _527 = any(isnan(referenceColor));
    bool _534;
    if (!_527)
    {
        _534 = any(isinf(referenceColor));
    }
    else
    {
        _534 = _527;
    }
    if (_534)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _547 = referenceColor;
    float3 _553 = fast::clamp(_547.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _553.x;
    referenceColor.y = _553.y;
    referenceColor.z = _553.z;
    out.finalColor = referenceColor;
    return out;
}

