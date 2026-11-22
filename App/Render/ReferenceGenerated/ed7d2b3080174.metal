// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxmatrixcode.xml
// Original source comments and attribution:
/////////////////////////
// if (adaptive) { syamjaidtz = acScreenNorm; }
// else { 
// }
/////////////////////////
// vec4 factor = mix(texColorX,result,alpha);
// normal
// multiply
// screen
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

struct ReferenceUniformsed7d2b3080174
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int typeC;
    char _m6_pad[8];
    float2 position;
    char _m7_pad[8];
    float progressa;
    char _m8_pad[12];
    float scale;
    char _m9_pad[12];
    float bright;
    char _m10_pad[12];
    float alpha;
    char _m11_pad[12];
    float angle;
    float4 color1;
    float4 color2;
    int blendMode;
};

struct refAM35_ed7d2b3080174_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float2 rand(thread const float2& uv)
{
    return floor(abs(mod(cos(((uv * 652.634521484375) + (uv.yx * 534.375)) + float2(2.4999999936881067696958780288696e-07 * dot(uv, float2(0.3639999926090240478515625, 0.9340000152587890625)))), float2(0.001000000047497451305389404296875))) * 16000.0);
}

static inline __attribute__((always_inline))
float fallerSpeed(thread const float& col, thread const float& faller)
{
    return (mod(cos((col * 363.43499755859375) + (faller * 234.322998046875)), 0.100000001490116119384765625) * 1.0) + 0.300000011920928955078125;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsed7d2b3080174& _111, texture2d<float> refImage1, sampler refImage1Smplr, texture2d<float> refImage2, sampler refImage2Smplr, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _111.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _111.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _111.refScreen.xy).y) * _111.refScreen.xy) - float2(_111.refLayer.x + (_111.refLayer.z * 0.5), (_111.refScreen.y - _111.refLayer.y) - (_111.refLayer.w * 0.5))) / _111.refLayer.zw;
    syamjaidtz.y *= (_111.refLayer.w / _111.refLayer.z);
    syamjaidtz /= float2(_111.scale);
    float param_1 = (180.0 + _111.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((_111.position * float2(-1.0, 1.0)) / float2(500.0));
    float2 uv = syamjaidtz;
    uv.y = 1.0 - uv.y;
    float2 pix = mod(uv, float2(0.015625, 0.0333333350718021392822265625));
    float2 cell = (uv - pix) * float2(64.0, 30.0);
    pix *= float2(51.299999237060546875, 30.0);
    float c;
    if (_111.typeC == 0)
    {
        float2 param_2 = cell;
        float2 param_3 = (rand(param_2) + pix) / float2(16.0);
        c = texture2DCv(refImage1, refImage1Smplr, param_3).x;
    }
    else
    {
        if (_111.typeC == 1)
        {
            float2 param_4 = cell;
            float2 param_5 = (rand(param_4) + pix) / float2(16.0);
            c = texture2DCv(refImage2, refImage2Smplr, param_5).x;
        }
    }
    float b = 0.0;
    for (float i = 0.0; i < 14.0; i += 1.0)
    {
        float param_6 = cell.x;
        float param_7 = i;
        float f = (3.0 - (cell.y * 0.0500000007450580596923828125)) - mod((_111.progressa + (i * 3534.340087890625)) * fallerSpeed(param_6, param_7), 12.0);
        if ((f > 0.0) && (f < 1.0))
        {
            b += f;
        }
    }
    float4 result = float4(0.0, c * b, 0.0, 1.0);
    float luminance = dot(result.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 gradmap = mix(_111.color1, _111.color2, float4(luminance)) * result.w;
    float4 factor = mix(texColorX, gradmap, float4(_111.alpha));
    float4 resultfinal;
    if (_111.blendMode == 0)
    {
        resultfinal = (factor * _111.bright) * texColor.w;
    }
    else
    {
        if (_111.blendMode == 1)
        {
            factor *= _111.bright;
            float4 c_1 = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c_1.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_111.blendMode == 2)
            {
                factor *= _111.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = resultfinal;
}

fragment refAM35_ed7d2b3080174_out refAM35_ed7d2b3080174(constant ReferenceUniformsed7d2b3080174& _111 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], texture2d<float> refImage2 [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], sampler refImage2Smplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed7d2b3080174_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _111, refImage1, refImage1Smplr, refImage2, refImage2Smplr, referenceColor);
    bool _446 = any(isnan(referenceColor));
    bool _453;
    if (!_446)
    {
        _453 = any(isinf(referenceColor));
    }
    else
    {
        _453 = _446;
    }
    if (_453)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _466 = referenceColor;
    float3 _472 = fast::clamp(_466.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _472.x;
    referenceColor.y = _472.y;
    referenceColor.z = _472.z;
    out.finalColor = referenceColor;
    return out;
}

