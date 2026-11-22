// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/bumpmap2.xml
// Original source comments and attribution:
// Flat
// Point Light
// * a;
// Directonal Light
// * a;
// Depth Map
// Normal Map
// Normal * Depth
//float texCrop = 1.0;
//if( mirror ) {
//    texCoord = 1.0 - texCoord;
//}
//texCoord *= texCrop;
//st calc----------------------------------------------------
//----------------------------------------------------st calc
//st calc----------------------------------------------------
//----------------------------------------------------st calc
//canvas - bumpmap_b.g
//bumpmap_b - bumpmap_b.r
//mud - bumpmap_a.b
//parchment - bumpmap_a.g
//wood - bumpmap_a.r
// weave - bumpmap_b.b
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

struct ReferenceUniformsed31095823fed
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int imgNo;
    char _m6_pad[12];
    int texNo;
    float4 texColor;
    uint mirror;
    char _m9_pad[12];
    float texScale;
    char _m10_pad[8];
    float2 texStretch;
    char _m11_pad[8];
    float texAngle;
    char _m12_pad[12];
    float texCrop;
    char _m13_pad[8];
    float2 texOffset;
    char _m14_pad[8];
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
    float4 shineColor;
    float2 lightDir;
    char _m22_pad[8];
    float lightDepth;
    char _m23_pad[12];
    float height;
    char _m24_pad[12];
    float smoothing;
};

struct refAM35_ed31095823fed_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2 mapTexture(thread float2& texCoord, thread const float& rate, constant ReferenceUniformsed31095823fed& _63)
{
    float texRad = _63.texAngle * 0.01745329983532428741455078125;
    float texCos = cos(texRad);
    float texSin = sin(texRad);
    float2x2 texRot = float2x2(float2(texCos, -texSin), float2(texSin, texCos));
    float texTwirl = 0.0;
    float texTwirlRad = texTwirl * 0.01745329983532428741455078125;
    float texTwirlCos = cos(texTwirlRad);
    float texTwirlSin = sin(texTwirlRad);
    float2x2 texTwirlRot = float2x2(float2(texTwirlCos, -texTwirlSin), float2(texTwirlSin, texTwirlCos));
    float2 texScaleVec = float2(_63.texScale, _63.texScale);
    texScaleVec *= float2(_63.texStretch.x, _63.texStretch.y);
    texCoord -= ((_63.texOffset * float2(1.0, -1.0)) / float2(1000.0));
    texCoord -= float2(0.5);
    texCoord.x *= rate;
    texCoord *= texRot;
    texCoord.x /= rate;
    texCoord /= texScaleVec;
    texCoord += float2(0.5);
    texCoord -= float2(0.5);
    texCoord *= (float2(1.0) - (float2(5.0) / _63.refScreen.xy));
    texCoord *= texTwirlRot;
    texCoord += float2(0.5);
    return texCoord;
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float lighting(thread const float3& p, thread const float3& n, constant ReferenceUniformsed31095823fed& _63)
{
    float3 lightPos = float3(_63.lightDir.x / 2.0, (-_63.lightDir.y) / 2.0, _63.lightDepth * 2.0) / float3(1000.0);
    float3 l = fast::normalize(lightPos - p);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float directionalLighting(thread const float3& p, thread const float3& n, constant ReferenceUniformsed31095823fed& _63)
{
    float3 lightPos = float3(_63.lightDir.x / 2.0, (-_63.lightDir.y) / 2.0, _63.lightDepth * 2.0) / float3(1000.0);
    float3 l = fast::normalize(lightPos);
    return dot(n, l);
}

static inline __attribute__((always_inline))
float4 applyShading(thread const float4& texColor, thread const float3& p, thread const float3& n, thread const float& d, constant ReferenceUniformsed31095823fed& _63)
{
    float4 result = float4(0.0);
    float a = smoothstep(30.0, 9.0, d);
    a *= smoothstep(0.300000011920928955078125, 0.20000000298023223876953125, n.z);
    if (_63.shadingType == 0)
    {
        result = texColor * a;
    }
    else
    {
        if (_63.shadingType == 1)
        {
            float3 param = p;
            float3 param_1 = n;
            float l = lighting(param, param_1, _63);
            float3 tc = texColor.xyz;
            float3 surface = (tc * _63.ambient) + (((tc * _63.lightColor.xyz) * l) * (1.0 - _63.ambient));
            surface *= _63.lightIntensity;
            float s = abs(powr(l, _63.spec));
            surface = mix(surface * (1.0 - (_63.shine * 0.100000001490116119384765625)), _63.shineColor.xyz, float3(_63.shine * s));
            result = float4(surface, texColor.w);
        }
        else
        {
            if (_63.shadingType == 2)
            {
                float3 param_2 = p;
                float3 param_3 = n;
                float l_1 = directionalLighting(param_2, param_3, _63);
                float3 tc_1 = texColor.xyz;
                float3 surface_1 = (tc_1 * _63.ambient) + (((tc_1 * _63.lightColor.xyz) * l_1) * (1.0 - _63.ambient));
                surface_1 *= _63.lightIntensity;
                float s_1 = abs(powr(l_1, _63.spec));
                surface_1 = mix(surface_1 * (1.0 - (_63.shine * 0.100000001490116119384765625)), _63.shineColor.xyz, float3(_63.shine * s_1));
                result = float4(surface_1, texColor.w);
            }
            else
            {
                if (_63.shadingType == 3)
                {
                    result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                }
                else
                {
                    if (_63.shadingType == 4)
                    {
                        result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                    }
                    else
                    {
                        if (_63.shadingType == 5)
                        {
                            result = float4((n / float3(2.0)) + float3(0.5), 1.0) * a;
                        }
                    }
                }
            }
        }
    }
    return result;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsed31095823fed& _63, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, texture2d<float> refReference, sampler refReferenceSmplr, texture2d<float> refImage2, sampler refImage2Smplr, texture2d<float> refImage1, sampler refImage1Smplr, thread float4& referenceColor)
{
    float2 st = gl_FragCoord.xy / _63.refScreen.xy;
    float curHeight = 0.0;
    float left = 0.0;
    float right = 0.0;
    float top = 0.0;
    float bottom = 0.0;
    float2 gradient = float2(0.0);
    float2 fragSize;
    if (_63.imgNo == 0)
    {
        st = (float4(st, 0.0, 1.0) * _63.refScreenToLayer).xy;
        float2 param = st;
        float param_1 = _63.refScreen.x / _63.refScreen.y;
        float2 _492 = mapTexture(param, param_1, _63);
        st = _492;
        if (_63.mirror != 0u)
        {
            st = abs(mod(st, float2(2.0)) - float2(1.0));
        }
        else
        {
            st = mod(st, float2(1.0));
        }
        st = mod(st, float2(1.0));
        st = (float4(st, 0.0, 1.0) * _63.refLayerToScreen).xy;
        st -= (float2(_63.refLayer.x + (_63.refLayer.z * 0.5), (_63.refScreen.y - _63.refLayer.y) - (_63.refLayer.w * 0.5)) / _63.refScreen.xy);
        st *= _63.texCrop;
        st += (float2(_63.refLayer.x + (_63.refLayer.z * 0.5), (_63.refScreen.y - _63.refLayer.y) - (_63.refLayer.w * 0.5)) / _63.refScreen.xy);
        float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
        fragSize = (float2(1.0) / getTexSize(param_2)) * _63.smoothing;
        float2 param_3 = st;
        curHeight = length(texture2DCv(refInput, refInputSmplr, param_3).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        float2 param_4 = float2(st.x - fragSize.x, st.y);
        left = length(texture2DCv(refInput, refInputSmplr, param_4).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        float2 param_5 = float2(st.x + fragSize.x, st.y);
        right = length(texture2DCv(refInput, refInputSmplr, param_5).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        float2 param_6 = float2(st.x, st.y + fragSize.y);
        top = length(texture2DCv(refInput, refInputSmplr, param_6).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        float2 param_7 = float2(st.x, st.y - fragSize.y);
        bottom = length(texture2DCv(refInput, refInputSmplr, param_7).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    }
    else
    {
        if (_63.imgNo == 1)
        {
            st = (float4(st, 0.0, 1.0) * _63.refScreenToLayer).xy;
            float2 param_8 = st;
            float param_9 = _63.refScreen.x / _63.refScreen.y;
            float2 _669 = mapTexture(param_8, param_9, _63);
            st = _669;
            if (_63.mirror != 0u)
            {
                st = abs(mod(st, float2(2.0)) - float2(1.0));
            }
            else
            {
                st = mod(st, float2(1.0));
            }
            st = mod(st, float2(1.0));
            st = (float4(st, 0.0, 1.0) * _63.refLayerToScreen).xy;
            st -= (float2(_63.refLayer.x + (_63.refLayer.z * 0.5), (_63.refScreen.y - _63.refLayer.y) - (_63.refLayer.w * 0.5)) / _63.refScreen.xy);
            st *= _63.texCrop;
            st += (float2(_63.refLayer.x + (_63.refLayer.z * 0.5), (_63.refScreen.y - _63.refLayer.y) - (_63.refLayer.w * 0.5)) / _63.refScreen.xy);
            fragSize = (float2(1.0) / float2(int2(refReference.get_width(), refReference.get_height()))) * _63.smoothing;
            float2 param_10 = st;
            curHeight = length(texture2DCv(refReference, refReferenceSmplr, param_10).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float2 param_11 = float2(st.x - fragSize.x, st.y);
            left = length(texture2DCv(refReference, refReferenceSmplr, param_11).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float2 param_12 = float2(st.x + fragSize.x, st.y);
            right = length(texture2DCv(refReference, refReferenceSmplr, param_12).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float2 param_13 = float2(st.x, st.y + fragSize.y);
            top = length(texture2DCv(refReference, refReferenceSmplr, param_13).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float2 param_14 = float2(st.x, st.y - fragSize.y);
            bottom = length(texture2DCv(refReference, refReferenceSmplr, param_14).xyz * float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
        }
        else
        {
            if (_63.imgNo == 2)
            {
                st = (float4(st, 0.0, 1.0) * _63.refScreenToLayer).xy;
                st.x *= (_63.refLayer.z / 1024.0);
                st.y *= (_63.refLayer.w / 1024.0);
                float2 param_15 = st;
                float param_16 = 1.0;
                float2 _843 = mapTexture(param_15, param_16, _63);
                st = _843;
                if (_63.mirror != 0u)
                {
                    st = abs(mod(st, float2(2.0)) - float2(1.0));
                }
                else
                {
                    st = mod(st, float2(1.0));
                }
                fragSize = float2(0.0009765625) * _63.smoothing;
                curHeight = refImage2.sample(refImage2Smplr, st).y;
                left = refImage2.sample(refImage2Smplr, float2(st.x - fragSize.x, st.y)).y;
                right = refImage2.sample(refImage2Smplr, float2(st.x + fragSize.x, st.y)).y;
                top = refImage2.sample(refImage2Smplr, float2(st.x, st.y + fragSize.y)).y;
                bottom = refImage2.sample(refImage2Smplr, float2(st.x, st.y - fragSize.y)).y;
            }
            else
            {
                if (_63.imgNo == 3)
                {
                    st = (float4(st, 0.0, 1.0) * _63.refScreenToLayer).xy;
                    st.x *= (_63.refLayer.z / 1024.0);
                    st.y *= (_63.refLayer.w / 1024.0);
                    float2 param_17 = st;
                    float param_18 = 1.0;
                    float2 _944 = mapTexture(param_17, param_18, _63);
                    st = _944;
                    if (_63.mirror != 0u)
                    {
                        st = abs(mod(st, float2(2.0)) - float2(1.0));
                    }
                    else
                    {
                        st = mod(st, float2(1.0));
                    }
                    fragSize = float2(0.0009765625) * _63.smoothing;
                    curHeight = refImage2.sample(refImage2Smplr, st).x;
                    left = refImage2.sample(refImage2Smplr, float2(st.x - fragSize.x, st.y)).x;
                    right = refImage2.sample(refImage2Smplr, float2(st.x + fragSize.x, st.y)).x;
                    top = refImage2.sample(refImage2Smplr, float2(st.x, st.y + fragSize.y)).x;
                    bottom = refImage2.sample(refImage2Smplr, float2(st.x, st.y - fragSize.y)).x;
                }
                else
                {
                    if (_63.imgNo == 4)
                    {
                        st = (float4(st, 0.0, 1.0) * _63.refScreenToLayer).xy;
                        st.x *= (_63.refLayer.z / 1024.0);
                        st.y *= (_63.refLayer.w / 1024.0);
                        float2 param_19 = st;
                        float param_20 = 1.0;
                        float2 _1042 = mapTexture(param_19, param_20, _63);
                        st = _1042;
                        if (_63.mirror != 0u)
                        {
                            st = abs(mod(st, float2(2.0)) - float2(1.0));
                        }
                        else
                        {
                            st = mod(st, float2(1.0));
                        }
                        fragSize = float2(0.0009765625) * _63.smoothing;
                        curHeight = refImage1.sample(refImage1Smplr, st).z;
                        left = refImage1.sample(refImage1Smplr, float2(st.x - fragSize.x, st.y)).z;
                        right = refImage1.sample(refImage1Smplr, float2(st.x + fragSize.x, st.y)).z;
                        top = refImage1.sample(refImage1Smplr, float2(st.x, st.y + fragSize.y)).z;
                        bottom = refImage1.sample(refImage1Smplr, float2(st.x, st.y - fragSize.y)).z;
                    }
                    else
                    {
                        if (_63.imgNo == 5)
                        {
                            st = (float4(st, 0.0, 1.0) * _63.refScreenToLayer).xy;
                            st.x *= (_63.refLayer.z / 1024.0);
                            st.y *= (_63.refLayer.w / 1024.0);
                            float2 param_21 = st;
                            float param_22 = 1.0;
                            float2 _1141 = mapTexture(param_21, param_22, _63);
                            st = _1141;
                            if (_63.mirror != 0u)
                            {
                                st = abs(mod(st, float2(2.0)) - float2(1.0));
                            }
                            else
                            {
                                st = mod(st, float2(1.0));
                            }
                            fragSize = float2(0.0009765625) * _63.smoothing;
                            curHeight = refImage1.sample(refImage1Smplr, st).y;
                            left = refImage1.sample(refImage1Smplr, float2(st.x - fragSize.x, st.y)).y;
                            right = refImage1.sample(refImage1Smplr, float2(st.x + fragSize.x, st.y)).y;
                            top = refImage1.sample(refImage1Smplr, float2(st.x, st.y + fragSize.y)).y;
                            bottom = refImage1.sample(refImage1Smplr, float2(st.x, st.y - fragSize.y)).y;
                        }
                        else
                        {
                            if (_63.imgNo == 6)
                            {
                                st = (float4(st, 0.0, 1.0) * _63.refScreenToLayer).xy;
                                st.x *= (_63.refLayer.z / 1024.0);
                                st.y *= (_63.refLayer.w / 1024.0);
                                float2 param_23 = st;
                                float param_24 = 1.0;
                                float2 _1240 = mapTexture(param_23, param_24, _63);
                                st = _1240;
                                if (_63.mirror != 0u)
                                {
                                    st = abs(mod(st, float2(2.0)) - float2(1.0));
                                }
                                else
                                {
                                    st = mod(st, float2(1.0));
                                }
                                fragSize = float2(0.0009765625) * _63.smoothing;
                                curHeight = refImage1.sample(refImage1Smplr, st).x;
                                left = refImage1.sample(refImage1Smplr, float2(st.x - fragSize.x, st.y)).x;
                                right = refImage1.sample(refImage1Smplr, float2(st.x + fragSize.x, st.y)).x;
                                top = refImage1.sample(refImage1Smplr, float2(st.x, st.y + fragSize.y)).x;
                                bottom = refImage1.sample(refImage1Smplr, float2(st.x, st.y - fragSize.y)).x;
                            }
                            else
                            {
                                if (_63.imgNo == 7)
                                {
                                    st = (float4(st, 0.0, 1.0) * _63.refScreenToLayer).xy;
                                    st.x *= (_63.refLayer.z / 1024.0);
                                    st.y *= (_63.refLayer.w / 1024.0);
                                    float2 param_25 = st;
                                    float param_26 = 1.0;
                                    float2 _1339 = mapTexture(param_25, param_26, _63);
                                    st = _1339;
                                    if (_63.mirror != 0u)
                                    {
                                        st = abs(mod(st, float2(2.0)) - float2(1.0));
                                    }
                                    else
                                    {
                                        st = mod(st, float2(1.0));
                                    }
                                    fragSize = float2(0.0009765625) * _63.smoothing;
                                    curHeight = refImage2.sample(refImage2Smplr, st).z;
                                    left = refImage2.sample(refImage2Smplr, float2(st.x - fragSize.x, st.y)).z;
                                    right = refImage2.sample(refImage2Smplr, float2(st.x + fragSize.x, st.y)).z;
                                    top = refImage2.sample(refImage2Smplr, float2(st.x, st.y + fragSize.y)).z;
                                    bottom = refImage2.sample(refImage2Smplr, float2(st.x, st.y - fragSize.y)).z;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    gradient = fast::normalize(float2((right - left) / (2.0 * fragSize.x), (top - bottom) / (2.0 * fragSize.y)));
    float adjHeight = _63.height / 10.0;
    curHeight *= adjHeight;
    left *= adjHeight;
    right *= adjHeight;
    top *= adjHeight;
    bottom *= adjHeight;
    float3 va = fast::normalize(float3(fragSize.x * 2.0, 0.0, right - left));
    float3 vb = fast::normalize(float3(0.0, fragSize.y * 2.0, top - bottom));
    float3 n = fast::normalize(cross(va, vb));
    float4 baseColor;
    if (_63.texNo == 0)
    {
        float2 param_27 = gl_FragCoord.xy / _63.refScreen.xy;
        baseColor = texture2DCv(refReference, refReferenceSmplr, param_27);
    }
    else
    {
        if (_63.texNo == 1)
        {
            float2 param_28 = gl_FragCoord.xy / _63.refScreen.xy;
            baseColor = texture2DCv(refInput, refInputSmplr, param_28);
        }
        else
        {
            baseColor = _63.texColor;
        }
    }
    float4 param_29 = baseColor;
    float3 param_30 = float3((gl_FragCoord.xy / _63.refScreen.xy).x - 0.5, (gl_FragCoord.xy / _63.refScreen.xy).y - 0.5, curHeight);
    float3 param_31 = n;
    float param_32 = 1.0;
    baseColor = applyShading(param_29, param_30, param_31, param_32, _63);
    float2 param_33 = gl_FragCoord.xy / _63.refScreen.xy;
    float alpha = texture2DCv(refInput, refInputSmplr, param_33).w;
    float4 result = baseColor * alpha;
    if (false)
    {
        float2 ld = (gl_FragCoord.xy / _63.refScreen.xy) - ((float2(_63.refLayer.x + (_63.refLayer.z * 0.5), (_63.refScreen.y - _63.refLayer.y) - (_63.refLayer.w * 0.5)) / _63.refScreen.xy) + (float2(_63.lightDir.x / 2.0, (-_63.lightDir.y) / 2.0) / float2(1000.0)));
        ld.x *= (_63.refScreen.x / _63.refScreen.y);
        float4 lightColor = float4(0.0, 0.0, 0.0, 1.0);
        float lightSize = 0.0199999995529651641845703125;
        float lightIntensity = 0.5;
        result = mix(result, lightColor, float4(lightIntensity * smoothstep(0.0, 0.0500000007450580596923828125, fast::max(0.0, lightSize - length(ld)) * (1.0 / lightSize))));
        lightColor = float4(1.0);
        lightSize = 0.00999999977648258209228515625;
        lightIntensity = 1.0;
        result = mix(result, lightColor, float4(lightIntensity * smoothstep(0.0, 0.0500000007450580596923828125, fast::max(0.0, lightSize - length(ld)) * (1.0 / lightSize))));
    }
    referenceColor = result;
}

fragment refAM35_ed31095823fed_out refAM35_ed31095823fed(constant ReferenceUniformsed31095823fed& _63 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], texture2d<float> refImage2 [[texture(2)]], texture2d<float> refReference [[texture(3)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], sampler refImage2Smplr [[sampler(2)]], sampler refReferenceSmplr [[sampler(3)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed31095823fed_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_63, gl_FragCoord, refInput, refInputSmplr, refReference, refReferenceSmplr, refImage2, refImage2Smplr, refImage1, refImage1Smplr, referenceColor);
    bool _1632 = any(isnan(referenceColor));
    bool _1639;
    if (!_1632)
    {
        _1639 = any(isinf(referenceColor));
    }
    else
    {
        _1639 = _1632;
    }
    if (_1639)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1652 = referenceColor;
    float3 _1658 = fast::clamp(_1652.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1658.x;
    referenceColor.y = _1658.y;
    referenceColor.z = _1658.z;
    out.finalColor = referenceColor;
    return out;
}

