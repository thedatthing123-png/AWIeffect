// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/lensflare.xml
// Original source comments and attribution:

#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse357c6c9c05a9
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float radius;
    char _m7_pad[12];
    float brightness;
    char _m8_pad[12];
    float shine;
    float4 color;
    float pointCount;
    char _m11_pad[12];
    float alpha;
    char _m12_pad[12];
    int blendMode;
};

struct refAM35_e357c6c9c05a9_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float bokeh(thread const float2& st, thread const float2& center, thread const float& r, thread const float& feather)
{
    return (smoothstep(r, r * (1.0 - feather), length(st - center)) - smoothstep(r * (1.0 - feather), r * (1.0 - (feather * 2.0)), length(st - center))) + (smoothstep(r, r * (1.0 - (feather * 2.0)), length(st - center)) * 1.6080000400543212890625);
}

static inline __attribute__((always_inline))
float combine(thread const float& p, thread const float& q)
{
    return p + q;
}

static inline __attribute__((always_inline))
float star(thread const float2& st, thread const float2& center, thread const float& r, thread const float& insideRadiusScale, thread const float& points)
{
    float2 dc = st - center;
    float ir = r * insideRadiusScale;
    float a = (precise::atan2(dc.x, dc.y) + 3.141590118408203125) / 2.0;
    float p = smoothstep(r, ir, length(dc));
    a = smoothstep(p, ir, abs(sin(a * points)));
    return fast::clamp((((p * 1.26400005817413330078125) + a) * p) * p, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float ring(thread const float2& st, thread const float2& center, thread const float& r, thread const float& feather)
{
    float dist = length(st - center);
    return (smoothstep(r, r * (1.0 - feather), length(st - center)) - smoothstep(r * (1.0 - feather), r * (1.0 - (feather * 2.0)), dist)) + ((smoothstep(0.0, r, dist) * 0.87999999523162841796875) * smoothstep(r + (feather / 2.0), r, dist));
}

static inline __attribute__((always_inline))
float smoothCircle(thread const float2& st, thread const float2& center, thread const float& r, thread const float& innerRad)
{
    return smoothstep(r, innerRad, length(st - center));
}

static inline __attribute__((always_inline))
float lensFlare(thread const float2& st, thread const float2& center, thread const float2& offset, thread const float& r, thread const float& shine, thread const float& points)
{
    float2 pos = offset;
    float2 offs = pos - center;
    float2 opp = center - offs;
    float dist = length(pos - center);
    float exposure = (1.0 - dist) + (0.5 * shine);
    exposure = 0.20000000298023223876953125 + (exposure * 0.800000011920928955078125);
    float p = 0.0;
    float2 param = st;
    float2 param_1 = mix(pos, opp, float2(1.1019999980926513671875));
    float param_2 = 0.120999999344348907470703125 * r;
    float param_3 = 0.2579999864101409912109375;
    float param_4 = p;
    float param_5 = bokeh(param, param_1, param_2, param_3) * 0.115999996662139892578125;
    p = combine(param_4, param_5);
    float2 param_6 = st;
    float2 param_7 = opp;
    float param_8 = 0.092000000178813934326171875 * r;
    float param_9 = 0.26800000667572021484375;
    float param_10 = p;
    float param_11 = bokeh(param_6, param_7, param_8, param_9) * 0.115999996662139892578125;
    p = combine(param_10, param_11);
    float2 param_12 = st;
    float2 param_13 = mix(pos, opp, float2(0.892000019550323486328125));
    float param_14 = 0.1319999992847442626953125 * r;
    float param_15 = 0.26800000667572021484375;
    float param_16 = p;
    float param_17 = bokeh(param_12, param_13, param_14, param_15) * 0.115999996662139892578125;
    p = combine(param_16, param_17);
    float2 param_18 = st;
    float2 param_19 = mix(pos, opp, float2(0.7400000095367431640625));
    float param_20 = 0.075999997556209564208984375 * r;
    float param_21 = 0.1480000019073486328125;
    float param_22 = p;
    float param_23 = bokeh(param_18, param_19, param_20, param_21) * 0.115999996662139892578125;
    p = combine(param_22, param_23);
    float2 param_24 = st;
    float2 param_25 = mix(pos, opp, float2(0.819999992847442626953125));
    float param_26 = 0.1640000045299530029296875 * r;
    float param_27 = (-0.62000000476837158203125) + (exposure * 0.100000001490116119384765625);
    float param_28 = points;
    float param_29 = p;
    float param_30 = (star(param_24, param_25, param_26, param_27, param_28) * 1.0) * exposure;
    p = combine(param_29, param_30);
    float2 param_31 = st;
    float2 param_32 = mix(pos, opp, float2(0.819999992847442626953125));
    float param_33 = 0.1640000045299530029296875 * r;
    float param_34 = (-0.62000000476837158203125) + (exposure * 0.100000001490116119384765625);
    float param_35 = points * 2.0;
    float param_36 = p;
    float param_37 = (star(param_31, param_32, param_33, param_34, param_35) * 0.439999997615814208984375) * exposure;
    p = combine(param_36, param_37);
    float2 param_38 = st;
    float2 param_39 = mix(pos, opp, float2(0.4280000030994415283203125));
    float param_40 = 0.0439999997615814208984375 * r;
    float param_41 = 0.1480000019073486328125;
    float param_42 = p;
    float param_43 = bokeh(param_38, param_39, param_40, param_41) * 0.115999996662139892578125;
    p = combine(param_42, param_43);
    float2 param_44 = st;
    float2 param_45 = mix(pos, opp, float2(0.4839999973773956298828125));
    float param_46 = 0.0280000008642673492431640625 * r;
    float param_47 = 0.26800000667572021484375;
    float param_48 = p;
    float param_49 = bokeh(param_44, param_45, param_46, param_47) * 0.115999996662139892578125;
    p = combine(param_48, param_49);
    float2 param_50 = st;
    float2 param_51 = mix(pos, opp, float2(0.56400001049041748046875));
    float param_52 = 0.0199999995529651641845703125 * r;
    float param_53 = 0.26800000667572021484375;
    float param_54 = p;
    float param_55 = bokeh(param_50, param_51, param_52, param_53) * 0.115999996662139892578125;
    p = combine(param_54, param_55);
    float2 param_56 = st;
    float2 param_57 = mix(pos, opp, float2(0.2759999930858612060546875));
    float param_58 = 0.0199999995529651641845703125 * r;
    float param_59 = 0.26800000667572021484375;
    float param_60 = p;
    float param_61 = bokeh(param_56, param_57, param_58, param_59) * 0.115999996662139892578125;
    p = combine(param_60, param_61);
    float2 param_62 = st;
    float2 param_63 = mix(pos, opp, float2(0.203999996185302734375));
    float param_64 = 0.075999997556209564208984375 * r;
    float param_65 = 0.22800000011920928955078125;
    float param_66 = p;
    float param_67 = bokeh(param_62, param_63, param_64, param_65) * 0.115999996662139892578125;
    p = combine(param_66, param_67);
    float2 param_68 = st;
    float2 param_69 = pos;
    float param_70 = 0.467999994754791259765625 * r;
    float param_71 = (-0.236000001430511474609375) + (exposure * 0.100000001490116119384765625);
    float param_72 = points;
    float param_73 = p;
    float param_74 = (star(param_68, param_69, param_70, param_71, param_72) * 5.032000064849853515625) * exposure;
    p = combine(param_73, param_74);
    float2 param_75 = st;
    float2 param_76 = pos + float2(0.0);
    float param_77 = (0.533999979496002197265625 * exposure) * r;
    float param_78 = 0.05200000107288360595703125;
    float param_79 = p;
    float param_80 = ring(param_75, param_76, param_77, param_78) * 0.296000003814697265625;
    p = combine(param_79, param_80);
    float2 param_81 = st;
    float2 param_82 = pos;
    float param_83 = 0.119999997317790985107421875 * r;
    float param_84 = 0.0500000007450580596923828125 * r;
    float param_85 = p;
    float param_86 = smoothCircle(param_81, param_82, param_83, param_84) * fast::max(0.20000000298023223876953125, 0.100000001490116119384765625 + exposure);
    p = combine(param_85, param_86);
    return p;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse357c6c9c05a9& _546, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _546.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 st = (gl_FragCoord.xy - _546.refLayer.xy) / _546.refLayer.zw;
    st.y = 1.0 - st.y;
    st -= float2(0.5);
    st.x *= (_546.refLayer.z / _546.refLayer.w);
    float2 param_1 = st;
    float2 param_2 = float2(0.0);
    float2 param_3 = _546.position / float2(1000.0);
    float param_4 = _546.radius;
    float param_5 = _546.shine * 0.99500000476837158203125;
    float param_6 = _546.pointCount;
    float p = lensFlare(param_1, param_2, param_3, param_4, param_5, param_6);
    float4 adjColor = fast::clamp(float4((mix(_546.color.xyz + float3(0.1500000059604644775390625), float3(1.0), float3(0.0500000007450580596923828125)) * p) * _546.brightness, 1.0), float4(0.0), float4(1.0)) * p;
    float4 result;
    if (_546.blendMode == 1)
    {
        result = float4((texColor.xyz / float3(texColor.w)) * adjColor.xyz, 1.0) * texColor.w;
    }
    else
    {
        if (_546.blendMode == 2)
        {
            result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - adjColor.xyz)), 1.0) * texColor.w;
        }
        else
        {
            result = adjColor * texColor.w;
            result = (texColor * (1.0 - result.w)) + result;
        }
    }
    referenceColor = mix(texColor, fast::clamp(result, float4(0.0), float4(1.0)), float4(_546.alpha));
}

fragment refAM35_e357c6c9c05a9_out refAM35_e357c6c9c05a9(constant ReferenceUniformse357c6c9c05a9& _546 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e357c6c9c05a9_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _546, referenceColor);
    bool _723 = any(isnan(referenceColor));
    bool _730;
    if (!_723)
    {
        _730 = any(isinf(referenceColor));
    }
    else
    {
        _730 = _723;
    }
    if (_730)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _743 = referenceColor;
    float3 _749 = fast::clamp(_743.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _749.x;
    referenceColor.y = _749.y;
    referenceColor.z = _749.z;
    out.finalColor = referenceColor;
    return out;
}

