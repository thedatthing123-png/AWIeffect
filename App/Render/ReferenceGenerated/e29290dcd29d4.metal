// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/crtemu.xml
// Original source comments and attribution:
// ---------- style colour grade ----------
// contrast
// saturation bias
// brightness bias
// bloom baked into the style (independent of Glow slider)
// ---------- geometry: glitches + TV border curve ----------
// wavy lines
// signal roll
// block displacement
// ---------- chromatic aberration (style + RGB-shift glitch) ----------
// ---------- signal ghost (faint horizontal echo: the CRT "double image" look) ----------
// px offset, normalised
// one echo (e.g. right / down)
// mirror echo (left / up)
// ---------- sharpness (unsharp mask) ----------
// ---------- glow / bloom (Glow slider + built-in style bloom) ----------
// ---------- PHOSPHOR GRID (RGB subpixel mask: Circle = dot/LED, Rectangle = aperture grille) ----------
// gate: structure shows across midtones, deep blacks stay clean
// width of one RGB triad; raise Grid Scale -> finer
// one subpixel column
// 0=R 1=G 2=B
// Phosphor Color controls subpixel saturation (avg brightness stays 1)
// Circle : round RGB dots (LED screen look)
// gaps never go fully black
// Rectangle : vertical RGB stripes (true CRT aperture grille)
// gap floor ~0.5
// brightness compensation for the gaps
// ---------- CRT LINES (horizontal scanlines, the CRT_LINE element) ----------
// 1 on the lit line, 0 in the gap
// brightness compensation
// ---------- style tint / contrast / brightness ----------
// ---------- exposure fix (base phosphor gain, trimmed by the slider) ----------
// ---------- vibrance (saturation, weighted to low-sat) ----------
// ---------- colorize (Style 10 exclusive hue shift) ----------
// ---------- noise / snow (static, only in the darkest portions) ----------
// ---------- COLOR SIGNAL BAR (rainbow strip, like the plugin's signal bar) ----------
// blue -> cyan -> green -> yellow -> red
// ---------- TV borders (rounded bezel + vignette) ----------
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

struct ReferenceUniformse29290dcd29d4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int style;
    char _m6_pad[12];
    int gridPattern;
    char _m7_pad[12];
    float gridStrength;
    char _m8_pad[12];
    float gridColor;
    char _m9_pad[12];
    float gridScale;
    char _m10_pad[12];
    float scanlines;
    char _m11_pad[12];
    float rgbSplit;
    char _m12_pad[12];
    float ghost;
    char _m13_pad[12];
    float ghostX;
    char _m14_pad[12];
    float ghostY;
    char _m15_pad[12];
    uint colorBar;
    char _m16_pad[12];
    int barPosition;
    char _m17_pad[12];
    float barHeight;
    char _m18_pad[12];
    float exposureFix;
    char _m19_pad[12];
    float noiseLevel;
    char _m20_pad[12];
    float vibrance;
    char _m21_pad[12];
    float sharpness;
    char _m22_pad[12];
    float glow;
    char _m23_pad[12];
    float colorize;
    char _m24_pad[12];
    int glitches;
    char _m25_pad[12];
    float glitchAmount;
    char _m26_pad[12];
    uint tvBorders;
    char _m27_pad[12];
    float borderCurve;
    char _m28_pad[12];
    float intensity;
};

struct refAM35_e29290dcd29d4_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float rnd(thread const float2& co)
{
    float dt = dot(co, float2(12.98980045318603515625, 78.233001708984375));
    return fract(sin(mod(dt, 3.1415927410125732421875)) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 barrelWarp(thread const float2& uv, thread const float2& center, thread const float& aspect, thread const float& k)
{
    float2 d = uv - center;
    d.x *= aspect;
    d *= (1.0 + ((k * dot(d, d)) * 2.0));
    d.x /= aspect;
    return center + d;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float luma(thread const float3& c)
{
    return dot(c, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse29290dcd29d4& _147, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 center = float2(_147.refLayer.x + (_147.refLayer.z * 0.5), (_147.refScreen.y - _147.refLayer.y) - (_147.refLayer.w * 0.5)) / _147.refScreen.xy;
    float aspect = _147.refScreen.x / _147.refScreen.y;
    float3 tint = float3(1.0);
    float3 glowTint = float3(1.0);
    float con = 1.059999942779541015625;
    float satB = 0.0;
    float brightB = 0.0;
    float styleAber = 0.006000000052154064178466796875;
    float styleGlow = 0.119999997317790985107421875;
    if (_147.style == 1)
    {
        tint = float3(1.0);
        con = 1.0499999523162841796875;
        satB = 0.0;
        glowTint = float3(1.0);
        styleAber = 0.004999999888241291046142578125;
        styleGlow = 0.100000001490116119384765625;
    }
    else
    {
        if (_147.style == 2)
        {
            tint = float3(1.08000004291534423828125, 1.0, 0.89999997615814208984375);
            con = 1.059999942779541015625;
            satB = 0.0599999986588954925537109375;
            glowTint = float3(1.10000002384185791015625, 0.949999988079071044921875, 0.800000011920928955078125);
            styleAber = 0.008000000379979610443115234375;
            styleGlow = 0.14000000059604644775390625;
        }
        else
        {
            if (_147.style == 3)
            {
                tint = float3(1.0);
                con = 1.2200000286102294921875;
                satB = -0.300000011920928955078125;
                glowTint = float3(1.0);
                styleAber = 0.0040000001899898052215576171875;
                styleGlow = 0.100000001490116119384765625;
            }
            else
            {
                if (_147.style == 4)
                {
                    tint = float3(0.89999997615814208984375, 1.0, 1.0499999523162841796875);
                    con = 1.10000002384185791015625;
                    satB = 0.100000001490116119384765625;
                    glowTint = float3(0.60000002384185791015625, 0.89999997615814208984375, 1.0);
                    styleAber = 0.0024999999441206455230712890625;
                    styleGlow = 0.300000011920928955078125;
                }
                else
                {
                    if (_147.style == 5)
                    {
                        tint = float3(1.0);
                        con = 1.059999942779541015625;
                        satB = 0.0;
                        glowTint = float3(1.0);
                        styleAber = 0.006000000052154064178466796875;
                        styleGlow = 0.100000001490116119384765625;
                    }
                    else
                    {
                        if (_147.style == 6)
                        {
                            tint = float3(0.699999988079071044921875, 1.17999994754791259765625, 0.800000011920928955078125);
                            con = 1.12000000476837158203125;
                            satB = 0.119999997317790985107421875;
                            glowTint = float3(0.300000011920928955078125, 1.10000002384185791015625, 0.4000000059604644775390625);
                            styleAber = 0.006000000052154064178466796875;
                            styleGlow = 0.3499999940395355224609375;
                        }
                        else
                        {
                            if (_147.style == 7)
                            {
                                tint = float3(1.12000000476837158203125, 0.85000002384185791015625, 1.10000002384185791015625);
                                con = 1.10000002384185791015625;
                                satB = 0.119999997317790985107421875;
                                glowTint = float3(1.10000002384185791015625, 0.4000000059604644775390625, 1.0);
                                styleAber = 0.0089999996125698089599609375;
                                styleGlow = 0.37999999523162841796875;
                            }
                            else
                            {
                                if (_147.style == 8)
                                {
                                    tint = float3(1.13999998569488525390625, 0.980000019073486328125, 0.7200000286102294921875);
                                    con = 1.03999996185302734375;
                                    satB = -0.180000007152557373046875;
                                    glowTint = float3(1.10000002384185791015625, 0.89999997615814208984375, 0.60000002384185791015625);
                                    styleAber = 0.006000000052154064178466796875;
                                    styleGlow = 0.1599999964237213134765625;
                                }
                                else
                                {
                                    if (_147.style == 9)
                                    {
                                        tint = float3(1.0);
                                        con = 1.34000003337860107421875;
                                        satB = 0.0500000007450580596923828125;
                                        glowTint = float3(1.0);
                                        styleAber = 0.006000000052154064178466796875;
                                        styleGlow = 0.119999997317790985107421875;
                                    }
                                    else
                                    {
                                        if (_147.style == 10)
                                        {
                                            tint = float3(0.7200000286102294921875, 1.019999980926513671875, 1.059999942779541015625);
                                            con = 1.12000000476837158203125;
                                            satB = 0.100000001490116119384765625;
                                            glowTint = float3(0.4000000059604644775390625, 1.0499999523162841796875, 1.0499999523162841796875);
                                            styleAber = 0.0089999996125698089599609375;
                                            styleGlow = 0.4000000059604644775390625;
                                        }
                                        else
                                        {
                                            if (_147.style == 11)
                                            {
                                                tint = float3(0.949999988079071044921875, 0.85000002384185791015625, 1.17999994754791259765625);
                                                con = 1.12000000476837158203125;
                                                satB = 0.100000001490116119384765625;
                                                glowTint = float3(0.699999988079071044921875, 0.4000000059604644775390625, 1.2000000476837158203125);
                                                styleAber = 0.00999999977648258209228515625;
                                                styleGlow = 0.4000000059604644775390625;
                                            }
                                            else
                                            {
                                                if (_147.style == 12)
                                                {
                                                    tint = float3(0.920000016689300537109375, 0.959999978542327880859375, 1.059999942779541015625);
                                                    con = 1.17999994754791259765625;
                                                    satB = 0.119999997317790985107421875;
                                                    brightB = 0.0500000007450580596923828125;
                                                    glowTint = float3(1.0, 0.60000002384185791015625, 1.0);
                                                    styleAber = 0.01200000010430812835693359375;
                                                    styleGlow = 0.5;
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
    float ga = _147.glitchAmount / 100.0;
    float2 suv = gl_FragCoord.xy / _147.refScreen.xy;
    if (_147.glitches == 2)
    {
        suv.x += ((ga * 0.02999999932944774627685546875) * sin(((gl_FragCoord.xy / _147.refScreen.xy).y * 130.0) + (_147.refScreen.z * 9.0)));
    }
    else
    {
        if (_147.glitches == 3)
        {
            suv.y = fract(suv.y - ((0.1500000059604644775390625 + (ga * 0.800000011920928955078125)) * _147.refScreen.z));
        }
        else
        {
            if (_147.glitches == 4)
            {
                float2 bc = floor((gl_FragCoord.xy / _147.refScreen.xy) * float2(18.0, 14.0));
                float2 param = bc + float2(floor(_147.refScreen.z * 12.0));
                float r = rnd(param);
                if (r > (1.0 - (ga * 0.60000002384185791015625)))
                {
                    float2 param_1 = bc + float2(1.7000000476837158203125);
                    suv.x += (((rnd(param_1) - 0.5) * ga) * 0.119999997317790985107421875);
                }
            }
        }
    }
    if (_147.tvBorders != 0u)
    {
        float2 param_2 = suv;
        float2 param_3 = center;
        float param_4 = aspect;
        float param_5 = _147.borderCurve;
        suv = barrelWarp(param_2, param_3, param_4, param_5);
    }
    float _468;
    if (_147.glitches == 1)
    {
        _468 = ga * 0.02500000037252902984619140625;
    }
    else
    {
        _468 = 0.0;
    }
    float aber = (styleAber * _147.rgbSplit) + _468;
    float2 ro = float2(aber, 0.0);
    float2 param_6 = gl_FragCoord.xy / _147.refScreen.xy;
    float4 orig = texture2DCv(refInput, refInputSmplr, param_6);
    float2 param_7 = suv + ro;
    float cr_ = texture2DCv(refInput, refInputSmplr, param_7).x;
    float2 param_8 = suv;
    float4 cg = texture2DCv(refInput, refInputSmplr, param_8);
    float2 param_9 = suv - ro;
    float cb_ = texture2DCv(refInput, refInputSmplr, param_9).z;
    float4 col = float4(cr_, cg.y, cb_, cg.w);
    if (_147.ghost > 0.001000000047497451305389404296875)
    {
        float2 goff = float2(_147.ghostX, _147.ghostY) / _147.refLayer.zw;
        float2 param_10 = suv + goff;
        float3 gh1 = texture2DCv(refInput, refInputSmplr, param_10).xyz;
        float2 param_11 = suv - goff;
        float3 gh2 = texture2DCv(refInput, refInputSmplr, param_11).xyz;
        float4 _548 = col;
        float3 _556 = fast::max(_548.xyz, fast::max(gh1, gh2) * _147.ghost);
        col.x = _556.x;
        col.y = _556.y;
        col.z = _556.z;
    }
    if (_147.sharpness > 0.5)
    {
        float sp = 0.001599999959580600261688232421875;
        float2 param_12 = suv + float2(sp, 0.0);
        float2 param_13 = suv - float2(sp, 0.0);
        float2 param_14 = suv + float2(0.0, sp);
        float2 param_15 = suv - float2(0.0, sp);
        float3 bl = ((texture2DCv(refInput, refInputSmplr, param_12).xyz + texture2DCv(refInput, refInputSmplr, param_13).xyz) + texture2DCv(refInput, refInputSmplr, param_14).xyz) + texture2DCv(refInput, refInputSmplr, param_15).xyz;
        bl *= 0.25;
        float4 _606 = col;
        float4 _615 = col;
        float3 _617 = _615.xyz + (((_606.xyz - bl) * (_147.sharpness / 100.0)) * 2.0);
        col.x = _617.x;
        col.y = _617.y;
        col.z = _617.z;
    }
    float gl = (_147.glow / 100.0) + styleGlow;
    if (gl > 0.001000000047497451305389404296875)
    {
        float d = 0.006000000052154064178466796875 + (gl * 0.01200000010430812835693359375);
        float2 param_16 = suv + float2(d, 0.0);
        float2 param_17 = suv - float2(d, 0.0);
        float2 param_18 = suv + float2(0.0, d);
        float2 param_19 = suv - float2(0.0, d);
        float2 param_20 = suv + (float2(d) * 0.699999988079071044921875);
        float2 param_21 = suv + (float2(-d, d) * 0.699999988079071044921875);
        float3 b = ((((texture2DCv(refInput, refInputSmplr, param_16).xyz + texture2DCv(refInput, refInputSmplr, param_17).xyz) + texture2DCv(refInput, refInputSmplr, param_18).xyz) + texture2DCv(refInput, refInputSmplr, param_19).xyz) + texture2DCv(refInput, refInputSmplr, param_20).xyz) + texture2DCv(refInput, refInputSmplr, param_21).xyz;
        b *= 0.16666667163372039794921875;
        float4 _705 = col;
        float3 _707 = _705.xyz + (((fast::max(b - float3(0.5), float3(0.0)) * glowTint) * gl) * 1.60000002384185791015625);
        col.x = _707.x;
        col.y = _707.y;
        col.z = _707.z;
    }
    if (_147.gridStrength > 0.001000000047497451305389404296875)
    {
        float3 param_22 = col.xyz;
        float gridAmt = mix(0.64999997615814208984375, 1.0, smoothstep(0.0, 0.119999997317790985107421875, luma(param_22)));
        float cell = fast::max(3.0, (_147.refLayer.z / 150.0) / _147.gridScale);
        float sub = cell / 3.0;
        float xpx = ((gl_FragCoord.xy - _147.refLayer.xy) / _147.refLayer.zw).x * _147.refLayer.z;
        float ypx = ((gl_FragCoord.xy - _147.refLayer.xy) / _147.refLayer.zw).y * _147.refLayer.w;
        float colIdx = floor(mod(xpx / sub, 3.0));
        float3 _778;
        if (colIdx < 0.5)
        {
            _778 = float3(1.0, 0.0, 0.0);
        }
        else
        {
            _778 = select(float3(0.0, 0.0, 1.0), float3(0.0, 1.0, 0.0), bool3(colIdx < 1.5));
        }
        float3 rgbmask = _778;
        rgbmask = mix(float3(1.0), rgbmask * 3.0, float3(_147.gridColor));
        float prof;
        if (_147.gridPattern == 0)
        {
            float dx = fract(xpx / sub) - 0.5;
            float dy = fract(ypx / cell) - 0.5;
            prof = 1.0 - smoothstep(0.300000011920928955078125, 0.62000000476837158203125, length(float2(dx, dy)));
            prof = 0.449999988079071044921875 + (0.550000011920928955078125 * prof);
        }
        else
        {
            prof = 0.5 + (0.5 * cos(6.283185482025146484375 * (fract(xpx / sub) - 0.5)));
            prof = 0.5 + (0.5 * prof);
        }
        prof /= 0.75;
        float4 _845 = col;
        float4 _847 = col;
        float3 _858 = mix(_845.xyz, (_847.xyz * rgbmask) * prof, float3(_147.gridStrength * gridAmt));
        col.x = _858.x;
        col.y = _858.y;
        col.z = _858.z;
    }
    if (_147.scanlines > 0.001000000047497451305389404296875)
    {
        float3 param_23 = col.xyz;
        float sgate = smoothstep(0.0500000007450580596923828125, 0.4000000059604644775390625, luma(param_23));
        float spitch = fast::max(2.0, (_147.refLayer.w / 220.0) * _147.gridScale);
        float ypx2 = ((gl_FragCoord.xy - _147.refLayer.xy) / _147.refLayer.zw).y * _147.refLayer.w;
        float sline = 0.5 + (0.5 * cos((6.283185482025146484375 * ypx2) / spitch));
        float4 _917 = col;
        float3 _919 = _917.xyz * (1.0 - (((_147.scanlines * 0.60000002384185791015625) * sgate) * (1.0 - sline)));
        col.x = _919.x;
        col.y = _919.y;
        col.z = _919.z;
        float4 _933 = col;
        float3 _935 = _933.xyz * (1.0 + ((_147.scanlines * 0.2199999988079071044921875) * sgate));
        col.x = _935.x;
        col.y = _935.y;
        col.z = _935.z;
    }
    float4 _943 = col;
    float3 _945 = _943.xyz * tint;
    col.x = _945.x;
    col.y = _945.y;
    col.z = _945.z;
    float4 _952 = col;
    float3 _962 = (((_952.xyz - float3(0.5)) * con) + float3(0.5)) + float3(brightB);
    col.x = _962.x;
    col.y = _962.y;
    col.z = _962.z;
    float4 _974 = col;
    float3 _976 = _974.xyz * powr(2.0, _147.exposureFix / 100.0);
    col.x = _976.x;
    col.y = _976.y;
    col.z = _976.z;
    float3 param_24 = col.xyz;
    float y = luma(param_24);
    float mx = fast::max(fast::max(col.x, col.y), col.z);
    float mn = fast::min(fast::min(col.x, col.y), col.z);
    float curSat = mx - mn;
    float v = _147.vibrance / 100.0;
    float amt = (v * (1.0 - (curSat * 0.699999988079071044921875))) + satB;
    float4 _1025 = col;
    float3 _1033 = fast::clamp(mix(float3(y), _1025.xyz, float3(1.0 + amt)), float3(0.0), float3(1.0));
    col.x = _1033.x;
    col.y = _1033.y;
    col.z = _1033.z;
    if (_147.style == 10)
    {
        float a = (_147.colorize / 360.0) * 6.283185482025146484375;
        float3 k = float3(0.57735002040863037109375);
        float cs = cos(a);
        float4 _1058 = col;
        float4 _1063 = col;
        float4 _1072 = col;
        float3 _1079 = ((_1058.xyz * cs) + (cross(k, _1063.xyz) * sin(a))) + ((k * dot(k, _1072.xyz)) * (1.0 - cs));
        col.x = _1079.x;
        col.y = _1079.y;
        col.z = _1079.z;
        float4 _1086 = col;
        float3 _1090 = fast::clamp(_1086.xyz, float3(0.0), float3(1.0));
        col.x = _1090.x;
        col.y = _1090.y;
        col.z = _1090.z;
    }
    if (_147.noiseLevel > 0.5)
    {
        float3 param_25 = col.xyz;
        float darkGate = 1.0 - smoothstep(0.0199999995529651641845703125, 0.3499999940395355224609375, luma(param_25));
        float ns = ((_147.noiseLevel / 10.0) * 0.3499999940395355224609375) * darkGate;
        float2 np = floor((((gl_FragCoord.xy - _147.refLayer.xy) / _147.refLayer.zw) * _147.refLayer.zw) / float2(2.0));
        float2 param_26 = np + float2(floor(_147.refScreen.z * 24.0));
        float n = rnd(param_26);
        float4 _1148 = col;
        float _1153 = col.w;
        float3 _1157 = mix(_1148.xyz, float3(n) * _1153, float3(ns));
        col.x = _1157.x;
        col.y = _1157.y;
        col.z = _1157.z;
    }
    bool _1167 = _147.colorBar != 0u;
    bool _1174;
    if (_1167)
    {
        _1174 = _147.barHeight > 0.001000000047497451305389404296875;
    }
    else
    {
        _1174 = _1167;
    }
    if (_1174)
    {
        float yN = ((gl_FragCoord.xy - _147.refLayer.xy) / _147.refLayer.zw).y;
        float _1194;
        if (_147.barPosition == 0)
        {
            _1194 = step(yN, _147.barHeight);
        }
        else
        {
            _1194 = step(1.0 - _147.barHeight, yN);
        }
        float inBar = _1194;
        if (inBar > 0.5)
        {
            float hue = fast::max(0.0, 0.666999995708465576171875 * (1.0 - (((gl_FragCoord.xy - _147.refLayer.xy) / _147.refLayer.zw).x / 0.75)));
            float3 param_27 = float3(hue, 1.0, 1.0);
            float3 _1232 = hsv2rgb(param_27);
            col.x = _1232.x;
            col.y = _1232.y;
            col.z = _1232.z;
        }
    }
    if (_147.tvBorders != 0u)
    {
        float2 param_28 = (gl_FragCoord.xy - _147.refLayer.xy) / _147.refLayer.zw;
        float2 param_29 = float2(0.5);
        float param_30 = aspect;
        float param_31 = _147.borderCurve;
        float2 dluv = barrelWarp(param_28, param_29, param_30, param_31);
        float2 q = abs(dluv - float2(0.5)) * 2.0;
        float crad = 0.07999999821186065673828125;
        float2 dd = fast::max(q - float2(1.0 - crad), float2(0.0));
        dd.x *= aspect;
        float edgeMask = 1.0 - smoothstep(crad, crad + 0.0199999995529651641845703125, length(dd));
        float inside = ((step(0.0, dluv.x) * step(dluv.x, 1.0)) * step(0.0, dluv.y)) * step(dluv.y, 1.0);
        col *= (edgeMask * inside);
        float2 vq = (dluv - float2(0.5)) * 2.0;
        float4 _1325 = col;
        float3 _1327 = _1325.xyz * (1.0 - (0.3499999940395355224609375 * smoothstep(0.4000000059604644775390625, 1.7000000476837158203125, dot(vq, vq))));
        col.x = _1327.x;
        col.y = _1327.y;
        col.z = _1327.z;
    }
    float4 _1334 = col;
    float3 _1338 = fast::clamp(_1334.xyz, float3(0.0), float3(1.0));
    col.x = _1338.x;
    col.y = _1338.y;
    col.z = _1338.z;
    referenceColor = mix(orig, col, float4(_147.intensity));
}

fragment refAM35_e29290dcd29d4_out refAM35_e29290dcd29d4(constant ReferenceUniformse29290dcd29d4& _147 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e29290dcd29d4_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_147, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1359 = any(isnan(referenceColor));
    bool _1366;
    if (!_1359)
    {
        _1366 = any(isinf(referenceColor));
    }
    else
    {
        _1366 = _1359;
    }
    if (_1366)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1379 = referenceColor;
    float3 _1385 = fast::clamp(_1379.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1385.x;
    referenceColor.y = _1385.y;
    referenceColor.z = _1385.z;
    out.finalColor = referenceColor;
    return out;
}

