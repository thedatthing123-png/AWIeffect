// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/noisetunnelblue.xml
// Original source comments and attribution:
// Blue Simplex FBM Tunnel - AM single pass
// Hash and simplex noise (hash33-based)
// normalized 0..1
// unused but retained
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

struct ReferenceUniformsefc18076eae6c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float SPEED;
    char _m6_pad[12];
    float CYCLE;
    char _m7_pad[12];
    float ROT_Y;
    char _m8_pad[12];
    float ROT_X;
    char _m9_pad[12];
    float ROT_SPEED;
    char _m10_pad[12];
    float FBM_SCALE;
    char _m11_pad[12];
    float FBM_OCT;
    char _m12_pad[12];
    float FBM_PERSIST;
    char _m13_pad[12];
    float FOCAL_DEPTH;
    char _m14_pad[12];
    float DISK_MIN;
    char _m15_pad[12];
    float DISK_SCALE;
    float4 COLOR_BASE;
    float WHITE_GAIN;
    char _m18_pad[12];
    float GAMMA;
    char _m19_pad[12];
    int WHITEOUT;
};

struct refAM35_efc18076eae6c_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float3x3 rotX(thread const float& a)
{
    return float3x3(float3(1.0, 0.0, 0.0), float3(0.0, cos(a), sin(a)), float3(0.0, -sin(a), cos(a)));
}

static inline __attribute__((always_inline))
float3x3 rotY(thread const float& a)
{
    return float3x3(float3(cos(a), 0.0, sin(a)), float3(0.0, 1.0, 0.0), float3(-sin(a), 0.0, cos(a)));
}

static inline __attribute__((always_inline))
float3 hash33(thread float3& p3)
{
    p3 = fract(p3 * float3(0.103100001811981201171875, 0.113689996302127838134765625, 0.13786999881267547607421875));
    p3 += float3(dot(p3, p3.yxz + float3(19.1900005340576171875)));
    return float3(-1.0) + (fract(float3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x)) * 2.0);
}

static inline __attribute__((always_inline))
float simplexNoise(thread const float3& p)
{
    float3 i = floor(p + float3(((p.x + p.y) + p.z) * 0.3333333432674407958984375));
    float3 d0 = p - (i - float3(((i.x + i.y) + i.z) * 0.16666667163372039794921875));
    float3 e = step(float3(0.0), d0 - d0.yzx);
    float3 i1 = e * (float3(1.0) - e.zxy);
    float3 i2 = float3(1.0) - (e.zxy * (float3(1.0) - e));
    float3 d1 = d0 - (i1 - float3(0.16666667163372039794921875));
    float3 d2 = d0 - (i2 - float3(0.3333333432674407958984375));
    float3 d3 = d0 - float3(0.5);
    float4 h = fast::max(float4(0.60000002384185791015625) - float4(dot(d0, d0), dot(d1, d1), dot(d2, d2), dot(d3, d3)), float4(0.0));
    float3 param = i;
    float3 _190 = hash33(param);
    float3 param_1 = i + i1;
    float3 _197 = hash33(param_1);
    float3 param_2 = i + i2;
    float3 _204 = hash33(param_2);
    float3 param_3 = i + float3(1.0);
    float3 _211 = hash33(param_3);
    float4 n = (((h * h) * h) * h) * float4(dot(d0, _190), dot(d1, _197), dot(d2, _204), dot(d3, _211));
    return dot(float4(31.3159999847412109375), n);
}

static inline __attribute__((always_inline))
float fbm3(thread const float3& p, constant ReferenceUniformsefc18076eae6c& _227)
{
    float f = 0.0;
    float scale = _227.FBM_SCALE;
    float amp = 0.75;
    int oct = int(fast::clamp(_227.FBM_OCT, 1.0, 8.0));
    for (int i = 0; i < 8; i++)
    {
        if (i >= oct)
        {
            break;
        }
        float3 param = p * scale;
        f += (simplexNoise(param) * amp);
        amp *= _227.FBM_PERSIST;
        scale *= 2.0;
    }
    return fast::min(f, 1.0);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsefc18076eae6c& _227, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 R = _227.refScreen.xy;
    float2 frag = (gl_FragCoord.xy / _227.refScreen.xy) * R;
    float t2 = fast::max(_227.CYCLE, 0.001000000047497451305389404296875);
    float t = mod(_227.refScreen.z, t2) / t2;
    float2 q = frag / R;
    float2 p = ((frag * 2.0) - R) / float2(fast::min(R.y, R.x));
    p += float2(0.0, -0.100000001490116119384765625);
    float ay = _227.ROT_Y;
    float ax = _227.ROT_X;
    float param = ax;
    float param_1 = ay;
    float3x3 m = rotX(param) * rotY(param_1);
    float3 v = float3(p, 1.0);
    v = m * v;
    float v_xy = length(v.xy);
    float z = v.z / fast::max(v_xy, 9.9999997473787516355514526367188e-06);
    float focal_depth = _227.FOCAL_DEPTH;
    float whiteoutSel = float(_227.WHITEOUT);
    if (whiteoutSel > 0.5)
    {
        float wf = smoothstep(0.64999997615814208984375, 0.89999997615814208984375, t);
        focal_depth = mix(0.1500000059604644775390625, 0.014999999664723873138427734375, wf);
    }
    float p_len = length(v.xy);
    float2 polar;
    polar.y = (z * focal_depth) + (_227.refScreen.z * _227.SPEED);
    float a = precise::atan2(v.y, v.x);
    a = 0.5 + ((0.5 * a) / 3.1415927410125732421875);
    a -= (_227.refScreen.z * _227.ROT_SPEED);
    float x = fract(a);
    if (x >= 0.5)
    {
        x = 1.0 - x;
    }
    polar.x = x;
    float3 param_2 = float3(float2(2.0, 0.5) * polar, 0.1500000059604644775390625 * _227.refScreen.z);
    float val = 0.449999988079071044921875 + (0.550000011920928955078125 * fbm3(param_2, _227));
    val = fast::clamp(val, 0.0, 1.0);
    float3 baseCol = _227.COLOR_BASE.xyz;
    float3 col = baseCol * float3(val);
    float3 white = float3(smoothstep(0.550000011920928955078125, 1.0, val)) * _227.WHITE_GAIN;
    col += white;
    col = fast::clamp(col, float3(0.0), float3(1.0));
    float w_total = 0.0;
    float w_out = 0.0;
    if (whiteoutSel > 0.5)
    {
        float w_in = abs(1.0 - smoothstep(0.0, 0.25, t));
        w_out = abs(smoothstep(0.800000011920928955078125, 1.0, t));
        w_total = fast::max(w_in, w_out);
    }
    float disk_size = fast::max(_227.DISK_MIN, _227.DISK_SCALE * w_out);
    float disk_col = exp((-(p_len - disk_size)) * 4.0);
    col += fast::clamp(float3(disk_col), float3(0.0), float3(1.0));
    if (whiteoutSel > 0.5)
    {
        col = mix(col, float3(1.0), float3(w_total));
    }
    col = powr(fast::max(col, float3(0.0)), float3(_227.GAMMA));
    referenceColor = float4(col, 1.0);
}

fragment refAM35_efc18076eae6c_out refAM35_efc18076eae6c(constant ReferenceUniformsefc18076eae6c& _227 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_efc18076eae6c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_227, gl_FragCoord, referenceColor);
    bool _582 = any(isnan(referenceColor));
    bool _589;
    if (!_582)
    {
        _589 = any(isinf(referenceColor));
    }
    else
    {
        _589 = _582;
    }
    if (_589)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _603 = referenceColor;
    float3 _609 = fast::clamp(_603.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _609.x;
    referenceColor.y = _609.y;
    referenceColor.z = _609.z;
    out.finalColor = referenceColor;
    return out;
}

