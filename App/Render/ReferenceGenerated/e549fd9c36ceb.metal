// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/s3d-starprism.xml
// Original source comments and attribution:
//#define MAX_ITER 35
// remove this line for an only partially signed sdf
//float sdStar( in vec3 p, in vec2 s) {
//    float d = 100000000.0;
//    float offs = s.x * 0.500;
//    vec3 disp = vec3(0.,-offs,0.);
//    //p.xy *= rot(3.14159);
//    d = min(d, sdTriPrism(p+disp, s) );
//    p.xy *= rot(3.14159*2./5.);
//    d = min(d, sdTriPrism(p+disp, s) );
//    p.xy *= rot(3.14159*2./5.);
//    d = min(d, sdTriPrism(p+disp, s) );
//    p.xy *= rot(3.14159*2./5.);
//    d = min(d, sdTriPrism(p+disp, s) );
//    p.xy *= rot(3.14159*2./5.);
//    d = min(d, sdTriPrism(p+disp, s) );
//    return d;
//}
//p.yz *= rot(3.14159/2.0);
//d = min(d,sdBox(p,vec3(width-smooth,height-smooth,depth-smooth))-smooth);
//d = min(d,sdStar(p,vec2(size-smooth,thickness-smooth))-smooth);
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

struct ReferenceUniformse549fd9c36ceb
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
    float thickness;
    float3 position;
    float scale;
    char _m11_pad[12];
    float pointCount;
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
    uint texStretch;
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

struct refAM35_e549fd9c36ceb_out
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
    float4x4 _171;
    if (inverted)
    {
        _171 = transpose(m);
    }
    else
    {
        _171 = m;
    }
    return _171;
}

static inline __attribute__((always_inline))
void referenceVertexInit(constant ReferenceUniformse549fd9c36ceb& _299, thread float4x4& invOrient)
{
    float3 r = _299.rotate * 0.01745329983532428741455078125;
    float3 param = float3(1.0, 0.0, 0.0);
    float param_1 = r.x;
    float4x4 rx = referenceVertex_rotationAxisAngle(param, param_1);
    float3 param_2 = float3(0.0, 1.0, 0.0);
    float param_3 = r.y;
    float4x4 ry = referenceVertex_rotationAxisAngle(param_2, param_3);
    float3 param_4 = float3(0.0, 0.0, 1.0);
    float param_5 = r.z;
    float4x4 rz = referenceVertex_rotationAxisAngle(param_4, param_5);
    float3 param_6 = _299.orient_euler;
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
float sdTriPrism(thread const float3& p, thread const float2& h)
{
    float3 q = abs(p);
    return fast::max(q.z - h.y, fast::max((q.x * 0.86602497100830078125) + (p.y * 0.5), -p.y) - (h.x * 0.5));
}

static inline __attribute__((always_inline))
float sdStar(thread float3& p, thread const float2& s, thread const int& points)
{
    float d = 100000000.0;
    float offs = s.x * 0.5;
    float3 disp = float3(0.0, -offs, 0.0);
    float param = 6.28318023681640625 / float(points);
    float2x2 rmat = rot(param);
    for (int i = 0; i < points; i++)
    {
        float3 param_1 = p + disp;
        float2 param_2 = s;
        d = fast::min(d, sdTriPrism(param_1, param_2));
        float3 _424 = p;
        float2 _426 = _424.xy * rmat;
        p.x = _426.x;
        p.y = _426.y;
    }
    return d;
}

static inline __attribute__((always_inline))
float dist(thread float3& p, constant ReferenceUniformse549fd9c36ceb& _299, thread float4x4& invOrient)
{
    float d = 100000000.0;
    p -= (_299.position / float3(100.0));
    p = (float4(p, 1.0) * invOrient).xyz;
    float3 param = p;
    float2 param_1 = float2(_299.size, _299.thickness);
    int param_2 = int(_299.pointCount);
    float _471 = sdStar(param, param_1, param_2);
    d = fast::min(d, _471);
    return d;
}

static inline __attribute__((always_inline))
float march(thread const float3& ro, thread const float3& rd, constant ReferenceUniformse549fd9c36ceb& _299, thread float4x4& invOrient)
{
    float d = 0.0;
    for (int i = 0; i < int(_299.MAX_ITER); i++)
    {
        float3 p = ro + (rd * d);
        float3 param = p;
        float _498 = dist(param, _299, invOrient);
        float dd = _498;
        d += dd;
        if ((dd < 9.9999997473787516355514526367188e-06) || (d > 1000.0))
        {
            break;
        }
    }
    return d;
}

static inline __attribute__((always_inline))
float3 calcNormal(thread const float3& p, constant ReferenceUniformse549fd9c36ceb& _299, thread float4x4& invOrient)
{
    float3 param = p;
    float _655 = dist(param, _299, invOrient);
    float d = _655;
    float2 e = float2(0.00999999977648258209228515625, 0.0);
    float3 param_1 = p - e.xyy;
    float _665 = dist(param_1, _299, invOrient);
    float3 param_2 = p - e.yxy;
    float _671 = dist(param_2, _299, invOrient);
    float3 param_3 = p - e.yyx;
    float _677 = dist(param_3, _299, invOrient);
    return fast::normalize(float3(d) - float3(_665, _671, _677));
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse549fd9c36ceb& _299)
{
    float3 lightPos = float3(_299.lightDir.x / 2.0, (-_299.lightDir.y) / 2.0, (-_299.lightDepth) * 2.0);
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
float2 mapTexture(thread float2& texCoord, constant ReferenceUniformse549fd9c36ceb& _299)
{
    float texRad = _299.texAngle * 0.01745329983532428741455078125;
    float texCos = cos(texRad);
    float texSin = sin(texRad);
    float2x2 texRot = float2x2(float2(texCos, -texSin), float2(texSin, texCos));
    float texTwirlRad = _299.texTwirl * 0.01745329983532428741455078125;
    float texTwirlCos = cos(texTwirlRad);
    float texTwirlSin = sin(texTwirlRad);
    float2x2 texTwirlRot = float2x2(float2(texTwirlCos, -texTwirlSin), float2(texTwirlSin, texTwirlCos));
    float2 texScaleVec = float2(1.0 / (_299.texRepeatX - 0.25), 1.0 / (_299.texRepeatY - 0.25));
    texCoord *= texRot;
    texCoord += ((_299.texOffset + float2(100.0)) / float2(1000.0));
    texCoord /= texScaleVec;
    if (_299.mirror != 0u)
    {
        texCoord = abs(mod(texCoord, float2(2.0)) - float2(1.0));
    }
    else
    {
        texCoord = mod(texCoord, float2(1.0));
    }
    texCoord -= float2(0.5);
    texCoord *= (float2(1.0) - (float2(5.0) / _299.refScreen.xy));
    texCoord *= _299.texCrop;
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
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformse549fd9c36ceb& _299)
{
    float3 lightPos = float3(_299.lightDir.x / 2.0, (-_299.lightDir.y) / 2.0, (-_299.lightDepth) * 2.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformse549fd9c36ceb& _299)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    if (_299.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_299.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _299);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _299.ambient) + (((tc * _299.lightColor.xyz) * l) * (1.0 - _299.ambient));
            surface *= _299.lightIntensity;
            float s = powr(l, _299.spec);
            surface = mix(surface * (1.0 - (_299.shine * 0.100000001490116119384765625)), float3(1.0), float3(_299.shine * s));
            result = float4(surface, texColor.w) * a;
        }
        else
        {
            if (_299.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _299);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _299.ambient) + (((tc_1 * _299.lightColor.xyz) * l_1) * (1.0 - _299.ambient));
                surface_1 *= _299.lightIntensity;
                float s_1 = powr(l_1, _299.spec);
                surface_1 = mix(surface_1 * (1.0 - (_299.shine * 0.100000001490116119384765625)), float3(1.0), float3(_299.shine * s_1));
                result = float4(surface_1, texColor.w) * a;
            }
            else
            {
                if (_299.shadingType == 3)
                {
                    float ds = fast::max(_299.thickness, _299.size) * 2.5;
                    float dd = 1.0 - (((d - (_299.position / float3(100.0)).z) + (ds / 2.0)) / ds);
                    result = float4(dd, dd, dd, 1.0) * a;
                }
                else
                {
                    if (_299.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_299.shadingType == 5)
                        {
                            float ds_1 = fast::max(_299.thickness, _299.size) * 2.5;
                            float dd_1 = 1.0 - (((d - (_299.position / float3(100.0)).z) + (ds_1 / 2.0)) / ds_1);
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
void referenceMain(constant ReferenceUniformse549fd9c36ceb& _299, thread float4x4& invOrient, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    referenceVertexInit(_299, invOrient);
    float2 st = (gl_FragCoord.xy - _299.refLayer.xy) / _299.refLayer.zw;
    st -= float2(0.5);
    st.x *= (_299.refLayer.z / _299.refLayer.w);
    st /= float2(_299.scale);
    float3 ro = float3(0.0, 1.0, -1.0);
    float3 rd = fast::normalize(float3(st, 1.0));
    float3 param = ro;
    float3 param_1 = rd;
    float d = march(param, param_1, _299, invOrient);
    float3 p = ro + (rd * d);
    float3 param_2 = p;
    float3 n = calcNormal(param_2, _299, invOrient);
    float3 nn = n;
    float3 param_3 = p;
    float3 param_4 = n;
    float l = lighting(param_3, param_4, _299);
    float4 localCoord = float4(p - (_299.position / float3(100.0)), 1.0);
    n = (float4(n, 0.0) * invOrient).xyz;
    localCoord *= invOrient;
    float4 pp = localCoord;
    float3 param_5 = n;
    float3 param_6 = pp.xyz * float3(0.0, 1.0, 0.0);
    float4 qq = pp * vecToVec(param_5, param_6);
    if (_299.texStretch != 0u)
    {
        pp /= float4(_299.size, _299.size, _299.thickness, 1.0);
    }
    float2 texCoord;
    float a;
    if (n.x > 0.5)
    {
        texCoord = (pp.zy + float2(1.0)) / float2(2.0);
        bool _1226 = _299.size < 0.010499999858438968658447265625;
        bool _1233;
        if (!_1226)
        {
            _1233 = _299.thickness < 0.010499999858438968658447265625;
        }
        else
        {
            _1233 = _1226;
        }
        a = _1233 ? 0.0 : 1.0;
    }
    else
    {
        if (n.x < (-0.5))
        {
            texCoord = (pp.zy + float2(1.0)) / float2(2.0);
            texCoord.x = 1.0 - texCoord.x;
            bool _1254 = _299.size < 0.010499999858438968658447265625;
            bool _1261;
            if (!_1254)
            {
                _1261 = _299.thickness < 0.010499999858438968658447265625;
            }
            else
            {
                _1261 = _1254;
            }
            a = _1261 ? 0.0 : 1.0;
        }
        else
        {
            if (n.y > 0.5)
            {
                texCoord = (pp.xz + float2(1.0)) / float2(2.0);
                bool _1277 = _299.size < 0.010499999858438968658447265625;
                bool _1284;
                if (!_1277)
                {
                    _1284 = _299.thickness < 0.010499999858438968658447265625;
                }
                else
                {
                    _1284 = _1277;
                }
                a = _1284 ? 0.0 : 1.0;
            }
            else
            {
                if (n.y < (-0.5))
                {
                    texCoord = float2(1.0) - ((pp.xz + float2(1.0)) / float2(2.0));
                    texCoord.x = 1.0 - texCoord.x;
                    bool _1306 = _299.size < 0.010499999858438968658447265625;
                    bool _1313;
                    if (!_1306)
                    {
                        _1313 = _299.thickness < 0.010499999858438968658447265625;
                    }
                    else
                    {
                        _1313 = _1306;
                    }
                    a = _1313 ? 0.0 : 1.0;
                }
                else
                {
                    if (n.z > 0.5)
                    {
                        texCoord = (pp.xy + float2(1.0)) / float2(2.0);
                        texCoord.x = 1.0 - texCoord.x;
                        bool _1333 = _299.size < 0.010499999858438968658447265625;
                        bool _1340;
                        if (!_1333)
                        {
                            _1340 = _299.size < 0.010499999858438968658447265625;
                        }
                        else
                        {
                            _1340 = _1333;
                        }
                        a = _1340 ? 0.0 : 1.0;
                    }
                    else
                    {
                        if (n.z < (-0.5))
                        {
                            texCoord = (pp.xy + float2(1.0)) / float2(2.0);
                            bool _1356 = _299.size < 0.010499999858438968658447265625;
                            bool _1363;
                            if (!_1356)
                            {
                                _1363 = _299.size < 0.010499999858438968658447265625;
                            }
                            else
                            {
                                _1363 = _1356;
                            }
                            a = _1363 ? 0.0 : 1.0;
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
    float2 _1369 = mapTexture(param_7, _299);
    texCoord = _1369;
    float2 param_8 = (float4(texCoord, 0.0, 1.0) * _299.refLayerToScreen).xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param_8);
    float4 param_9 = texColor;
    float3 param_10 = p;
    float3 param_11 = nn;
    float param_12 = d;
    referenceColor = applyShading(param_9, param_10, param_11, param_12, _299) * a;
}

fragment refAM35_e549fd9c36ceb_out refAM35_e549fd9c36ceb(constant ReferenceUniformse549fd9c36ceb& _299 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e549fd9c36ceb_out out = {};
    float4 referenceColor = float4(0.0);
    float4x4 invOrient;
    referenceMain(_299, invOrient, gl_FragCoord, refInput, refInputSmplr, referenceColor);
    bool _1400 = any(isnan(referenceColor));
    bool _1407;
    if (!_1400)
    {
        _1407 = any(isinf(referenceColor));
    }
    else
    {
        _1407 = _1400;
    }
    if (_1407)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1420 = referenceColor;
    float3 _1426 = fast::clamp(_1420.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1426.x;
    referenceColor.y = _1426.y;
    referenceColor.z = _1426.z;
    out.finalColor = referenceColor;
    return out;
}

