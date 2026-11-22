// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxshsl.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
// gray
//////////////////////////
/////////////////////////
// adjust each channel
// adjust hue
// adjust saturation
// TODO：移到业务层
// adjust brightness
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsebdacb4cdd872
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float rex;
    char _m6_pad[12];
    float rey;
    char _m7_pad[12];
    float rez;
    char _m8_pad[12];
    float orx;
    char _m9_pad[12];
    float ory;
    char _m10_pad[12];
    float orz;
    char _m11_pad[12];
    float yex;
    char _m12_pad[12];
    float yey;
    char _m13_pad[12];
    float yez;
    char _m14_pad[12];
    float grx;
    char _m15_pad[12];
    float gry;
    char _m16_pad[12];
    float grz;
    char _m17_pad[12];
    float cyx;
    char _m18_pad[12];
    float cyy;
    char _m19_pad[12];
    float cyz;
    char _m20_pad[12];
    float blx;
    char _m21_pad[12];
    float bly;
    char _m22_pad[12];
    float blz;
    char _m23_pad[12];
    float pux;
    char _m24_pad[12];
    float puy;
    char _m25_pad[12];
    float puz;
    char _m26_pad[12];
    float maxx;
    char _m27_pad[12];
    float may;
    char _m28_pad[12];
    float maz;
    char _m29_pad[12];
    float bright;
    char _m30_pad[12];
    float alpha;
    char _m31_pad[12];
    int blendMode;
};

struct refAM35_ebdacb4cdd872_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 RGB2HSL(thread const float3& rgb)
{
    float h = 0.0;
    float s = 0.0;
    float l = 0.0;
    float r = rgb.x;
    float g = rgb.y;
    float b = rgb.z;
    float cmax = fast::max(r, fast::max(g, b));
    float cmin = fast::min(r, fast::min(g, b));
    float delta = cmax - cmin;
    l = (cmax + cmin) / 2.0;
    if (delta == 0.0)
    {
        s = 0.0;
        h = 0.0;
    }
    else
    {
        if (l <= 0.5)
        {
            s = delta / (cmax + cmin);
        }
        else
        {
            s = delta / (2.0 - (cmax + cmin));
        }
        if (cmax == r)
        {
            if (g >= b)
            {
                h = (60.0 * (g - b)) / delta;
            }
            else
            {
                h = ((60.0 * (g - b)) / delta) + 360.0;
            }
        }
        else
        {
            if (cmax == g)
            {
                h = ((60.0 * (b - r)) / delta) + 120.0;
            }
            else
            {
                h = ((60.0 * (r - g)) / delta) + 240.0;
            }
        }
    }
    return float3(h, s, l);
}

static inline __attribute__((always_inline))
float3 pixel_adjust(thread const float& h, thread const float& hue, thread const float& saturation, thread const float& brightness, thread const float& left_left, thread const float& left, thread const float& right, thread const float& right_right, thread float3& delta_hsb)
{
    if (((left_left < left) && (left > right)) && (right < right_right))
    {
        if ((h >= left) && (h <= 360.0))
        {
            delta_hsb.x += hue;
            delta_hsb.y += saturation;
            delta_hsb.z += brightness;
            return delta_hsb;
        }
        if ((h >= 0.0) && (h <= right))
        {
            delta_hsb.x += hue;
            delta_hsb.y += saturation;
            delta_hsb.z += brightness;
            return delta_hsb;
        }
        if ((h >= left_left) && (h <= left))
        {
            delta_hsb.x += ((hue * (h - left_left)) / (left - left_left));
            delta_hsb.y += ((saturation * (h - left_left)) / (left - left_left));
            delta_hsb.z += ((brightness * (h - left_left)) / (left - left_left));
            return delta_hsb;
        }
        if ((h >= right) && (h <= right_right))
        {
            delta_hsb.x += ((hue * (right_right - h)) / (right_right - right));
            delta_hsb.y += ((saturation * (right_right - h)) / (right_right - right));
            delta_hsb.z += ((brightness * (right_right - h)) / (right_right - right));
            return delta_hsb;
        }
    }
    if (((left_left > left) && (left < right)) && (right < right_right))
    {
        if ((h >= left) && (h <= right))
        {
            delta_hsb.x += hue;
            delta_hsb.y += saturation;
            delta_hsb.z += brightness;
            return delta_hsb;
        }
        if ((h >= 0.0) && (h <= left))
        {
            delta_hsb.x += ((hue * ((h + 360.0) - left_left)) / ((left + 360.0) - left_left));
            delta_hsb.y += ((saturation * ((h + 360.0) - left_left)) / ((left + 360.0) - left_left));
            delta_hsb.z += ((brightness * ((h + 360.0) - left_left)) / ((left + 360.0) - left_left));
            return delta_hsb;
        }
        if ((h >= left_left) && (h <= 360.0))
        {
            delta_hsb.x += ((hue * (h - left_left)) / ((left + 360.0) - left_left));
            delta_hsb.y += ((saturation * (h - left_left)) / ((left + 360.0) - left_left));
            delta_hsb.z += ((brightness * (h - left_left)) / ((left + 360.0) - left_left));
            return delta_hsb;
        }
        if ((h >= right) && (h <= right_right))
        {
            delta_hsb.x += ((hue * (right_right - h)) / (right_right - right));
            delta_hsb.y += ((saturation * (right_right - h)) / (right_right - right));
            delta_hsb.z += ((brightness * (right_right - h)) / (right_right - right));
            return delta_hsb;
        }
    }
    if (((left_left <= left) && (left < right)) && (right <= right_right))
    {
        if ((h >= left) && (h <= right))
        {
            delta_hsb.x += hue;
            delta_hsb.y += saturation;
            delta_hsb.z += brightness;
            return delta_hsb;
        }
        if ((h >= left_left) && (h <= left))
        {
            delta_hsb.x += ((hue * (h - left_left)) / (left - left_left));
            delta_hsb.y += ((saturation * (h - left_left)) / (left - left_left));
            delta_hsb.z += ((brightness * (h - left_left)) / (left - left_left));
            return delta_hsb;
        }
        if ((h >= right) && (h <= right_right))
        {
            delta_hsb.x += ((hue * (right_right - h)) / (right_right - right));
            delta_hsb.y += ((saturation * (right_right - h)) / (right_right - right));
            delta_hsb.z += ((brightness * (right_right - h)) / (right_right - right));
            return delta_hsb;
        }
    }
    if (((left_left < left) && (left < right)) && (right > right_right))
    {
        if ((h >= left) && (h <= right))
        {
            delta_hsb.x += hue;
            delta_hsb.y += saturation;
            delta_hsb.z += brightness;
            return delta_hsb;
        }
        if ((h >= left_left) && (h <= left))
        {
            delta_hsb.x += ((hue * (h - left_left)) / (left - left_left));
            delta_hsb.y += ((saturation * (h - left_left)) / (left - left_left));
            delta_hsb.z += ((brightness * (h - left_left)) / (left - left_left));
            return delta_hsb;
        }
        if ((h >= right) && (h <= 360.0))
        {
            delta_hsb.x += ((hue * ((right_right + 360.0) - h)) / ((right_right + 360.0) - right));
            delta_hsb.y += ((saturation * ((right_right + 360.0) - h)) / ((right_right + 360.0) - right));
            delta_hsb.z += ((brightness * ((right_right + 360.0) - h)) / ((right_right + 360.0) - right));
            return delta_hsb;
        }
        if ((h >= 0.0) && (h <= right_right))
        {
            delta_hsb.x += ((hue * (right_right - h)) / ((right_right + 360.0) - right));
            delta_hsb.y += ((saturation * (right_right - h)) / ((right_right + 360.0) - right));
            delta_hsb.z += ((brightness * (right_right - h)) / ((right_right + 360.0) - right));
            return delta_hsb;
        }
    }
    return delta_hsb;
}

static inline __attribute__((always_inline))
float hueToRgb(thread const float& p, thread const float& q, thread float& t)
{
    if (t < 0.0)
    {
        t += 1.0;
    }
    if (t > 1.0)
    {
        t -= 1.0;
    }
    if (t < 0.16666667163372039794921875)
    {
        return p + (((q - p) * 6.0) * t);
    }
    if (t < 0.5)
    {
        return q;
    }
    if (t < 0.666666686534881591796875)
    {
        return p + (((q - p) * (0.666666686534881591796875 - t)) * 6.0);
    }
    return p;
}

static inline __attribute__((always_inline))
float3 HSL2RGB(thread const float3& hsl)
{
    float h = hsl.x / 360.0;
    float r;
    float g;
    float b;
    if (hsl.y == 0.0)
    {
        b = hsl.z;
        g = hsl.z;
        r = hsl.z;
    }
    else
    {
        float _240;
        if (hsl.z < 0.5)
        {
            _240 = hsl.z * (1.0 + hsl.y);
        }
        else
        {
            _240 = (hsl.z + hsl.y) - (hsl.z * hsl.y);
        }
        float q = _240;
        float p = (2.0 * hsl.z) - q;
        float param = p;
        float param_1 = q;
        float param_2 = h + 0.3333333432674407958984375;
        float _276 = hueToRgb(param, param_1, param_2);
        r = _276;
        float param_3 = p;
        float param_4 = q;
        float param_5 = h;
        float _283 = hueToRgb(param_3, param_4, param_5);
        g = _283;
        float param_6 = p;
        float param_7 = q;
        float param_8 = h - 0.3333333432674407958984375;
        float _291 = hueToRgb(param_6, param_7, param_8);
        b = _291;
    }
    return float3(r, g, b);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsebdacb4cdd872& _999, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_999.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _999.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_999.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _999.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 syamjaidtz = gl_FragCoord.xy / _999.refScreen.xy;
            float3 RedHSL = float3(_999.rex * 0.25, _999.rey, _999.rez / 2.7000000476837158203125);
            float3 OrangeHSL = float3(_999.orx * 0.1500000059604644775390625, _999.ory, _999.orz / 2.7000000476837158203125);
            float3 YellowHSL = float3(_999.yex * 0.300000011920928955078125, _999.yey, _999.yez / 2.7000000476837158203125);
            float3 GreenHSL = float3(_999.grx * 0.300000011920928955078125, _999.gry * 1.10000002384185791015625, _999.grz / 2.7000000476837158203125);
            float3 CyanHSL = float3(_999.cyx * 0.4000000059604644775390625, _999.cyy, _999.cyz / 2.2000000476837158203125);
            float3 BlueHSL = float3(_999.blx * 0.4000000059604644775390625, _999.bly * 1.2000000476837158203125, _999.blz / 2.0);
            float3 PurpleHSL = float3(_999.pux * 0.4000000059604644775390625, _999.puy, _999.puz / 2.7000000476837158203125);
            float3 MagentaHSL = float3(_999.maxx * 0.4000000059604644775390625, _999.may, _999.maz / 2.7000000476837158203125);
            float2 param_2 = syamjaidtz;
            float4 baseColor = texture2DCv(refInput, refInputSmplr, param_2);
            float3 clO = baseColor.xyz;
            float3 param_3 = clO;
            float3 hsb = RGB2HSL(param_3);
            float3 delta_hsb = float3(0.0);
            float param_4 = hsb.x;
            float param_5 = RedHSL.x;
            float param_6 = RedHSL.y;
            float param_7 = RedHSL.z;
            float param_8 = 315.0;
            float param_9 = 330.0;
            float param_10 = 5.0;
            float param_11 = 20.0;
            float3 param_12 = delta_hsb;
            float3 _1203 = pixel_adjust(param_4, param_5, param_6, param_7, param_8, param_9, param_10, param_11, param_12);
            delta_hsb = _1203;
            float param_13 = hsb.x;
            float param_14 = OrangeHSL.x;
            float param_15 = OrangeHSL.y;
            float param_16 = OrangeHSL.z;
            float param_17 = 350.0;
            float param_18 = 20.0;
            float param_19 = 40.0;
            float param_20 = 60.0;
            float3 param_21 = delta_hsb;
            float3 _1224 = pixel_adjust(param_13, param_14, param_15, param_16, param_17, param_18, param_19, param_20, param_21);
            delta_hsb = _1224;
            float param_22 = hsb.x;
            float param_23 = YellowHSL.x;
            float param_24 = YellowHSL.y;
            float param_25 = YellowHSL.z;
            float param_26 = 25.0;
            float param_27 = 50.0;
            float param_28 = 70.0;
            float param_29 = 90.0;
            float3 param_30 = delta_hsb;
            float3 _1247 = pixel_adjust(param_22, param_23, param_24, param_25, param_26, param_27, param_28, param_29, param_30);
            delta_hsb = _1247;
            float param_31 = hsb.x;
            float param_32 = GreenHSL.x;
            float param_33 = GreenHSL.y;
            float param_34 = GreenHSL.z;
            float param_35 = 50.0;
            float param_36 = 70.0;
            float param_37 = 160.0;
            float param_38 = 190.0;
            float3 param_39 = delta_hsb;
            float3 _1268 = pixel_adjust(param_31, param_32, param_33, param_34, param_35, param_36, param_37, param_38, param_39);
            delta_hsb = _1268;
            float param_40 = hsb.x;
            float param_41 = CyanHSL.x;
            float param_42 = CyanHSL.y;
            float param_43 = CyanHSL.z;
            float param_44 = 135.0;
            float param_45 = 165.0;
            float param_46 = 195.0;
            float param_47 = 225.0;
            float3 param_48 = delta_hsb;
            float3 _1291 = pixel_adjust(param_40, param_41, param_42, param_43, param_44, param_45, param_46, param_47, param_48);
            delta_hsb = _1291;
            float param_49 = hsb.x;
            float param_50 = BlueHSL.x;
            float param_51 = 0.0;
            float param_52 = 0.0;
            float param_53 = 145.0;
            float param_54 = 180.0;
            float param_55 = 235.0;
            float param_56 = 275.0;
            float3 param_57 = delta_hsb;
            float3 _1310 = pixel_adjust(param_49, param_50, param_51, param_52, param_53, param_54, param_55, param_56, param_57);
            delta_hsb = _1310;
            float param_58 = hsb.x;
            float param_59 = 0.0;
            float param_60 = BlueHSL.y;
            float param_61 = BlueHSL.z;
            float param_62 = 145.0;
            float param_63 = 180.0;
            float param_64 = 235.0;
            float param_65 = 270.0;
            float3 param_66 = delta_hsb;
            float3 _1328 = pixel_adjust(param_58, param_59, param_60, param_61, param_62, param_63, param_64, param_65, param_66);
            delta_hsb = _1328;
            float param_67 = hsb.x;
            float param_68 = PurpleHSL.x;
            float param_69 = PurpleHSL.y;
            float param_70 = PurpleHSL.z;
            float param_71 = 235.0;
            float param_72 = 255.0;
            float param_73 = 315.0;
            float param_74 = 335.0;
            float3 param_75 = delta_hsb;
            float3 _1349 = pixel_adjust(param_67, param_68, param_69, param_70, param_71, param_72, param_73, param_74, param_75);
            delta_hsb = _1349;
            float param_76 = hsb.x;
            float param_77 = MagentaHSL.x;
            float param_78 = MagentaHSL.y;
            float param_79 = MagentaHSL.z;
            float param_80 = 255.0;
            float param_81 = 285.0;
            float param_82 = 335.0;
            float param_83 = 5.0;
            float3 param_84 = delta_hsb;
            float3 _1369 = pixel_adjust(param_76, param_77, param_78, param_79, param_80, param_81, param_82, param_83, param_84);
            delta_hsb = _1369;
            hsb.x += delta_hsb.x;
            for (float j = 0.100000001490116119384765625; j >= 0.0; j += 1.0)
            {
                if (hsb.x > 360.0)
                {
                    hsb.x -= 360.0;
                }
                if (hsb.x < 0.0)
                {
                    hsb.x += 360.0;
                }
                bool _1405 = hsb.x <= 360.0;
                bool _1411;
                if (_1405)
                {
                    _1411 = hsb.x >= 0.0;
                }
                else
                {
                    _1411 = _1405;
                }
                if (_1411)
                {
                    break;
                }
            }
            delta_hsb.y = fast::clamp(delta_hsb.y / 100.0, -1.0, 1.0);
            if (delta_hsb.y < 0.0)
            {
                hsb.y *= (1.0 + delta_hsb.y);
            }
            else
            {
                delta_hsb.y /= 2.0;
                float temp = hsb.y * (1.0 - delta_hsb.y);
                hsb.y += (hsb.y - temp);
            }
            delta_hsb.z = fast::clamp(delta_hsb.z / 100.0, -1.0, 1.0);
            if (delta_hsb.z <= 0.0)
            {
                float radio = hsb.y;
                if (hsb.z >= 0.5)
                {
                    radio = hsb.y * 1.0;
                }
                if (hsb.z < 0.5)
                {
                    radio = (hsb.y * 2.0) * hsb.z;
                }
                float temp_1 = hsb.z - ((radio * (1.0 - hsb.z)) * delta_hsb.z);
                hsb.z += (hsb.z - temp_1);
            }
            else
            {
                float radio_1 = hsb.y;
                if (hsb.z >= 0.5)
                {
                    radio_1 = hsb.y * 1.0;
                }
                if (hsb.z < 0.5)
                {
                    radio_1 = (hsb.y * 2.0) * hsb.z;
                }
                delta_hsb.z = (1.0 - delta_hsb.y) * delta_hsb.z;
                hsb.z += ((radio_1 * (1.14999997615814208984375 - hsb.z)) * delta_hsb.z);
            }
            hsb.y = fast::clamp(hsb.y, 0.0, 1.0);
            hsb.z = fast::clamp(hsb.z, 0.0, 1.0);
            float3 param_85 = hsb;
            clO = HSL2RGB(param_85);
            float4 fragColor = float4(clO, baseColor.w);
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float4 resultfinal;
            if (_999.blendMode == 0)
            {
                resultfinal = (factor * _999.bright) * texColor.w;
            }
            else
            {
                if (_999.blendMode == 1)
                {
                    factor *= _999.bright;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_999.blendMode == 2)
                    {
                        factor *= _999.bright;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_999.alpha));
        }
    }
}

fragment refAM35_ebdacb4cdd872_out refAM35_ebdacb4cdd872(constant ReferenceUniformsebdacb4cdd872& _999 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ebdacb4cdd872_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_999, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _1669 = any(isnan(referenceColor));
    bool _1676;
    if (!_1669)
    {
        _1676 = any(isinf(referenceColor));
    }
    else
    {
        _1676 = _1669;
    }
    if (_1676)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1689 = referenceColor;
    float3 _1695 = fast::clamp(_1689.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1695.x;
    referenceColor.y = _1695.y;
    referenceColor.z = _1695.z;
    out.finalColor = referenceColor;
    return out;
}

