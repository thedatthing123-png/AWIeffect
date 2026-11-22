// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/3dcubeskybox.xml
// Original source comments and attribution:

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

struct ReferenceUniformse039f5ed2414d
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 orient_euler;
    float3 rotate;
    float3 skyRotate;
    float width;
    char _m9_pad[12];
    float height;
    char _m10_pad[12];
    float depth;
    char _m11_pad[12];
    float texCrop;
    float3 position;
    float scale;
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
};

struct refAM35_e039f5ed2414d_out
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
    float4x4 _161;
    if (inverted)
    {
        _161 = transpose(m);
    }
    else
    {
        _161 = m;
    }
    return _161;
}

static inline __attribute__((always_inline))
void referenceVertexInit(constant ReferenceUniformse039f5ed2414d& _290, thread float4x4& invOrient, thread float4x4& skyRotM)
{
    float3 r = _290.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = referenceVertex_rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = referenceVertex_rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = referenceVertex_rotationAxisAngle(param_4, param_5);
    float3 param_6 = _290.orient_euler;
    bool param_7 = true;
    invOrient = ((referenceEuler(param_6, param_7) * rz) * rx) * ry;
    float3 sr = _290.skyRotate * 0.01745329983532428741455078125;
    float3 param_8 = float3(1.0, 0.0, 0.0);
    float param_9 = sr.x;
    float4x4 srx = referenceVertex_rotationAxisAngle(param_8, param_9);
    float3 param_10 = float3(0.0, 1.0, 0.0);
    float param_11 = sr.y;
    float4x4 sry = referenceVertex_rotationAxisAngle(param_10, param_11);
    float3 param_12 = float3(0.0, 0.0, 1.0);
    float param_13 = sr.z;
    float4x4 srz = referenceVertex_rotationAxisAngle(param_12, param_13);
    skyRotM = (srz * srx) * sry;
}

static inline __attribute__((always_inline))
float sdBox(thread const float3& p, thread const float3& b)
{
    float3 d = abs(p) - b;
    return length(fast::max(d, float3(0.0))) + fast::min(fast::max(d.x, fast::max(d.y, d.z)), 0.0);
}

static inline __attribute__((always_inline))
float dist(thread float3& p, constant ReferenceUniformse039f5ed2414d& _290, thread float4x4& invOrient)
{
    float d = 100000000.0;
    p -= (_290.position / float3(100.0));
    p = (float4(p, 1.0) * invOrient).xyz;
    float3 param = p;
    float3 param_1 = float3(_290.width, _290.height, _290.depth);
    d = fast::min(d, sdBox(param, param_1));
    return d;
}

static inline __attribute__((always_inline))
float march(thread const float3& ro, thread const float3& rd, constant ReferenceUniformse039f5ed2414d& _290, thread float4x4& invOrient)
{
    float d = 0.0;
    for (int i = 0; i < 35; i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float _442 = dist(param, _290, invOrient);
        float dd = _442;
        d += dd;
        if ((dd < 9.9999997473787516355514526367188e-06) || (d > 1000.0))
        {
            break;
        }
    }
    return d;
}

static inline __attribute__((always_inline))
float2 dirToEquirectUV(thread float3& d)
{
    d = fast::normalize(d);
    float u = (precise::atan2(d.x, d.z) / 6.283185482025146484375) + 0.5;
    float v = (asin(fast::clamp(d.y, -1.0, 1.0)) / 3.1415927410125732421875) + 0.5;
    return float2(u, v);
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 calcNormal(thread const float3& p, constant ReferenceUniformse039f5ed2414d& _290, thread float4x4& invOrient)
{
    float3 param = p;
    float _600 = dist(param, _290, invOrient);
    float d = _600;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_1 = p - e.xyy;
    float _610 = dist(param_1, _290, invOrient);
    float3 param_2 = p - e.yxy;
    float _616 = dist(param_2, _290, invOrient);
    float3 param_3 = p - e.yyx;
    float _622 = dist(param_3, _290, invOrient);
    return fast::normalize(float3(d) - float3(_610, _616, _622));
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
float2 mapTexture(thread float2& texCoord, constant ReferenceUniformse039f5ed2414d& _290)
{
    texCoord = mod(texCoord, float2(1.0));
    texCoord -= float2(0.5);
    texCoord *= (float2(1.0) - (float2(5.0) / _290.refScreen.xy));
    texCoord *= _290.texCrop;
    texCoord += float2(0.5);
    texCoord = float2(mod(texCoord.x, 1.0), mod(texCoord.y, 1.0));
    return texCoord;
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse039f5ed2414d& _290)
{
    float3 lightPos = float3(_290.lightDir.x / 2.0, (-_290.lightDir.y) / 2.0, (-_290.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos - p);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse039f5ed2414d& _290)
{
    float3 lightPos = float3(_290.lightDir.x / 2.0, (-_290.lightDir.y) / 2.0, (-_290.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformse039f5ed2414d& _290)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    if (_290.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_290.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _290);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _290.ambient) + (((tc * _290.lightColor.xyz) * l) * (1.0 - _290.ambient));
            surface *= _290.lightIntensity;
            float s = powr(l, _290.spec);
            surface = mix(surface * (1.0 - (_290.shine * 0.100000001490116119384765625)), float3(1.0), float3(_290.shine * s));
            result = float4(surface, texColor.w) * a;
        }
        else
        {
            if (_290.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _290);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _290.ambient) + (((tc_1 * _290.lightColor.xyz) * l_1) * (1.0 - _290.ambient));
                surface_1 *= _290.lightIntensity;
                float s_1 = powr(l_1, _290.spec);
                surface_1 = mix(surface_1 * (1.0 - (_290.shine * 0.100000001490116119384765625)), float3(1.0), float3(_290.shine * s_1));
                result = float4(surface_1, texColor.w) * a;
            }
            else
            {
                if (_290.shadingType == 3)
                {
                    float ds = fast::max(fast::max(_290.width, _290.height), _290.depth) * 2.5;
                    float dd = 1.0 - (((d - (_290.position / float3(100.0)).z) + (ds / 2.0)) / ds);
                    result = float4(dd, dd, dd, 1.0) * a;
                }
                else
                {
                    if (_290.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_290.shadingType == 5)
                        {
                            float ds_1 = fast::max(fast::max(_290.width, _290.height), _290.depth) * 2.5;
                            float dd_1 = 1.0 - (((d - (_290.position / float3(100.0)).z) + (ds_1 / 2.0)) / ds_1);
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
void referenceMain(constant ReferenceUniformse039f5ed2414d& _290, thread float4x4& invOrient, thread float4x4& skyRotM, thread float4& gl_FragCoord, texture2d<float> refReference, sampler refReferenceSmplr, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    referenceVertexInit(_290, invOrient, skyRotM);
    float2 st = (gl_FragCoord.xy - _290.refLayer.xy) / _290.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_290.refLayer.z / _290.refLayer.w);
    st /= float2(_290.scale);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float d = march(param, param_1, _290, invOrient);
    float3 p = ro + (rd * d);
    if (d > 999.9000244140625)
    {
        float3 skyDir = (float4(rd, 0.0) * skyRotM).xyz;
        float3 param_2 = skyDir;
        float2 _1063 = dirToEquirectUV(param_2);
        float2 suv = _1063;
        float2 param_3 = suv;
        float4 sky = texture2DCv(refReference, refReferenceSmplr, param_3);
        referenceColor = sky;
        return;
    }
    float3 param_4 = p;
    float3 n = calcNormal(param_4, _290, invOrient);
    float3 nn = n;
    float4 localCoord = float4(p - (_290.position / float3(100.0)), 1.0);
    n = (float4(n, 0.0) * invOrient).xyz;
    localCoord *= invOrient;
    float4 pp = localCoord;
    float3 param_5 = n;
    float3 param_6 = pp.xyz * float3(0.0, 1.0, 0.0);
    float4 qq = pp * vecToVec(param_5, param_6);
    pp /= float4(_290.width, _290.height, _290.depth, 1.0);
    float2 texCoord;
    float a;
    if (n.x > 0.5)
    {
        texCoord = (pp.zy + float2(1.0)) / float2(2.0);
        bool _1138 = _290.height < 0.010499999858438968658447265625;
        bool _1145;
        if (!_1138)
        {
            _1145 = _290.depth < 0.010499999858438968658447265625;
        }
        else
        {
            _1145 = _1138;
        }
        a = _1145 ? 0.0 : 1.0;
    }
    else
    {
        if (n.x < (-0.5))
        {
            texCoord = (pp.zy + float2(1.0)) / float2(2.0);
            texCoord.x = 1.0 - texCoord.x;
            bool _1166 = _290.height < 0.010499999858438968658447265625;
            bool _1173;
            if (!_1166)
            {
                _1173 = _290.depth < 0.010499999858438968658447265625;
            }
            else
            {
                _1173 = _1166;
            }
            a = _1173 ? 0.0 : 1.0;
        }
        else
        {
            if (n.y > 0.5)
            {
                texCoord = (pp.xz + float2(1.0)) / float2(2.0);
                bool _1189 = _290.width < 0.010499999858438968658447265625;
                bool _1196;
                if (!_1189)
                {
                    _1196 = _290.depth < 0.010499999858438968658447265625;
                }
                else
                {
                    _1196 = _1189;
                }
                a = _1196 ? 0.0 : 1.0;
            }
            else
            {
                if (n.y < (-0.5))
                {
                    texCoord = float2(1.0) - ((pp.xz + float2(1.0)) / float2(2.0));
                    texCoord.x = 1.0 - texCoord.x;
                    bool _1218 = _290.width < 0.010499999858438968658447265625;
                    bool _1225;
                    if (!_1218)
                    {
                        _1225 = _290.depth < 0.010499999858438968658447265625;
                    }
                    else
                    {
                        _1225 = _1218;
                    }
                    a = _1225 ? 0.0 : 1.0;
                }
                else
                {
                    if (n.z > 0.5)
                    {
                        texCoord = (pp.xy + float2(1.0)) / float2(2.0);
                        texCoord.x = 1.0 - texCoord.x;
                        bool _1245 = _290.width < 0.010499999858438968658447265625;
                        bool _1252;
                        if (!_1245)
                        {
                            _1252 = _290.height < 0.010499999858438968658447265625;
                        }
                        else
                        {
                            _1252 = _1245;
                        }
                        a = _1252 ? 0.0 : 1.0;
                    }
                    else
                    {
                        if (n.z < (-0.5))
                        {
                            texCoord = (pp.xy + float2(1.0)) / float2(2.0);
                            bool _1268 = _290.width < 0.010499999858438968658447265625;
                            bool _1275;
                            if (!_1268)
                            {
                                _1275 = _290.height < 0.010499999858438968658447265625;
                            }
                            else
                            {
                                _1275 = _1268;
                            }
                            a = _1275 ? 0.0 : 1.0;
                        }
                        else
                        {
                            texCoord = float2(0.0);
                            a = 1.0;
                        }
                    }
                }
            }
        }
    }
    float2 param_7 = texCoord;
    float2 _1281 = mapTexture(param_7, _290);
    texCoord = _1281;
    float2 param_8 = (float4(texCoord, 0.0, 1.0) * _290.refLayerToScreen).xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_8);
    float4 param_9 = texColor;
    float3 param_10 = p;
    float3 param_11 = nn;
    float param_12 = d;
    referenceColor = applyShading(param_9, param_10, param_11, param_12, _290) * a;
}

fragment refAM35_e039f5ed2414d_out refAM35_e039f5ed2414d(constant ReferenceUniformse039f5ed2414d& _290 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refReference [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refReferenceSmplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e039f5ed2414d_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 invOrient;
    float4x4 skyRotM;
    referenceMain(_290, invOrient, skyRotM, gl_FragCoord, refReference, refReferenceSmplr, referenceColor, refInput, refInputSmplr);
    bool _1310 = any(isnan(referenceColor));
    bool _1317;
    if (!_1310)
    {
        _1317 = any(isinf(referenceColor));
    }
    else
    {
        _1317 = _1310;
    }
    if (_1317)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1330 = referenceColor;
    float3 _1336 = fast::clamp(_1330.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1336.x;
    referenceColor.y = _1336.y;
    referenceColor.z = _1336.z;
    out.finalColor = referenceColor;
    return out;
}

