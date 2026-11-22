// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/hexarray.xml
// Original source comments and attribution:
// hexRatio;
// * vec2(1.,-1.);
//float p = smoothstep(pp,pp+(1.0-pp)*feather,huv.y);
//pp *= 1.0 - feather;
//pp += feather / 2.;
//} else if ( colorMode == 7 ) {
//    color = mix(color1,color2,(sin(id.x/2.0)+1.)/2.);
//vec4 c = color * p;
// normal
// multiply
// screen
// overflow
// punchout
// overlay
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

struct ReferenceUniformse08f25e008dac
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float size;
    char _m7_pad[12];
    float stretch;
    char _m8_pad[12];
    int colorMode;
    float4 color1;
    float4 color2;
    float4 color3;
    float alpha;
    char _m13_pad[12];
    int blendMode;
    char _m14_pad[12];
    uint alphaScale;
    char _m15_pad[12];
    uint copyAlpha;
    char _m16_pad[12];
    float lineWidth;
    char _m17_pad[12];
    float feather;
    char _m18_pad[12];
    float angle;
    char _m19_pad[12];
    uint screenSpace;
};

struct refAM35_e08f25e008dac_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float hexDist(thread const float2& p)
{
    return fast::max(dot(abs(p), float2(0.500444352626800537109375, 0.865768730640411376953125)), abs(p.x));
}

static inline __attribute__((always_inline))
void hexTile(thread const float2& st, thread float2& uv, thread float2& huv, thread float2& id)
{
    float2 grid = mod(st, float2(1.0, 1.730000019073486328125)) - float2(0.5, 0.8650000095367431640625);
    float2 offsetGrid = mod(st - float2(0.5, 0.8650000095367431640625), float2(1.0, 1.730000019073486328125)) - float2(0.5, 0.8650000095367431640625);
    uv = select(offsetGrid, grid, bool2(length(grid) < length(offsetGrid)));
    float2 param = uv;
    huv = float2(precise::atan2(uv.x, uv.y), (0.5 - hexDist(param)) * 2.0);
    id = float2(st.x - uv.x, st.y - uv.y);
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, thread const float4x4& acLTS)
{
    return (float4(v, 0.0, 1.0) * acLTS).xy;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse08f25e008dac& _149, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _149.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st;
    if (_149.screenSpace != 0u)
    {
        st = gl_FragCoord.xy / _149.refScreen.xy;
        st -= float2(0.5);
        st.x *= (_149.refScreen.x / _149.refScreen.y);
    }
    else
    {
        st = (gl_FragCoord.xy - _149.refLayer.xy) / _149.refLayer.zw;
        st -= float2(0.5);
        st.x *= (_149.refLayer.z / _149.refLayer.w);
    }
    float2 scale = float2(_149.size / 100.0, (_149.size / 100.0) * _149.stretch);
    float2 pos = (_149.position / float2(500.0)) * float2(1.0, -1.0);
    st /= scale;
    float param_1 = _149.angle * 0.01745329983532428741455078125;
    st *= rot(param_1);
    float param_2 = (-_149.angle) * 0.01745329983532428741455078125;
    pos *= rot(param_2);
    float2 modPos = mod(pos, float2(2.0, 3.46000003814697265625));
    float2 basePos = pos - modPos;
    float2 stepPos = basePos;
    st -= modPos;
    float2 param_3 = st;
    float2 param_4;
    float2 param_5;
    float2 param_6;
    hexTile(param_3, param_4, param_5, param_6);
    float2 uv = param_4;
    float2 huv = param_5;
    float2 id = param_6;
    id -= stepPos;
    id += float2(1000.0);
    float2 screenCoord = st - uv;
    screenCoord += modPos;
    float param_7 = (-_149.angle) * 0.01745329983532428741455078125;
    screenCoord *= rot(param_7);
    screenCoord *= scale;
    screenCoord.x /= (_149.refLayer.z / _149.refLayer.w);
    screenCoord += float2(0.5);
    float2 param_8 = screenCoord;
    float4x4 param_9 = _149.refLayerToScreen;
    screenCoord = l2s(param_8, param_9);
    float2 param_10 = screenCoord;
    float4 centerColor = texture2DCv(refInput, refInputSmplr, param_10);
    float pp;
    if (_149.alphaScale != 0u)
    {
        pp = fast::max(1.0 - centerColor.w, _149.lineWidth);
    }
    else
    {
        if (_149.blendMode == 3)
        {
            pp = fast::max(1.0 - step(0.001000000047497451305389404296875, centerColor.w), _149.lineWidth);
        }
        else
        {
            pp = _149.lineWidth;
        }
    }
    pp = ((pp - 0.5) * (1.0 + _149.feather)) + 0.5;
    float p = smoothstep(pp - (_149.feather / 2.0), pp + (_149.feather / 2.0), huv.y);
    float4 color;
    if (_149.colorMode == 0)
    {
        color = centerColor;
    }
    else
    {
        if (_149.colorMode == 1)
        {
            color = _149.color1;
            float _404 = color.w;
            float4 _406 = color;
            float3 _408 = _406.xyz * _404;
            color.x = _408.x;
            color.y = _408.y;
            color.z = _408.z;
        }
        else
        {
            if (_149.colorMode == 2)
            {
                float ys = step(0.8650000095367431640625, mod(id.y, 1.730000019073486328125));
                color = mix(_149.color1, _149.color2, float4(ys));
                float _436 = color.w;
                float4 _437 = color;
                float3 _439 = _437.xyz * _436;
                color.x = _439.x;
                color.y = _439.y;
                color.z = _439.z;
            }
            else
            {
                if (_149.colorMode == 3)
                {
                    float ys_1 = step(0.8650000095367431640625, mod(id.y, 1.730000019073486328125));
                    color = _149.color1;
                    color = mix(color, _149.color2, float4(step(0.3300000131130218505859375, mod(id.x + (ys_1 * 1.65999996662139892578125), 3.0))));
                    color = mix(_149.color3, color, float4(step(0.3300000131130218505859375, mod((id.x + 1.15999996662139892578125) + (ys_1 * 1.65999996662139892578125), 3.0))));
                    float _490 = color.w;
                    float4 _491 = color;
                    float3 _493 = _491.xyz * _490;
                    color.x = _493.x;
                    color.y = _493.y;
                    color.z = _493.z;
                }
                else
                {
                    if (_149.colorMode == 4)
                    {
                        color = _149.color1;
                        color = mix(color, _149.color3, float4(smoothstep(2.0813033580780029296875, 2.107483386993408203125, huv.x + 3.141590118408203125)));
                        color = mix(color, _149.color2, float4(smoothstep(1.034106731414794921875, 1.06028664112091064453125, huv.x)));
                        float _532 = color.w;
                        float4 _533 = color;
                        float3 _535 = _533.xyz * _532;
                        color.x = _535.x;
                        color.y = _535.y;
                        color.z = _535.z;
                    }
                    else
                    {
                        if (_149.colorMode == 5)
                        {
                            float section = floor(((huv.x + 3.141590118408203125) * 3.0) / 3.141590118408203125);
                            if (section < 1.0)
                            {
                                color = _149.color1;
                            }
                            else
                            {
                                if (section < 2.0)
                                {
                                    color = _149.color2;
                                }
                                else
                                {
                                    if (section < 3.0)
                                    {
                                        color = _149.color1;
                                    }
                                    else
                                    {
                                        if (section < 4.0)
                                        {
                                            color = _149.color3;
                                        }
                                        else
                                        {
                                            if (section < 5.0)
                                            {
                                                color = _149.color1;
                                            }
                                            else
                                            {
                                                color = _149.color2;
                                            }
                                        }
                                    }
                                }
                            }
                            float _595 = color.w;
                            float4 _596 = color;
                            float3 _598 = _596.xyz * _595;
                            color.x = _598.x;
                            color.y = _598.y;
                            color.z = _598.z;
                        }
                        else
                        {
                            if (_149.colorMode == 6)
                            {
                                float section_1 = floor(((huv.x + 3.141590118408203125) * 6.0) / 3.141590118408203125);
                                if (section_1 < 1.0)
                                {
                                    color = _149.color1;
                                }
                                else
                                {
                                    if (section_1 < 5.0)
                                    {
                                        color = _149.color2;
                                    }
                                    else
                                    {
                                        if (section_1 < 9.0)
                                        {
                                            color = _149.color3;
                                        }
                                        else
                                        {
                                            color = _149.color1;
                                        }
                                    }
                                }
                                float _644 = color.w;
                                float4 _645 = color;
                                float3 _647 = _645.xyz * _644;
                                color.x = _647.x;
                                color.y = _647.y;
                                color.z = _647.z;
                            }
                        }
                    }
                }
            }
        }
    }
    color *= p;
    if (_149.copyAlpha != 0u)
    {
        color *= centerColor.w;
    }
    color *= _149.alpha;
    float4 result;
    if (_149.blendMode == 0)
    {
        color *= texColor.w;
        result = color + (texColor * (1.0 - color.w));
    }
    else
    {
        if (_149.blendMode == 1)
        {
            float4 c = color + (float4(1.0) * (1.0 - color.w));
            result = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_149.blendMode == 2)
            {
                result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - color.xyz)), 1.0) * texColor.w;
            }
            else
            {
                if (_149.blendMode == 3)
                {
                    result = color;
                }
                else
                {
                    if (_149.blendMode == 4)
                    {
                        result = texColor * (1.0 - p);
                    }
                    else
                    {
                        if (_149.blendMode == 5)
                        {
                            float3 top = color.xyz / float3(color.w);
                            float3 bot = texColor.xyz / float3(texColor.w);
                            float3 t = smoothstep(float3(0.5), float3(0.5), bot);
                            float3 r3 = (t * (float3(1.0) - ((float3(1.0) - ((bot - float3(0.5)) * 2.0)) * (float3(1.0) - top)))) + ((float3(1.0) - t) * ((bot * 2.0) * top));
                            float4 r4 = (float4(r3, 1.0) * color.w) * texColor.w;
                            result = (texColor * (1.0 - r4.w)) + r4;
                        }
                    }
                }
            }
        }
    }
    referenceColor = result;
}

fragment refAM35_e08f25e008dac_out refAM35_e08f25e008dac(constant ReferenceUniformse08f25e008dac& _149 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e08f25e008dac_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _149, referenceColor);
    bool _841 = any(isnan(referenceColor));
    bool _848;
    if (!_841)
    {
        _848 = any(isinf(referenceColor));
    }
    else
    {
        _848 = _841;
    }
    if (_848)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _861 = referenceColor;
    float3 _867 = fast::clamp(_861.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _867.x;
    referenceColor.y = _867.y;
    referenceColor.z = _867.z;
    out.finalColor = referenceColor;
    return out;
}

