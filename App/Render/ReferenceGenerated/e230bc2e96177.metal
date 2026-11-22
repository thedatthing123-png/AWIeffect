// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/checkerdissolve2.xml
// Original source comments and attribution:
// st.x /= stretch;
// st /= tileSize;
// st += offset/1000.0;
// st.x /= acLayerSize.x/acLayerSize.y;
//r = step(amount,r);
//float scale = 1.0/(1.0+fade);
//r = smoothstep(amount*scale, (amount+fade)*scale, r);
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

struct ReferenceUniformse230bc2e96177
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amount;
    char _m6_pad[12];
    float size;
    char _m7_pad[8];
    float2 stretch;
    char _m8_pad[8];
    float seed;
    char _m9_pad[12];
    float fade;
    char _m10_pad[8];
    float2 offset;
};

struct refAM35_e230bc2e96177_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float rand(thread const float2& co)
{
    float a = 719.30999755859375;
    float b = 178.233001708984375;
    float c = 33758.546875;
    float dt = dot(co, float2(a, b));
    float sn = mod(dt, 3.1400001049041748046875);
    return fract(sin(sn) * c);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse230bc2e96177& _63, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _63.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = floor((float2((gl_FragCoord.xy / _63.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _63.refScreen.xy).y) * _63.refScreen.xy) - float2(_63.refLayer.x + (_63.refLayer.z * 0.5), (_63.refScreen.y - _63.refLayer.y) - (_63.refLayer.w * 0.5))) / _63.refLayer.zw;
    float t = _63.seed * 3197.379150390625;
    t = mod(t, 2.7999999523162841796875) + 2.7000000476837158203125;
    float tileSize = fast::min(_63.refLayer.z, _63.refLayer.w) / _63.size;
    st.x *= (_63.refLayer.z / _63.refLayer.w);
    st -= (_63.offset / float2(1000.0));
    st *= tileSize;
    st.x /= _63.stretch.x;
    st.y /= _63.stretch.y;
    st = floor(st);
    float2 param_1 = st * t;
    float r = rand(param_1);
    float adjFade = fast::max(_63.fade, 9.9999997473787516355514526367188e-06);
    float adjAmount = _63.amount;
    adjAmount -= 0.5;
    adjAmount *= (1.0 + (adjFade * 2.0));
    adjAmount += 0.5;
    r = smoothstep(adjAmount - adjFade, adjAmount + adjFade, r);
    referenceColor = texColor * r;
}

fragment refAM35_e230bc2e96177_out refAM35_e230bc2e96177(constant ReferenceUniformse230bc2e96177& _63 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e230bc2e96177_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _63, referenceColor);
    bool _228 = any(isnan(referenceColor));
    bool _235;
    if (!_228)
    {
        _235 = any(isinf(referenceColor));
    }
    else
    {
        _235 = _228;
    }
    if (_235)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _249 = referenceColor;
    float3 _255 = fast::clamp(_249.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _255.x;
    referenceColor.y = _255.y;
    referenceColor.z = _255.z;
    out.finalColor = referenceColor;
    return out;
}

