// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s3d-starpoly.xml
// Original source comments and attribution:
//#define MAX_ITER 35
//d = min(d,sdOctahedron(p,size-smooth) - smooth);
// Flat
// Point Light
// Directonal Light
// Depth Map
//float dd = clamp(1.-d/10.,0.,1.)*2.;
// Normal Map
// Normal * Depth
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

struct ReferenceUniformsede5369a89427
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
    float pointLength;
    char _m10_pad[12];
    float ref_smooth;
    float3 position;
    float scale;
    char _m13_pad[12];
    float pointCount;
    char _m14_pad[12];
    int shadingType;
    char _m15_pad[12];
    float lightIntensity;
    char _m16_pad[12];
    float shine;
    char _m17_pad[12];
    float spec;
    char _m18_pad[12];
    float ambient;
    float4 lightColor;
    float2 lightDir;
    char _m21_pad[8];
    float lightDepth;
    char _m22_pad[12];
    uint mirror;
    char _m23_pad[12];
    float texRepeatX;
    char _m24_pad[12];
    float texRepeatY;
    char _m25_pad[12];
    float texAngle;
    char _m26_pad[12];
    float texCrop;
    char _m27_pad[12];
    float texTwirl;
    char _m28_pad[8];
    float2 texOffset;
    char _m29_pad[8];
    float MAX_ITER;
};

struct refAM35_ede5369a89427_out
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
void referenceVertexInit(constant ReferenceUniformsede5369a89427& _301, thread float4x4& rotateAndOrient)
{
    float3 r = _301.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = referenceVertex_rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = referenceVertex_rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = referenceVertex_rotationAxisAngle(param_4, param_5);
    float3 param_6 = _301.orient_euler;
    bool param_7 = true;
    rotateAndOrient = ((referenceEuler(param_6, param_7) * rz) * rx) * ry;
}

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
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
float sdPartialLongOctahedron(thread float3& p, thread const float& s, thread const float& elongation, constant ReferenceUniformsede5369a89427& _301)
{
    p.y /= elongation;
    float3 param = p;
    float param_1 = s;
    float _446 = sdOctahedron(param, param_1);
    float d = _446;
    d = fast::max(d, fast::clamp((-p.y) + _301.ref_smooth, 0.0, 1.0));
    d *= fast::min(1.0, elongation);
    return d;
}

static inline __attribute__((always_inline))
float sdStarPoly(thread float3& p, thread const float2& s, thread const int& points, constant ReferenceUniformsede5369a89427& _301)
{
    float d = 100000000.0;
    float param = 6.28318023681640625 / float(points);
    float2x2 rmat = rot(param);
    for (int i = 0; i < points; i++)
    {
        float3 param_1 = p;
        float param_2 = s.x;
        float param_3 = _301.pointLength + 0.800000011920928955078125;
        float _497 = sdPartialLongOctahedron(param_1, param_2, param_3, _301);
        d = fast::min(d, _497);
        float2 pr = p.xy * rmat;
        p.x = pr.x;
        p.y = pr.y;
    }
    return d;
}

static inline __attribute__((always_inline))
float dist(thread float3& p, constant ReferenceUniformsede5369a89427& _301, thread float4x4& rotateAndOrient)
{
    float d = 100000000.0;
    p -= ((_301.position + float3(0.0, -5.0, 0.0)) / float3(100.0));
    p = (float4(p, 1.0) * rotateAndOrient).xyz;
    p.z /= _301.height;
    float3 param = p;
    float2 param_1 = float2(_301.size - _301.ref_smooth);
    int param_2 = int(_301.pointCount);
    float _559 = sdStarPoly(param, param_1, param_2, _301);
    d = fast::min(d, _559 - _301.ref_smooth);
    return d * fast::min(1.0, _301.height);
}

static inline __attribute__((always_inline))
float march(thread const float3& ro, thread const float3& rd, constant ReferenceUniformsede5369a89427& _301, thread float4x4& rotateAndOrient)
{
    float d = 0.0;
    for (int i = 0; i < int(_301.MAX_ITER); i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float _593 = dist(param, _301, rotateAndOrient);
        float dd = _593;
        d += dd;
        if ((dd < 9.9999997473787516355514526367188e-06) || (d > 1000.0))
        {
            break;
        }
    }
    return d;
}

static inline __attribute__((always_inline))
float3 calcNormal(thread const float3& p, constant ReferenceUniformsede5369a89427& _301, thread float4x4& rotateAndOrient)
{
    float3 param = p;
    float _615 = dist(param, _301, rotateAndOrient);
    float d = _615;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_1 = p - e.xyy;
    float _625 = dist(param_1, _301, rotateAndOrient);
    float3 param_2 = p - e.yxy;
    float _631 = dist(param_2, _301, rotateAndOrient);
    float3 param_3 = p - e.yyx;
    float _637 = dist(param_3, _301, rotateAndOrient);
    return fast::normalize(float3(d) - float3(_625, _631, _637));
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformsede5369a89427& _301)
{
    float3 lightPos = float3(_301.lightDir.x / 2.0, (-_301.lightDir.y) / 2.0, (-_301.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos - p);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float2 mapTexture(thread float2& texCoord, constant ReferenceUniformsede5369a89427& _301)
{
    float texRad = _301.texAngle * 0.01745329983532428741455078125;
    float texCos = cos(texRad);
    float texSin = sin(texRad);
    float2x2 texRot = float2x2(float2(texCos, -texSin), float2(texSin, texCos));
    float texTwirlRad = _301.texTwirl * 0.01745329983532428741455078125;
    float texTwirlCos = cos(texTwirlRad);
    float texTwirlSin = sin(texTwirlRad);
    float2x2 texTwirlRot = float2x2(float2(texTwirlCos, -texTwirlSin), float2(texTwirlSin, texTwirlCos));
    float2 texScaleVec = float2(1.0 / _301.texRepeatX, 1.0 / _301.texRepeatY);
    texCoord *= texRot;
    texCoord += (_301.texOffset / float2(1000.0));
    texCoord /= texScaleVec;
    if (_301.mirror != 0u)
    {
        texCoord = abs(mod(texCoord, float2(2.0)) - float2(1.0));
    }
    else
    {
        texCoord = mod(texCoord, float2(1.0));
    }
    texCoord -= float2(0.5);
    texCoord *= (float2(1.0) - (float2(5.0) / _301.refScreen.xy));
    texCoord *= _301.texCrop;
    texCoord *= texTwirlRot;
    texCoord += float2(0.5);
    return texCoord;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, float2(uv.x, 1.0 - uv.y));
}

static inline __attribute__((always_inline))
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformsede5369a89427& _301)
{
    float3 lightPos = float3(_301.lightDir.x / 2.0, (-_301.lightDir.y) / 2.0, (-_301.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformsede5369a89427& _301)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    if (_301.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_301.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _301);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _301.ambient) + (((tc * _301.lightColor.xyz) * l) * (1.0 - _301.ambient));
            surface *= _301.lightIntensity;
            float s = powr(l, _301.spec);
            surface = mix(surface * (1.0 - (_301.shine * 0.100000001490116119384765625)), float3(1.0), float3(_301.shine * s));
            result = float4(surface, texColor.w) * a;
        }
        else
        {
            if (_301.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _301);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _301.ambient) + (((tc_1 * _301.lightColor.xyz) * l_1) * (1.0 - _301.ambient));
                surface_1 *= _301.lightIntensity;
                float s_1 = powr(l_1, _301.spec);
                surface_1 = mix(surface_1 * (1.0 - (_301.shine * 0.100000001490116119384765625)), float3(1.0), float3(_301.shine * s_1));
                result = float4(surface_1, texColor.w) * a;
            }
            else
            {
                if (_301.shadingType == 3)
                {
                    float ds = _301.size * 2.5;
                    float dd = 1.0 - (((d - ((_301.position + float3(0.0, -5.0, 0.0)) / float3(100.0)).z) + (ds / 2.0)) / ds);
                    result = float4(dd, dd, dd, 1.0) * a;
                }
                else
                {
                    if (_301.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_301.shadingType == 5)
                        {
                            float ds_1 = _301.size * 2.5;
                            float dd_1 = 1.0 - (((d - ((_301.position + float3(0.0, -5.0, 0.0)) / float3(100.0)).z) + (ds_1 / 2.0)) / ds_1);
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
void referenceMain(constant ReferenceUniformsede5369a89427& _301, thread float4x4& rotateAndOrient, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    referenceVertexInit(_301, rotateAndOrient);
    float2 st = float2((gl_FragCoord.x - _301.refLayer.x) / _301.refLayer.z, 1.0 - ((gl_FragCoord.y - _301.refLayer.y) / _301.refLayer.w));
    st -= float2(0.5);
    st.x *= (_301.refLayer.z / _301.refLayer.w);
    st /= float2(_301.scale);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float d = march(param, param_1, _301, rotateAndOrient);
    float3 p = ro + (rd * d);
    float3 param_2 = p;
    float3 n = calcNormal(param_2, _301, rotateAndOrient);
    float3 nn = n;
    float3 param_3 = p;
    float3 param_4 = n;
    float l = lighting(param_3, param_4, _301);
    float4 localCoord = float4(p - ((_301.position + float3(0.0, -5.0, 0.0)) / float3(100.0)), 1.0);
    localCoord *= rotateAndOrient;
    localCoord /= float4(_301.size);
    float2 texCoord = localCoord.xy / float2(2.0);
    texCoord.y /= (_301.refLayer.w / _301.refLayer.z);
    texCoord -= float2(0.5);
    float2 param_5 = texCoord;
    float2 _1160 = mapTexture(param_5, _301);
    texCoord = _1160;
    float2 param_6 = (float4(texCoord, 0.0, 1.0) * _301.refLayerToScreen).xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_6);
    float4 param_7 = texColor;
    float3 param_8 = p;
    float3 param_9 = nn;
    float param_10 = d;
    referenceColor = applyShading(param_7, param_8, param_9, param_10, _301);
}

fragment refAM35_ede5369a89427_out refAM35_ede5369a89427(constant ReferenceUniformsede5369a89427& _301 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ede5369a89427_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 rotateAndOrient;
    referenceMain(_301, rotateAndOrient, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1189 = any(isnan(referenceColor));
    bool _1196;
    if (!_1189)
    {
        _1196 = any(isinf(referenceColor));
    }
    else
    {
        _1196 = _1189;
    }
    if (_1196)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1209 = referenceColor;
    float3 _1215 = fast::clamp(_1209.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1215.x;
    referenceColor.y = _1215.y;
    referenceColor.z = _1215.z;
    out.finalColor = referenceColor;
    return out;
}

