// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/3audiospactrum.xml
// Original source comments and attribution:
// Transparent audio spectrum visualizer
// Bars and dots around a horizontal baseline. No background fill.
// Hash for deterministic jitter
// Smooth rectangle (x-axis) and circle (for dots)
// global level with reactivity curve
// symmetric jitter
// slight mid emphasis
// Outside drawing area: fully transparent
// bar center
// Coverage accumulation: baseline line + bar + dot
// Baseline
// Vertical bar centered on baseline (extends up and down)
// X coverage by width, Y coverage by height symmetrical around baseline
// Dot between bars: centered halfway to next bar, on baseline
// Final color: premultiplied by coverage, transparent elsewhere
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse5233aa604543
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color;
    float alpha;
    char _m7_pad[12];
    float line_thickness;
    char _m8_pad[12];
    float bar_width;
    char _m9_pad[12];
    float dot_size;
    char _m10_pad[12];
    float baseline_y;
    char _m11_pad[12];
    float left_margin;
    char _m12_pad[12];
    float bar_count;
    char _m13_pad[12];
    float bar_max_height;
    char _m14_pad[12];
    float audio_level;
    char _m15_pad[12];
    float reactivity;
    char _m16_pad[12];
    float jitter;
    char _m17_pad[12];
    float speed;
    char _m18_pad[12];
    float seed;
};

struct refAM35_e5233aa604543_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float hash11(thread const float& n)
{
    return fract(sin((n * 127.09999847412109375) + 311.70001220703125) * 43758.546875);
}

static inline __attribute__((always_inline))
float bandAmp(thread const float& i, thread const float& N, constant ReferenceUniformse5233aa604543& _84)
{
    float base = powr(_84.audio_level, _84.reactivity);
    float param = i + _84.seed;
    float rnd = ((hash11(param) * 2.0) - 1.0) * _84.jitter;
    float wob = 0.5 + (0.5 * sin((_84.refScreen.z * (2.5 * _84.speed)) + (i * 0.89999997615814208984375)));
    float env = 0.85000002384185791015625 - (0.3499999940395355224609375 * abs(((i / (N - 1.0)) * 2.0) - 1.0));
    float amp = fast::clamp((base * env) * ((0.60000002384185791015625 + (0.800000011920928955078125 * wob)) + rnd), 0.0, 1.0);
    return amp;
}

static inline __attribute__((always_inline))
float smoothLine(thread const float& y, thread const float& halfT)
{
    return 1.0 - smoothstep(halfT - 9.9999997473787516355514526367188e-05, halfT + 9.9999997473787516355514526367188e-05, abs(y));
}

static inline __attribute__((always_inline))
float smoothRect(thread const float& x, thread const float& halfW)
{
    return 1.0 - smoothstep(halfW - 9.9999997473787516355514526367188e-05, halfW + 9.9999997473787516355514526367188e-05, abs(x));
}

static inline __attribute__((always_inline))
float smoothCircle(thread const float2& p, thread const float& r)
{
    float d = length(p);
    return 1.0 - smoothstep(r - 9.9999997473787516355514526367188e-05, r + 9.9999997473787516355514526367188e-05, d);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse5233aa604543& _84, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _84.refScreen.xy;
    float margin = fast::clamp(_84.left_margin, 0.0, 0.4900000095367431640625);
    float N = _84.bar_count;
    float usableW = 1.0 - (2.0 * margin);
    float xIn = (uv.x - margin) / fast::max(usableW, 9.9999997473787516355514526367188e-05);
    if ((xIn < 0.0) || (xIn > 1.0))
    {
        referenceColor = float4(0.0);
        return;
    }
    float i = floor(xIn * N);
    float cx = margin + (((i + 0.5) / N) * usableW);
    float dx = uv.x - cx;
    float param = i;
    float param_1 = N;
    float amp = bandAmp(param, param_1, _84);
    float h = _84.bar_max_height * amp;
    float halfW = _84.bar_width * 0.5;
    float baseline = _84.baseline_y;
    float cov = 0.0;
    float param_2 = uv.y - baseline;
    float param_3 = _84.line_thickness * 0.5;
    cov = fast::max(cov, smoothLine(param_2, param_3));
    float param_4 = dx;
    float param_5 = halfW;
    float cxCov = smoothRect(param_4, param_5);
    float yTop = baseline + h;
    float yBot = baseline - h;
    float yDist = fast::max(0.0, fast::max(uv.y - yTop, yBot - uv.y));
    float yCov = 1.0 - smoothstep(0.0, 9.9999997473787516355514526367188e-05, yDist);
    cov = fast::max(cov, cxCov * yCov);
    float nextCx = margin + (((i + 1.0) / N) * usableW);
    float midX = mix(cx, nextCx, 0.5);
    float2 dp = float2(uv.x - midX, uv.y - baseline);
    float2 param_6 = dp;
    float param_7 = _84.dot_size;
    cov = fast::max(cov, smoothCircle(param_6, param_7));
    float3 col = _84.color.xyz;
    float a = cov * _84.alpha;
    referenceColor = float4(col * a, a);
}

fragment refAM35_e5233aa604543_out refAM35_e5233aa604543(constant ReferenceUniformse5233aa604543& _84 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e5233aa604543_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_84, gl_FragCoord, referenceColor);
    bool _349 = any(isnan(referenceColor));
    bool _356;
    if (!_349)
    {
        _356 = any(isinf(referenceColor));
    }
    else
    {
        _356 = _349;
    }
    if (_356)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _370 = referenceColor;
    float3 _376 = fast::clamp(_370.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _376.x;
    referenceColor.y = _376.y;
    referenceColor.z = _376.z;
    out.finalColor = referenceColor;
    return out;
}

