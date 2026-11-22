// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxglitchvhs.xml
// Original source comments and attribution:
/////////////////////////
//remaps inteval [a;b] to [0;1]
//note: /\ t=[0;0.5;1], y=[0;1;0]
/*
    	vec3 ret;
    	float lo = step(t,0.5);
    	float hi = 1.0-lo;
    	float w = linterp( remap( t, 1.0/6.0, 5.0/6.0 ) );
    	float neg_w = 1.0-w;
    	ret = vec3(lo,1.0,hi) * vec3(neg_w, w, neg_w);
    	return pow( ret, vec3(1.0/2.2) );
    */
//note: [0;1]
//note: [-1;1]
/////////////////////////
// + modelmat[0].x + modelmat[0].z;
// float rdist = length( (uv - vec2(0.5,0.5))*vec2(aspect, 1.0) )/1.4;
// GLITCH *= rdist;
//horz
// float r1 = 1.0f - sat( (1.0f-gnm)*0.5f + rnd1 );
//note: weird ass bug on old drivers
//vert
// const int NUM_SAMPLES = 10;
// const float RCP_NUM_SAMPLES_F = 1.0 / float(NUM_SAMPLES);
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformse834231f5b840
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float progressa;
    char _m6_pad[12];
    float AMOUNT;
    char _m7_pad[12];
    float alpha;
};

struct refAM35_e834231f5b840_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float sat(thread const float& t)
{
    return fast::clamp(t, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float2 mytrunc(thread const float2& x, thread const float& num_levels)
{
    return floor(x * num_levels) / float2(num_levels);
}

static inline __attribute__((always_inline))
float rand(thread const float2& n)
{
    return fract(sin(dot(n, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float mytrunc(thread const float& x, thread const float& num_levels)
{
    return floor(x * num_levels) / num_levels;
}

static inline __attribute__((always_inline))
float3 spectrum_offset(thread const float& t)
{
    float t0 = (3.0 * t) - 1.5;
    return fast::clamp(float3(-t0, 1.0 - abs(t0), t0), float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse834231f5b840& _111, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _111.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = gl_FragCoord.xy / _111.refScreen.xy;
    float aspect = _111.refScreen.x / _111.refScreen.y;
    float2 uv = syamjaidtz;
    float time = mod(_111.progressa, 32.0);
    float GLITCH = 0.100000001490116119384765625 + (0.0 / syamjaidtz.x);
    float param_1 = GLITCH;
    float gnm = sat(param_1);
    float2 param_2 = float2(time);
    float param_3 = 6.0;
    float2 param_4 = mytrunc(param_2, param_3);
    float rnd0 = rand(param_4);
    float param_5 = ((1.0 - gnm) * 0.699999988079071044921875) + rnd0;
    float r0 = sat(param_5);
    float param_6 = uv.x;
    float param_7 = 10.0 * r0;
    float2 param_8 = float2(mytrunc(param_6, param_7), time);
    float rnd1 = rand(param_8);
    float r1 = (0.5 - (0.5 * gnm)) + rnd1;
    r1 = 1.0 - fast::max(0.0, (r1 < 1.0) ? r1 : 0.99999988079071044921875);
    float param_9 = uv.y;
    float param_10 = 40.0 * r1;
    float2 param_11 = float2(mytrunc(param_9, param_10), time);
    float rnd2 = rand(param_11);
    float param_12 = rnd2;
    float r2 = sat(param_12);
    float param_13 = uv.y;
    float param_14 = 10.0 * r0;
    float2 param_15 = float2(mytrunc(param_13, param_14), time);
    float rnd3 = rand(param_15);
    float param_16 = rnd3 + 0.800000011920928955078125;
    float r3 = (1.0 - sat(param_16)) - 0.100000001490116119384765625;
    float2 param_17 = uv + float2(time);
    float pxrnd = rand(param_17);
    float ofs = ((0.0500000007450580596923828125 * r2) * GLITCH) * ((rnd0 > 0.5) ? 1.0 : (-1.0));
    ofs += ((0.5 * pxrnd) * ofs);
    uv.y += ((0.100000001490116119384765625 * r3) * GLITCH);
    float RCP_NUM_SAMPLES_F = 1.0 / _111.AMOUNT;
    float4 sum = float4(0.0);
    float3 wsum = float3(0.0);
    for (int i = 0; i < int(_111.AMOUNT); i++)
    {
        float t = float(i) * RCP_NUM_SAMPLES_F;
        float param_18 = uv.x + (ofs * t);
        uv.x = sat(param_18);
        float2 param_19 = uv;
        float4 samplecol = texture2DCv(refInput, refInputSmplr, param_19);
        float param_20 = t;
        float3 s = spectrum_offset(param_20);
        float4 _321 = samplecol;
        float3 _324 = _321.xyz * s;
        samplecol.x = _324.x;
        samplecol.y = _324.y;
        samplecol.z = _324.z;
        sum += samplecol;
        wsum += s;
    }
    float4 _342 = sum;
    float3 _344 = _342.xyz / wsum;
    sum.x = _344.x;
    sum.y = _344.y;
    sum.z = _344.z;
    sum.w *= RCP_NUM_SAMPLES_F;
    float4 result;
    result.w = sum.w;
    result.x = sum.xyz.x;
    result.y = sum.xyz.y;
    result.z = sum.xyz.z;
    float4 factor = mix(texColorX, result, float4(1.0));
    float4 resultfinal = (factor * 1.0) * texColor.w;
    referenceColor = mix(texColor, resultfinal, float4(_111.alpha));
}

fragment refAM35_e834231f5b840_out refAM35_e834231f5b840(constant ReferenceUniformse834231f5b840& _111 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e834231f5b840_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _111, referenceColor);
    bool _392 = any(isnan(referenceColor));
    bool _399;
    if (!_392)
    {
        _399 = any(isinf(referenceColor));
    }
    else
    {
        _399 = _392;
    }
    if (_399)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _412 = referenceColor;
    float3 _418 = fast::clamp(_412.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _418.x;
    referenceColor.y = _418.y;
    referenceColor.z = _418.z;
    out.finalColor = referenceColor;
    return out;
}

