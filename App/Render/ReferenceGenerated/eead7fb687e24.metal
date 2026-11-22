// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s3d-extrude.xml
// Original source comments and attribution:
// remove this line for an only partially signed sdf
// Flat
// Point Light
// Directonal Light
// Depth Map
//float dd = clamp(1.-d/10.,0.,1.)*2.;
// Normal Map
// Normal * Depth
/*if( n.x > 0.5 ) {
                texCoord = ((pp.zy+1.)/2.);
                a = height<0.0105 || depth<0.0105 ? 0.0 : 1.0;
            } else if ( n.x < -0.5 ) {
                texCoord = ((pp.zy+1.)/2.);
                texCoord.x = 1.-texCoord.x;
                a = height<0.0105 || depth<0.0105 ? 0.0 : 1.0;
            } else if ( n.y > 0.5 ) {
                texCoord = ((pp.xz+1.)/2.);
                a = width<0.0105 || depth<0.0105 ? 0.0 : 1.0;
            } else if ( n.y < -0.5 ) {
                texCoord = 1.-((pp.xz+1.)/2.);
                texCoord.x = 1.-texCoord.x;
                a = width<0.0105 || depth<0.0105 ? 0.0 : 1.0;
            } else if ( n.z > 0.5 ) {
                texCoord = (pp.xy+1.)/2.;
                texCoord.x = 1.-texCoord.x;
                a = width<0.0105 || height<0.0105 ? 0.0 : 1.0;
            } else if ( n.z < -0.5 ) {
                texCoord = (pp.xy+1.)/2.;
                a = width<0.0105 || height<0.0105 ? 0.0 : 1.0;
            } else {
                texCoord = vec2(0.,0.);
                a = 1.0;
            }*/
//vec2 texCoord = (qq.xz+1.)/2.;
//texCoord = mod(texCoord*crop, 1.);
//texCoord = mapTexture(texCoord);
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

struct ReferenceUniformseead7fb687e24
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 orient_euler;
    float3 rotate;
    float widthRatio;
    char _m8_pad[12];
    float heightRatio;
    char _m9_pad[12];
    float depth;
    float3 position;
    float scale;
    float4 interiorColor;
    float interiorBlend;
    float4 fadeColor;
    float fadeBlend;
    char _m16_pad[12];
    int shadingType;
    char _m17_pad[12];
    float lightIntensity;
    char _m18_pad[12];
    float shine;
    char _m19_pad[12];
    float spec;
    char _m20_pad[12];
    float ambient;
    float4 lightColor;
    float2 lightDir;
    char _m23_pad[8];
    float lightDepth;
    char _m24_pad[12];
    float MAX_ITER;
};

struct refAM35_eead7fb687e24_out
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
    float4x4 _173;
    if (inverted)
    {
        _173 = transpose(m);
    }
    else
    {
        _173 = m;
    }
    return _173;
}

static inline __attribute__((always_inline))
void referenceVertexInit(constant ReferenceUniformseead7fb687e24& _302, thread float4x4& rotateAndOrient)
{
    float3 r = _302.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = referenceVertex_rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = referenceVertex_rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = referenceVertex_rotationAxisAngle(param_4, param_5);
    float3 param_6 = _302.orient_euler;
    bool param_7 = true;
    rotateAndOrient = ((referenceEuler(param_6, param_7) * rz) * rx) * ry;
}

static inline __attribute__((always_inline))
float2 l2s(thread const float2& v, constant ReferenceUniformseead7fb687e24& _302)
{
    return (float4(v, 0.0, 1.0) * _302.refLayerToScreen).xy;
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
float2 sdExtrude(thread const float3& p, thread const float3& r, thread const float3& rd, constant ReferenceUniformseead7fb687e24& _302, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float2 st = (((p.xy / r.xy) * float2(1.0)) + float2(1.0)) / float2(2.0);
    float2 param = st;
    float2 param_1 = l2s(param, _302);
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
    float2 param_2 = st;
    float2 param_3 = l2s(param_2, _302);
    float4 blurColor = texture2DCv(refBuffer1, refBuffer1Smplr, param_3);
    float param_4 = blurColor.w * 2.0;
    float t = fast::max(saturate0(param_4), texColor.w);
    float z = ((p.z / r.z) + 1.0) / 2.0;
    float maxdim = length(r);
    float td = ((1.0 - t) * ((maxdim * 2.0) * 1.10000002384185791015625)) / _302.MAX_ITER;
    float3 param_5 = p;
    float3 param_6 = r * float3(2.0, 2.0, 1.0);
    return float2(fast::max(td, sdBox(param_5, param_6)), z);
}

static inline __attribute__((always_inline))
float2 dist(thread float3& p, thread const float3& rd, constant ReferenceUniformseead7fb687e24& _302, thread float4x4& rotateAndOrient, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    p -= (_302.position / float3(100.0));
    p = (float4(p, 1.0) * rotateAndOrient).xyz;
    float3 param = p;
    float3 param_1 = float3(((_302.widthRatio * 0.5) * _302.refLayer.z) / fast::max(_302.refLayer.z, _302.refLayer.w), ((_302.heightRatio * 0.5) * _302.refLayer.w) / fast::max(_302.refLayer.z, _302.refLayer.w), _302.depth);
    float3 param_2 = rd;
    return sdExtrude(param, param_1, param_2, _302, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr);
}

static inline __attribute__((always_inline))
float2 march(thread const float3& ro, thread const float3& rd, constant ReferenceUniformseead7fb687e24& _302, thread float4x4& rotateAndOrient, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float d = 0.0;
    float dz = -1.0;
    for (int i = 0; i < int(_302.MAX_ITER); i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float3 param_1 = rd;
        float2 _535 = dist(param, param_1, _302, rotateAndOrient, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr);
        float2 dinf = _535;
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
float3 calcNormal(thread const float3& p, thread const float3& rd, constant ReferenceUniformseead7fb687e24& _302, thread float4x4& rotateAndOrient, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float3 param = p;
    float3 param_1 = rd;
    float2 _701 = dist(param, param_1, _302, rotateAndOrient, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr);
    float d = _701.x;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_2 = p - e.xyy;
    float3 param_3 = rd;
    float2 _714 = dist(param_2, param_3, _302, rotateAndOrient, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr);
    float3 param_4 = p - e.yxy;
    float3 param_5 = rd;
    float2 _723 = dist(param_4, param_5, _302, rotateAndOrient, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr);
    float3 param_6 = p - e.yyx;
    float3 param_7 = rd;
    float2 _732 = dist(param_6, param_7, _302, rotateAndOrient, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr);
    return fast::normalize(float3(d) - float3(_714.x, _723.x, _732.x));
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformseead7fb687e24& _302)
{
    float3 lightPos = float3(_302.lightDir.x / 2.0, (-_302.lightDir.y) / 2.0, (-_302.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos - p);
    return dot(n, l);
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
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformseead7fb687e24& _302)
{
    float3 lightPos = float3(_302.lightDir.x / 2.0, (-_302.lightDir.y) / 2.0, (-_302.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformseead7fb687e24& _302)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    if (_302.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_302.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _302);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _302.ambient) + (((tc * _302.lightColor.xyz) * l) * (1.0 - _302.ambient));
            surface *= _302.lightIntensity;
            float s = powr(l, _302.spec);
            surface = mix(surface * (1.0 - (_302.shine * 0.100000001490116119384765625)), float3(1.0), float3(_302.shine * s));
            result = float4(surface, texColor.w) * a;
        }
        else
        {
            if (_302.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _302);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _302.ambient) + (((tc_1 * _302.lightColor.xyz) * l_1) * (1.0 - _302.ambient));
                surface_1 *= _302.lightIntensity;
                float s_1 = powr(l_1, _302.spec);
                surface_1 = mix(surface_1 * (1.0 - (_302.shine * 0.100000001490116119384765625)), float3(1.0), float3(_302.shine * s_1));
                result = float4(surface_1, texColor.w) * a;
            }
            else
            {
                if (_302.shadingType == 3)
                {
                    float ds = fast::max(fast::max(((_302.widthRatio * 0.5) * _302.refLayer.z) / fast::max(_302.refLayer.z, _302.refLayer.w), ((_302.heightRatio * 0.5) * _302.refLayer.w) / fast::max(_302.refLayer.z, _302.refLayer.w)), _302.depth) * 2.5;
                    float dd = 1.0 - (((d - (_302.position / float3(100.0)).z) + (ds / 2.0)) / ds);
                    result = float4(dd, dd, dd, 1.0) * a;
                }
                else
                {
                    if (_302.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_302.shadingType == 5)
                        {
                            float ds_1 = fast::max(fast::max(((_302.widthRatio * 0.5) * _302.refLayer.z) / fast::max(_302.refLayer.z, _302.refLayer.w), ((_302.heightRatio * 0.5) * _302.refLayer.w) / fast::max(_302.refLayer.z, _302.refLayer.w)), _302.depth) * 2.5;
                            float dd_1 = 1.0 - (((d - (_302.position / float3(100.0)).z) + (ds_1 / 2.0)) / ds_1);
                            result = float4(((n / float3(2.0)) + float3(0.5)) * dd_1, 1.0) * a;
                        }
                    }
                }
            }
        }
    }
    return result;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseead7fb687e24& _302, thread float4x4& rotateAndOrient, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refBuffer1, sampler refBuffer1Smplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    referenceVertexInit(_302, rotateAndOrient);
    float2 st = (gl_FragCoord.xy - _302.refLayer.xy) / _302.refLayer.zw;
    st -= float2(0.5);
    if (_302.refLayer.z < _302.refLayer.w)
    {
        st.x *= (_302.refLayer.z / _302.refLayer.w);
    }
    else
    {
        st.y *= (_302.refLayer.w / _302.refLayer.z);
    }
    st /= float2(_302.scale);
    st /= float2(5.80000019073486328125);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float2 dinf = march(param, param_1, _302, rotateAndOrient, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr);
    float d = dinf.x;
    float dz = dinf.y;
    float3 p = ro + (rd * d);
    float3 param_2 = p;
    float3 param_3 = rd;
    float3 n = calcNormal(param_2, param_3, _302, rotateAndOrient, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr);
    float3 nn = n;
    float3 param_4 = p;
    float3 param_5 = n;
    float l = lighting(param_4, param_5, _302);
    float4 localCoord = float4(p - (_302.position / float3(100.0)), 1.0);
    n = (float4(n, 0.0) * rotateAndOrient).xyz;
    localCoord *= rotateAndOrient;
    float4 pp = localCoord;
    float3 param_6 = n;
    float3 param_7 = pp.xyz * float3(0.0, 1.0, 0.0);
    float4 qq = pp * vecToVec(param_6, param_7);
    pp /= float4(((_302.widthRatio * 0.5) * _302.refLayer.z) / fast::max(_302.refLayer.z, _302.refLayer.w), ((_302.heightRatio * 0.5) * _302.refLayer.w) / fast::max(_302.refLayer.z, _302.refLayer.w), _302.depth, 1.0);
    float2 texCoord = (pp.xy + float2(1.0)) / float2(2.0);
    bool _1259 = (((_302.widthRatio * 0.5) * _302.refLayer.z) / fast::max(_302.refLayer.z, _302.refLayer.w)) < 0.010499999858438968658447265625;
    bool _1276;
    if (!_1259)
    {
        _1276 = (((_302.heightRatio * 0.5) * _302.refLayer.w) / fast::max(_302.refLayer.z, _302.refLayer.w)) < 0.010499999858438968658447265625;
    }
    else
    {
        _1276 = _1259;
    }
    float a = _1276 ? 0.0 : 1.0;
    float2 param_8 = texCoord;
    float2 tc = l2s(param_8, _302);
    float2 param_9 = tc;
    float4 baseColor = texture2DCv(refInput, refInputSmplr, param_9);
    float2 param_10 = tc;
    float4 blurColor = texture2DCv(refBuffer1, refBuffer1Smplr, param_10);
    bool _1294 = blurColor.w > baseColor.w;
    bool _1301;
    if (_1294)
    {
        _1301 = blurColor.w > 0.25;
    }
    else
    {
        _1301 = _1294;
    }
    float4 texColor;
    if (_1301)
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
    if ((dz > 0.001000000047497451305389404296875) && (dz < 0.999000012874603271484375))
    {
        if (_302.interiorBlend > 0.0)
        {
            texColor = mix(texColor, _302.interiorColor * texColor.w, float4(_302.interiorBlend));
        }
        if (_302.fadeBlend > 0.0)
        {
            texColor = mix(texColor, _302.fadeColor * texColor.w, float4(_302.fadeBlend * dz));
        }
    }
    float4 param_11 = texColor;
    float3 param_12 = p;
    float3 param_13 = nn;
    float param_14 = d;
    referenceColor = applyShading(param_11, param_12, param_13, param_14, _302) * a;
}

fragment refAM35_eead7fb687e24_out refAM35_eead7fb687e24(constant ReferenceUniformseead7fb687e24& _302 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_eead7fb687e24_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 rotateAndOrient;
    referenceMain(_302, rotateAndOrient, refInput, refInputSmplr, refBuffer1, refBuffer1Smplr, gl_FragCoord, referenceColor);
    bool _1385 = any(isnan(referenceColor));
    bool _1392;
    if (!_1385)
    {
        _1392 = any(isinf(referenceColor));
    }
    else
    {
        _1392 = _1385;
    }
    if (_1392)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1405 = referenceColor;
    float3 _1411 = fast::clamp(_1405.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1411.x;
    referenceColor.y = _1411.y;
    referenceColor.z = _1411.z;
    out.finalColor = referenceColor;
    return out;
}

