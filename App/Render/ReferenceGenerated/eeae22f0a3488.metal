// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxedgeline.xml
// Original source comments and attribution:
// if (mix) {
// vec4 mixresult = 1.0-(1.0-texColor)*(1.0-edgeLine);
// edgeNew = mix(texColor,mixresult,1.0) * texColor.a; }
// else {
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseeae22f0a3488
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float smoothing;
    char _m6_pad[12];
    float threshold;
    char _m7_pad[12];
    float amp;
    char _m8_pad[12];
    float alpha;
    float4 color2;
    float4 color1;
    int blendMode;
    char _m12_pad[12];
    uint fix;
    char _m13_pad[12];
    uint newMode;
    char _m14_pad[12];
    uint invert;
};

struct refAM35_eeae22f0a3488_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformseeae22f0a3488& _42, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 st = gl_FragCoord.xy / _42.refScreen.xy;
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 fragSize = (float2(1.0) / getTexSize(param)) * _42.smoothing;
    float2 param_1 = float2((gl_FragCoord.xy / _42.refScreen.xy).x - fragSize.x, (gl_FragCoord.xy / _42.refScreen.xy).y);
    float w = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_1).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_2 = float2((gl_FragCoord.xy / _42.refScreen.xy).x + fragSize.x, (gl_FragCoord.xy / _42.refScreen.xy).y);
    float e = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_2).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_3 = float2((gl_FragCoord.xy / _42.refScreen.xy).x, (gl_FragCoord.xy / _42.refScreen.xy).y + fragSize.y);
    float n = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_3).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_4 = float2((gl_FragCoord.xy / _42.refScreen.xy).x, (gl_FragCoord.xy / _42.refScreen.xy).y - fragSize.y);
    float s = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_4).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_5 = float2((gl_FragCoord.xy / _42.refScreen.xy).x - fragSize.x, (gl_FragCoord.xy / _42.refScreen.xy).y + fragSize.y);
    float nw = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_5).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_6 = float2((gl_FragCoord.xy / _42.refScreen.xy).x + fragSize.x, (gl_FragCoord.xy / _42.refScreen.xy).y + fragSize.y);
    float ne = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_6).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_7 = float2((gl_FragCoord.xy / _42.refScreen.xy).x - fragSize.x, (gl_FragCoord.xy / _42.refScreen.xy).y - fragSize.y);
    float sw = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_7).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float2 param_8 = float2((gl_FragCoord.xy / _42.refScreen.xy).x + fragSize.x, (gl_FragCoord.xy / _42.refScreen.xy).y - fragSize.y);
    float se = dot(float3(1.0), texture2DCv(refInput, refInputSmplr, param_8).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float v = (((((nw * 3.0) + (n * 10.0)) + (ne * 3.0)) + (sw * (-3.0))) + (s * (-10.0))) + (se * (-3.0));
    float h = (((((nw * (-3.0)) + (w * (-10.0))) + (sw * (-3.0))) + (ne * 3.0)) + (e * 10.0)) + (se * 3.0);
    float2 param_9 = gl_FragCoord.xy / _42.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_9);
    if (_42.fix != 0u)
    {
        v *= v;
        h *= h;
    }
    v *= _42.amp;
    h *= _42.amp;
    float g = fast::clamp(sqrt((h * h) + (v * v)) - _42.threshold, 0.0, 1.0);
    float edge = sqrt((h * h) + (v * v));
    float4 keyColor = float4(1.0);
    float4 colour = float4(edge * keyColor.x, edge * keyColor.y, edge * keyColor.z, 1.0);
    float4 edgeLine = (fast::clamp(colour - float4(_42.threshold), float4(0.0), float4(1.0)) * 1.0) / float4(1.0 - _42.threshold);
    float4 edgeNew = float4(1.0 - edgeLine.x, 1.0 - edgeLine.y, 1.0 - edgeLine.z, edgeLine.w) * texColor.w;
    float luminance = dot(edgeNew.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 edgeFinal = mix(_42.color1, _42.color2, float4(luminance)) * edgeNew.w;
    float4 xnxx = edgeFinal;
    float4 edgeNewFinal;
    float4 edgeOld;
    if (_42.invert != 0u)
    {
        edgeNewFinal = float4(1.0 - xnxx.x, 1.0 - xnxx.y, 1.0 - xnxx.z, xnxx.w) * texColor.w;
        edgeOld = float4(g, g, g, 1.0) * texColor;
    }
    else
    {
        edgeNewFinal = edgeFinal * texColor.w;
        edgeOld = float4(1.0 - g, 1.0 - g, 1.0 - g, 1.0) * texColor.w;
    }
    float4 factor = select(edgeOld, edgeNewFinal, bool4(_42.newMode != 0u));
    float4 resultfinal;
    if (_42.blendMode == 0)
    {
        resultfinal = factor * texColor.w;
    }
    else
    {
        if (_42.blendMode == 1)
        {
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_42.blendMode == 2)
            {
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_42.alpha));
}

fragment refAM35_eeae22f0a3488_out refAM35_eeae22f0a3488(constant ReferenceUniformseeae22f0a3488& _42 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eeae22f0a3488_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _42, refInput, refInputSmplr, referenceColor);
    bool _580 = any(isnan(referenceColor));
    bool _587;
    if (!_580)
    {
        _587 = any(isinf(referenceColor));
    }
    else
    {
        _587 = _580;
    }
    if (_587)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _600 = referenceColor;
    float3 _606 = fast::clamp(_600.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _606.x;
    referenceColor.y = _606.y;
    referenceColor.z = _606.z;
    out.finalColor = referenceColor;
    return out;
}

