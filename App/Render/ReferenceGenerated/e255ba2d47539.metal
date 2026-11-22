// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/contourstrips.xml
// Original source comments and attribution:

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

struct ReferenceUniformse255ba2d47539
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amount;
    char _m6_pad[12];
    float width;
    char _m7_pad[12];
    float angle;
    char _m8_pad[12];
    float thickness;
    char _m9_pad[12];
    float phase;
    char _m10_pad[12];
    uint invert;
    float4 lineColor;
    float4 color1;
    float4 color2;
    float4 lightColor;
    float lightAngle;
    char _m16_pad[12];
    int heightSource;
    char _m17_pad[12];
    uint maskToLayer;
};

struct refAM35_e255ba2d47539_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rot2d(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse255ba2d47539& _76)
{
    return (float4(v, 0.0, 1.0) * _76.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 perpCCW(thread const float2& v)
{
    return float2(v.y, -v.x);
}

static inline __attribute__((always_inline))
float4 premult(thread const float4& c)
{
    return float4(c.xyz * c.w, c.w);
}

static inline __attribute__((always_inline))
float4 composite(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
float saturate0(thread const float& v)
{
    return fast::clamp(v, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float4 saturate0(thread const float4& v)
{
    return fast::clamp(v, float4(0.0), float4(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse255ba2d47539& _76, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refBuffer1, sampler refBuffer1Smplr, thread float4& referenceColor)
{
    float2 st = (gl_FragCoord.xy - _76.refLayer.xy) / _76.refLayer.zw;
    float a = (_76.angle + 180.0) * 0.01745329238474369049072265625;
    float la = _76.lightAngle * 0.01745329238474369049072265625;
    float param = la;
    float2 lightVec = float2(1.0, 0.0) * rot2d(param);
    float band = 1.0 / _76.amount;
    st -= float2(0.5);
    float param_1 = a;
    st *= rot2d(param_1);
    st += float2(0.5);
    st.y += (((_76.phase + 0.054999999701976776123046875) / 10.0) + (0.5 / _76.refLayer.w));
    float4 result = float4(0.0);
    float pixel = 1.0 / fast::min(_76.refLayer.z, _76.refLayer.w);
    float soffs = (pixel * 4.0) * fast::max(1.0, _76.width);
    float bandPixel = (pixel / _76.amount) / _76.width;
    float baseThickness = ((_76.thickness / _76.width) * _76.amount) / 20.0;
    float _350;
    float _368;
    float _382;
    for (float i = -1.0; i < (_76.width + 1.0); i += 1.0)
    {
        float2 uv = st;
        float bandId = floor(uv.y / band) + i;
        float py = mod(uv.y, band);
        uv.y -= py;
        uv.y += (band * i);
        py /= band;
        uv.y -= (((_76.phase + 0.054999999701976776123046875) / 10.0) + (0.5 / _76.refLayer.w));
        uv -= float2(0.5);
        float param_2 = -a;
        uv *= rot2d(param_2);
        uv += float2(0.5);
        py = 1.0 - (((1.0 - py) + i) / _76.width);
        float2 param_3 = uv;
        float2 param_4 = l2s(param_3, _76);
        float4 texColor = texture2DCv(refInput, refInputSmplr, param_4);
        float2 param_5 = uv + float2(-soffs, 0.0);
        float2 param_6 = l2s(param_5, _76);
        float4 texColorL = texture2DCv(refBuffer1, refBuffer1Smplr, param_6);
        float2 param_7 = uv + float2(soffs, 0.0);
        float2 param_8 = l2s(param_7, _76);
        float4 texColorR = texture2DCv(refBuffer1, refBuffer1Smplr, param_8);
        if (_76.heightSource == 0)
        {
            _350 = texColor.w;
        }
        else
        {
            _350 = dot(texColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        }
        float luminance = _350;
        if (_76.heightSource == 0)
        {
            _368 = texColorL.w;
        }
        else
        {
            _368 = dot(texColorL.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        }
        float lumL = _368;
        if (_76.heightSource == 0)
        {
            _382 = texColorR.w;
        }
        else
        {
            _382 = dot(texColorR.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        }
        float lumR = _382;
        if (!(_76.invert != 0u))
        {
            lumL = 1.0 - lumL;
            lumR = 1.0 - lumR;
            luminance = 1.0 - luminance;
        }
        float2 aa = float2(-soffs, (lumL * band) * _76.width);
        float2 cc = float2(soffs, (lumR * band) * _76.width);
        float2 param_9 = cc - aa;
        float2 n = fast::normalize(perpCCW(param_9));
        float2 dac = cc - aa;
        float slope = abs(dac.y) / abs(dac.x);
        float th = baseThickness * (1.0 + (slope * 0.5));
        float line = smoothstep((luminance - th) - bandPixel, luminance - th, py) * smoothstep((luminance + th) + bandPixel, luminance + th, py);
        float2 vn = (n * 0.5) + float2(0.5);
        float4 param_10 = _76.lightColor;
        float4 param_11 = _76.lineColor;
        float4 param_12 = premult(param_10);
        float param_13 = dot(n, lightVec);
        float param_14 = line;
        float4 param_15 = mix(_76.lineColor, composite(param_11, param_12), float4(saturate0(param_13))) * saturate0(param_14);
        float4 lc = saturate0(param_15);
        float p = smoothstep(luminance - 0.0199999995529651641845703125, luminance + 0.00999999977648258209228515625, py);
        float4 c = texColor * p;
        if (_76.heightSource == 0)
        {
            float4 param_16 = _76.color1;
            float4 param_17 = texColor;
            float4 param_18 = premult(param_16);
            float4 param_19 = _76.color2;
            float4 param_20 = texColor;
            float4 param_21 = premult(param_19);
            c = mix(composite(param_17, param_18), composite(param_20, param_21), float4(py)) * p;
        }
        else
        {
            float4 param_22 = _76.color1;
            float4 param_23 = _76.color2;
            c = mix(premult(param_22), premult(param_23), float4(py)) * p;
        }
        if (_76.maskToLayer != 0u)
        {
            c *= texColor.w;
            lc *= texColor.w;
        }
        result = (result * (1.0 - c.w)) + c;
        result = (result * (1.0 - lc.w)) + lc;
    }
    referenceColor = result;
}

fragment refAM35_e255ba2d47539_out refAM35_e255ba2d47539(constant ReferenceUniformse255ba2d47539& _76 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e255ba2d47539_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_76, gl_FragCoord, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr, referenceColor);
    bool _596 = any(isnan(referenceColor));
    bool _603;
    if (!_596)
    {
        _603 = any(isinf(referenceColor));
    }
    else
    {
        _603 = _596;
    }
    if (_603)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _616 = referenceColor;
    float3 _622 = fast::clamp(_616.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _622.x;
    referenceColor.y = _622.y;
    referenceColor.z = _622.z;
    out.finalColor = referenceColor;
    return out;
}

