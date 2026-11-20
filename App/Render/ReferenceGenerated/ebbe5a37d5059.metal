// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/starpannel.xml
// Original source comments and attribution:
// Alight Motion mapping
// iResolution -> acScreenSize
// iTime -> acTime
// Matt Taylor ACES approx (tonemapping)
// Scene constants
// sqrt(0.5)
// 5-pointed star SDF (tweaked inner rounding)
// 2.0-0.25
// Composite over input layer
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsebbe5a37d5059
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float speed;
    char _m6_pad[12];
    float intensity;
    char _m7_pad[12];
    float exposure;
    char _m8_pad[12];
    float opacity;
};

struct refAM35_ebbe5a37d5059_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float3 offsetf(thread const float& z)
{
    return float3(float2(1.0, 0.707106769084930419921875) * sin(float2(0.310000002384185791015625, 0.4099999964237213134765625) * z), z);
}

static inline __attribute__((always_inline))
float3 doffsetf(thread const float& z)
{
    return float3(float2(0.310000002384185791015625, 0.28991377353668212890625) * cos(float2(0.310000002384185791015625, 0.4099999964237213134765625) * z), 1.0);
}

static inline __attribute__((always_inline))
float3 ddoffsetf(thread const float& z)
{
    return float3(float2(-0.0961000025272369384765625, -0.118864648044109344482421875) * sin(float2(0.310000002384185791015625, 0.4099999964237213134765625) * z), 0.0);
}

static inline __attribute__((always_inline))
float2x2 ROT(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, s), float2(-s, c));
}

static inline __attribute__((always_inline))
float pmin(thread const float& a, thread const float& b, thread const float& k)
{
    float h = fast::clamp(0.5 + ((0.5 * (b - a)) / k), 0.0, 1.0);
    return mix(b, a, h) - ((k * h) * (1.0 - h));
}

static inline __attribute__((always_inline))
float pabs(thread const float& a, thread const float& k)
{
    float param = a;
    float param_1 = -a;
    float param_2 = k;
    return -pmin(param, param_1, param_2);
}

static inline __attribute__((always_inline))
float star5(thread float2& p, thread const float& r, thread const float& rf, thread const float& sm)
{
    p = -p;
    p.x = abs(p.x);
    p -= (float2(0.809017002582550048828125, -0.587785243988037109375) * (2.0 * fast::max(dot(float2(0.809017002582550048828125, -0.587785243988037109375), p), 0.0)));
    p -= (float2(-0.809017002582550048828125, -0.587785243988037109375) * (2.0 * fast::max(dot(float2(-0.809017002582550048828125, -0.587785243988037109375), p), 0.0)));
    float param = p.x;
    float param_1 = sm;
    p.x = pabs(param, param_1);
    p.y -= r;
    float2 ba = (float2(0.587785243988037109375, 0.809017002582550048828125) * rf) - float2(0.0, 1.0);
    float h = fast::clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
    return length(p - (ba * h)) * sign((p.y * ba.x) - (p.x * ba.y));
}

static inline __attribute__((always_inline))
float3 palette(thread const float& n)
{
    return float3(0.5) + (sin(float3(0.0, 1.0, 2.0) + float3(n)) * 0.5);
}

static inline __attribute__((always_inline))
float4 plane(thread const float3& ro, thread const float3& rd, thread const float3& pp, thread const float3& npp, thread const float& pd, thread const float3& cp, thread const float3& off, thread const float& n)
{
    float aa = (3.0 * pd) * distance(pp.xy, npp.xy);
    float4 col = float4(0.0);
    float2 p2 = pp.xy;
    float param = pp.z;
    p2 -= offsetf(param).xy;
    float param_1 = pp.z;
    float2 doff = ddoffsetf(param_1).xz;
    float param_2 = pp.z;
    float2 ddoff = doffsetf(param_2).xz;
    float dd = dot(doff, ddoff);
    float param_3 = (dd * 3.1415927410125732421875) * 5.0;
    p2 = ROT(param_3) * p2;
    float2 param_4 = p2;
    float param_5 = 0.449999988079071044921875;
    float param_6 = 1.60000002384185791015625;
    float param_7 = 0.20000000298023223876953125;
    float _419 = star5(param_4, param_5, param_6, param_7);
    float d0 = _419 - 0.0199999995529651641845703125;
    float d1 = d0 - 0.00999999977648258209228515625;
    float d2 = length(p2);
    float colaa = aa * 200.0;
    float param_8 = (0.5 * n) + (2.0 * d2);
    float3 _463 = (palette(param_8) * mix(0.5 / (d2 * d2), 1.0, smoothstep((-0.5) + colaa, 0.5 + colaa, sin(d2 * 314.159271240234375)))) / float3(fast::max((3.0 * d2) * d2, 0.100000001490116119384765625));
    col.x = _463.x;
    col.y = _463.y;
    col.z = _463.z;
    float4 _470 = col;
    float3 _479 = mix(_470.xyz, float3(2.0), float3(smoothstep(aa, -aa, d1)));
    col.x = _479.x;
    col.y = _479.y;
    col.z = _479.z;
    col.w = smoothstep(aa, -aa, -d0);
    return col;
}

static inline __attribute__((always_inline))
float4 alphaBlend(thread const float4& back, thread const float4& front)
{
    float w = front.w + (back.w * (1.0 - front.w));
    float3 xyz = ((front.xyz * front.w) + ((back.xyz * back.w) * (1.0 - front.w))) / float3(fast::max(w, 9.9999999747524270787835121154785e-07));
    float4 _227;
    if (w > 0.0)
    {
        _227 = float4(xyz, w);
    }
    else
    {
        _227 = float4(0.0);
    }
    return _227;
}

static inline __attribute__((always_inline))
float3 colorfn(thread const float3& ww, thread const float3& uu, thread const float3& vv, thread const float3& ro, thread const float2& p, thread const float2& iResolution)
{
    float2 np = p + (float2(1.0) / iResolution);
    float rdd = 1.75;
    float3 rd = fast::normalize(((uu * p.x) + (vv * p.y)) + (ww * rdd));
    float3 nrd = fast::normalize(((uu * np.x) + (vv * np.y)) + (ww * rdd));
    float nz = floor(ro.z / 0.5);
    float4 acol = float4(0.0);
    float3 aro = ro;
    float apd = 0.0;
    for (float i = 1.0; i <= 16.0; i += 1.0)
    {
        if (acol.w > 0.949999988079071044921875)
        {
            break;
        }
        float pz = (0.5 * nz) + (0.5 * i);
        float lpd = (pz - aro.z) / rd.z;
        float npd = (pz - aro.z) / nrd.z;
        float cpd = (pz - aro.z) / ww.z;
        float3 pp = aro + (rd * lpd);
        float3 npp = aro + (nrd * npd);
        float3 cp = aro + (ww * cpd);
        apd += lpd;
        float param = pp.z;
        float3 off = offsetf(param);
        float dz = pp.z - ro.z;
        float fadeIn = smoothstep(8.0, 4.0, dz);
        float fadeOut = smoothstep(0.0, 0.0500000007450580596923828125, dz);
        float fadeOutRI = smoothstep(0.0, 0.5, dz);
        float ri = mix(1.0, 0.89999997615814208984375, fadeOutRI * fadeIn);
        float3 param_1 = ro;
        float3 param_2 = rd;
        float3 param_3 = pp;
        float3 param_4 = npp;
        float param_5 = apd;
        float3 param_6 = cp;
        float3 param_7 = off;
        float param_8 = nz + i;
        float4 pcol = plane(param_1, param_2, param_3, param_4, param_5, param_6, param_7, param_8);
        pcol.w *= (fadeOut * fadeIn);
        float4 param_9 = pcol;
        float4 param_10 = acol;
        acol = alphaBlend(param_9, param_10);
        aro = pp;
    }
    return acol.xyz * acol.w;
}

static inline __attribute__((always_inline))
float3 aces_approx(thread float3& v)
{
    v = fast::max(v, float3(0.0));
    v *= 0.60000002384185791015625;
    float a = 2.5099999904632568359375;
    float b = 0.02999999932944774627685546875;
    float c = 2.4300000667572021484375;
    float d = 0.589999973773956298828125;
    float e = 0.14000000059604644775390625;
    return fast::clamp((v * ((v * a) + float3(b))) / ((v * ((v * c) + float3(d))) + float3(e)), float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsebbe5a37d5059& _689, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 fragCoord = (gl_FragCoord.xy / _689.refScreen.xy) * _689.refScreen.xy;
    float2 iResolution = _689.refScreen.xy;
    float iTime = _689.refScreen.z * _689.speed;
    float2 r = iResolution;
    float2 q = fragCoord / r;
    float2 pp = float2(-1.0) + (q * 2.0);
    float2 p = pp;
    p.x *= (r.x / fast::max(r.y, 1.0));
    float tm = 0.5 * iTime;
    float param = tm;
    float3 ro = offsetf(param);
    float param_1 = tm;
    float3 dro = doffsetf(param_1);
    float param_2 = tm;
    float3 ddro = ddoffsetf(param_2);
    float3 ww = fast::normalize(dro);
    float3 uu = fast::normalize(cross(float3(0.0, 1.0, 0.0) + ddro, ww));
    float3 vv = cross(ww, uu);
    float3 param_3 = ww;
    float3 param_4 = uu;
    float3 param_5 = vv;
    float3 param_6 = ro;
    float2 param_7 = p;
    float2 param_8 = iResolution;
    float3 col = colorfn(param_3, param_4, param_5, param_6, param_7, param_8);
    float3 param_9 = col * _689.exposure;
    float3 _786 = aces_approx(param_9);
    col = _786 * _689.intensity;
    col = sqrt(fast::max(col, float3(0.0)));
    float2 param_10 = gl_FragCoord.xy / _689.refScreen.xy;
    float4 base = texture2DCv(refInput, refInputSmplr, param_10);
    float4 outC = float4(col, 1.0) * _689.opacity;
    outC = (base * (1.0 - outC.w)) + outC;
    referenceColor = outC;
}

fragment refAM35_ebbe5a37d5059_out refAM35_ebbe5a37d5059(constant ReferenceUniformsebbe5a37d5059& _689 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ebbe5a37d5059_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _689, refInput, refInputSmplr, referenceColor);
    bool _829 = any(isnan(referenceColor));
    bool _836;
    if (!_829)
    {
        _836 = any(isinf(referenceColor));
    }
    else
    {
        _836 = _829;
    }
    if (_836)
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

