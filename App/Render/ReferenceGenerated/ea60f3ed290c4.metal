// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/bcc_led.xml
// Original source comments and attribution:
// ── KEY FIX: sample full RGBA so we keep the PNG alpha ──
// PNG transparency
// ── Multiply LED mask by the source PNG alpha ──
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea60f3ed290c4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float ledSizeX;
    char _m6_pad[12];
    float ledSizeY;
    char _m7_pad[12];
    float dotSize;
    char _m8_pad[12];
    float antialias;
    char _m9_pad[12];
    int ledShape;
    float4 tintColor;
    float tintAmount;
    char _m12_pad[12];
    float flickerSpeed;
    char _m13_pad[12];
    float flickerAmount;
    char _m14_pad[12];
    float glowAlpha;
    char _m15_pad[12];
    float glowSize;
    char _m16_pad[12];
    float glowBrightness;
    char _m17_pad[12];
    float brightness;
};

struct refAM35_ea60f3ed290c4_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float2 getResolution(constant ReferenceUniformsea60f3ed290c4& _44)
{
    float2 param = _44.refScreen.xy;
    float2 s = getTexSize(param);
    bool _59 = s.x <= 0.0;
    bool _67;
    if (!_59)
    {
        _67 = s.y <= 0.0;
    }
    else
    {
        _67 = _59;
    }
    if (_67)
    {
        s = float2(1920.0, 1080.0);
    }
    return s;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float rand(thread const float2& co)
{
    return fract(sin(dot(co, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsea60f3ed290c4& _44, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 res = getResolution(_44);
    float2 fragCoord = (gl_FragCoord.xy / _44.refScreen.xy) * res;
    float2 uv = gl_FragCoord.xy / _44.refScreen.xy;
    float cellW = res.x / fast::max(_44.ledSizeX, 1.0);
    float cellH = res.y / fast::max(_44.ledSizeY, 1.0);
    float2 cellSize = float2(cellW, cellH);
    float2 cellIndex = floor(fragCoord / cellSize);
    float2 cellCenterPos = (cellIndex + float2(0.5)) * cellSize;
    float2 cellUVn = (fragCoord - cellCenterPos) / cellSize;
    float2 textureUV = cellCenterPos / res;
    float2 param = textureUV;
    float4 baseSample = texture2DCv(refInput, refInputSmplr, param);
    float srcAlpha = baseSample.w;
    float3 baseCol = baseSample.xyz;
    baseCol = mix(baseCol, _44.tintColor.xyz, float3(_44.tintAmount));
    float tBlock = floor(_44.refScreen.z * fast::max(_44.flickerSpeed, 0.0));
    float2 param_1 = cellIndex + float2(tBlock, tBlock * 0.37000000476837158203125);
    float flickerRnd = rand(param_1);
    float flicker = mix(1.0 - _44.flickerAmount, 1.0, flickerRnd);
    float dMask;
    if (_44.ledShape == 0)
    {
        float dist = length(cellUVn);
        dMask = smoothstep(_44.dotSize, _44.dotSize - _44.antialias, dist);
    }
    else
    {
        float m = fast::max(abs(cellUVn.x), abs(cellUVn.y));
        dMask = smoothstep(_44.dotSize, _44.dotSize - _44.antialias, m);
    }
    float glowMask;
    if (_44.ledShape == 0)
    {
        float dist_1 = length(cellUVn);
        glowMask = smoothstep(_44.dotSize + _44.glowSize, (_44.dotSize + _44.glowSize) - _44.antialias, dist_1);
    }
    else
    {
        float m_1 = fast::max(abs(cellUVn.x), abs(cellUVn.y));
        glowMask = smoothstep(_44.dotSize + _44.glowSize, (_44.dotSize + _44.glowSize) - _44.antialias, m_1);
    }
    float3 col = (baseCol * dMask) * flicker;
    col += (((baseCol * _44.glowBrightness) * glowMask) * _44.glowAlpha);
    col *= _44.brightness;
    float outA = fast::max(dMask, _44.glowAlpha * glowMask) * srcAlpha;
    referenceColor = float4(col * srcAlpha, outA);
}

fragment refAM35_ea60f3ed290c4_out refAM35_ea60f3ed290c4(constant ReferenceUniformsea60f3ed290c4& _44 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea60f3ed290c4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_44, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _340 = any(isnan(referenceColor));
    bool _347;
    if (!_340)
    {
        _347 = any(isinf(referenceColor));
    }
    else
    {
        _347 = _340;
    }
    if (_347)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    out.finalColor = referenceColor;
    return out;
}

