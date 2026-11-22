// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxspointunnel.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//Square of x
//Angular repeat
//Signed distance to circle
//Mix a shape defined by a distance field 'sd' with a 'target' color using the 'fill' color.
//Tunnel/Camera path
//////////////////////////
/////////////////////////
// vec2 uv = fragCoord.xy / iResolution.y;
//Scroll the points towards the screen
//Layer x/y offset
//Radius of the current ring
//Only draw points when uv is close to the ring.
//Angular repeated uv coords
//Distance to the nearest point
//Stripes
//Distance fade
// vec4 factor = mix(texColorX,fragColor,1.0);
// resultfinal = (newLayer(texColor, factor) * hardness) * texColor.a; }
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
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

struct ReferenceUniformse066e5f75d7f0
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 colorfg;
    float4 colorbg;
    int EVOTYPE;
    char _m8_pad[12];
    float PROGRESS;
    char _m9_pad[12];
    uint MANUAL;
    char _m10_pad[8];
    float2 EVO;
    char _m11_pad[8];
    float TUNNEL_LAYERS;
    char _m12_pad[12];
    float RING_POINTS;
    char _m13_pad[12];
    float POINT_SIZE;
    char _m14_pad[12];
    float scale;
    char _m15_pad[8];
    float2 position;
    char _m16_pad[8];
    float2 stretch;
    char _m17_pad[8];
    float alpha;
    char _m18_pad[12];
    float hardness;
    char _m19_pad[12];
    float angle;
    char _m20_pad[12];
    int blendMode;
};

struct refAM35_e066e5f75d7f0_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float2 TunnelPath(thread const float& x, constant ReferenceUniformse066e5f75d7f0& _134)
{
    float2 offs = float2(0.0);
    float _157;
    if (_134.MANUAL != 0u)
    {
        _157 = 0.20000000298023223876953125 * ((6.283185482025146484375 * x) * (1.0 - _134.EVO.x));
    }
    else
    {
        _157 = (0.20000000298023223876953125 * sin((6.283185482025146484375 * x) * 0.5)) + (0.4000000059604644775390625 * sin(((6.283185482025146484375 * x) * 0.20000000298023223876953125) + 0.300000011920928955078125));
    }
    offs.x = _157;
    float _191;
    if (_134.MANUAL != 0u)
    {
        _191 = 0.300000011920928955078125 * ((6.283185482025146484375 * x) * (1.0 - _134.EVO.y));
    }
    else
    {
        _191 = (0.300000011920928955078125 * cos((6.283185482025146484375 * x) * 0.300000011920928955078125)) + (0.20000000298023223876953125 * cos((6.283185482025146484375 * x) * 0.100000001490116119384765625));
    }
    offs.y = _191;
    offs *= smoothstep(1.0, 4.0, x);
    return offs;
}

static inline __attribute__((always_inline))
float sq(thread const float& x)
{
    return x * x;
}

static inline __attribute__((always_inline))
float2 AngRep(thread const float2& uv, thread const float& angle)
{
    float2 polar = float2(precise::atan2(uv.y, uv.x), length(uv));
    polar.x = mod(polar.x + (angle / 2.0), angle) - (angle / 2.0);
    return float2(cos(polar.x), sin(polar.x)) * polar.y;
}

static inline __attribute__((always_inline))
float sdCircle(thread const float2& uv, thread const float& r)
{
    return length(uv) - r;
}

static inline __attribute__((always_inline))
float3 MixShape(thread const float& sd, thread const float3& fill, thread const float3& target, constant ReferenceUniformse066e5f75d7f0& _134)
{
    float blend = smoothstep(0.0, 1.0 / _134.refScreen.y, sd);
    return mix(fill, target, float3(blend));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse066e5f75d7f0& _134, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_134.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _134.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_134.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _134.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_134.refScreen.x, _134.refScreen.y);
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _134.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _134.refScreen.xy).y) * _134.refScreen.xy) - float2(_134.refLayer.x + (_134.refLayer.z * 0.5), (_134.refScreen.y - _134.refLayer.y) - (_134.refLayer.w * 0.5))) / _134.refLayer.zw;
            syamjaidtz.y *= (_134.refLayer.w / _134.refLayer.z);
            syamjaidtz /= float2(_134.scale);
            float param_3 = (0.0 + _134.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2((-330.0) + _134.position.x, 200.0 - _134.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_134.scale * _134.stretch.x, _134.scale * _134.stretch.y);
            syamjaidtz /= scaleVec;
            float2 res = iResolution / float2(iResolution.y);
            float2 uv = syamjaidtz;
            uv -= (res / float2(2.0));
            float3 color = float3(0.0);
            float repAngle = 6.283185482025146484375 / fast::max(abs(_134.RING_POINTS), 1.0);
            float pointSize = (_134.POINT_SIZE / 2.0) / iResolution.y;
            float camZ;
            if (_134.EVOTYPE == 0)
            {
                camZ = _134.PROGRESS;
            }
            else
            {
                if (_134.EVOTYPE == 1)
                {
                    camZ = _134.PROGRESS - (_134.refScreen.z * 0.5);
                }
                else
                {
                    if (_134.EVOTYPE == 2)
                    {
                        camZ = _134.PROGRESS + (_134.refScreen.z * 0.5);
                    }
                }
            }
            float param_4 = camZ;
            float2 camOffs = TunnelPath(param_4, _134);
            for (int i = 1; i <= int(_134.TUNNEL_LAYERS); i++)
            {
                float pz = 1.0 - (float(i) / fast::max(abs(_134.TUNNEL_LAYERS), 1.0));
                pz -= mod(camZ, 4.0 / fast::max(abs(_134.TUNNEL_LAYERS), 1.0));
                float param_5 = camZ + pz;
                float2 offs = TunnelPath(param_5, _134) - camOffs;
                float param_6 = (pz * 0.800000011920928955078125) + 0.4000000059604644775390625;
                float ringRad = 0.1500000059604644775390625 * (1.0 / sq(param_6));
                if (abs(length(uv + offs) - ringRad) < (pointSize * 1.5))
                {
                    float2 param_7 = uv + offs;
                    float param_8 = repAngle;
                    float2 aruv = AngRep(param_7, param_8);
                    float2 param_9 = aruv - float2(ringRad, 0.0);
                    float param_10 = pointSize;
                    float pdist = sdCircle(param_9, param_10);
                    float3 ptColor = select(float3(1.0), float3(1.0), bool3(mod(float(i / 2), 2.0) == 0.0));
                    float shade = 1.0 - pz;
                    float param_11 = pdist;
                    float3 param_12 = ptColor * shade;
                    float3 param_13 = color;
                    color = MixShape(param_11, param_12, param_13, _134);
                }
            }
            float4 fragColor = float4(color, 1.0);
            float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float4 gradmap = mix(_134.colorbg, _134.colorfg, float4(luminance)) * fragColor.w;
            float4 factor = mix(texColorX, gradmap, float4(1.0));
            float4 resultfinal;
            if (_134.blendMode == 0)
            {
                resultfinal = (factor * _134.hardness) * texColor.w;
            }
            else
            {
                if (_134.blendMode == 1)
                {
                    factor *= _134.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_134.blendMode == 2)
                    {
                        factor *= _134.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_134.alpha));
        }
    }
}

fragment refAM35_e066e5f75d7f0_out refAM35_e066e5f75d7f0(constant ReferenceUniformse066e5f75d7f0& _134 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e066e5f75d7f0_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_134, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _682 = any(isnan(referenceColor));
    bool _689;
    if (!_682)
    {
        _689 = any(isinf(referenceColor));
    }
    else
    {
        _689 = _682;
    }
    if (_689)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _702 = referenceColor;
    float3 _708 = fast::clamp(_702.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _708.x;
    referenceColor.y = _708.y;
    referenceColor.z = _708.z;
    out.finalColor = referenceColor;
    return out;
}

