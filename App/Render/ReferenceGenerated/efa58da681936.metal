// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/ribbon.xml
// Original source comments and attribution:
//float p = = st.y > min(y1,y2) && st.y < max(y1,y2) ? color : vec4(0.);
//float b = smoothing*(highy-lowy)/2.;
//float p = st.y > lowy && st.y < highy ? 1.0 : 0.0;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsefa58da681936
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amplitude;
    char _m6_pad[12];
    float frequency;
    char _m7_pad[12];
    float width;
    char _m8_pad[12];
    float phase;
    char _m9_pad[12];
    float offset;
    float4 color;
    uint punchout;
    char _m12_pad[12];
    float smoothing;
    float4 tintColor;
    float tint;
    char _m15_pad[12];
    float angle;
};

struct refAM35_efa58da681936_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsefa58da681936& _36, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _36.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _36.refLayer.xy) / _36.refLayer.zw;
    float a = _36.angle * 0.01745329983532428741455078125;
    st -= float2(0.5);
    st *= float2x2(float2(cos(a), -sin(a)), float2(sin(a), cos(a)));
    st += float2(0.5);
    float x = st.x;
    float y = sin(x * _36.frequency);
    float t = 0.00999999977648258209228515625 * ((-_36.phase) * 130.0);
    y += (sin(((x * _36.frequency) * 2.099999904632568359375) + t) * 4.5);
    y += (sin(((x * _36.frequency) * 1.7200000286102294921875) + (t * 1.1210000514984130859375)) * 4.0);
    y += (sin(((x * _36.frequency) * 2.2209999561309814453125) + (t * 0.4370000064373016357421875)) * 5.0);
    y += (sin(((x * _36.frequency) * 3.1122000217437744140625) + (t * 4.26900005340576171875)) * 2.5);
    y *= (_36.amplitude * 0.02999999932944774627685546875);
    y += (0.5 + _36.offset);
    float y1 = y;
    y = sin(x * _36.frequency);
    t = (0.00999999977648258209228515625 * ((-_36.phase) * 130.0)) + _36.width;
    y += (sin(((x * _36.frequency) * 2.099999904632568359375) + t) * 4.5);
    y += (sin(((x * _36.frequency) * 1.7200000286102294921875) + (t * 1.1210000514984130859375)) * 4.0);
    y += (sin(((x * _36.frequency) * 2.2209999561309814453125) + (t * 0.4370000064373016357421875)) * 5.0);
    y += (sin(((x * _36.frequency) * 3.1122000217437744140625) + (t * 4.26900005340576171875)) * 2.5);
    y *= (_36.amplitude * 0.02999999932944774627685546875);
    y += (0.5 + _36.offset);
    float y2 = y;
    float lowy = fast::min(y1, y2);
    float highy = fast::max(y1, y2);
    float b = _36.smoothing / 20.0;
    float p = fast::min(smoothstep(lowy - (b / 2.0), lowy + (b / 2.0), st.y), 1.0 - smoothstep(highy - (b / 2.0), highy + (b / 2.0), st.y));
    float4 mixedColor = mix(_36.color, _36.tintColor, float4(smoothstep(y1, y2, st.y) * _36.tint));
    float4 c = mixedColor * p;
    if (_36.punchout != 0u)
    {
        referenceColor = texColor * (1.0 - p);
    }
    else
    {
        c *= texColor.w;
        referenceColor = c + (texColor * (1.0 - c.w));
    }
}

fragment refAM35_efa58da681936_out refAM35_efa58da681936(constant ReferenceUniformsefa58da681936& _36 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_efa58da681936_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _36, referenceColor);
    bool _351 = any(isnan(referenceColor));
    bool _358;
    if (!_351)
    {
        _358 = any(isinf(referenceColor));
    }
    else
    {
        _358 = _351;
    }
    if (_358)
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

