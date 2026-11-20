// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/warp+.xml
// Original source comments and attribution:
// ═══ CORE WARP FUNCTIONS ═══
// Fisheye — barrel with spherical projection
// Anti-fisheye — pincushion inverse of fisheye
// Barrel distortion — polynomial lens warp
// Pincushion — inverse barrel
// Bulge — expand center outward
// Bullseye — concentric ring distortion
// Upper shell — warp only top half
// Lower shell — warp only bottom half
// Spherize — map onto sphere surface
// Twirl — rotation that decreases with distance
// Wave — sinusoidal displacement
// Ripple — concentric wave from center
// Warp center from point param
// Center-relative coordinates with aspect correction
// ═══ APPLY WARP MODE ═══
// ═══ BEND ═══
// ═══ K DISTORTION (on top of mode) ═══
// Undo aspect correction
// Back to UV space
// ═══ CHROMATIC WARP ═══
// Sample each channel at slightly different warp amounts
// ═══ MIX ═══
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

struct ReferenceUniformse46a11ff71be9
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int warpMode;
    char _m6_pad[12];
    float warpAmount;
    char _m7_pad[12];
    float warpRadius;
    char _m8_pad[12];
    float warpSoftness;
    char _m9_pad[8];
    float2 warpCenter;
    char _m10_pad[8];
    float bendX;
    char _m11_pad[12];
    float bendY;
    char _m12_pad[12];
    float bendUniform;
    char _m13_pad[12];
    float k1;
    char _m14_pad[12];
    float k2;
    char _m15_pad[12];
    float k3;
    char _m16_pad[12];
    float twirlAngle;
    char _m17_pad[12];
    float twirlRadius;
    char _m18_pad[12];
    float waveAmplitude;
    char _m19_pad[12];
    float waveFrequency;
    char _m20_pad[12];
    float wavePhase;
    char _m21_pad[12];
    float waveAngle;
    char _m22_pad[12];
    float waveSpeed;
    char _m23_pad[12];
    float rippleAmplitude;
    char _m24_pad[12];
    float rippleFrequency;
    char _m25_pad[12];
    float ripplePhase;
    char _m26_pad[12];
    float rippleDecay;
    char _m27_pad[12];
    float rippleSpeed;
    char _m28_pad[12];
    float aspectX;
    char _m29_pad[12];
    float aspectY;
    char _m30_pad[12];
    float chromaWarp;
    char _m31_pad[12];
    int edgeMode;
    char _m32_pad[12];
    float globalMix;
};

struct refAM35_e46a11ff71be9_out
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
float2 warpFisheye(thread const float2& p, thread const float& amount, thread const float& radius, thread const float& softness)
{
    float dist = length(p);
    float r = radius * 0.5;
    if (dist < 9.9999997473787516355514526367188e-06)
    {
        return p;
    }
    float amt = amount / 100.0;
    float normDist = dist / fast::max(r, 9.9999997473787516355514526367188e-06);
    float power = 1.0 + (amt * 2.0);
    float warpedDist = powr(normDist, power) * r;
    float blend = smoothstep(r, r * (1.0 - (softness * 0.00999999977648258209228515625)), dist);
    float finalDist = mix(dist, warpedDist, blend);
    return p * (finalDist / fast::max(dist, 9.9999997473787516355514526367188e-06));
}

static inline __attribute__((always_inline))
float2 warpAntiFisheye(thread const float2& p, thread const float& amount, thread const float& radius, thread const float& softness)
{
    float dist = length(p);
    float r = radius * 0.5;
    if (dist < 9.9999997473787516355514526367188e-06)
    {
        return p;
    }
    float amt = amount / 100.0;
    float normDist = dist / fast::max(r, 9.9999997473787516355514526367188e-06);
    float power = 1.0 / fast::max(1.0 + (amt * 2.0), 0.00999999977648258209228515625);
    float warpedDist = powr(normDist, power) * r;
    float blend = smoothstep(r, r * (1.0 - (softness * 0.00999999977648258209228515625)), dist);
    float finalDist = mix(dist, warpedDist, blend);
    return p * (finalDist / fast::max(dist, 9.9999997473787516355514526367188e-06));
}

static inline __attribute__((always_inline))
float2 warpBarrel(thread const float2& p, thread const float& k1v, thread const float& k2v, thread const float& k3v)
{
    float r2 = dot(p, p);
    float r4 = r2 * r2;
    float r6 = r4 * r2;
    float distortion = ((1.0 + (k1v * r2)) + (k2v * r4)) + (k3v * r6);
    return p * distortion;
}

static inline __attribute__((always_inline))
float2 warpPincushion(thread const float2& p, thread const float& amount)
{
    float dist = length(p);
    if (dist < 9.9999997473787516355514526367188e-06)
    {
        return p;
    }
    float amt = (-amount) / 100.0;
    float r2 = dot(p, p);
    float distortion = (1.0 + (amt * r2)) + (((amt * amt) * r2) * r2);
    return p * distortion;
}

static inline __attribute__((always_inline))
float2 warpBulge(thread const float2& p, thread const float& amount, thread const float& radius, thread const float& softness)
{
    float dist = length(p);
    float r = radius * 0.5;
    if (dist < 9.9999997473787516355514526367188e-06)
    {
        return p;
    }
    float amt = amount / 100.0;
    float normDist = dist / fast::max(r, 9.9999997473787516355514526367188e-06);
    float bulge = 1.0 + (amt * (1.0 - (normDist * normDist)));
    bulge = fast::max(bulge, 0.00999999977648258209228515625);
    float blend = smoothstep(r, r * (1.0 - (softness * 0.00999999977648258209228515625)), dist);
    float scale = mix(1.0, bulge, blend);
    return p * scale;
}

static inline __attribute__((always_inline))
float2 warpBullseye(thread const float2& p, thread const float& amount, thread const float& radius)
{
    float dist = length(p);
    float r = radius * 0.5;
    if (dist < 9.9999997473787516355514526367188e-06)
    {
        return p;
    }
    float amt = amount / 100.0;
    float normDist = dist / fast::max(r, 9.9999997473787516355514526367188e-06);
    float ringDist = (sin((normDist * 3.1415927410125732421875) * 3.0) * amt) * 0.300000011920928955078125;
    float finalDist = dist + (ringDist * r);
    return p * (finalDist / fast::max(dist, 9.9999997473787516355514526367188e-06));
}

static inline __attribute__((always_inline))
float2 warpUpperShell(thread const float2& p, thread const float& amount, thread const float& radius, thread const float& softness)
{
    float dist = length(p);
    float r = radius * 0.5;
    if (dist < 9.9999997473787516355514526367188e-06)
    {
        return p;
    }
    float amt = amount / 100.0;
    float topMask = smoothstep(-0.100000001490116119384765625, 0.100000001490116119384765625, -p.y);
    float normDist = dist / fast::max(r, 9.9999997473787516355514526367188e-06);
    float power = 1.0 + ((amt * 2.0) * topMask);
    float warpedDist = powr(normDist, power) * r;
    float blend = smoothstep(r, r * (1.0 - (softness * 0.00999999977648258209228515625)), dist);
    float finalDist = mix(dist, warpedDist, blend * topMask);
    return p * (finalDist / fast::max(dist, 9.9999997473787516355514526367188e-06));
}

static inline __attribute__((always_inline))
float2 warpLowerShell(thread const float2& p, thread const float& amount, thread const float& radius, thread const float& softness)
{
    float dist = length(p);
    float r = radius * 0.5;
    if (dist < 9.9999997473787516355514526367188e-06)
    {
        return p;
    }
    float amt = amount / 100.0;
    float bottomMask = smoothstep(-0.100000001490116119384765625, 0.100000001490116119384765625, p.y);
    float normDist = dist / fast::max(r, 9.9999997473787516355514526367188e-06);
    float power = 1.0 + ((amt * 2.0) * bottomMask);
    float warpedDist = powr(normDist, power) * r;
    float blend = smoothstep(r, r * (1.0 - (softness * 0.00999999977648258209228515625)), dist);
    float finalDist = mix(dist, warpedDist, blend * bottomMask);
    return p * (finalDist / fast::max(dist, 9.9999997473787516355514526367188e-06));
}

static inline __attribute__((always_inline))
float2 warpSpherize(thread const float2& p, thread const float& amount, thread const float& radius)
{
    float dist = length(p);
    float r = radius * 0.5;
    if ((dist < 9.9999997473787516355514526367188e-06) || (dist > r))
    {
        return p;
    }
    float amt = amount / 100.0;
    float normDist = dist / r;
    float z = sqrt(fast::max(1.0 - (normDist * normDist), 0.0));
    float sphereDist = asin(normDist) / 1.57079637050628662109375;
    float finalDist = mix(normDist, sphereDist, amt) * r;
    return p * (finalDist / fast::max(dist, 9.9999997473787516355514526367188e-06));
}

static inline __attribute__((always_inline))
float2 warpTwirl(thread const float2& p, thread const float& angle, thread const float& radius)
{
    float dist = length(p);
    float r = radius * 0.5;
    if (dist < 9.9999997473787516355514526367188e-06)
    {
        return p;
    }
    float angRad = (angle * 3.1415927410125732421875) / 180.0;
    float normDist = fast::clamp(dist / fast::max(r, 9.9999997473787516355514526367188e-06), 0.0, 1.0);
    float twirlAmt = angRad * (1.0 - normDist);
    float cs = cos(twirlAmt);
    float sn = sin(twirlAmt);
    return float2((p.x * cs) - (p.y * sn), (p.x * sn) + (p.y * cs));
}

static inline __attribute__((always_inline))
float2 warpWave(thread const float2& p, thread const float& amp, thread const float& freq, thread const float& phase, thread const float& angle, thread const float& time)
{
    float angRad = (angle * 3.1415927410125732421875) / 180.0;
    float phaseRad = (phase * 3.1415927410125732421875) / 180.0;
    float2 dir = float2(cos(angRad), sin(angRad));
    float2 perp = float2(-dir.y, dir.x);
    float projection = dot(p, dir);
    float waveVal = (sin((((projection * freq) * 6.283185482025146484375) + phaseRad) + (time * 6.283185482025146484375)) * amp) * 0.00999999977648258209228515625;
    return p + (perp * waveVal);
}

static inline __attribute__((always_inline))
float2 warpRipple(thread const float2& p, thread const float& amp, thread const float& freq, thread const float& phase, thread const float& decay, thread const float& time)
{
    float dist = length(p);
    if (dist < 9.9999997473787516355514526367188e-06)
    {
        return p;
    }
    float phaseRad = (phase * 3.1415927410125732421875) / 180.0;
    float decayFactor = 1.0;
    if (decay > 0.5)
    {
        decayFactor = exp(((-dist) * decay) * 0.100000001490116119384765625);
    }
    float rippleVal = ((sin((((dist * freq) * 6.283185482025146484375) - phaseRad) - (time * 6.283185482025146484375)) * amp) * 0.00999999977648258209228515625) * decayFactor;
    float2 dir = p / float2(dist);
    return p + (dir * rippleVal);
}

static inline __attribute__((always_inline))
float isInBounds(thread const float2& uv)
{
    return ((step(0.0, uv.x) * step(uv.x, 1.0)) * step(0.0, uv.y)) * step(uv.y, 1.0);
}

static inline __attribute__((always_inline))
float2 applyEdge(thread const float2& uv, thread const float& mode)
{
    if (mode < 1.5)
    {
        return uv;
    }
    if (mode < 2.5)
    {
        return fract(uv);
    }
    if (mode < 3.5)
    {
        float2 r = uv;
        float _148;
        if (mod(floor(r.x), 2.0) == 0.0)
        {
            _148 = fract(r.x);
        }
        else
        {
            _148 = 1.0 - fract(r.x);
        }
        r.x = _148;
        float _168;
        if (mod(floor(r.y), 2.0) == 0.0)
        {
            _168 = fract(r.y);
        }
        else
        {
            _168 = 1.0 - fract(r.y);
        }
        r.y = _168;
        return r;
    }
    return fast::clamp(uv, float2(0.0), float2(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse46a11ff71be9& _810, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _810.refScreen.xy;
    float em = float(_810.edgeMode);
    float wm = float(_810.warpMode);
    float2 param = _810.refScreen.xy;
    float2 imgSize = getTexSize(param);
    float aspect = imgSize.x / fast::max(imgSize.y, 1.0);
    float2 param_1 = uv;
    float4 original = texture2DCv(refInput, refInputSmplr, param_1);
    float3 baseRGB = original.xyz;
    float2 center = float2(0.5 + _810.warpCenter.x, 0.5 + _810.warpCenter.y);
    float2 p = uv - center;
    p.x *= (aspect * _810.aspectX);
    p.y *= _810.aspectY;
    float radius = _810.warpRadius / 100.0;
    float softness = _810.warpSoftness;
    float amt = _810.warpAmount;
    float t = _810.refScreen.z;
    float2 warped = p;
    if (wm < 1.5)
    {
        float2 param_2 = p;
        float param_3 = amt;
        float param_4 = radius;
        float param_5 = softness;
        warped = warpFisheye(param_2, param_3, param_4, param_5);
    }
    else
    {
        if (wm < 2.5)
        {
            float2 param_6 = p;
            float param_7 = amt;
            float param_8 = radius;
            float param_9 = softness;
            warped = warpAntiFisheye(param_6, param_7, param_8, param_9);
        }
        else
        {
            if (wm < 3.5)
            {
                float2 param_10 = p;
                float param_11 = _810.k1 + (amt * 0.00999999977648258209228515625);
                float param_12 = _810.k2;
                float param_13 = _810.k3;
                warped = warpBarrel(param_10, param_11, param_12, param_13);
            }
            else
            {
                if (wm < 4.5)
                {
                    float2 param_14 = p;
                    float param_15 = amt;
                    warped = warpPincushion(param_14, param_15);
                }
                else
                {
                    if (wm < 5.5)
                    {
                        float2 param_16 = p;
                        float param_17 = amt;
                        float param_18 = radius;
                        float param_19 = softness;
                        warped = warpBulge(param_16, param_17, param_18, param_19);
                    }
                    else
                    {
                        if (wm < 6.5)
                        {
                            float2 param_20 = p;
                            float param_21 = amt;
                            float param_22 = radius;
                            warped = warpBullseye(param_20, param_21, param_22);
                        }
                        else
                        {
                            if (wm < 7.5)
                            {
                                float2 param_23 = p;
                                float param_24 = amt;
                                float param_25 = radius;
                                float param_26 = softness;
                                warped = warpUpperShell(param_23, param_24, param_25, param_26);
                            }
                            else
                            {
                                if (wm < 8.5)
                                {
                                    float2 param_27 = p;
                                    float param_28 = amt;
                                    float param_29 = radius;
                                    float param_30 = softness;
                                    warped = warpLowerShell(param_27, param_28, param_29, param_30);
                                }
                                else
                                {
                                    if (wm < 9.5)
                                    {
                                        float2 param_31 = p;
                                        float param_32 = amt;
                                        float param_33 = radius;
                                        warped = warpSpherize(param_31, param_32, param_33);
                                    }
                                    else
                                    {
                                        if (wm < 10.5)
                                        {
                                            float2 param_34 = p;
                                            float param_35 = _810.twirlAngle + amt;
                                            float param_36 = _810.twirlRadius / 100.0;
                                            warped = warpTwirl(param_34, param_35, param_36);
                                        }
                                        else
                                        {
                                            if (wm < 11.5)
                                            {
                                                float2 param_37 = p;
                                                float param_38 = _810.waveAmplitude + (abs(amt) * 0.5);
                                                float param_39 = _810.waveFrequency;
                                                float param_40 = _810.wavePhase;
                                                float param_41 = _810.waveAngle;
                                                float param_42 = t * _810.waveSpeed;
                                                warped = warpWave(param_37, param_38, param_39, param_40, param_41, param_42);
                                            }
                                            else
                                            {
                                                float2 param_43 = p;
                                                float param_44 = _810.rippleAmplitude + (abs(amt) * 0.5);
                                                float param_45 = _810.rippleFrequency;
                                                float param_46 = _810.ripplePhase;
                                                float param_47 = _810.rippleDecay;
                                                float param_48 = t * _810.rippleSpeed;
                                                warped = warpRipple(param_43, param_44, param_45, param_46, param_47, param_48);
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
    bool _1122 = abs(_810.bendX) > 0.5;
    bool _1131;
    if (!_1122)
    {
        _1131 = abs(_810.bendY) > 0.5;
    }
    else
    {
        _1131 = _1122;
    }
    bool _1140;
    if (!_1131)
    {
        _1140 = abs(_810.bendUniform) > 0.5;
    }
    else
    {
        _1140 = _1131;
    }
    if (_1140)
    {
        float bx = (_810.bendX + _810.bendUniform) / 100.0;
        float by = (_810.bendY + _810.bendUniform) / 100.0;
        warped.x += ((bx * warped.y) * warped.y);
        warped.y += ((by * warped.x) * warped.x);
    }
    if ((wm > 3.5) || (wm < 2.5))
    {
        bool _1189 = abs(_810.k1) > 9.9999997473787516355514526367188e-06;
        bool _1197;
        if (!_1189)
        {
            _1197 = abs(_810.k2) > 9.9999997473787516355514526367188e-06;
        }
        else
        {
            _1197 = _1189;
        }
        bool _1205;
        if (!_1197)
        {
            _1205 = abs(_810.k3) > 9.9999997473787516355514526367188e-06;
        }
        else
        {
            _1205 = _1197;
        }
        if (_1205)
        {
            float r2 = dot(warped, warped);
            float r4 = r2 * r2;
            float r6 = r4 * r2;
            float kDist = ((1.0 + (_810.k1 * r2)) + (_810.k2 * r4)) + (_810.k3 * r6);
            warped *= kDist;
        }
    }
    warped.x /= (aspect * _810.aspectX);
    warped.y /= _810.aspectY;
    float2 warpedUV = warped + center;
    float chromaStr = _810.chromaWarp / 100.0;
    float3 result;
    if (chromaStr > 9.9999997473787516355514526367188e-06)
    {
        float2 pR = uv - center;
        pR.x *= (aspect * _810.aspectX);
        pR.y *= _810.aspectY;
        float2 pB = pR;
        float rAmt = amt * (1.0 + (chromaStr * 0.300000011920928955078125));
        float bAmt = amt * (1.0 - (chromaStr * 0.300000011920928955078125));
        float2 warpedR = pR;
        float2 warpedB = pB;
        if (wm < 1.5)
        {
            float2 param_49 = pR;
            float param_50 = rAmt;
            float param_51 = radius;
            float param_52 = softness;
            warpedR = warpFisheye(param_49, param_50, param_51, param_52);
            float2 param_53 = pB;
            float param_54 = bAmt;
            float param_55 = radius;
            float param_56 = softness;
            warpedB = warpFisheye(param_53, param_54, param_55, param_56);
        }
        else
        {
            if (wm < 2.5)
            {
                float2 param_57 = pR;
                float param_58 = rAmt;
                float param_59 = radius;
                float param_60 = softness;
                warpedR = warpAntiFisheye(param_57, param_58, param_59, param_60);
                float2 param_61 = pB;
                float param_62 = bAmt;
                float param_63 = radius;
                float param_64 = softness;
                warpedB = warpAntiFisheye(param_61, param_62, param_63, param_64);
            }
            else
            {
                if (wm < 3.5)
                {
                    float2 param_65 = pR;
                    float param_66 = _810.k1 + (rAmt * 0.00999999977648258209228515625);
                    float param_67 = _810.k2;
                    float param_68 = _810.k3;
                    warpedR = warpBarrel(param_65, param_66, param_67, param_68);
                    float2 param_69 = pB;
                    float param_70 = _810.k1 + (bAmt * 0.00999999977648258209228515625);
                    float param_71 = _810.k2;
                    float param_72 = _810.k3;
                    warpedB = warpBarrel(param_69, param_70, param_71, param_72);
                }
                else
                {
                    if (wm < 5.5)
                    {
                        float2 param_73 = pR;
                        float param_74 = rAmt;
                        float param_75 = radius;
                        float param_76 = softness;
                        warpedR = warpBulge(param_73, param_74, param_75, param_76);
                        float2 param_77 = pB;
                        float param_78 = bAmt;
                        float param_79 = radius;
                        float param_80 = softness;
                        warpedB = warpBulge(param_77, param_78, param_79, param_80);
                    }
                    else
                    {
                        warpedR = warped;
                        warpedB = warped;
                    }
                }
            }
        }
        bool _1411 = abs(_810.bendX) > 0.5;
        bool _1419;
        if (!_1411)
        {
            _1419 = abs(_810.bendY) > 0.5;
        }
        else
        {
            _1419 = _1411;
        }
        bool _1427;
        if (!_1419)
        {
            _1427 = abs(_810.bendUniform) > 0.5;
        }
        else
        {
            _1427 = _1419;
        }
        if (_1427)
        {
            float bx_1 = (_810.bendX + _810.bendUniform) / 100.0;
            float by_1 = (_810.bendY + _810.bendUniform) / 100.0;
            warpedR.x += ((bx_1 * warpedR.y) * warpedR.y);
            warpedR.y += ((by_1 * warpedR.x) * warpedR.x);
            warpedB.x += ((bx_1 * warpedB.y) * warpedB.y);
            warpedB.y += ((by_1 * warpedB.x) * warpedB.x);
        }
        warpedR.x /= (aspect * _810.aspectX);
        warpedR.y /= _810.aspectY;
        warpedB.x /= (aspect * _810.aspectX);
        warpedB.y /= _810.aspectY;
        float2 uvR = warpedR + center;
        float2 uvB = warpedB + center;
        float _1527;
        if (em < 1.5)
        {
            float2 param_81 = uvR;
            _1527 = isInBounds(param_81);
        }
        else
        {
            _1527 = 1.0;
        }
        float inR = _1527;
        float _1538;
        if (em < 1.5)
        {
            float2 param_82 = warpedUV;
            _1538 = isInBounds(param_82);
        }
        else
        {
            _1538 = 1.0;
        }
        float inG = _1538;
        float _1549;
        if (em < 1.5)
        {
            float2 param_83 = uvB;
            _1549 = isInBounds(param_83);
        }
        else
        {
            _1549 = 1.0;
        }
        float inB = _1549;
        float2 param_84 = uvR;
        float param_85 = em;
        uvR = applyEdge(param_84, param_85);
        uvR = fast::clamp(uvR, float2(0.0), float2(1.0));
        float2 param_86 = warpedUV;
        float param_87 = em;
        float2 uvG = applyEdge(param_86, param_87);
        uvG = fast::clamp(uvG, float2(0.0), float2(1.0));
        float2 param_88 = uvB;
        float param_89 = em;
        uvB = applyEdge(param_88, param_89);
        uvB = fast::clamp(uvB, float2(0.0), float2(1.0));
        float2 param_90 = uvR;
        result.x = texture2DCv(refInput, refInputSmplr, param_90).x * inR;
        float2 param_91 = uvG;
        result.y = texture2DCv(refInput, refInputSmplr, param_91).y * inG;
        float2 param_92 = uvB;
        result.z = texture2DCv(refInput, refInputSmplr, param_92).z * inB;
    }
    else
    {
        float _1611;
        if (em < 1.5)
        {
            float2 param_93 = warpedUV;
            _1611 = isInBounds(param_93);
        }
        else
        {
            _1611 = 1.0;
        }
        float inBounds = _1611;
        float2 param_94 = warpedUV;
        float param_95 = em;
        warpedUV = applyEdge(param_94, param_95);
        warpedUV = fast::clamp(warpedUV, float2(0.0), float2(1.0));
        float2 param_96 = warpedUV;
        result = texture2DCv(refInput, refInputSmplr, param_96).xyz * inBounds;
    }
    result = mix(baseRGB, result, float3(_810.globalMix));
    result = fast::clamp(result, float3(0.0), float3(1.0));
    referenceColor = float4(result, original.w);
}

fragment refAM35_e46a11ff71be9_out refAM35_e46a11ff71be9(constant ReferenceUniformse46a11ff71be9& _810 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e46a11ff71be9_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _810, refInput, refInputSmplr, referenceColor);
    bool _1660 = any(isnan(referenceColor));
    bool _1667;
    if (!_1660)
    {
        _1667 = any(isinf(referenceColor));
    }
    else
    {
        _1667 = _1660;
    }
    if (_1667)
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

