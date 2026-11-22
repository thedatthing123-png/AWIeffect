// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s3d-pyramid.xml
// Original source comments and attribution:
//#define MAX_ITER 35
// remove this line for an only partially signed sdf
//d = min(d,sdOctahedron(p,size-smooth) - smooth);
// Pyramid
// Flat
// Point Light
// Directonal Light
// Depth Map
//float dd = clamp(1.-d/10.,0.,1.)*2.;
// Normal Map
// Normal * Depth
//pp *= (vecToVec(n,vec3(0.,0.,localCoord.z))); // Octahedron
// pp *= (vecToVec(n,vec3(localCoord.x,0.,0.))); // Cylinder, Taurus
//vec3 mappedCoord = pp.xyz;
//vec2 texCoord = mod((mappedCoord.xy + 0.838)*0.6*crop, 1.);
//vec2 texCoord = (mappedCoord.xy + 0.838)*0.6;
//gl_FragColor = d > 500.0 ? vec4( 0. ) : vec4(texColor.rgb * l, texColor.a);
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

// Implementation of the GLSL radians() function
template<typename T>
inline T radians(T d)
{
    return d * T(0.01745329251);
}

struct ReferenceUniformsec2da1b62e988
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 orient_euler;
    float3 rotate;
    float size;
    char _m8_pad[12];
    float height;
    char _m9_pad[12];
    float ref_smooth;
    float3 position;
    float scale;
    char _m12_pad[12];
    int shadingType;
    char _m13_pad[12];
    float lightIntensity;
    char _m14_pad[12];
    float shine;
    char _m15_pad[12];
    float spec;
    char _m16_pad[12];
    float ambient;
    float4 lightColor;
    float2 lightDir;
    char _m19_pad[8];
    float lightDepth;
    char _m20_pad[12];
    uint mirror;
    char _m21_pad[12];
    float texSqueeze;
    char _m22_pad[12];
    float texRepeatX;
    char _m23_pad[12];
    float texRepeatY;
    char _m24_pad[12];
    float texAngle;
    char _m25_pad[12];
    float texCrop;
    char _m26_pad[12];
    float texTwirl;
    char _m27_pad[8];
    float2 texOffset;
    char _m28_pad[8];
    float MAX_ITER;
};

struct refAM35_ec2da1b62e988_out
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
    float4x4 _164;
    if (inverted)
    {
        _164 = transpose(m);
    }
    else
    {
        _164 = m;
    }
    return _164;
}

static inline __attribute__((always_inline))
void referenceVertexInit(constant ReferenceUniformsec2da1b62e988& _293, thread float4x4& invOrient)
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
    invOrient = ((referenceEuler(param_6, param_7) * rz) * rx) * ry;
}

static inline __attribute__((always_inline))
float sdOctahedron(thread float3& p, thread const float& s)
{
    p = abs(p);
    float m = ((p.x + p.y) + p.z) - s;
    float3 q;
    if ((3.0 * p.x) < m)
    {
        q = p;
    }
    else
    {
        if ((3.0 * p.y) < m)
        {
            q = p.yzx;
        }
        else
        {
            if ((3.0 * p.z) < m)
            {
                q = p.zxy;
            }
            else
            {
                return m * 0.57735025882720947265625;
            }
        }
    }
    float k = fast::clamp(0.5 * ((q.z - q.y) + s), 0.0, s);
    return length(float3(q.x, (q.y - s) + k, q.z - k));
}

static inline __attribute__((always_inline))
float sdBox(thread const float3& p, thread const float3& b)
{
    float3 d = abs(p) - b;
    return length(fast::max(d, float3(0.0))) + fast::min(fast::max(d.x, fast::max(d.y, d.z)), 0.0);
}

static inline __attribute__((always_inline))
float opSmoothIntersection(thread const float& d1, thread const float& d2, thread const float& k)
{
    float h = fast::clamp(0.5 - ((0.5 * (d2 - d1)) / k), 0.0, 1.0);
    return mix(d2, d1, h) + ((k * h) * (1.0 - h));
}

static inline __attribute__((always_inline))
float dist(thread float3& p, constant ReferenceUniformsec2da1b62e988& _293, thread float4x4& invOrient)
{
    float d = 100000000.0;
    p -= (_293.position / float3(100.0));
    p = (float4(p, 1.0) * invOrient).xyz;
    p.y /= _293.height;
    float3 param = p;
    float param_1 = _293.size - _293.ref_smooth;
    float _492 = sdOctahedron(param, param_1);
    float3 param_2 = p + (float3(0.0, -2.0, 0.0) * _293.size);
    float3 param_3 = float3(3.0, 2.0, 3.0) * _293.size;
    float param_4 = _492 - _293.ref_smooth;
    float param_5 = sdBox(param_2, param_3);
    float param_6 = _293.ref_smooth;
    d = fast::min(d, opSmoothIntersection(param_4, param_5, param_6));
    return d * fast::min(1.0, _293.height);
}

static inline __attribute__((always_inline))
float march(thread const float3& ro, thread const float3& rd, constant ReferenceUniformsec2da1b62e988& _293, thread float4x4& invOrient)
{
    float d = 0.0;
    for (int i = 0; i < int(_293.MAX_ITER); i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float _549 = dist(param, _293, invOrient);
        float dd = _549;
        d += dd;
        if ((dd < 9.9999997473787516355514526367188e-06) || (d > 1000.0))
        {
            break;
        }
    }
    return d;
}

static inline __attribute__((always_inline))
float3 calcNormal(thread const float3& p, constant ReferenceUniformsec2da1b62e988& _293, thread float4x4& invOrient)
{
    float3 param = p;
    float _572 = dist(param, _293, invOrient);
    float d = _572;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_1 = p - e.xyy;
    float _582 = dist(param_1, _293, invOrient);
    float3 param_2 = p - e.yxy;
    float _588 = dist(param_2, _293, invOrient);
    float3 param_3 = p - e.yyx;
    float _594 = dist(param_3, _293, invOrient);
    return fast::normalize(float3(d) - float3(_582, _588, _594));
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformsec2da1b62e988& _293)
{
    float3 lightPos = float3(_293.lightDir.x / 2.0, (-_293.lightDir.y) / 2.0, (-_293.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos - p);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float2 mapTexture(thread float2& texCoord, constant ReferenceUniformsec2da1b62e988& _293)
{
    float texRad = _293.texAngle * 0.01745329983532428741455078125;
    float texCos = cos(texRad);
    float texSin = sin(texRad);
    float2x2 texRot = float2x2(float2(texCos, -texSin), float2(texSin, texCos));
    float texTwirlRad = _293.texTwirl * 0.01745329983532428741455078125;
    float texTwirlCos = cos(texTwirlRad);
    float texTwirlSin = sin(texTwirlRad);
    float2x2 texTwirlRot = float2x2(float2(texTwirlCos, -texTwirlSin), float2(texTwirlSin, texTwirlCos));
    float2 texScaleVec = float2(1.0 / _293.texRepeatX, 1.0 / _293.texRepeatY);
    texCoord *= texRot;
    texCoord += (_293.texOffset / float2(1000.0));
    texCoord /= texScaleVec;
    if (_293.mirror != 0u)
    {
        texCoord = abs(mod(texCoord, float2(2.0)) - float2(1.0));
    }
    else
    {
        texCoord = mod(texCoord, float2(1.0));
    }
    texCoord -= float2(0.5);
    texCoord *= (float2(1.0) - (float2(5.0) / _293.refScreen.xy));
    texCoord *= _293.texCrop;
    texCoord *= texTwirlRot;
    texCoord += float2(0.5);
    return texCoord;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformsec2da1b62e988& _293)
{
    float3 lightPos = float3(_293.lightDir.x / 2.0, (-_293.lightDir.y) / 2.0, (-_293.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformsec2da1b62e988& _293)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    if (_293.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_293.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _293);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _293.ambient) + (((tc * _293.lightColor.xyz) * l) * (1.0 - _293.ambient));
            surface *= _293.lightIntensity;
            float s = powr(l, _293.spec);
            surface = mix(surface * (1.0 - (_293.shine * 0.100000001490116119384765625)), float3(1.0), float3(_293.shine * s));
            result = float4(surface, texColor.w) * a;
        }
        else
        {
            if (_293.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _293);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _293.ambient) + (((tc_1 * _293.lightColor.xyz) * l_1) * (1.0 - _293.ambient));
                surface_1 *= _293.lightIntensity;
                float s_1 = powr(l_1, _293.spec);
                surface_1 = mix(surface_1 * (1.0 - (_293.shine * 0.100000001490116119384765625)), float3(1.0), float3(_293.shine * s_1));
                result = float4(surface_1, texColor.w) * a;
            }
            else
            {
                if (_293.shadingType == 3)
                {
                    float ds = _293.size * 2.5;
                    float dd = 1.0 - ((d - (_293.position / float3(100.0)).z) / ds);
                    result = float4(dd, dd, dd, 1.0) * a;
                }
                else
                {
                    if (_293.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_293.shadingType == 5)
                        {
                            float ds_1 = _293.size * 2.5;
                            float dd_1 = 1.0 - ((d - (_293.position / float3(100.0)).z) / ds_1);
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
void referenceMain(constant ReferenceUniformsec2da1b62e988& _293, thread float4x4& invOrient, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    referenceVertexInit(_293, invOrient);
    float2 st = (gl_FragCoord.xy - _293.refLayer.xy) / _293.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_293.refLayer.z / _293.refLayer.w);
    st /= float2(_293.scale);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float d = march(param, param_1, _293, invOrient);
    float3 p = ro + (rd * d);
    float3 param_2 = p;
    float3 n = calcNormal(param_2, _293, invOrient);
    float3 nn = n;
    float3 param_3 = p;
    float3 param_4 = n;
    float l = lighting(param_3, param_4, _293);
    float4 localCoord = float4(p - (_293.position / float3(100.0)), 1.0);
    n = (float4(n, 1.0) * invOrient).xyz;
    localCoord *= invOrient;
    float3 pp = localCoord.xyz;
    pp /= float3(_293.size);
    pp.y /= _293.height;
    pp = abs(pp);
    float rr = 1.0 - pp.y;
    float3 xedge = float3(rr, pp.y, 0.0);
    float xdist = length(pp - xedge) / (1.41420996189117431640625 * rr);
    float adjxdist = ((xdist - 0.5) * mix(rr, 1.0, _293.texSqueeze)) + 0.5;
    float3 top = float3(0.0, 1.0, 0.0);
    float ydist = length(pp - top) * cos(abs(xdist - 0.5) * 1.0471899509429931640625);
    ydist /= 1.41420996189117431640625;
    float2 texCoord = float2(adjxdist, 1.0 - ydist);
    float param_5 = 3.9269907474517822265625;
    float2 bottomCoord = localCoord.xz * rot(param_5);
    bottomCoord = ((bottomCoord / float2(_293.size)) + float2(1.0)) / float2(2.0);
    bottomCoord = ((bottomCoord - float2(0.5)) * 1.41420996189117431640625) + float2(0.5);
    bottomCoord.x = 1.0 - bottomCoord.x;
    texCoord = mix(texCoord, bottomCoord, float2(fast::clamp(-n.y, 0.0, 1.0)));
    float2 param_6 = texCoord;
    float2 _1199 = mapTexture(param_6, _293);
    texCoord = _1199;
    float2 param_7 = (float4(texCoord, 0.0, 1.0) * _293.refLayerToScreen).xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_7);
    float4 param_8 = texColor;
    float3 param_9 = p;
    float3 param_10 = nn;
    float param_11 = d;
    referenceColor = applyShading(param_8, param_9, param_10, param_11, _293);
}

fragment refAM35_ec2da1b62e988_out refAM35_ec2da1b62e988(constant ReferenceUniformsec2da1b62e988& _293 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec2da1b62e988_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 invOrient;
    referenceMain(_293, invOrient, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1228 = any(isnan(referenceColor));
    bool _1235;
    if (!_1228)
    {
        _1235 = any(isinf(referenceColor));
    }
    else
    {
        _1235 = _1228;
    }
    if (_1235)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1248 = referenceColor;
    float3 _1254 = fast::clamp(_1248.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1254.x;
    referenceColor.y = _1254.y;
    referenceColor.z = _1254.z;
    out.finalColor = referenceColor;
    return out;
}

