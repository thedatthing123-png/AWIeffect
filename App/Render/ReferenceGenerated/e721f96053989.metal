// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsfuji.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//////////////////////////
/////////////////////////
// if(progressa <= 0.0) { gl_FragColor = texture2DCv(inputImg.texture,acScreenNorm); }
// else if(progressa >= 0.0001) { 
// vec3 cx;
// cx.r = color1.r;
// cx.g = color1.g + 0.3;
// cx.b = color1.b;
// vec3 cxx;
// cxx.r = color1.r;
// cxx.g = color1.g + 0.2;
// cxx.b = color1.b;
// vec2 uv = (2.0 * fragCoord.xy - iResolution.xy)/iResolution.y;
// Grid
//180
// col = mix(col, cx, gridVal);
// col *= alphag;
// col = mix(col, vec3(1.0, 0.5, 1.0), gridVal);
// float fujiD = min(uv.y * 4.5 - 0.5, 1.0);
// uv.y -= battery * 1.1 - 0.51;
// Sun
//193
//uv.y -= 1.1 - 0.51;
// col = vec3(1.0, 0.2, 1.0);
//197
// col = mix(col, cxx, sunUV.y * 2.0 + 0.2);
//)*alphag;
// col = mix(col, vec3(1.0, 0.4, 0.1), sunUV.y * 2.0 + 0.2);
//) * alphag;
// col += mix( col, mix(vec3(1.0, 0.12, 0.8), vec3(0.0, 0.0, 0.2), clamp(uv.y * 3.5 + 3.0, 0.0, 1.0)), vec3(1.0, 1.0, 1.0) );
// col = mix(vec3(col.r, col.r, col.r) * 0.5, col, battery * 0.7);
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse721f96053989
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint scalex;
    char _m6_pad[8];
    float2 positionn;
    char _m7_pad[8];
    float progressa;
    char _m8_pad[12];
    float scalen;
    char _m9_pad[12];
    float anglen;
    char _m10_pad[12];
    float alphan;
    char _m11_pad[8];
    float2 position;
    char _m12_pad[8];
    float2 sstretch;
    char _m13_pad[8];
    float2 stretch;
    char _m14_pad[8];
    float progressb;
    char _m15_pad[12];
    float scale;
    char _m16_pad[12];
    float angle;
    char _m17_pad[12];
    uint visible;
    float4 color1;
    float4 color3;
    float4 color4;
    float4 color2;
    float alpha;
    char _m23_pad[12];
    float bright;
    char _m24_pad[12];
    int blendMode;
};

struct refAM35_e721f96053989_out
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
float grid(thread float2& uv, thread const float& battery, constant ReferenceUniformse721f96053989& _79)
{
    float2 size = float2(uv.y, (uv.y * uv.y) * 0.20000000298023223876953125) * 0.00999999977648258209228515625;
    uv += float2(0.0, (_79.progressb * 4.0) * (battery + 0.0500000007450580596923828125));
    uv = abs(fract(uv) - float2(0.5));
    float2 lines = smoothstep(size, float2(0.0), uv);
    lines += ((smoothstep(size * 5.0, float2(0.0), uv) * 0.4000000059604644775390625) * battery);
    return fast::clamp(lines.x + lines.y, 0.0, 3.0);
}

static inline __attribute__((always_inline))
float sun(thread const float2& uv, thread const float& battery, constant ReferenceUniformse721f96053989& _79)
{
    float val = smoothstep(0.300000011920928955078125, 0.2899999916553497314453125, length(uv));
    float bloom = smoothstep(0.699999988079071044921875, 0.0, length(uv));
    float cut = (3.0 * sin((uv.y + ((_79.progressa * 0.20000000298023223876953125) * (battery + 0.0199999995529651641845703125))) * 100.0)) + fast::clamp((uv.y * 14.0) + 1.0, -6.0, 6.0);
    cut = fast::clamp(cut, 0.0, 1.0);
    return fast::clamp(val * cut, 0.0, 1.0) + (bloom * 0.60000002384185791015625);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse721f96053989& _79, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_79.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _79.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_79.refComposition.z) == 1)
        {
            float2 sscaleVec = float2(1.0 * _79.sstretch.x, 1.0 * _79.sstretch.y);
            float2 param_1 = fast::clamp((gl_FragCoord.xy / _79.refScreen.xy) / sscaleVec, float2(0.0), float2(1.0));
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _79.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _79.refScreen.xy).y) * _79.refScreen.xy) - float2(_79.refLayer.x + (_79.refLayer.z * 0.5), (_79.refScreen.y - _79.refLayer.y) - (_79.refLayer.w * 0.5))) / _79.refLayer.zw;
            syamjaidtz.y *= (_79.refLayer.w / _79.refLayer.z);
            if (_79.visible != 0u)
            {
                syamjaidtz /= float2(100.0);
            }
            else
            {
                float _299;
                if (_79.scalex != 0u)
                {
                    _299 = _79.scale + 3.5;
                }
                else
                {
                    _299 = _79.scale;
                }
                syamjaidtz /= float2(_299);
            }
            float param_2 = (180.0 + _79.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_2);
            syamjaidtz += ((float2(0.0 + _79.position.x, 0.0 + _79.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 sunst = ((float2((gl_FragCoord.xy / _79.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _79.refScreen.xy).y) * _79.refScreen.xy) - float2(_79.refLayer.x + (_79.refLayer.z * 0.5), (_79.refScreen.y - _79.refLayer.y) - (_79.refLayer.w * 0.5))) / _79.refLayer.zw;
            sunst.y *= (_79.refLayer.w / _79.refLayer.z);
            float _395;
            if (_79.scalex != 0u)
            {
                _395 = _79.scalen + 3.5;
            }
            else
            {
                _395 = _79.scalen;
            }
            sunst /= float2(_395);
            float param_3 = (180.0 + _79.anglen) * 0.01745329983532428741455078125;
            sunst *= rot2m(param_3);
            sunst += ((float2(375.0 + _79.positionn.x, (-180.0) + _79.positionn.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(1.0 * _79.stretch.x, 1.0 * _79.stretch.y);
            float2 uv = syamjaidtz / scaleVec;
            float battery = 1.0;
            float fog = smoothstep(0.100000001490116119384765625, -0.0199999995529651641845703125, abs(uv.y + 0.20000000298023223876953125));
            float3 col = float3(0.0, 0.100000001490116119384765625, 0.20000000298023223876953125);
            if (uv.y < (-0.20000000298023223876953125))
            {
                uv.y = 3.0 / (abs(uv.y + 0.20000000298023223876953125) + 0.0500000007450580596923828125);
                uv.x *= (uv.y * 1.0);
                float2 param_4 = uv;
                float param_5 = battery;
                float _484 = grid(param_4, param_5, _79);
                float gridVal = _484;
                col = mix(col, _79.color4.xyz, float3(gridVal));
            }
            else
            {
                float2 sunUV = sunst;
                sunUV += float2(0.75, 0.20000000298023223876953125);
                col = _79.color1.xyz;
                float2 param_6 = sunUV;
                float param_7 = battery;
                float sunVal = sun(param_6, param_7, _79);
                col = mix(col, _79.color3.xyz, float3((sunUV.y * 2.0) + 0.20000000298023223876953125));
                col = mix(float3(0.0), col, float3(sunVal * _79.alphan));
                col += mix(col, mix(_79.color4.xyz, float3(0.0, 0.0, 0.20000000298023223876953125), float3(fast::clamp((uv.y * 3.5) + 3.0, 0.0, 1.0))), float3(1.0));
                col = mix(col, float3(0.0, 0.0, 0.20000000298023223876953125), float3(0.0));
            }
            col += float3((fog * fog) * fog);
            col = mix(_79.color2.xyz, col, float3(battery * 0.699999988079071044921875));
            float4 fragColor = float4(col, 1.0);
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal;
            if (_79.blendMode == 0)
            {
                resultfinal = (factor * _79.bright) * texColor.w;
            }
            else
            {
                if (_79.blendMode == 1)
                {
                    factor *= _79.bright;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_79.blendMode == 2)
                    {
                        factor *= _79.bright;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_79.alpha));
        }
    }
}

fragment refAM35_e721f96053989_out refAM35_e721f96053989(constant ReferenceUniformse721f96053989& _79 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e721f96053989_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_79, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _671 = any(isnan(referenceColor));
    bool _678;
    if (!_671)
    {
        _678 = any(isinf(referenceColor));
    }
    else
    {
        _678 = _671;
    }
    if (_678)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _691 = referenceColor;
    float3 _697 = fast::clamp(_691.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _697.x;
    referenceColor.y = _697.y;
    referenceColor.z = _697.z;
    out.finalColor = referenceColor;
    return out;
}

