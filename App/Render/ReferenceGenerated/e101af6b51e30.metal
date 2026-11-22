// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s3d-box.xml
// Original source comments and attribution:
//#define MAX_ITER 35
// remove this line for an only partially signed sdf
//p.yz *= rot(3.14159/2.0);
// Flat
// Point Light
// Directonal Light
// Depth Map
//float dd = clamp(1.-d/10.,0.,1.)*2.;
// Normal Map
// Normal * Depth
//vec2 texCoord = pp.xy;
//vec2 texCoordOutside = qq.zx;
//vec2 texCoordEnds = pp.xy;
//vec2 texCoord = mix(texCoordOutside,texCoordEnds,abs(n.z));
//vec2 texCoord = (qq.xz+1.)/2.;
//texCoord = mod(texCoord*crop, 1.);
//gl_FragColor = vec4(n.xyz,applyShading(texColor, p, nn, d).a);
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

struct ReferenceUniformse101af6b51e30
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float3 orient_euler;
    float3 rotate;
    float width;
    char _m8_pad[12];
    float height;
    char _m9_pad[12];
    float depth;
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

struct refAM35_e101af6b51e30_out
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
    float4x4 _157;
    if (inverted)
    {
        _157 = transpose(m);
    }
    else
    {
        _157 = m;
    }
    return _157;
}

static inline __attribute__((always_inline))
void referenceVertexInit(constant ReferenceUniformse101af6b51e30& _286, thread float4x4& invOrient)
{
    float3 r = _286.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = referenceVertex_rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = referenceVertex_rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = referenceVertex_rotationAxisAngle(param_4, param_5);
    float3 param_6 = _286.orient_euler;
    bool param_7 = true;
    invOrient = ((referenceEuler(param_6, param_7) * rz) * rx) * ry;
}

static inline __attribute__((always_inline))
float sdBox(thread const float3& p, thread const float3& b)
{
    float3 d = abs(p) - b;
    return length(fast::max(d, float3(0.0))) + fast::min(fast::max(d.x, fast::max(d.y, d.z)), 0.0);
}

static inline __attribute__((always_inline))
float dist(thread float3& p, constant ReferenceUniformse101af6b51e30& _286, thread float4x4& invOrient)
{
    float d = 100000000.0;
    p -= (_286.position / float3(100.0));
    p = (float4(p, 1.0) * invOrient).xyz;
    float3 param = p;
    float3 param_1 = float3(_286.width - _286.ref_smooth, _286.height - _286.ref_smooth, _286.depth - _286.ref_smooth);
    d = fast::min(d, sdBox(param, param_1) - _286.ref_smooth);
    return d;
}

static inline __attribute__((always_inline))
float march(thread const float3& ro, thread const float3& rd, constant ReferenceUniformse101af6b51e30& _286, thread float4x4& invOrient)
{
    float d = 0.0;
    for (int i = 0; i < int(_286.MAX_ITER); i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float _425 = dist(param, _286, invOrient);
        float dd = _425;
        d += dd;
        if ((dd < 9.9999997473787516355514526367188e-06) || (d > 1000.0))
        {
            break;
        }
    }
    return d;
}

static inline __attribute__((always_inline))
float3 calcNormal(thread const float3& p, constant ReferenceUniformse101af6b51e30& _286, thread float4x4& invOrient)
{
    float3 param = p;
    float _583 = dist(param, _286, invOrient);
    float d = _583;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_1 = p - e.xyy;
    float _593 = dist(param_1, _286, invOrient);
    float3 param_2 = p - e.yxy;
    float _599 = dist(param_2, _286, invOrient);
    float3 param_3 = p - e.yyx;
    float _605 = dist(param_3, _286, invOrient);
    return fast::normalize(float3(d) - float3(_593, _599, _605));
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse101af6b51e30& _286)
{
    float3 lightPos = float3(_286.lightDir.x / 2.0, (-_286.lightDir.y) / 2.0, (-_286.lightDepth) * 2.0);
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
float2 mapTexture(thread float2& texCoord, constant ReferenceUniformse101af6b51e30& _286)
{
    float texRad = _286.texAngle * 0.01745329983532428741455078125;
    float texCos = cos(texRad);
    float texSin = sin(texRad);
    float2x2 texRot = float2x2(float2(texCos, -texSin), float2(texSin, texCos));
    float texTwirlRad = _286.texTwirl * 0.01745329983532428741455078125;
    float texTwirlCos = cos(texTwirlRad);
    float texTwirlSin = sin(texTwirlRad);
    float2x2 texTwirlRot = float2x2(float2(texTwirlCos, -texTwirlSin), float2(texTwirlSin, texTwirlCos));
    float2 texScaleVec = float2(1.0 / _286.texRepeatX, 1.0 / _286.texRepeatY);
    texCoord *= texRot;
    texCoord += (_286.texOffset / float2(1000.0));
    texCoord /= texScaleVec;
    if (_286.mirror != 0u)
    {
        texCoord = abs(mod(texCoord, float2(2.0)) - float2(1.0));
    }
    else
    {
        texCoord = mod(texCoord, float2(1.0));
    }
    texCoord -= float2(0.5);
    texCoord *= (float2(1.0) - (float2(5.0) / _286.refScreen.xy));
    texCoord *= _286.texCrop;
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
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse101af6b51e30& _286)
{
    float3 lightPos = float3(_286.lightDir.x / 2.0, (-_286.lightDir.y) / 2.0, (-_286.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformse101af6b51e30& _286)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    if (_286.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_286.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _286);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _286.ambient) + (((tc * _286.lightColor.xyz) * l) * (1.0 - _286.ambient));
            surface *= _286.lightIntensity;
            float s = powr(l, _286.spec);
            surface = mix(surface * (1.0 - (_286.shine * 0.100000001490116119384765625)), float3(1.0), float3(_286.shine * s));
            result = float4(surface, texColor.w) * a;
        }
        else
        {
            if (_286.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _286);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _286.ambient) + (((tc_1 * _286.lightColor.xyz) * l_1) * (1.0 - _286.ambient));
                surface_1 *= _286.lightIntensity;
                float s_1 = powr(l_1, _286.spec);
                surface_1 = mix(surface_1 * (1.0 - (_286.shine * 0.100000001490116119384765625)), float3(1.0), float3(_286.shine * s_1));
                result = float4(surface_1, texColor.w) * a;
            }
            else
            {
                if (_286.shadingType == 3)
                {
                    float ds = fast::max(fast::max(_286.width, _286.height), _286.depth) * 2.5;
                    float dd = 1.0 - (((d - (_286.position / float3(100.0)).z) + (ds / 2.0)) / ds);
                    result = float4(dd, dd, dd, 1.0) * a;
                }
                else
                {
                    if (_286.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_286.shadingType == 5)
                        {
                            float ds_1 = fast::max(fast::max(_286.width, _286.height), _286.depth) * 2.5;
                            float dd_1 = 1.0 - (((d - (_286.position / float3(100.0)).z) + (ds_1 / 2.0)) / ds_1);
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
void referenceMain(constant ReferenceUniformse101af6b51e30& _286, thread float4x4& invOrient, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    referenceVertexInit(_286, invOrient);
    float2 st = (gl_FragCoord.xy - _286.refLayer.xy) / _286.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_286.refLayer.z / _286.refLayer.w);
    st /= float2(_286.scale);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float d = march(param, param_1, _286, invOrient);
    float3 p = ro + (rd * d);
    float3 param_2 = p;
    float3 n = calcNormal(param_2, _286, invOrient);
    float3 nn = n;
    float3 param_3 = p;
    float3 param_4 = n;
    float l = lighting(param_3, param_4, _286);
    float4 localCoord = float4(p - (_286.position / float3(100.0)), 1.0);
    n = (float4(n, 0.0) * invOrient).xyz;
    localCoord *= invOrient;
    float4 pp = localCoord;
    float3 param_5 = n;
    float3 param_6 = pp.xyz * float3(0.0, 1.0, 0.0);
    float4 qq = pp * vecToVec(param_5, param_6);
    if (_286.texStretch != 0u)
    {
        pp /= float4(_286.width, _286.height, _286.depth, 1.0);
    }
    float2 texCoord;
    float a;
    if (n.x > 0.5)
    {
        texCoord = (pp.zy + float2(1.0)) / float2(2.0);
        bool _1158 = _286.height < 0.010499999858438968658447265625;
        bool _1165;
        if (!_1158)
        {
            _1165 = _286.depth < 0.010499999858438968658447265625;
        }
        else
        {
            _1165 = _1158;
        }
        a = _1165 ? 0.0 : 1.0;
    }
    else
    {
        if (n.x < (-0.5))
        {
            texCoord = (pp.zy + float2(1.0)) / float2(2.0);
            texCoord.x = 1.0 - texCoord.x;
            bool _1186 = _286.height < 0.010499999858438968658447265625;
            bool _1193;
            if (!_1186)
            {
                _1193 = _286.depth < 0.010499999858438968658447265625;
            }
            else
            {
                _1193 = _1186;
            }
            a = _1193 ? 0.0 : 1.0;
        }
        else
        {
            if (n.y > 0.5)
            {
                texCoord = (pp.xz + float2(1.0)) / float2(2.0);
                bool _1209 = _286.width < 0.010499999858438968658447265625;
                bool _1216;
                if (!_1209)
                {
                    _1216 = _286.depth < 0.010499999858438968658447265625;
                }
                else
                {
                    _1216 = _1209;
                }
                a = _1216 ? 0.0 : 1.0;
            }
            else
            {
                if (n.y < (-0.5))
                {
                    texCoord = float2(1.0) - ((pp.xz + float2(1.0)) / float2(2.0));
                    texCoord.x = 1.0 - texCoord.x;
                    bool _1238 = _286.width < 0.010499999858438968658447265625;
                    bool _1245;
                    if (!_1238)
                    {
                        _1245 = _286.depth < 0.010499999858438968658447265625;
                    }
                    else
                    {
                        _1245 = _1238;
                    }
                    a = _1245 ? 0.0 : 1.0;
                }
                else
                {
                    if (n.z > 0.5)
                    {
                        texCoord = (pp.xy + float2(1.0)) / float2(2.0);
                        texCoord.x = 1.0 - texCoord.x;
                        bool _1265 = _286.width < 0.010499999858438968658447265625;
                        bool _1272;
                        if (!_1265)
                        {
                            _1272 = _286.height < 0.010499999858438968658447265625;
                        }
                        else
                        {
                            _1272 = _1265;
                        }
                        a = _1272 ? 0.0 : 1.0;
                    }
                    else
                    {
                        if (n.z < (-0.5))
                        {
                            texCoord = (pp.xy + float2(1.0)) / float2(2.0);
                            bool _1288 = _286.width < 0.010499999858438968658447265625;
                            bool _1295;
                            if (!_1288)
                            {
                                _1295 = _286.height < 0.010499999858438968658447265625;
                            }
                            else
                            {
                                _1295 = _1288;
                            }
                            a = _1295 ? 0.0 : 1.0;
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
    float2 _1301 = mapTexture(param_7, _286);
    texCoord = _1301;
    float2 param_8 = (float4(texCoord, 0.0, 1.0) * _286.refLayerToScreen).xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_8);
    float4 param_9 = texColor;
    float3 param_10 = p;
    float3 param_11 = nn;
    float param_12 = d;
    referenceColor = applyShading(param_9, param_10, param_11, param_12, _286) * a;
}

fragment refAM35_e101af6b51e30_out refAM35_e101af6b51e30(constant ReferenceUniformse101af6b51e30& _286 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e101af6b51e30_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 invOrient;
    referenceMain(_286, invOrient, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1332 = any(isnan(referenceColor));
    bool _1339;
    if (!_1332)
    {
        _1339 = any(isinf(referenceColor));
    }
    else
    {
        _1339 = _1332;
    }
    if (_1339)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1352 = referenceColor;
    float3 _1358 = fast::clamp(_1352.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1358.x;
    referenceColor.y = _1358.y;
    referenceColor.z = _1358.z;
    out.finalColor = referenceColor;
    return out;
}

