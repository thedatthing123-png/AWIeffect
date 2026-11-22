// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxextrudeflat.xml
// Original source comments and attribution:
// remove this line for an only partially signed sdf
// vec4 sss = texture2DCv(xDistBuf.texture, l2s(st) );
// vec4 ooo = texture2DCv(inputImg.texture, l2s(st) );
// vec4 texColor = bevelfx? sss : ooo;
///
// float t = max(saturate(blurColor.a*2.),texColor.a);
// float lighting(vec3 p, vec3 n) {
// vec3 lightPos = vec3(lightDir.x/2.0, -lightDir.y/2.0, -lightDepth*2.0);
// vec3 l = normalize(lightPos-p);
// return dot(n,l);
// }
// if(sMode == 0) {
// } else if(sMode == 1) {
// float l = lighting(p,n);
// vec3 tc = texColor.rgb;
// vec3 surface = tc * ambient + tc * lightColor.rgb * l * (1.-ambient);
// surface *= lightIntensity;
// float s = pow(l,spec);
// surface = mix(surface*(1.-shine*0.1),vec3(1.),shine*s);
// result = vec4(surface, texColor.a) * a;
// }
///
///
// vec4 sbevel = texture2DCv(xDistBuf.texture, tc);
// vec4 ori = texture2DCv(inputImg.texture, tc);
// vec4 baseColor = bevelfx? sbevel : ori;
// vec4 blurColor = bevelfx? sbevel : ori;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL radians() function
template<typename T>
inline T radians(T d)
{
    return d * T(0.01745329251);
}

struct ReferenceUniformse9bbc23eabea4
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 orient_euler;
    float3 rotate;
    float3 position;
    float2 stretch;
    char _m9_pad[8];
    float depth;
    char _m10_pad[12];
    float scale;
    char _m11_pad[12];
    float MAX_ITER;
    char _m12_pad[12];
    uint inton;
    float4 interiorColor;
    float interiorBlend;
    float4 fadeColor;
    float fadeBlend;
};

struct refAM35_e9bbc23eabea4_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4x4 referenceVertex_rotationAxisAngle(thread const float3& v, thread const float& angle)
{
    float s = sin(angle);
    float c = cos(angle);
    float ic = 1.0 - c;
    return float4x4(float4(((v.x * v.x) * ic) + c, ((v.y * v.x) * ic) - (s * v.z), ((v.z * v.x) * ic) + (s * v.y), 0.0), float4(((v.x * v.y) * ic) + (s * v.z), ((v.y * v.y) * ic) + c, ((v.z * v.y) * ic) - (s * v.x), 0.0), float4(((v.x * v.z) * ic) - (s * v.y), ((v.y * v.z) * ic) + (s * v.x), ((v.z * v.z) * ic) + c, 0.0), float4(0.0, 0.0, 0.0, 1.0));
}

static inline __attribute__((always_inline))
float4x4 referenceEuler(thread const float3& _degrees, thread const bool& inverted)
{
    float3 r = radians(_degrees);
    float3 s = sin(r);
    float3 c = cos(r);
    float4x4 rx = float4x4(float4(1.0, 0.0, 0.0, 0.0), float4(0.0, c.x, -s.x, 0.0), float4(0.0, s.x, c.x, 0.0), float4(0.0, 0.0, 0.0, 1.0));
    float4x4 ry = float4x4(float4(c.y, 0.0, s.y, 0.0), float4(0.0, 1.0, 0.0, 0.0), float4(-s.y, 0.0, c.y, 0.0), float4(0.0, 0.0, 0.0, 1.0));
    float4x4 rz = float4x4(float4(c.z, -s.z, 0.0, 0.0), float4(s.z, c.z, 0.0, 0.0), float4(0.0, 0.0, 1.0, 0.0), float4(0.0, 0.0, 0.0, 1.0));
    float4x4 m = (rz * rx) * ry;
    float4x4 _165;
    if (inverted)
    {
        _165 = transpose(m);
    }
    else
    {
        _165 = m;
    }
    return _165;
}

static inline __attribute__((always_inline))
void referenceVertexInit(constant ReferenceUniformse9bbc23eabea4& _293, thread float4x4& rotateAndOrient)
{
    float3 r = _293.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = referenceVertex_rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = referenceVertex_rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = referenceVertex_rotationAxisAngle(param_4, param_5);
    float3 param_6 = _293.orient_euler;
    bool param_7 = true;
    rotateAndOrient = ((referenceEuler(param_6, param_7) * rz) * rx) * ry;
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformse9bbc23eabea4& _293)
{
    return (float4(v, 0.0, 1.0) * _293.refLayerToScreen).xy;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float saturate0(thread const float& v)
{
    return fast::clamp(v, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float sdBox(thread const float3& p, thread const float3& b)
{
    float3 d = abs(p) - b;
    return length(fast::max(d, float3(0.0))) + fast::min(fast::max(d.x, fast::max(d.y, d.z)), 0.0);
}

static inline __attribute__((always_inline))
float2 sdExtrude(thread const float3& p, thread const float3& r, thread const float3& rd, constant ReferenceUniformse9bbc23eabea4& _293, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 st = (((p.xy / r.xy) * float2(1.0)) + float2(1.0)) / float2(2.0);
    float2 param = st;
    float2 param_1 = l2s(param, _293);
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
    float4 blurColor = float4(1.0, 1.0, 1.0, texColor.w);
    float param_2 = blurColor.w * 1.5;
    float t = fast::max(saturate0(param_2), texColor.w);
    float z = ((p.z / r.z) + 1.0) / 2.0;
    float maxdim = length(r);
    float td = ((1.0 - t) * ((maxdim * 2.0) * 1.0)) / _293.MAX_ITER;
    float3 param_3 = p;
    float3 param_4 = r * float3(2.0, 2.0, 1.0);
    return float2(fast::max(td, sdBox(param_3, param_4)), z);
}

static inline __attribute__((always_inline))
float2 dist(thread float3& p, thread const float3& rd, constant ReferenceUniformse9bbc23eabea4& _293, thread float4x4& rotateAndOrient, texture2d<float> refInput, sampler refInputSmplr)
{
    p -= (_293.position / float3(100.0));
    p = (float4(p, 1.0) * rotateAndOrient).xyz;
    float3 param = p;
    float3 param_1 = float3(((_293.stretch.x * 0.5) * _293.refLayer.z) / fast::max(_293.refLayer.z, _293.refLayer.w), ((_293.stretch.y * 0.5) * _293.refLayer.w) / fast::max(_293.refLayer.z, _293.refLayer.w), _293.depth);
    float3 param_2 = rd;
    return sdExtrude(param, param_1, param_2, _293, refInput, refInputSmplr);
}

static inline __attribute__((always_inline))
float2 march(thread const float3& ro, thread const float3& rd, constant ReferenceUniformse9bbc23eabea4& _293, thread float4x4& rotateAndOrient, texture2d<float> refInput, sampler refInputSmplr)
{
    float d = 0.0;
    float dz = -1.0;
    for (int i = 0; i < int(_293.MAX_ITER); i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float3 param_1 = rd;
        float2 _523 = dist(param, param_1, _293, rotateAndOrient, refInput, refInputSmplr);
        float2 dinf = _523;
        float dd = dinf.x;
        d += dd;
        if ((dd < 1.0000000116860974230803549289703e-07) || (d > 10000.0))
        {
            dz = dinf.y;
            break;
        }
    }
    return float2(d, dz);
}

static inline __attribute__((always_inline))
float3 calcNormal(thread const float3& p, thread const float3& rd, constant ReferenceUniformse9bbc23eabea4& _293, thread float4x4& rotateAndOrient, texture2d<float> refInput, sampler refInputSmplr)
{
    float3 param = p;
    float3 param_1 = rd;
    float2 _689 = dist(param, param_1, _293, rotateAndOrient, refInput, refInputSmplr);
    float d = _689.x;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_2 = p - e.xyy;
    float3 param_3 = rd;
    float2 _702 = dist(param_2, param_3, _293, rotateAndOrient, refInput, refInputSmplr);
    float3 param_4 = p - e.yxy;
    float3 param_5 = rd;
    float2 _711 = dist(param_4, param_5, _293, rotateAndOrient, refInput, refInputSmplr);
    float3 param_6 = p - e.yyx;
    float3 param_7 = rd;
    float2 _720 = dist(param_6, param_7, _293, rotateAndOrient, refInput, refInputSmplr);
    return fast::normalize(float3(d) - float3(_702.x, _711.x, _720.x));
}

static inline __attribute__((always_inline))
float4x4 rotationAxisAngle(thread const float3& v, thread const float& angle)
{
    float s = sin(angle);
    float c = cos(angle);
    float ic = 1.0 - c;
    return float4x4(float4(((v.x * v.x) * ic) + c, ((v.y * v.x) * ic) - (s * v.z), ((v.z * v.x) * ic) + (s * v.y), 0.0), float4(((v.x * v.y) * ic) + (s * v.z), ((v.y * v.y) * ic) + c, ((v.z * v.y) * ic) - (s * v.x), 0.0), float4(((v.x * v.z) * ic) - (s * v.y), ((v.y * v.z) * ic) + (s * v.x), ((v.z * v.z) * ic) + c, 0.0), float4(0.0, 0.0, 0.0, 1.0));
}

static inline __attribute__((always_inline))
float4x4 vecToVec(thread const float3& from, thread const float3& to)
{
    float3 w = cross(fast::normalize(from), fast::normalize(to));
    float3 axis = fast::normalize(w);
    float angle = asin(length(w));
    float3 param = axis;
    float param_1 = angle;
    return rotationAxisAngle(param, param_1);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    result = texColor * a;
    return result;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse9bbc23eabea4& _293, thread float4x4& rotateAndOrient, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    referenceVertexInit(_293, rotateAndOrient);
    float2 st = (gl_FragCoord.xy - _293.refLayer.xy) / _293.refLayer.zw;
    st -= float2(0.5);
    if (_293.refLayer.z < _293.refLayer.w)
    {
        st.x *= (_293.refLayer.z / _293.refLayer.w);
    }
    else
    {
        st.y *= (_293.refLayer.w / _293.refLayer.z);
    }
    st /= float2(_293.scale);
    st /= float2(6.0);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float2 dinf = march(param, param_1, _293, rotateAndOrient, refInput, refInputSmplr);
    float d = dinf.x;
    float dz = dinf.y;
    float3 p = ro + (rd * d);
    float3 param_2 = p;
    float3 param_3 = rd;
    float3 n = calcNormal(param_2, param_3, _293, rotateAndOrient, refInput, refInputSmplr);
    float3 nn = n;
    float4 localCoord = float4(p - (_293.position / float3(100.0)), 1.0);
    n = (float4(n, 0.0) * rotateAndOrient).xyz;
    localCoord *= rotateAndOrient;
    float4 pp = localCoord;
    float3 param_4 = n;
    float3 param_5 = pp.xyz * float3(0.0, 1.0, 0.0);
    float4 qq = pp * vecToVec(param_4, param_5);
    pp /= float4(((_293.stretch.x * 0.5) * _293.refLayer.z) / fast::max(_293.refLayer.z, _293.refLayer.w), ((_293.stretch.y * 0.5) * _293.refLayer.w) / fast::max(_293.refLayer.z, _293.refLayer.w), _293.depth, 1.0);
    float2 texCoord = (pp.xy + float2(1.0)) / float2(2.0);
    bool _920 = (((_293.stretch.x * 0.5) * _293.refLayer.z) / fast::max(_293.refLayer.z, _293.refLayer.w)) < 0.010499999858438968658447265625;
    bool _937;
    if (!_920)
    {
        _937 = (((_293.stretch.y * 0.5) * _293.refLayer.w) / fast::max(_293.refLayer.z, _293.refLayer.w)) < 0.010499999858438968658447265625;
    }
    else
    {
        _937 = _920;
    }
    float a = _937 ? 0.0 : 1.0;
    float2 param_6 = texCoord;
    float2 tc = l2s(param_6, _293);
    float2 param_7 = tc;
    float4 baseColor = texture2DCv(refInput, refInputSmplr, param_7);
    float2 param_8 = tc;
    float4 blurColor = texture2DCv(refInput, refInputSmplr, param_8);
    bool _955 = blurColor.w > baseColor.w;
    bool _962;
    if (_955)
    {
        _962 = blurColor.w > 0.25;
    }
    else
    {
        _962 = _955;
    }
    float4 texColor;
    if (_962)
    {
        texColor = blurColor / float4(blurColor.w);
    }
    else
    {
        if (baseColor.w > 0.25)
        {
            texColor = baseColor / float4(baseColor.w);
        }
        else
        {
            texColor = baseColor;
        }
    }
    if (_293.inton != 0u)
    {
        if ((dz > 0.001000000047497451305389404296875) && (dz < 0.999000012874603271484375))
        {
            if (_293.interiorBlend > 0.0)
            {
                texColor = mix(texColor, _293.interiorColor * texColor.w, float4(_293.interiorBlend));
            }
            if (_293.fadeBlend > 0.0)
            {
                texColor = mix(texColor, _293.fadeColor * texColor.w, float4(_293.fadeBlend * dz));
            }
        }
    }
    float4 param_9 = texColor;
    float3 param_10 = p;
    float3 param_11 = nn;
    float param_12 = d;
    referenceColor = applyShading(param_9, param_10, param_11, param_12) * a;
}

fragment refAM35_e9bbc23eabea4_out refAM35_e9bbc23eabea4(constant ReferenceUniformse9bbc23eabea4& _293 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9bbc23eabea4_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 rotateAndOrient;
    referenceMain(_293, rotateAndOrient, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _1053 = any(isnan(referenceColor));
    bool _1060;
    if (!_1053)
    {
        _1060 = any(isinf(referenceColor));
    }
    else
    {
        _1060 = _1053;
    }
    if (_1060)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1073 = referenceColor;
    float3 _1079 = fast::clamp(_1073.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1079.x;
    referenceColor.y = _1079.y;
    referenceColor.z = _1079.z;
    out.finalColor = referenceColor;
    return out;
}

