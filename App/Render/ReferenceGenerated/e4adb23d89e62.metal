// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsseascape.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
// A documented, altered, recolored version of "Seascape".
// The famous original at:
// https://www.shadertoy.com/view/Ms2SD1
// "Seascape" by Alexander Alekseev aka TDM - 2014
// const int NUM_STEPS = 6;
// const int ITER_GEOMETRY = 2;
// const int ITER_FRAGMENT =5;
// const float SEA_HEIGHT = 0.5;
// const float SEA_CHOPPY = 3.0;
// const float SEA_FREQ = 0.24;
// const vec3 SEA_BASE = vec3(0.11,0.19,0.22);
// const vec3 SEA_WATER_COLOR = vec3(0.55,0.9,0.7);
// for(int i = 0; i < int(ITER_GEOMETRY); i++) {
// bteitler: Detailed height relative to surface, temporarily here to save a variable?
// bteitler approximate X gradient as change in height along X axis delta
// bteitler approximate Z gradient as change in height along Z axis delta
// bteitler: a really far distance, this could likely be tweaked a bit as desired
// bteitler: Constant number of ray marches per ray that hits the water
// bteitler: Re-evaluate height relative to ocean surface in Y axis
// bteitler: We went through the ocean surface if we are negative relative to surface now
//////////////////////////
/////////////////////////
//  bteitler: Shift pixel coordinates from 0 to 1 to between -1 and 1
// bteitler: Aspect ratio correction - if you don't do this your rays will be distorted
// bteitler: Animation is based on time, but allows you to scrub the animation based on mouse movement
// float roll = PI + sin(progressc)/14.0 + cos(progressc/2.0)/14.0 ;
// bteitler: distance vector to ocean surface for this pixel's ray
// bteitler: Think of this as inverse resolution, so far distances get bigger at an expnential rate
// bteitler: Just a resolution constant.. could easily be tweaked to artistic content
//night mode!
// if( isKeyPressed(KEY_SP) > 0.0 )    //night mode!
//day mode!
// bteitler: Can be thought of as "fog" that gets thicker in the distance
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse4adb23d89e62
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint nmode;
    char _m6_pad[12];
    float camprog;
    char _m7_pad[12];
    float camx;
    char _m8_pad[12];
    float camy;
    char _m9_pad[12];
    float progressa;
    char _m10_pad[12];
    float SEA_HEIGHT;
    char _m11_pad[12];
    float SEA_CHOPPY;
    char _m12_pad[12];
    float SEA_FREQ;
    float4 SEA_BASE;
    float4 SEA_WATER_COLOR;
    float4 CSKY;
    float4 SKYCOLOR;
    float NUM_STEPS;
    char _m18_pad[12];
    float ITER_FRAGMENT;
    char _m19_pad[12];
    float scale;
    char _m20_pad[12];
    float progressc;
    char _m21_pad[8];
    float2 position;
    char _m22_pad[8];
    float alpha;
    char _m23_pad[12];
    uint adaptive;
};

struct refAM35_e4adb23d89e62_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float3x3 fromEuler(thread const float3& ang)
{
    float2 a1 = float2(sin(ang.x), cos(ang.x));
    float2 a2 = float2(sin(ang.y), cos(ang.y));
    float2 a3 = float2(sin(ang.z), cos(ang.z));
    float3x3 m;
    m[0] = float3((a1.y * a3.y) + ((a1.x * a2.x) * a3.x), ((a1.y * a2.x) * a3.x) + (a3.y * a1.x), (-a2.y) * a3.x);
    m[1] = float3((-a2.y) * a1.x, a1.y * a2.y, a2.x);
    m[2] = float3(((a3.y * a1.x) * a2.x) + (a1.y * a3.x), (a1.x * a3.x) - ((a1.y * a3.y) * a2.x), a2.y * a3.y);
    return m;
}

static inline __attribute__((always_inline))
float hash(thread const float2& p)
{
    float h = dot(p, float2(127.09999847412109375, 311.70001220703125));
    return fract(sin(h) * 83758.546875);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i + float2(0.0);
    float2 param_1 = i + float2(1.0, 0.0);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 param_3 = i + float2(1.0);
    return (-1.0) + (2.0 * mix(mix(hash(param), hash(param_1), u.x), mix(hash(param_2), hash(param_3), u.x), u.y));
}

static inline __attribute__((always_inline))
float sea_octave(thread float2& uv, thread const float& choppy)
{
    float2 param = uv;
    uv += float2(_noise(param));
    float2 wv = float2(1.0) - abs(sin(uv));
    float2 swv = abs(cos(uv));
    wv = mix(wv, swv, wv);
    return powr(1.0 - powr(wv.x * wv.y, 0.64999997615814208984375), choppy);
}

static inline __attribute__((always_inline))
float map(thread const float3& p, thread float2x2& octave_m, constant ReferenceUniformse4adb23d89e62& _491)
{
    float freq = _491.SEA_FREQ;
    float amp = _491.SEA_HEIGHT;
    float choppy = _491.SEA_CHOPPY;
    float2 uv = p.xz;
    uv.x *= 0.75;
    float h = 0.0;
    for (int i = 0; i < 2; i++)
    {
        float2 param = (uv + float2(_491.progressa * 2.0)) * freq;
        float param_1 = choppy;
        float _579 = sea_octave(param, param_1);
        float d = _579;
        h += (d * amp);
        uv *= octave_m;
        freq *= 1.89999997615814208984375;
        amp *= 0.2199999988079071044921875;
        choppy = mix(choppy, 1.0, 0.20000000298023223876953125);
    }
    return p.y - h;
}

static inline __attribute__((always_inline))
float heightMapTracing(thread const float3& ori, thread const float3& dir, thread float3& p, thread float2x2& octave_m, constant ReferenceUniformse4adb23d89e62& _491)
{
    float tm = 0.0;
    float tx = 500.0;
    float3 param = ori + (dir * tx);
    float hx = map(param, octave_m, _491);
    if (hx > 0.0)
    {
        return tx;
    }
    float3 param_1 = ori + (dir * tm);
    float hm = map(param_1, octave_m, _491);
    float tmid = 0.0;
    for (int i = 0; i < int(_491.NUM_STEPS); i++)
    {
        tmid = mix(tm, tx, hm / (hm - hx));
        p = ori + (dir * tmid);
        float3 param_2 = p;
        float hmid = map(param_2, octave_m, _491);
        if (hmid < 0.0)
        {
            tx = tmid;
            hx = hmid;
        }
        else
        {
            tm = tmid;
            hm = hmid;
        }
    }
    return tmid;
}

static inline __attribute__((always_inline))
float map_detailed(thread const float3& p, thread float2x2& octave_m, constant ReferenceUniformse4adb23d89e62& _491)
{
    float freq = _491.SEA_FREQ;
    float amp = _491.SEA_HEIGHT;
    float choppy = _491.SEA_CHOPPY;
    float2 uv = p.xz;
    uv.x *= 0.75;
    float h = 0.0;
    for (int i = 0; i < int(_491.ITER_FRAGMENT); i++)
    {
        float2 param = (uv + float2(_491.progressa * 2.0)) * freq;
        float param_1 = choppy;
        float _646 = sea_octave(param, param_1);
        float d = _646;
        float2 param_2 = (uv - float2(_491.progressa * 2.0)) * freq;
        float param_3 = choppy;
        float _658 = sea_octave(param_2, param_3);
        d += _658;
        h += (d * amp);
        uv *= (octave_m * (1.0 / 1.2000000476837158203125));
        freq *= 1.89999997615814208984375;
        amp *= 0.2199999988079071044921875;
        choppy = mix(choppy, 1.0, 0.20000000298023223876953125);
    }
    return p.y - h;
}

static inline __attribute__((always_inline))
float3 getNormal(thread const float3& p, thread const float& eps, thread float2x2& octave_m, constant ReferenceUniformse4adb23d89e62& _491)
{
    float3 param = p;
    float3 n;
    n.y = map_detailed(param, octave_m, _491);
    float3 param_1 = float3(p.x + eps, p.y, p.z);
    n.x = map_detailed(param_1, octave_m, _491) - n.y;
    float3 param_2 = float3(p.x, p.y, p.z + eps);
    n.z = map_detailed(param_2, octave_m, _491) - n.y;
    n.y = eps;
    return fast::normalize(n);
}

static inline __attribute__((always_inline))
float3 getSkyColor(thread float3& e, constant ReferenceUniformse4adb23d89e62& _491)
{
    e.y = fast::max(e.y, 0.0);
    float3 ret;
    ret.x = powr(1.0 - e.y, 2.0);
    ret.y = 1.0 - e.y;
    ret.z = 0.60000002384185791015625 + ((1.0 - e.y) * 0.4000000059604644775390625);
    ret *= _491.SKYCOLOR.xyz;
    return ret;
}

static inline __attribute__((always_inline))
float diffuse(thread const float3& n, thread const float3& l, thread const float& p)
{
    return powr((dot(n, l) * 0.4000000059604644775390625) + 0.60000002384185791015625, p);
}

static inline __attribute__((always_inline))
float specular(thread const float3& n, thread const float3& l, thread const float3& e, thread const float& s)
{
    float nrm = (s + 8.0) / 25.131999969482421875;
    return powr(fast::max(dot(reflect(e, n), l), 0.0), s) * nrm;
}

static inline __attribute__((always_inline))
float3 getSeaColor(thread const float3& p, thread const float3& n, thread const float3& l, thread const float3& eye, thread const float3& dist, constant ReferenceUniformse4adb23d89e62& _491)
{
    float fresnel = 1.0 - fast::max(dot(n, -eye), 0.0);
    fresnel = powr(fresnel, 3.0) * 0.449999988079071044921875;
    float3 param = reflect(eye, n);
    float3 _701 = getSkyColor(param, _491);
    float3 reflected = _701 * 0.9900000095367431640625;
    reflected *= _491.CSKY.xyz;
    float3 param_1 = n;
    float3 param_2 = l;
    float param_3 = 80.0;
    float3 refracted = _491.SEA_BASE.xyz + ((_491.SEA_WATER_COLOR.xyz * diffuse(param_1, param_2, param_3)) * 0.2700000107288360595703125);
    float3 color = mix(refracted, reflected, float3(fresnel));
    float atten = fast::max(1.0 - (dot(dist, dist) * 0.001000000047497451305389404296875), 0.0);
    color += (((_491.SEA_WATER_COLOR.xyz * (p.y - _491.SEA_HEIGHT)) * 0.1500000059604644775390625) * atten);
    float3 param_4 = n;
    float3 param_5 = l;
    float3 param_6 = eye;
    float param_7 = 90.0;
    color += (float3(specular(param_4, param_5, param_6, param_7)) * 0.5);
    return color;
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
void referenceMain(thread float2x2& octave_m, constant ReferenceUniformse4adb23d89e62& _491, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_491.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _491.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_491.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _491.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float2 syamjaidtz;
            if (_491.adaptive != 0u)
            {
                syamjaidtz = gl_FragCoord.xy / _491.refScreen.xy;
            }
            else
            {
                syamjaidtz = ((float2((gl_FragCoord.xy / _491.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _491.refScreen.xy).y) * _491.refScreen.xy) - float2(_491.refLayer.x + (_491.refLayer.z * 0.5), (_491.refScreen.y - _491.refLayer.y) - (_491.refLayer.w * 0.5))) / _491.refLayer.zw;
                syamjaidtz.y *= (_491.refLayer.w / _491.refLayer.z);
            }
            syamjaidtz /= float2(_491.scale);
            float param_2 = 0.0;
            syamjaidtz *= rot2m(param_2);
            syamjaidtz += ((float2(0.0 + _491.position.x, 0.0 + _491.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 uv = syamjaidtz;
            uv = (uv * 2.0) - float2(1.0);
            uv.x *= (_491.refScreen.x / _491.refScreen.y);
            float time = _491.camprog * 2.7000000476837158203125;
            float roll = 3.1415927410125732421875 + _491.progressc;
            float pitch = 3.233059406280517578125 + (((((200.0 + _491.camy) / _491.refScreen.y) - 0.800000011920928955078125) * 3.1415927410125732421875) / 3.0);
            float yaw = ((_491.camx / _491.refScreen.x) * 3.1415927410125732421875) * 4.0;
            float3 ang = float3(roll, pitch, yaw);
            float3 ori = float3(0.0, 3.5, time * 3.0);
            float3 dir = fast::normalize(float3(uv, -1.60000002384185791015625));
            float3 param_3 = ang;
            dir = fast::normalize(dir) * fromEuler(param_3);
            float3 param_4 = ori;
            float3 param_5 = dir;
            float3 param_6;
            float _1091 = heightMapTracing(param_4, param_5, param_6, octave_m, _491);
            float3 p = param_6;
            float3 dist = p - ori;
            float3 param_7 = p;
            float param_8 = dot(dist, dist) * (0.5 / _491.refScreen.x);
            float3 n = getNormal(param_7, param_8, octave_m, _491);
            float3 light = float3(0.0, 0.780868828296661376953125, 0.6246950626373291015625);
            float3 param_9 = dir;
            float3 _1116 = getSkyColor(param_9, _491);
            float3 skyColor = _1116;
            float3 param_10 = p;
            float3 param_11 = n;
            float3 param_12 = light;
            float3 param_13 = dir;
            float3 param_14 = dist;
            float3 seaColor = getSeaColor(param_10, param_11, param_12, param_13, param_14, _491);
            seaColor /= float3(sqrt(sqrt(length(dist))));
            bool night;
            if (_491.nmode != 0u)
            {
                seaColor *= (seaColor * 8.5);
                skyColor /= float3(1.690000057220458984375);
                night = true;
            }
            else
            {
                seaColor *= (sqrt(sqrt(seaColor)) * 4.0);
                skyColor *= 1.0499999523162841796875;
                skyColor -= float3(0.02999999932944774627685546875);
                night = false;
            }
            skyColor *= skyColor;
            float3 param_15 = seaColor;
            float3 seaHsv = rgb2hsv(param_15);
            bool _1178 = seaHsv.z > 0.75;
            bool _1185;
            if (_1178)
            {
                _1185 = length(dist) < 50.0;
            }
            else
            {
                _1185 = _1178;
            }
            if (_1185)
            {
                seaHsv.z -= ((0.89999997615814208984375 - seaHsv.z) * 1.2999999523162841796875);
            }
            float3 param_16 = seaHsv;
            seaColor = hsv2rgb(param_16);
            float3 color = mix(skyColor, seaColor, float3(powr(smoothstep(0.0, -0.0500000007450580596923828125, dir.y), 0.300000011920928955078125)));
            float4 fragColor = float4(powr(color, float3(0.75)), 1.0);
            float3 param_17 = fragColor.xyz;
            float3 hsv = rgb2hsv(param_17);
            hsv.y += 0.13099999725818634033203125;
            hsv.z *= (sqrt(hsv.z) * 1.10000002384185791015625);
            if (night)
            {
                hsv.z -= 0.04500000178813934326171875;
                hsv *= 0.800000011920928955078125;
                hsv.x += (0.119999997317790985107421875 + (hsv.z / 100.0));
                hsv.y *= 2.86999988555908203125;
            }
            else
            {
                hsv.z *= 0.89999997615814208984375;
                hsv.x -= (hsv.z / 10.0);
                hsv.x += (0.0199999995529651641845703125 + (hsv.z / 50.0));
                hsv.z *= 1.0099999904632568359375;
                hsv.y += 0.070000000298023223876953125;
            }
            float3 param_18 = hsv;
            float3 _1298 = hsv2rgb(param_18);
            fragColor.x = _1298.x;
            fragColor.y = _1298.y;
            fragColor.z = _1298.z;
            referenceColor = mix(texColor, fragColor, float4(_491.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_e4adb23d89e62_out refAM35_e4adb23d89e62(constant ReferenceUniformse4adb23d89e62& _491 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e4adb23d89e62_out out = {};
    float2x2 octave_m = float2x2(float2(1.7000000476837158203125, 1.2000000476837158203125), float2(-1.2000000476837158203125, 1.39999997615814208984375));
    float4 referenceColor = float4(0.0);
    referenceMain(octave_m, _491, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _1320 = any(isnan(referenceColor));
    bool _1327;
    if (!_1320)
    {
        _1327 = any(isinf(referenceColor));
    }
    else
    {
        _1327 = _1320;
    }
    if (_1327)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1340 = referenceColor;
    float3 _1346 = fast::clamp(_1340.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1346.x;
    referenceColor.y = _1346.y;
    referenceColor.z = _1346.z;
    out.finalColor = referenceColor;
    return out;
}

