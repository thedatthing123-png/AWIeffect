// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxcomet.xml
// Original source comments and attribution:
/////////////////////////
// H-Count
// stretch
// offset
// speed
// trail length
/////////////////////////
// if (adaptive) { syamjaidtz = acScreenNorm; }
// else { 
// }
// syamjaidtz /= (5.0+scale);
/////////////////////////
// red
// blue
// green
// V-flip
// Drop Colour
// H-Count
// stretch
// offset
// speed
// trail length
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9e78f72e74ef
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int typeComet;
    char _m6_pad[12];
    float scale;
    char _m7_pad[12];
    float progressa;
    char _m8_pad[8];
    float2 position;
    char _m9_pad[8];
    float bright;
    char _m10_pad[12];
    float alpha;
    char _m11_pad[12];
    float angle;
    float4 color1;
    float4 color2;
    float4 color3;
    int blendMode;
};

struct refAM35_e9e78f72e74ef_out
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
float vDrop(thread float2& uv, thread const float& t)
{
    uv.x *= 128.0;
    float dx = fract(uv.x);
    uv.x = floor(uv.x);
    uv.y *= 0.0500000007450580596923828125;
    float o = sin(uv.x * 215.399993896484375);
    float s = (cos(uv.x * 33.09999847412109375) * 0.300000011920928955078125) + 0.699999988079071044921875;
    float trail = mix(95.0, 35.0, s);
    float yv = fract((uv.y + (t * s)) + o) * trail;
    yv = 1.0 / yv;
    yv = smoothstep(0.0, 1.0, yv * yv);
    yv = sin(yv * 3.141590118408203125) * (s * 5.0);
    float d2 = sin(dx * 3.141590118408203125);
    return yv * (d2 * d2);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse9e78f72e74ef& _144, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _144.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _144.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _144.refScreen.xy).y) * _144.refScreen.xy) - float2(_144.refLayer.x + (_144.refLayer.z * 0.5), (_144.refScreen.y - _144.refLayer.y) - (_144.refLayer.w * 0.5))) / _144.refLayer.zw;
    syamjaidtz.y *= (_144.refLayer.w / _144.refLayer.z);
    float param_1 = (0.0 + _144.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((float2(0.0 + _144.position.x, 0.0 + _144.position.y) * float2(-1.0, 1.0)) / float2(250.0));
    float2 p = syamjaidtz;
    float _250;
    if (abs(_144.scale - 0.5) > 0.001000000047497451305389404296875)
    {
        _250 = _144.scale - 0.5;
    }
    else
    {
        _250 = 0.001000000047497451305389404296875;
    }
    p /= float2(_250);
    float d = length(p) + 0.100000001490116119384765625;
    p = float2(precise::atan2(p.x, p.y) / 3.141590118408203125, 2.5 / d);
    if (false)
    {
        p.y *= 0.5;
    }
    float t = _144.progressa * 0.4000000059604644775390625;
    float2 param_2 = p;
    float param_3 = t;
    float _300 = vDrop(param_2, param_3);
    float3 col = _144.color1.xyz * _300;
    float2 param_4 = p;
    float param_5 = t + 0.3300000131130218505859375;
    float _312 = vDrop(param_4, param_5);
    col += (_144.color2.xyz * _312);
    float2 param_6 = p;
    float param_7 = t + 0.660000026226043701171875;
    float _326 = vDrop(param_6, param_7);
    col += (_144.color3.xyz * _326);
    float4 fragColor = float4(col * (d * d), 1.0);
    float2 uvX = syamjaidtz;
    float _347;
    if (abs(_144.scale - 0.5) > 0.001000000047497451305389404296875)
    {
        _347 = _144.scale - 0.5;
    }
    else
    {
        _347 = 0.001000000047497451305389404296875;
    }
    uvX /= float2(_347);
    uvX.y = 1.0 - uvX.y;
    if (false)
    {
        uvX.y = 1.0 - uvX.y;
    }
    float3 colX = _144.color1.xyz;
    uvX.x *= 64.0;
    float dxX = fract(uvX.x);
    uvX.x = floor(uvX.x);
    float tX = _144.progressa * 0.4000000059604644775390625;
    uvX.y *= 0.1500000059604644775390625;
    float oX = sin(uvX.x * 215.399993896484375);
    float sX = (cos(uvX.x * 33.09999847412109375) * 0.300000011920928955078125) + 0.699999988079071044921875;
    float trailX = mix(95.0, 35.0, sX);
    float yvX = fract((uvX.y + (tX * sX)) + oX) * trailX;
    yvX = 1.0 / yvX;
    yvX = smoothstep(0.0, 1.0, yvX * yvX);
    yvX = sin(yvX * 3.141590118408203125) * (sX * 5.0);
    float d2X = sin(dxX * 3.141590118408203125);
    yvX *= (d2X * d2X);
    colX *= yvX;
    float4 comet = float4(colX, 1.0);
    float4 factor;
    if (_144.typeComet == 0)
    {
        factor = mix(texColorX, fragColor, float4(_144.alpha));
    }
    else
    {
        if (_144.typeComet == 1)
        {
            factor = mix(texColorX, comet, float4(_144.alpha));
        }
    }
    float4 resultfinal;
    if (_144.blendMode == 0)
    {
        resultfinal = (factor * _144.bright) * texColor.w;
    }
    else
    {
        if (_144.blendMode == 1)
        {
            factor *= _144.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(fast::max(texColor.w, 9.9999997473787516355514526367188e-06))) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_144.blendMode == 2)
            {
                factor *= _144.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(fast::max(texColor.w, 9.9999997473787516355514526367188e-06)))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = resultfinal;
}

fragment refAM35_e9e78f72e74ef_out refAM35_e9e78f72e74ef(constant ReferenceUniformse9e78f72e74ef& _144 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9e78f72e74ef_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _144, referenceColor);
    bool _571 = any(isnan(referenceColor));
    bool _578;
    if (!_571)
    {
        _578 = any(isinf(referenceColor));
    }
    else
    {
        _578 = _571;
    }
    if (_578)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _591 = referenceColor;
    float3 _597 = fast::clamp(_591.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _597.x;
    referenceColor.y = _597.y;
    referenceColor.z = _597.z;
    out.finalColor = referenceColor;
    return out;
}

