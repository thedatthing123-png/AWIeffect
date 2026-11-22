// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxdith.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
// vec2 uv = fragCoord.xy / iResolution.xy;
// vec3 col = texture2DCv(inputImg.texture, uv).rgb; 
// col.rgb = vec3(greyScale(col.rgb));
// fragColor = vec4( xnxx, 1.0 );
// normal
// resultfinal = (newLayer(texColor, factor) * 1.0) * texColor.a;
// multiply
// screen
// gl_FragColor = colX;
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse398a5f60192e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int type;
    char _m6_pad[12];
    float scale;
    char _m7_pad[12];
    float amount;
    char _m8_pad[12];
    float angle;
    char _m9_pad[12];
    float satt;
    char _m10_pad[12];
    float exposure;
    char _m11_pad[12];
    float gamma;
    char _m12_pad[12];
    float brightness;
    char _m13_pad[12];
    float contrast;
    char _m14_pad[12];
    float highlights;
    char _m15_pad[12];
    float shadows;
    char _m16_pad[12];
    float offset;
    char _m17_pad[12];
    float alpha;
    char _m18_pad[12];
    uint greyscale;
    char _m19_pad[12];
    uint inv;
    char _m20_pad[12];
    int blendMode;
};

struct refAM35_e398a5f60192e_out
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
float greyScale(thread const float3& col)
{
    return dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float2x2 rotate2d(thread const float& angle)
{
    return float2x2(float2(cos(angle), -sin(angle)), float2(sin(angle), cos(angle)));
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse398a5f60192e& _80, texture2d<float> refBuffer2, sampler refBuffer2Smplr, texture2d<float> refImage1, sampler refImage1Smplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _80.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param_1);
    float2 iRes = float2(_80.refScreen.x, _80.refScreen.y);
    float2 syamjaidtz = gl_FragCoord.xy / _80.refScreen.xy;
    float2 uv = syamjaidtz;
    float2 param_2 = uv;
    float4 colX = texture2DCv(refBuffer2, refBuffer2Smplr, param_2);
    float4 col = colX;
    if (_80.greyscale != 0u)
    {
        float3 param_3 = col.xyz;
        float3 _140 = float3(greyScale(param_3));
        col.x = _140.x;
        col.y = _140.y;
        col.z = _140.z;
    }
    if (_80.greyscale != 0u)
    {
        float4 _154 = col;
        float3 _156 = float3(1.0) - _154.xyz;
        col.x = _156.x;
        col.y = _156.y;
        col.z = _156.z;
    }
    uv *= iRes;
    float param_4 = _80.angle;
    float2 p = (rotate2d(param_4) * uv) * _80.scale;
    float pattern;
    float3 xnxx;
    if (_80.type == 0)
    {
        pattern = sin(p.x) * _80.amount;
        xnxx = (((col.xyz * 10.0) * _80.satt) - float3(5.0)) + float3(pattern);
    }
    else
    {
        if (_80.type == 1)
        {
            pattern = (sin(p.x) * sin(p.y)) * _80.amount;
            xnxx = (((col.xyz * 10.0) * _80.satt) - float3(5.0)) + float3(pattern);
        }
        else
        {
            if (_80.type == 2)
            {
                float2 param_5 = (gl_FragCoord.xy / float2(4.0)) * _80.scale;
                pattern = (texture2DCv(refImage1, refImage1Smplr, param_5).x * _80.amount) / 5.0;
                xnxx = step(float3(pattern), col.xyz);
            }
        }
    }
    float4 fragColor = float4(xnxx, 1.0);
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_80.blendMode == 0)
    {
        resultfinal = (factor * 1.0) * texColor.w;
    }
    else
    {
        if (_80.blendMode == 1)
        {
            factor *= 1.0;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_80.blendMode == 2)
            {
                factor *= 1.0;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_80.alpha));
}

fragment refAM35_e398a5f60192e_out refAM35_e398a5f60192e(constant ReferenceUniformse398a5f60192e& _80 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], texture2d<float> refBuffer2 [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], sampler refBuffer2Smplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_e398a5f60192e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _80, refBuffer2, refBuffer2Smplr, refImage1, refImage1Smplr, referenceColor);
    bool _363 = any(isnan(referenceColor));
    bool _370;
    if (!_363)
    {
        _370 = any(isinf(referenceColor));
    }
    else
    {
        _370 = _363;
    }
    if (_370)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _383 = referenceColor;
    float3 _389 = fast::clamp(_383.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _389.x;
    referenceColor.y = _389.y;
    referenceColor.z = _389.z;
    out.finalColor = referenceColor;
    return out;
}

