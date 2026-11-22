// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/invertadv.xml
// Original source comments and attribution:
// --- Utility Functions ---
// RGB to HSV
// HSV to RGB
// Full Invert
// Luminance Only — invert brightness, preserve hue/sat
// Hue Rotate 180 degrees
// Red Channel only
// Green Channel only
// Blue Channel only
// Red + Green
// Red + Blue
// Green + Blue
// Invert + Desaturate (grayscale negative)
// Soft Invert via gamma (gentler, non-linear)
// Invert Shadows Only (below threshold)
// Invert Highlights Only (above threshold)
// Invert Midtones Only
// Color Negative (film negative simulation)
// Solarize — invert values above threshold
// Blend invert with original by amount
// Global adjustments
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsef570d703a6f8
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int invertMode;
    char _m6_pad[12];
    float amount;
    char _m7_pad[12];
    float threshold;
    char _m8_pad[12];
    float brightness;
    char _m9_pad[12];
    float contrast;
    char _m10_pad[12];
    float saturation;
    char _m11_pad[12];
    float blend;
};

struct refAM35_ef570d703a6f8_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float getLuma(thread const float3& col)
{
    return dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float3 rgb2hsv(thread const float3& c)
{
    float4 K = float4(0.0, -0.3333333432674407958984375, 0.666666686534881591796875, -1.0);
    float4 p = mix(float4(c.zy, K.wz), float4(c.yz, K.xy), float4(step(c.z, c.y)));
    float4 q = mix(float4(p.xyw, c.x), float4(c.x, p.yzx), float4(step(p.x, c.x)));
    float d = q.x - fast::min(q.w, q.y);
    float e = 1.0000000133514319600180897396058e-10;
    return float3(abs(q.z + ((q.w - q.y) / ((6.0 * d) + e))), d / (q.x + e), q.x);
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
float3 applyContrast(thread const float3& col, thread const float& con)
{
    return ((col - float3(0.5)) * con) + float3(0.5);
}

static inline __attribute__((always_inline))
float3 saturateCol(thread const float3& col, thread const float& sat)
{
    float grey = dot(col, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    return mix(float3(grey), col, float3(sat));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsef570d703a6f8& _220, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _220.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float3 col = src.xyz;
    float alpha = src.w;
    float3 invertCol = col;
    if (_220.invertMode == 0)
    {
        invertCol = float3(1.0) - col;
    }
    else
    {
        if (_220.invertMode == 1)
        {
            float3 param_1 = col;
            float luma = getLuma(param_1);
            float invertLuma = 1.0 - luma;
            invertCol = col * (invertLuma / fast::max(luma, 0.001000000047497451305389404296875));
        }
        else
        {
            if (_220.invertMode == 2)
            {
                float3 param_2 = col;
                float3 hsv = rgb2hsv(param_2);
                hsv.x = fract(hsv.x + 0.5);
                float3 param_3 = hsv;
                invertCol = hsv2rgb(param_3);
            }
            else
            {
                if (_220.invertMode == 3)
                {
                    invertCol = float3(1.0 - col.x, col.y, col.z);
                }
                else
                {
                    if (_220.invertMode == 4)
                    {
                        invertCol = float3(col.x, 1.0 - col.y, col.z);
                    }
                    else
                    {
                        if (_220.invertMode == 5)
                        {
                            invertCol = float3(col.x, col.y, 1.0 - col.z);
                        }
                        else
                        {
                            if (_220.invertMode == 6)
                            {
                                invertCol = float3(1.0 - col.x, 1.0 - col.y, col.z);
                            }
                            else
                            {
                                if (_220.invertMode == 7)
                                {
                                    invertCol = float3(1.0 - col.x, col.y, 1.0 - col.z);
                                }
                                else
                                {
                                    if (_220.invertMode == 8)
                                    {
                                        invertCol = float3(col.x, 1.0 - col.y, 1.0 - col.z);
                                    }
                                    else
                                    {
                                        if (_220.invertMode == 9)
                                        {
                                            float3 inv = float3(1.0) - col;
                                            float3 param_4 = inv;
                                            float luma_1 = getLuma(param_4);
                                            invertCol = float3(luma_1);
                                        }
                                        else
                                        {
                                            if (_220.invertMode == 10)
                                            {
                                                invertCol = powr(float3(1.0) - col, float3(0.699999988079071044921875));
                                            }
                                            else
                                            {
                                                if (_220.invertMode == 11)
                                                {
                                                    float3 param_5 = col;
                                                    float luma_2 = getLuma(param_5);
                                                    float mask = 1.0 - smoothstep(0.0, _220.threshold, luma_2);
                                                    invertCol = mix(col, float3(1.0) - col, float3(mask));
                                                }
                                                else
                                                {
                                                    if (_220.invertMode == 12)
                                                    {
                                                        float3 param_6 = col;
                                                        float luma_3 = getLuma(param_6);
                                                        float mask_1 = smoothstep(_220.threshold, 1.0, luma_3);
                                                        invertCol = mix(col, float3(1.0) - col, float3(mask_1));
                                                    }
                                                    else
                                                    {
                                                        if (_220.invertMode == 13)
                                                        {
                                                            float3 param_7 = col;
                                                            float luma_4 = getLuma(param_7);
                                                            float lo = _220.threshold * 0.5;
                                                            float hi = _220.threshold + ((1.0 - _220.threshold) * 0.5);
                                                            float mask_2 = smoothstep(lo, _220.threshold, luma_4) * (1.0 - smoothstep(_220.threshold, hi, luma_4));
                                                            invertCol = mix(col, float3(1.0) - col, float3(mask_2));
                                                        }
                                                        else
                                                        {
                                                            if (_220.invertMode == 14)
                                                            {
                                                                invertCol = float3(1.0) - (col * float3(0.949999988079071044921875, 0.85000002384185791015625, 0.75));
                                                                invertCol = fast::clamp(invertCol, float3(0.0), float3(1.0));
                                                            }
                                                            else
                                                            {
                                                                if (_220.invertMode == 15)
                                                                {
                                                                    float3 param_8 = col;
                                                                    float luma_5 = getLuma(param_8);
                                                                    float mask_3 = step(_220.threshold, luma_5);
                                                                    invertCol = mix(col, float3(1.0) - col, float3(mask_3));
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    float3 result = mix(col, invertCol, float3(_220.amount));
    result += float3(_220.brightness);
    float3 param_9 = result;
    float param_10 = _220.contrast;
    result = applyContrast(param_9, param_10);
    float3 param_11 = result;
    float param_12 = _220.saturation;
    result = saturateCol(param_11, param_12);
    result = fast::clamp(result, float3(0.0), float3(1.0));
    referenceColor = (float4(result, alpha) * _220.blend) + (src * (1.0 - _220.blend));
}

fragment refAM35_ef570d703a6f8_out refAM35_ef570d703a6f8(constant ReferenceUniformsef570d703a6f8& _220 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ef570d703a6f8_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _220, refInput, refInputSmplr, referenceColor);
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

