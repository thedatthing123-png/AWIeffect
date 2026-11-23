// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s3d-triprism2.xml
// Original source comments and attribution:
// Flat
// Point Light
// Directonal Light
// Depth Map
//float dd = clamp(1.-d/10.,0.,1.)*2.;
// Normal Map
// Normal * Depth
//vec2(atan(pp.x,pp.z),pp.y);
//texCoord = mod(texCoord*crop, 1.);
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

struct ReferenceUniformse22830a1895e5
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 orient_euler;
    float radius;
    char _m7_pad[12];
    float height;
    char _m8_pad[12];
    float zdist;
    char _m9_pad[12];
    float scale;
    char _m10_pad[12];
    int shadingType;
    char _m11_pad[12];
    float lightIntensity;
    char _m12_pad[12];
    float shine;
    char _m13_pad[12];
    float spec;
    char _m14_pad[12];
    float ambient;
    float4 lightColor;
    float2 lightDir;
    char _m17_pad[8];
    float lightDepth;
    char _m18_pad[12];
    uint mirror;
    char _m19_pad[12];
    float texCrop;
    char _m20_pad[12];
    float texScale;
    char _m21_pad[8];
    float2 texStretch;
    char _m22_pad[8];
    float texAngle;
    char _m23_pad[12];
    float texTwirl;
    char _m24_pad[8];
    float2 texOffset;
};

struct refAM35_e22830a1895e5_out
{
    float4 finalColor [[color(0)]];
};

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
void referenceVertexInit(thread float4x4& invOrient, constant ReferenceUniformse22830a1895e5& _179)
{
    float3 param = _179.orient_euler;
    bool param_1 = true;
    invOrient = referenceEuler(param, param_1);
}

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float sdTriPrism(thread const float3& p, thread const float2& h)
{
    float3 q = abs(p);
    return fast::max(q.z - h.y, fast::max((q.x * 0.86602497100830078125) + (p.y * 0.5), -p.y) - (h.x * 0.5));
}

static inline __attribute__((always_inline))
float dist(thread float3& p, thread float4x4& invOrient, constant ReferenceUniformse22830a1895e5& _179)
{
    float d = 100000000.0;
    p -= float3(0.0, 1.0, _179.zdist);
    p = (float4(p, 1.0) * invOrient).xyz;
    float param = 1.5707950592041015625;
    float3 _252 = p;
    float2 _254 = _252.yz * rot(param);
    p.y = _254.x;
    p.z = _254.y;
    float ref_smooth = 0.0;
    float3 param_1 = p;
    float2 param_2 = float2(_179.radius - ref_smooth, _179.height - (ref_smooth / 2.0));
    d = fast::min(d, sdTriPrism(param_1, param_2) - ref_smooth);
    return d;
}

static inline __attribute__((always_inline))
float march(thread const float3& ro, thread const float3& rd, thread float4x4& invOrient, constant ReferenceUniformse22830a1895e5& _179)
{
    float d = 0.0;
    for (int i = 0; i < 35; i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float _305 = dist(param, invOrient, _179);
        float dd = _305;
        d += dd;
        if ((dd < 9.9999997473787516355514526367188e-06) || (d > 1000.0))
        {
            break;
        }
    }
    return d;
}

static inline __attribute__((always_inline))
float3 calcNormal(thread const float3& p, thread float4x4& invOrient, constant ReferenceUniformse22830a1895e5& _179)
{
    float3 param = p;
    float _463 = dist(param, invOrient, _179);
    float d = _463;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_1 = p - e.xyy;
    float _473 = dist(param_1, invOrient, _179);
    float3 param_2 = p - e.yxy;
    float _479 = dist(param_2, invOrient, _179);
    float3 param_3 = p - e.yyx;
    float _485 = dist(param_3, invOrient, _179);
    return fast::normalize(float3(d) - float3(_473, _479, _485));
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse22830a1895e5& _179)
{
    float3 lightPos = float3(_179.lightDir.x / 2.0, (-_179.lightDir.y) / 2.0, (-_179.lightDepth) * 2.0);
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
float2 mapTexture(thread float2& texCoord, constant ReferenceUniformse22830a1895e5& _179)
{
    float texRad = _179.texAngle * 0.01745329983532428741455078125;
    float texCos = cos(texRad);
    float texSin = sin(texRad);
    float2x2 texRot = float2x2(float2(texCos, -texSin), float2(texSin, texCos));
    float texTwirlRad = _179.texTwirl * 0.01745329983532428741455078125;
    float texTwirlCos = cos(texTwirlRad);
    float texTwirlSin = sin(texTwirlRad);
    float2x2 texTwirlRot = float2x2(float2(texTwirlCos, -texTwirlSin), float2(texTwirlSin, texTwirlCos));
    float2 texScaleVec = float2(_179.texScale, _179.texScale);
    texScaleVec *= float2(_179.texStretch.x, _179.texStretch.y);
    texCoord *= texRot;
    texCoord += (_179.texOffset / float2(1000.0));
    texCoord /= texScaleVec;
    if (_179.mirror != 0u)
    {
        texCoord = abs(mod(texCoord, float2(2.0)) - float2(1.0));
    }
    else
    {
        texCoord = mod(texCoord, float2(1.0));
    }
    texCoord -= float2(0.5);
    texCoord *= (float2(1.0) - (float2(5.0) / _179.refScreen.xy));
    texCoord *= _179.texCrop;
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
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse22830a1895e5& _179)
{
    float3 lightPos = float3(_179.lightDir.x / 2.0, (-_179.lightDir.y) / 2.0, (-_179.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformse22830a1895e5& _179)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    if (_179.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_179.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _179);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _179.ambient) + (((tc * _179.lightColor.xyz) * l) * (1.0 - _179.ambient));
            surface *= _179.lightIntensity;
            float s = powr(l, _179.spec);
            surface = mix(surface * (1.0 - (_179.shine * 0.100000001490116119384765625)), float3(1.0), float3(_179.shine * s));
            result = float4(surface, texColor.w) * a;
        }
        else
        {
            if (_179.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _179);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _179.ambient) + (((tc_1 * _179.lightColor.xyz) * l_1) * (1.0 - _179.ambient));
                surface_1 *= _179.lightIntensity;
                float s_1 = powr(l_1, _179.spec);
                surface_1 = mix(surface_1 * (1.0 - (_179.shine * 0.100000001490116119384765625)), float3(1.0), float3(_179.shine * s_1));
                result = float4(surface_1, texColor.w) * a;
            }
            else
            {
                if (_179.shadingType == 3)
                {
                    float ds = fast::max(_179.radius, _179.height) * 2.5;
                    float dd = 1.0 - (((d - _179.zdist) + (ds / 2.0)) / ds);
                    result = float4(dd, dd, dd, 1.0) * a;
                }
                else
                {
                    if (_179.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_179.shadingType == 5)
                        {
                            float ds_1 = fast::max(_179.radius, _179.height) * 2.5;
                            float dd_1 = 1.0 - (((d - _179.zdist) + (ds_1 / 2.0)) / ds_1);
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
void referenceMain(thread float4x4& invOrient, constant ReferenceUniformse22830a1895e5& _179, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    referenceVertexInit(invOrient, _179);
    float2 st = float2((gl_FragCoord.x - _179.refLayer.x) / _179.refLayer.z, 1.0 - ((gl_FragCoord.y - _179.refLayer.y) / _179.refLayer.w));
    st -= float2(0.5);
    st.x *= (_179.refLayer.z / _179.refLayer.w);
    st /= float2(_179.scale);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float d = march(param, param_1, invOrient, _179);
    float3 p = ro + (rd * d);
    float3 param_2 = p;
    float3 n = calcNormal(param_2, invOrient, _179);
    float3 nn = n;
    float3 param_3 = p;
    float3 param_4 = n;
    float l = lighting(param_3, param_4, _179);
    float4 localCoord = float4(p - float3(0.0, 1.0, _179.zdist), 1.0);
    n = (float4(n, 1.0) * invOrient).xyz;
    localCoord *= invOrient;
    float4 pp = localCoord;
    float3 param_5 = n;
    float3 param_6 = pp.xyz * float3(0.0, 1.0, 0.0);
    float4 qq = pp * vecToVec(param_5, param_6);
    float2 texCoordOutside = qq.zx;
    float2 texCoordEnds = pp.xy;
    float2 texCoord = mix(texCoordOutside, texCoordEnds, float2(abs(n.z)));
    float2 param_7 = texCoord;
    float2 _1016 = mapTexture(param_7, _179);
    texCoord = _1016;
    float2 param_8 = (float4(texCoord, 0.0, 1.0) * _179.refLayerToScreen).xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_8);
    float4 param_9 = texColor;
    float3 param_10 = p;
    float3 param_11 = nn;
    float param_12 = d;
    referenceColor = applyShading(param_9, param_10, param_11, param_12, _179);
}

fragment refAM35_e22830a1895e5_out refAM35_e22830a1895e5(constant ReferenceUniformse22830a1895e5& _179 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e22830a1895e5_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 invOrient;
    referenceMain(invOrient, _179, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1045 = any(isnan(referenceColor));
    bool _1052;
    if (!_1045)
    {
        _1052 = any(isinf(referenceColor));
    }
    else
    {
        _1052 = _1045;
    }
    if (_1052)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1065 = referenceColor;
    float3 _1071 = fast::clamp(_1065.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1071.x;
    referenceColor.y = _1071.y;
    referenceColor.z = _1071.z;
    out.finalColor = referenceColor;
    return out;
}

