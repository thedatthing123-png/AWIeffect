// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s3d-ring.xml
// Original source comments and attribution:
//#define MAX_ITER 35
// Flat
// Point Light
// Directonal Light
// Depth Map
//float dd = clamp(1.-d/10.,0.,1.)*2.;
// Normal Map
// Normal * Depth
//texCoordEnds.x = 1. - texCoordEnds.x;
//            texCoord = mod(texCoord*crop, 1.);
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

struct ReferenceUniformseb0eb768807ba
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 orient_euler;
    float3 rotate;
    float radius;
    char _m8_pad[12];
    float thickness;
    char _m9_pad[12];
    float height;
    char _m10_pad[12];
    float ref_smooth;
    float3 position;
    float scale;
    char _m13_pad[12];
    int shadingType;
    char _m14_pad[12];
    float lightIntensity;
    char _m15_pad[12];
    float shine;
    char _m16_pad[12];
    float spec;
    char _m17_pad[12];
    float ambient;
    float4 lightColor;
    float2 lightDir;
    char _m20_pad[8];
    float lightDepth;
    char _m21_pad[12];
    uint mirror;
    char _m22_pad[12];
    uint texStretch;
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

struct refAM35_eb0eb768807ba_out
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
    float4x4 _156;
    if (inverted)
    {
        _156 = transpose(m);
    }
    else
    {
        _156 = m;
    }
    return _156;
}

static inline __attribute__((always_inline))
void referenceVertexInit(constant ReferenceUniformseb0eb768807ba& _285, thread float4x4& orientAndRotate)
{
    float3 r = _285.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = referenceVertex_rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = referenceVertex_rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = referenceVertex_rotationAxisAngle(param_4, param_5);
    float3 param_6 = _285.orient_euler;
    bool param_7 = true;
    orientAndRotate = ((referenceEuler(param_6, param_7) * rz) * rx) * ry;
}

static inline __attribute__((always_inline))
float sdCappedCylinder(thread const float3& p, thread const float& h, thread const float& r)
{
    float2 d = abs(float2(length(p.xz), p.y)) - float2(h, r);
    return fast::min(fast::max(d.x, d.y), 0.0) + length(fast::max(d, float2(0.0)));
}

static inline __attribute__((always_inline))
float opSmoothSubtraction(thread const float& d1, thread const float& d2, thread const float& k)
{
    float h = fast::clamp(0.5 - ((0.5 * (d2 + d1)) / k), 0.0, 1.0);
    return mix(d2, -d1, h) + ((k * h) * (1.0 - h));
}

static inline __attribute__((always_inline))
float dist(thread float3& p, constant ReferenceUniformseb0eb768807ba& _285, thread float4x4& orientAndRotate)
{
    float d = 100000000.0;
    p -= (_285.position / float3(100.0));
    p = (float4(p, 1.0) * orientAndRotate).xyz;
    float3 param = p;
    float param_1 = _285.radius - _285.ref_smooth;
    float param_2 = _285.height - _285.ref_smooth;
    float outer = sdCappedCylinder(param, param_1, param_2) - _285.ref_smooth;
    float3 param_3 = p;
    float param_4 = _285.radius - _285.thickness;
    float param_5 = _285.height + 0.100000001490116119384765625;
    float inner = sdCappedCylinder(param_3, param_4, param_5);
    float param_6 = inner;
    float param_7 = outer;
    float param_8 = _285.ref_smooth;
    return opSmoothSubtraction(param_6, param_7, param_8);
}

static inline __attribute__((always_inline))
float march(thread const float3& ro, thread const float3& rd, constant ReferenceUniformseb0eb768807ba& _285, thread float4x4& orientAndRotate)
{
    float d = 0.0;
    for (int i = 0; i < int(_285.MAX_ITER); i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float _468 = dist(param, _285, orientAndRotate);
        float dd = _468;
        d += dd;
        if ((dd < 9.9999997473787516355514526367188e-06) || (d > 1000.0))
        {
            break;
        }
    }
    return d;
}

static inline __attribute__((always_inline))
float3 calcNormal(thread const float3& p, constant ReferenceUniformseb0eb768807ba& _285, thread float4x4& orientAndRotate)
{
    float3 param = p;
    float _491 = dist(param, _285, orientAndRotate);
    float d = _491;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_1 = p - e.xyy;
    float _501 = dist(param_1, _285, orientAndRotate);
    float3 param_2 = p - e.yxy;
    float _507 = dist(param_2, _285, orientAndRotate);
    float3 param_3 = p - e.yyx;
    float _513 = dist(param_3, _285, orientAndRotate);
    return fast::normalize(float3(d) - float3(_501, _507, _513));
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformseb0eb768807ba& _285)
{
    float3 lightPos = float3(_285.lightDir.x / 2.0, (-_285.lightDir.y) / 2.0, (-_285.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos - p);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float2 mapTexture(thread float2& texCoord, constant ReferenceUniformseb0eb768807ba& _285)
{
    float texRad = _285.texAngle * 0.01745329983532428741455078125;
    float texCos = cos(texRad);
    float texSin = sin(texRad);
    float2x2 texRot = float2x2(float2(texCos, -texSin), float2(texSin, texCos));
    float texTwirlRad = _285.texTwirl * 0.01745329983532428741455078125;
    float texTwirlCos = cos(texTwirlRad);
    float texTwirlSin = sin(texTwirlRad);
    float2x2 texTwirlRot = float2x2(float2(texTwirlCos, -texTwirlSin), float2(texTwirlSin, texTwirlCos));
    float2 texScaleVec = float2(1.0 / _285.texRepeatX, 1.0 / _285.texRepeatY);
    texCoord *= texRot;
    texCoord += (_285.texOffset / float2(1000.0));
    texCoord /= texScaleVec;
    if (_285.mirror != 0u)
    {
        texCoord = abs(mod(texCoord - float2(1.0), float2(2.0)) - float2(1.0));
    }
    else
    {
        texCoord = mod(texCoord, float2(1.0));
    }
    texCoord -= float2(0.5);
    texCoord *= (float2(1.0) - (float2(5.0) / _285.refScreen.xy));
    texCoord *= _285.texCrop;
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
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformseb0eb768807ba& _285)
{
    float3 lightPos = float3(_285.lightDir.x / 2.0, (-_285.lightDir.y) / 2.0, (-_285.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformseb0eb768807ba& _285)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    if (_285.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_285.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _285);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _285.ambient) + (((tc * _285.lightColor.xyz) * l) * (1.0 - _285.ambient));
            surface *= _285.lightIntensity;
            float s = powr(l, _285.spec);
            surface = mix(surface * (1.0 - (_285.shine * 0.100000001490116119384765625)), float3(1.0), float3(_285.shine * s));
            result = float4(surface, texColor.w) * a;
        }
        else
        {
            if (_285.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _285);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _285.ambient) + (((tc_1 * _285.lightColor.xyz) * l_1) * (1.0 - _285.ambient));
                surface_1 *= _285.lightIntensity;
                float s_1 = powr(l_1, _285.spec);
                surface_1 = mix(surface_1 * (1.0 - (_285.shine * 0.100000001490116119384765625)), float3(1.0), float3(_285.shine * s_1));
                result = float4(surface_1, texColor.w) * a;
            }
            else
            {
                if (_285.shadingType == 3)
                {
                    float ds = fast::max(_285.radius, _285.height) * 2.5;
                    float dd = 1.0 - (((d - (_285.position / float3(100.0)).z) + (ds / 2.0)) / ds);
                    result = float4(dd, dd, dd, 1.0) * a;
                }
                else
                {
                    if (_285.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_285.shadingType == 5)
                        {
                            float ds_1 = fast::max(_285.radius, _285.height) * 2.5;
                            float dd_1 = 1.0 - (((d - (_285.position / float3(100.0)).z) + (ds_1 / 2.0)) / ds_1);
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
void referenceMain(constant ReferenceUniformseb0eb768807ba& _285, thread float4x4& orientAndRotate, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    referenceVertexInit(_285, orientAndRotate);
    float2 st = (gl_FragCoord.xy - _285.refLayer.xy) / _285.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_285.refLayer.z / _285.refLayer.w);
    st /= float2(_285.scale);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float d = march(param, param_1, _285, orientAndRotate);
    float3 p = ro + (rd * d);
    float3 param_2 = p;
    float3 n = calcNormal(param_2, _285, orientAndRotate);
    float3 nn = n;
    float3 param_3 = p;
    float3 param_4 = n;
    float l = lighting(param_3, param_4, _285);
    float4 localCoord = float4(p - (_285.position / float3(100.0)), 1.0);
    n = (float4(n, 1.0) * orientAndRotate).xyz;
    localCoord *= orientAndRotate;
    float4 pp = localCoord;
    if (_285.texStretch != 0u)
    {
        pp.y /= _285.height;
    }
    float aa = (precise::atan2(pp.x, pp.z) / 6.283100128173828125) + 0.5;
    if (!(_285.texStretch != 0u))
    {
        aa *= (_285.radius * 3.141590118408203125);
    }
    float2 texCoordOutside = float2(aa, (pp.y / 2.0) + 0.5);
    texCoordOutside.x = 1.0 - mod(texCoordOutside.x + 0.5, 1.0);
    float2 texCoordEnds = localCoord.xz / float2(_285.radius / 1.5);
    texCoordEnds = (texCoordEnds + float2(1.0)) / float2(2.0);
    float _1080;
    if (n.y < 0.0)
    {
        _1080 = 1.0 - texCoordEnds.y;
    }
    else
    {
        _1080 = texCoordEnds.y;
    }
    texCoordEnds.y = _1080;
    float2 texCoord = mix(texCoordOutside, texCoordEnds, float2(abs(n.y)));
    float2 param_5 = texCoord;
    float2 _1101 = mapTexture(param_5, _285);
    texCoord = _1101;
    float2 param_6 = (float4(texCoord, 0.0, 1.0) * _285.refLayerToScreen).xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_6);
    float4 param_7 = texColor;
    float3 param_8 = p;
    float3 param_9 = nn;
    float param_10 = d;
    referenceColor = applyShading(param_7, param_8, param_9, param_10, _285);
}

fragment refAM35_eb0eb768807ba_out refAM35_eb0eb768807ba(constant ReferenceUniformseb0eb768807ba& _285 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb0eb768807ba_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 orientAndRotate;
    referenceMain(_285, orientAndRotate, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1130 = any(isnan(referenceColor));
    bool _1137;
    if (!_1130)
    {
        _1137 = any(isinf(referenceColor));
    }
    else
    {
        _1137 = _1130;
    }
    if (_1137)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1150 = referenceColor;
    float3 _1156 = fast::clamp(_1150.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1156.x;
    referenceColor.y = _1156.y;
    referenceColor.z = _1156.z;
    out.finalColor = referenceColor;
    return out;
}

