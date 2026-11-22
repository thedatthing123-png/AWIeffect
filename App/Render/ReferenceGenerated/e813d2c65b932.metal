// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s3d-octahedron.xml
// Original source comments and attribution:
//#define MAX_ITER 35
// Flat
// Point Light
// Directonal Light
// Depth Map
//float dd = clamp(1.-d/10.,0.,1.)*2.;
// Normal Map
// Normal * Depth
//vec4 localCoord = vec4(p-OBJECT_CENTER, 1.);
//n = (vec4(n,1.) * invOrient).xyz;
//localCoord *= invOrient;
//vec4 pp = localCoord;
//pp *= (vecToVec(n,vec3(0.,0.,localCoord.z))); // Octahedron
//// pp *= (vecToVec(n,vec3(localCoord.x,0.,0.))); // Cylinder, Taurus
//vec3 mappedCoord = pp.xyz;
//vec2 bottomCoord = localCoord.xz * rot(3.926990817);
//bottomCoord = ((bottomCoord/size)+1.0)/2.;
//bottomCoord = (bottomCoord - 0.5) * 1.41421 + 0.5;
//bottomCoord.x = 1.-bottomCoord.x;
//texCoord = mix(texCoord,bottomCoord,clamp(-n.y,0.,1.));
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

struct ReferenceUniformse813d2c65b932
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

struct refAM35_e813d2c65b932_out
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
    float4x4 _149;
    if (inverted)
    {
        _149 = transpose(m);
    }
    else
    {
        _149 = m;
    }
    return _149;
}

static inline __attribute__((always_inline))
void referenceVertexInit(constant ReferenceUniformse813d2c65b932& _278, thread float4x4& invOrient)
{
    float3 r = _278.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = referenceVertex_rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = referenceVertex_rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = referenceVertex_rotationAxisAngle(param_4, param_5);
    float3 param_6 = _278.orient_euler;
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
float dist(thread float3& p, constant ReferenceUniformse813d2c65b932& _278, thread float4x4& invOrient)
{
    float d = 100000000.0;
    p -= (_278.position / float3(100.0));
    p = (float4(p, 1.0) * invOrient).xyz;
    p.y /= _278.height;
    float3 param = p;
    float param_1 = _278.size - _278.ref_smooth;
    float _434 = sdOctahedron(param, param_1);
    d = fast::min(d, _434 - _278.ref_smooth);
    return d * fast::min(1.0, _278.height);
}

static inline __attribute__((always_inline))
float march(thread const float3& ro, thread const float3& rd, constant ReferenceUniformse813d2c65b932& _278, thread float4x4& invOrient)
{
    float d = 0.0;
    for (int i = 0; i < int(_278.MAX_ITER); i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float _470 = dist(param, _278, invOrient);
        float dd = _470;
        d += dd;
        if ((dd < 9.9999997473787516355514526367188e-06) || (d > 1000.0))
        {
            break;
        }
    }
    return d;
}

static inline __attribute__((always_inline))
float3 calcNormal(thread const float3& p, constant ReferenceUniformse813d2c65b932& _278, thread float4x4& invOrient)
{
    float3 param = p;
    float _493 = dist(param, _278, invOrient);
    float d = _493;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_1 = p - e.xyy;
    float _503 = dist(param_1, _278, invOrient);
    float3 param_2 = p - e.yxy;
    float _509 = dist(param_2, _278, invOrient);
    float3 param_3 = p - e.yyx;
    float _515 = dist(param_3, _278, invOrient);
    return fast::normalize(float3(d) - float3(_503, _509, _515));
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse813d2c65b932& _278)
{
    float3 lightPos = float3(_278.lightDir.x / 2.0, (-_278.lightDir.y) / 2.0, (-_278.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos - p);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float2 mapTexture(thread float2& texCoord, constant ReferenceUniformse813d2c65b932& _278)
{
    float texRad = _278.texAngle * 0.01745329983532428741455078125;
    float texCos = cos(texRad);
    float texSin = sin(texRad);
    float2x2 texRot = float2x2(float2(texCos, -texSin), float2(texSin, texCos));
    float texTwirlRad = _278.texTwirl * 0.01745329983532428741455078125;
    float texTwirlCos = cos(texTwirlRad);
    float texTwirlSin = sin(texTwirlRad);
    float2x2 texTwirlRot = float2x2(float2(texTwirlCos, -texTwirlSin), float2(texTwirlSin, texTwirlCos));
    float2 texScaleVec = float2(1.0 / _278.texRepeatX, 1.0 / _278.texRepeatY);
    texCoord *= texRot;
    texCoord += (_278.texOffset / float2(1000.0));
    texCoord /= texScaleVec;
    if (_278.mirror != 0u)
    {
        texCoord = abs(mod(texCoord, float2(2.0)) - float2(1.0));
    }
    else
    {
        texCoord = mod(texCoord, float2(1.0));
    }
    texCoord -= float2(0.5);
    texCoord *= (float2(1.0) - (float2(5.0) / _278.refScreen.xy));
    texCoord *= _278.texCrop;
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
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse813d2c65b932& _278)
{
    float3 lightPos = float3(_278.lightDir.x / 2.0, (-_278.lightDir.y) / 2.0, (-_278.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformse813d2c65b932& _278)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    if (_278.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_278.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _278);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _278.ambient) + (((tc * _278.lightColor.xyz) * l) * (1.0 - _278.ambient));
            surface *= _278.lightIntensity;
            float s = powr(l, _278.spec);
            surface = mix(surface * (1.0 - (_278.shine * 0.100000001490116119384765625)), float3(1.0), float3(_278.shine * s));
            result = float4(surface, texColor.w) * a;
        }
        else
        {
            if (_278.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _278);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _278.ambient) + (((tc_1 * _278.lightColor.xyz) * l_1) * (1.0 - _278.ambient));
                surface_1 *= _278.lightIntensity;
                float s_1 = powr(l_1, _278.spec);
                surface_1 = mix(surface_1 * (1.0 - (_278.shine * 0.100000001490116119384765625)), float3(1.0), float3(_278.shine * s_1));
                result = float4(surface_1, texColor.w) * a;
            }
            else
            {
                if (_278.shadingType == 3)
                {
                    float ds = _278.size * 2.5;
                    float dd = 1.0 - (((d - (_278.position / float3(100.0)).z) + (ds / 2.0)) / ds);
                    result = float4(dd, dd, dd, 1.0) * a;
                }
                else
                {
                    if (_278.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_278.shadingType == 5)
                        {
                            float ds_1 = _278.size * 2.5;
                            float dd_1 = 1.0 - (((d - (_278.position / float3(100.0)).z) + (ds_1 / 2.0)) / ds_1);
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
void referenceMain(constant ReferenceUniformse813d2c65b932& _278, thread float4x4& invOrient, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    referenceVertexInit(_278, invOrient);
    float2 st = (gl_FragCoord.xy - _278.refLayer.xy) / _278.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_278.refLayer.z / _278.refLayer.w);
    st /= float2(_278.scale);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float d = march(param, param_1, _278, invOrient);
    float3 p = ro + (rd * d);
    float3 param_2 = p;
    float3 n = calcNormal(param_2, _278, invOrient);
    float3 nn = n;
    float3 param_3 = p;
    float3 param_4 = n;
    float l = lighting(param_3, param_4, _278);
    float4 localCoord = float4(p - (_278.position / float3(100.0)), 1.0);
    n = (float4(n, 1.0) * invOrient).xyz;
    localCoord *= invOrient;
    float3 pp = localCoord.xyz;
    pp /= float3(_278.size);
    pp.y /= _278.height;
    pp = abs(pp);
    float rr = 1.0 - pp.y;
    float3 xedge = float3(rr, pp.y, 0.0);
    float xdist = length(pp - xedge) / (1.41420996189117431640625 * rr);
    float adjxdist = ((xdist - 0.5) * mix(rr, 1.0, _278.texSqueeze)) + 0.5;
    float3 top = float3(0.0, 1.0, 0.0);
    float ydist = length(pp - top) * cos(abs(xdist - 0.5) * 1.0471899509429931640625);
    ydist /= 1.41420996189117431640625;
    float2 texCoord = float2(adjxdist, 1.0 - ydist);
    float2 param_5 = texCoord;
    float2 _1078 = mapTexture(param_5, _278);
    texCoord = _1078;
    float2 param_6 = (float4(texCoord, 0.0, 1.0) * _278.refLayerToScreen).xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_6);
    float4 param_7 = texColor;
    float3 param_8 = p;
    float3 param_9 = nn;
    float param_10 = d;
    referenceColor = applyShading(param_7, param_8, param_9, param_10, _278);
}

fragment refAM35_e813d2c65b932_out refAM35_e813d2c65b932(constant ReferenceUniformse813d2c65b932& _278 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e813d2c65b932_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 invOrient;
    referenceMain(_278, invOrient, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1107 = any(isnan(referenceColor));
    bool _1114;
    if (!_1107)
    {
        _1114 = any(isinf(referenceColor));
    }
    else
    {
        _1114 = _1107;
    }
    if (_1114)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1127 = referenceColor;
    float3 _1133 = fast::clamp(_1127.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1133.x;
    referenceColor.y = _1133.y;
    referenceColor.z = _1133.z;
    out.finalColor = referenceColor;
    return out;
}

