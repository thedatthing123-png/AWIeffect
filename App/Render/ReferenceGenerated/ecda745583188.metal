// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s3d-hexprism.xml
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
//vec4 qq = pp * (vecToVec(n,pp.xyz*vec3(0.,1.,0.)));
//
//vec2 texCoordOutside = qq.zx; //vec2(atan(pp.x,pp.z),pp.y);
//vec2 texCoordEnds = pp.xy;
//vec2 texCoord = mix(texCoordOutside,texCoordEnds,abs(n.z));
//vec2 texCoord;
//float a;
//if ( n.y > 0.5 ) {
//    texCoord = ((pp.xz+1.)/2.);
//    a = width<0.0105 || depth<0.0105 ? 0.0 : 1.0;
//} else if ( n.y < -0.5 ) {
//    texCoord = 1.-((pp.xz+1.)/2.);
//    texCoord.x = 1.-texCoord.x;
//    a = width<0.0105 || depth<0.0105 ? 0.0 : 1.0;
//} else if( n.x > 0.5 ) {
//    texCoord = ((pp.zy+1.)/2.);
//    a = height<0.0105 || depth<0.0105 ? 0.0 : 1.0;
//} else if ( n.x < -0.5 ) {
//    texCoord = ((pp.zy+1.)/2.);
//    texCoord.x = 1.-texCoord.x;
//    a = height<0.0105 || depth<0.0105 ? 0.0 : 1.0;
//} else if ( n.z > 0.5 ) {
//    texCoord = (pp.xy+1.)/2.;
//    texCoord.x = 1.-texCoord.x;
//    a = width<0.0105 || height<0.0105 ? 0.0 : 1.0;
//} else if ( n.z < -0.5 ) {
//    texCoord = (pp.xy+1.)/2.;
//    a = width<0.0105 || height<0.0105 ? 0.0 : 1.0;
//} else {
//    texCoord = vec2(0.,0.);
//    a = 1.0;
//}
//n = (vec4(n,1.) * invOrient).xyz;
//texCoordEnds.x = 1. - texCoordEnds.x;
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

struct ReferenceUniformsecda745583188
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

struct refAM35_ecda745583188_out
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
    float4x4 _154;
    if (inverted)
    {
        _154 = transpose(m);
    }
    else
    {
        _154 = m;
    }
    return _154;
}

static inline __attribute__((always_inline))
void referenceVertexInit(constant ReferenceUniformsecda745583188& _283, thread float4x4& invOrient)
{
    float3 r = _283.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = referenceVertex_rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = referenceVertex_rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = referenceVertex_rotationAxisAngle(param_4, param_5);
    float3 param_6 = _283.orient_euler;
    bool param_7 = true;
    invOrient = ((referenceEuler(param_6, param_7) * rz) * rx) * ry;
}

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float sdHexPrism(thread float3& p, thread const float2& h)
{
    p = abs(p);
    float3 _332 = p;
    float3 _338 = p;
    float2 _340 = _338.xy - (float2(-0.866025388240814208984375, 0.5) * (2.0 * fast::min(dot(float2(-0.866025388240814208984375, 0.5), _332.xy), 0.0)));
    p.x = _340.x;
    p.y = _340.y;
    float2 d = float2(length(p.xy - float2(fast::clamp(p.x, (-0.57735002040863037109375) * h.x, 0.57735002040863037109375 * h.x), h.x)) * sign(p.y - h.x), p.z - h.y);
    return fast::min(fast::max(d.x, d.y), 0.0) + length(fast::max(d, float2(0.0)));
}

static inline __attribute__((always_inline))
float dist(thread float3& p, constant ReferenceUniformsecda745583188& _283, thread float4x4& invOrient)
{
    float d = 100000000.0;
    p -= (_283.position / float3(100.0));
    p = (float4(p, 1.0) * invOrient).xyz;
    float param = 1.5707950592041015625;
    float3 _427 = p;
    float2 _429 = _427.yz * rot(param);
    p.y = _429.x;
    p.z = _429.y;
    float3 param_1 = p;
    float2 param_2 = float2(_283.radius - _283.ref_smooth, _283.height - (_283.ref_smooth / 2.0));
    float _454 = sdHexPrism(param_1, param_2);
    d = fast::min(d, _454 - _283.ref_smooth);
    return d;
}

static inline __attribute__((always_inline))
float march(thread const float3& ro, thread const float3& rd, constant ReferenceUniformsecda745583188& _283, thread float4x4& invOrient)
{
    float d = 0.0;
    for (int i = 0; i < int(_283.MAX_ITER); i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float _486 = dist(param, _283, invOrient);
        float dd = _486;
        d += dd;
        if ((dd < 9.9999997473787516355514526367188e-06) || (d > 1000.0))
        {
            break;
        }
    }
    return d;
}

static inline __attribute__((always_inline))
float3 calcNormal(thread const float3& p, constant ReferenceUniformsecda745583188& _283, thread float4x4& invOrient)
{
    float3 param = p;
    float _509 = dist(param, _283, invOrient);
    float d = _509;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_1 = p - e.xyy;
    float _519 = dist(param_1, _283, invOrient);
    float3 param_2 = p - e.yxy;
    float _525 = dist(param_2, _283, invOrient);
    float3 param_3 = p - e.yyx;
    float _531 = dist(param_3, _283, invOrient);
    return fast::normalize(float3(d) - float3(_519, _525, _531));
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformsecda745583188& _283)
{
    float3 lightPos = float3(_283.lightDir.x / 2.0, (-_283.lightDir.y) / 2.0, (-_283.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos - p);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float2 mapTexture(thread float2& texCoord, constant ReferenceUniformsecda745583188& _283)
{
    float texRad = _283.texAngle * 0.01745329983532428741455078125;
    float texCos = cos(texRad);
    float texSin = sin(texRad);
    float2x2 texRot = float2x2(float2(texCos, -texSin), float2(texSin, texCos));
    float texTwirlRad = _283.texTwirl * 0.01745329983532428741455078125;
    float texTwirlCos = cos(texTwirlRad);
    float texTwirlSin = sin(texTwirlRad);
    float2x2 texTwirlRot = float2x2(float2(texTwirlCos, -texTwirlSin), float2(texTwirlSin, texTwirlCos));
    float2 texScaleVec = float2(1.0 / _283.texRepeatX, 1.0 / _283.texRepeatY);
    texCoord *= texRot;
    texCoord += (_283.texOffset / float2(1000.0));
    texCoord /= texScaleVec;
    if (_283.mirror != 0u)
    {
        texCoord = abs(mod(texCoord, float2(2.0)) - float2(1.0));
    }
    else
    {
        texCoord = mod(texCoord, float2(1.0));
    }
    texCoord -= float2(0.5);
    texCoord *= (float2(1.0) - (float2(5.0) / _283.refScreen.xy));
    texCoord *= _283.texCrop;
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
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformsecda745583188& _283)
{
    float3 lightPos = float3(_283.lightDir.x / 2.0, (-_283.lightDir.y) / 2.0, (-_283.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformsecda745583188& _283)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    if (_283.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_283.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _283);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _283.ambient) + (((tc * _283.lightColor.xyz) * l) * (1.0 - _283.ambient));
            surface *= _283.lightIntensity;
            float s = powr(l, _283.spec);
            surface = mix(surface * (1.0 - (_283.shine * 0.100000001490116119384765625)), float3(1.0), float3(_283.shine * s));
            result = float4(surface, texColor.w) * a;
        }
        else
        {
            if (_283.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _283);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _283.ambient) + (((tc_1 * _283.lightColor.xyz) * l_1) * (1.0 - _283.ambient));
                surface_1 *= _283.lightIntensity;
                float s_1 = powr(l_1, _283.spec);
                surface_1 = mix(surface_1 * (1.0 - (_283.shine * 0.100000001490116119384765625)), float3(1.0), float3(_283.shine * s_1));
                result = float4(surface_1, texColor.w) * a;
            }
            else
            {
                if (_283.shadingType == 3)
                {
                    float ds = fast::max(_283.radius, _283.height) * 2.5;
                    float dd = 1.0 - (((d - (_283.position / float3(100.0)).z) + (ds / 2.0)) / ds);
                    result = float4(dd, dd, dd, 1.0) * a;
                }
                else
                {
                    if (_283.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_283.shadingType == 5)
                        {
                            float ds_1 = fast::max(_283.radius, _283.height) * 2.5;
                            float dd_1 = 1.0 - (((d - (_283.position / float3(100.0)).z) + (ds_1 / 2.0)) / ds_1);
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
void referenceMain(constant ReferenceUniformsecda745583188& _283, thread float4x4& invOrient, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    referenceVertexInit(_283, invOrient);
    float2 st = (gl_FragCoord.xy - _283.refLayer.xy) / _283.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_283.refLayer.z / _283.refLayer.w);
    st /= float2(_283.scale);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float d = march(param, param_1, _283, invOrient);
    float3 p = ro + (rd * d);
    float3 param_2 = p;
    float3 n = calcNormal(param_2, _283, invOrient);
    float3 nn = n;
    float3 param_3 = p;
    float3 param_4 = n;
    float l = lighting(param_3, param_4, _283);
    n = (float4(n, 1.0) * invOrient).xyz;
    float4 localCoord = float4(p - (_283.position / float3(100.0)), 1.0);
    localCoord *= invOrient;
    float4 pp = localCoord;
    float2 texCoordOutside = float2((precise::atan2(pp.x, pp.z) / 6.283100128173828125) + 0.5, ((pp.y / _283.height) / 2.0) + 0.5);
    texCoordOutside.x = 1.0 - mod(texCoordOutside.x + 0.5, 1.0);
    float2 texCoordEnds = pp.xz / float2(_283.radius * 2.0);
    texCoordEnds = (texCoordEnds + float2(1.0)) / float2(2.0);
    float _1073;
    if (n.y < 0.0)
    {
        _1073 = 1.0 - texCoordEnds.y;
    }
    else
    {
        _1073 = texCoordEnds.y;
    }
    texCoordEnds.y = _1073;
    float2 texCoord = mix(texCoordOutside, texCoordEnds, float2(abs(n.y)));
    float2 param_5 = texCoord;
    float2 _1094 = mapTexture(param_5, _283);
    texCoord = _1094;
    float2 param_6 = (float4(texCoord, 0.0, 1.0) * _283.refLayerToScreen).xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_6);
    float4 param_7 = texColor;
    float3 param_8 = p;
    float3 param_9 = nn;
    float param_10 = d;
    referenceColor = applyShading(param_7, param_8, param_9, param_10, _283);
}

fragment refAM35_ecda745583188_out refAM35_ecda745583188(constant ReferenceUniformsecda745583188& _283 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ecda745583188_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 invOrient;
    referenceMain(_283, invOrient, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1123 = any(isnan(referenceColor));
    bool _1130;
    if (!_1123)
    {
        _1130 = any(isinf(referenceColor));
    }
    else
    {
        _1130 = _1123;
    }
    if (_1130)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1143 = referenceColor;
    float3 _1149 = fast::clamp(_1143.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1149.x;
    referenceColor.y = _1149.y;
    referenceColor.z = _1149.z;
    out.finalColor = referenceColor;
    return out;
}

