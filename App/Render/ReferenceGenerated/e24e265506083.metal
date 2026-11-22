// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxfrostednew.xml
// Original source comments and attribution:
/////////////////////////
// vec2 myPatternx(in vec2 uvx){
// vec2 uv2x = uvx;
// uv2x.x = uv2x.x + 0.1 * (random2(uvx));
// return uv2x - uvx;
// }
// vec2 myPatterny(in vec2 uvy){
// vec2 uv2y = uvy;
// uv2y.y = uv2y.y + 0.1 * (random2(uvy));
// return uv2y - uvy;
// }
/////////////////////////
// vec4 texColorX = vec4(0.0,0.0,0.0,1.0) * texColor.a;
// vec2 xxx;
// xxx = acScreenNorm; 
// xxx += vec2((-25.0), (0.0))*vec2(-1.,1.)/500.;
// vec2 yyy;
// yyy = acScreenNorm; 
// yyy += vec2((0.0), (25.0))*vec2(-1.,1.)/500.;
/////////////////////////
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse24e265506083
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int type;
    char _m6_pad[12];
    float iter;
    char _m7_pad[12];
    float alpha;
};

struct refAM35_e24e265506083_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float random2(thread const float2& st)
{
    return fract(sin(dot(st, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 myPattern(thread const float2& uv, constant ReferenceUniformse24e265506083& _50)
{
    float2 uv2 = uv;
    if (_50.type == 0)
    {
        float2 param = uv;
        uv2.x += (0.100000001490116119384765625 * random2(param));
    }
    else
    {
        if (_50.type == 1)
        {
            float2 param_1 = uv;
            uv2.y += (0.100000001490116119384765625 * random2(param_1));
        }
        else
        {
            if (_50.type == 2)
            {
                float2 param_2 = uv;
                uv2.x += (0.100000001490116119384765625 * random2(param_2));
                float2 param_3 = uv;
                uv2.y += (0.100000001490116119384765625 * random2(param_3));
            }
        }
    }
    return uv2 - uv;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse24e265506083& _50, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _50.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 syamjaidtz = gl_FragCoord.xy / _50.refScreen.xy;
    if (_50.type == 0)
    {
        syamjaidtz += float2(0.0500000007450580596923828125, 0.0);
    }
    else
    {
        if (_50.type == 1)
        {
            syamjaidtz += float2(-0.0, 0.0500000007450580596923828125);
        }
        else
        {
            if (_50.type == 2)
            {
                syamjaidtz += float2(0.0500000007450580596923828125);
            }
        }
    }
    float2 uv = syamjaidtz;
    float2 p = uv;
    for (int i = 0; i < 10; i++)
    {
        float2 param_1 = p;
        p -= (myPattern(param_1, _50) * 0.100000001490116119384765625);
    }
    float2 param_2 = p;
    float3 col = texture2DCv(refInput, refInputSmplr, param_2).xyz;
    float4 fragColor = float4(col, 1.0);
    referenceColor = mix(texColor, fragColor, float4(_50.alpha)) * texColor.w;
}

fragment refAM35_e24e265506083_out refAM35_e24e265506083(constant ReferenceUniformse24e265506083& _50 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e24e265506083_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_50, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _221 = any(isnan(referenceColor));
    bool _228;
    if (!_221)
    {
        _228 = any(isinf(referenceColor));
    }
    else
    {
        _228 = _221;
    }
    if (_228)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _241 = referenceColor;
    float3 _247 = fast::clamp(_241.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _247.x;
    referenceColor.y = _247.y;
    referenceColor.z = _247.z;
    out.finalColor = referenceColor;
    return out;
}

