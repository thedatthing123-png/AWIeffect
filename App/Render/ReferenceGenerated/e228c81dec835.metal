// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s3d-cylinder.xml
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

struct ReferenceUniformse228c81dec835
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
    float texRepeatX;
    char _m22_pad[12];
    float texRepeatY;
    char _m23_pad[12];
    float texAngle;
    char _m24_pad[12];
    float texCrop;
    char _m25_pad[12];
    float texTwirl;
    char _m26_pad[8];
    float2 texOffset;
    char _m27_pad[8];
    float MAX_ITER;
};

struct refAM35_e228c81dec835_out
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
    float4x4 _151;
    if (inverted)
    {
        _151 = transpose(m);
    }
    else
    {
        _151 = m;
    }
    return _151;
}

static inline __attribute__((always_inline))
void referenceVertexInit(constant ReferenceUniformse228c81dec835& _280, thread float4x4& invOrient)
{
    float3 r = _280.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = referenceVertex_rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = referenceVertex_rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = referenceVertex_rotationAxisAngle(param_4, param_5);
    float3 param_6 = _280.orient_euler;
    bool param_7 = true;
    invOrient = ((referenceEuler(param_6, param_7) * rz) * rx) * ry;
}

static inline __attribute__((always_inline))
float sdRoundedCylinder(thread const float3& p, thread const float& ra, thread const float& rb, thread const float& h)
{
    float2 d = float2((length(p.xz) - (2.0 * ra)) + rb, abs(p.y) - h);
    return (fast::min(fast::max(d.x, d.y), 0.0) + length(fast::max(d, float2(0.0)))) - rb;
}

static inline __attribute__((always_inline))
float dist(thread float3& p, constant ReferenceUniformse228c81dec835& _280, thread float4x4& invOrient)
{
    float d = 100000000.0;
    p -= (_280.position / float3(100.0));
    p = (float4(p, 1.0) * invOrient).xyz;
    float3 param = p;
    float param_1 = _280.radius;
    float param_2 = _280.ref_smooth;
    float param_3 = _280.height;
    d = fast::min(d, sdRoundedCylinder(param, param_1, param_2, param_3));
    return d;
}

static inline __attribute__((always_inline))
float march(thread const float3& ro, thread const float3& rd, constant ReferenceUniformse228c81dec835& _280, thread float4x4& invOrient)
{
    float d = 0.0;
    for (int i = 0; i < int(_280.MAX_ITER); i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float _417 = dist(param, _280, invOrient);
        float dd = _417;
        d += dd;
        if ((dd < 9.9999997473787516355514526367188e-06) || (d > 1000.0))
        {
            break;
        }
    }
    return d;
}

static inline __attribute__((always_inline))
float3 calcNormal(thread const float3& p, constant ReferenceUniformse228c81dec835& _280, thread float4x4& invOrient)
{
    float3 param = p;
    float _440 = dist(param, _280, invOrient);
    float d = _440;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_1 = p - e.xyy;
    float _450 = dist(param_1, _280, invOrient);
    float3 param_2 = p - e.yxy;
    float _456 = dist(param_2, _280, invOrient);
    float3 param_3 = p - e.yyx;
    float _462 = dist(param_3, _280, invOrient);
    return fast::normalize(float3(d) - float3(_450, _456, _462));
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse228c81dec835& _280)
{
    float3 lightPos = float3(_280.lightDir.x / 2.0, (-_280.lightDir.y) / 2.0, (-_280.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos - p);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float2 mapTexture(thread float2& texCoord, constant ReferenceUniformse228c81dec835& _280)
{
    float texRad = _280.texAngle * 0.01745329983532428741455078125;
    float texCos = cos(texRad);
    float texSin = sin(texRad);
    float2x2 texRot = float2x2(float2(texCos, -texSin), float2(texSin, texCos));
    float texTwirlRad = _280.texTwirl * 0.01745329983532428741455078125;
    float texTwirlCos = cos(texTwirlRad);
    float texTwirlSin = sin(texTwirlRad);
    float2x2 texTwirlRot = float2x2(float2(texTwirlCos, -texTwirlSin), float2(texTwirlSin, texTwirlCos));
    float2 texScaleVec = float2(1.0 / _280.texRepeatX, 1.0 / _280.texRepeatY);
    texCoord *= texRot;
    texCoord += (_280.texOffset / float2(1000.0));
    texCoord /= texScaleVec;
    if (_280.mirror != 0u)
    {
        texCoord = abs(mod(texCoord, float2(2.0)) - float2(1.0));
    }
    else
    {
        texCoord = mod(texCoord, float2(1.0));
    }
    texCoord -= float2(0.5);
    texCoord *= (float2(1.0) - (float2(5.0) / _280.refScreen.xy));
    texCoord *= _280.texCrop;
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
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse228c81dec835& _280)
{
    float3 lightPos = float3(_280.lightDir.x / 2.0, (-_280.lightDir.y) / 2.0, (-_280.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformse228c81dec835& _280)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    if (_280.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_280.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _280);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _280.ambient) + (((tc * _280.lightColor.xyz) * l) * (1.0 - _280.ambient));
            surface *= _280.lightIntensity;
            float s = powr(l, _280.spec);
            surface = mix(surface * (1.0 - (_280.shine * 0.100000001490116119384765625)), float3(1.0), float3(_280.shine * s));
            result = float4(surface, texColor.w) * a;
        }
        else
        {
            if (_280.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _280);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _280.ambient) + (((tc_1 * _280.lightColor.xyz) * l_1) * (1.0 - _280.ambient));
                surface_1 *= _280.lightIntensity;
                float s_1 = powr(l_1, _280.spec);
                surface_1 = mix(surface_1 * (1.0 - (_280.shine * 0.100000001490116119384765625)), float3(1.0), float3(_280.shine * s_1));
                result = float4(surface_1, texColor.w) * a;
            }
            else
            {
                if (_280.shadingType == 3)
                {
                    float ds = fast::max(_280.radius, _280.height) * 2.5;
                    float dd = 1.0 - (((d - (_280.position / float3(100.0)).z) + (ds / 2.0)) / ds);
                    result = float4(dd, dd, dd, 1.0) * a;
                }
                else
                {
                    if (_280.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_280.shadingType == 5)
                        {
                            float ds_1 = fast::max(_280.radius, _280.height) * 2.5;
                            float dd_1 = 1.0 - (((d - (_280.position / float3(100.0)).z) + (ds_1 / 2.0)) / ds_1);
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
void referenceMain(constant ReferenceUniformse228c81dec835& _280, thread float4x4& invOrient, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    referenceVertexInit(_280, invOrient);
    float2 st = (gl_FragCoord.xy - _280.refLayer.xy) / _280.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_280.refLayer.z / _280.refLayer.w);
    st /= float2(_280.scale);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float d = march(param, param_1, _280, invOrient);
    float3 p = ro + (rd * d);
    float3 param_2 = p;
    float3 n = calcNormal(param_2, _280, invOrient);
    float3 nn = n;
    float3 param_3 = p;
    float3 param_4 = n;
    float l = lighting(param_3, param_4, _280);
    float4 localCoord = float4(p - (_280.position / float3(100.0)), 1.0);
    n = (float4(n, 1.0) * invOrient).xyz;
    localCoord *= invOrient;
    float4 pp = localCoord;
    float2 texCoordOutside = float2((precise::atan2(pp.x, pp.z) / 6.283100128173828125) + 0.5, ((pp.y / _280.height) / 2.0) + 0.5);
    texCoordOutside.x = 1.0 - mod(texCoordOutside.x + 0.5, 1.0);
    float2 texCoordEnds = pp.xz / float2(_280.radius * 2.0);
    texCoordEnds = (texCoordEnds + float2(1.0)) / float2(2.0);
    float _1006;
    if (n.y < 0.0)
    {
        _1006 = 1.0 - texCoordEnds.y;
    }
    else
    {
        _1006 = texCoordEnds.y;
    }
    texCoordEnds.y = _1006;
    float2 texCoord = mix(texCoordOutside, texCoordEnds, float2(abs(n.y)));
    float2 param_5 = texCoord;
    float2 _1027 = mapTexture(param_5, _280);
    texCoord = _1027;
    float2 param_6 = (float4(texCoord, 0.0, 1.0) * _280.refLayerToScreen).xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_6);
    float4 param_7 = texColor;
    float3 param_8 = p;
    float3 param_9 = nn;
    float param_10 = d;
    referenceColor = applyShading(param_7, param_8, param_9, param_10, _280);
}

fragment refAM35_e228c81dec835_out refAM35_e228c81dec835(constant ReferenceUniformse228c81dec835& _280 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e228c81dec835_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 invOrient;
    referenceMain(_280, invOrient, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1056 = any(isnan(referenceColor));
    bool _1063;
    if (!_1056)
    {
        _1063 = any(isinf(referenceColor));
    }
    else
    {
        _1063 = _1056;
    }
    if (_1063)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1076 = referenceColor;
    float3 _1082 = fast::clamp(_1076.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1082.x;
    referenceColor.y = _1082.y;
    referenceColor.z = _1082.z;
    out.finalColor = referenceColor;
    return out;
}

