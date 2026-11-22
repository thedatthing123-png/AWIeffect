// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxsglowtunnels.xml
// Original source comments and attribution:
//////////////////////////
// From iq - https://www.shadertoy.com/view/MsS3Wc
// cubic smoothing	
//////////////////////////
// syamjaidtz = acScreenNorm; 
/////////////////////////
// for(int i = 0; i < 64; ++i)
// color = COLORS.rgb;
//color=pow(color,vec3(0.4545));
// vec4 xbuffer = texture2DCv(buff1.texture, acScreenNorm.st);
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

struct ReferenceUniformseeb04e6930133
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    uint autop;
    char _m6_pad[12];
    float PROGRESS;
    char _m7_pad[12];
    float SPEED;
    char _m8_pad[12];
    float scale;
    char _m9_pad[12];
    float angle;
    char _m10_pad[8];
    float2 position;
    char _m11_pad[8];
    float2 stretch;
    char _m12_pad[8];
    float alpha;
    char _m13_pad[12];
    float HRD;
    char _m14_pad[12];
    int blendMode;
    char _m15_pad[12];
    uint GRADMAP;
    float4 color1;
    float4 color2;
};

struct refAM35_eeb04e6930133_out
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
float tunnel(thread float3& p, constant ReferenceUniformseeb04e6930133& _213)
{
    float _220;
    if (_213.autop != 0u)
    {
        _220 = _213.PROGRESS + (_213.refScreen.z * _213.SPEED);
    }
    else
    {
        _220 = _213.PROGRESS;
    }
    p.z += _220;
    float _244 = p.z;
    float3 _248 = p;
    float3 _257 = p;
    float3 _265 = p;
    float2 _267 = _265.xy + ((float2(sin(_244) * 0.5) + (sin(_248.xz * 12.0) * 0.0500000007450580596923828125)) + (sin(_257.zy * 20.0) * 0.02500000037252902984619140625));
    p.x = _267.x;
    p.y = _267.y;
    return 1.0 - length(p.xy);
}

static inline __attribute__((always_inline))
float map(thread const float3& p, constant ReferenceUniformseeb04e6930133& _213)
{
    float3 param = p;
    float _280 = tunnel(param, _213);
    return _280;
}

static inline __attribute__((always_inline))
float3 rgb2hsv(thread const float3& c)
{
    float4 K = float4(0.0, -0.3333333432674407958984375, 0.666666686534881591796875, -1.0);
    float4 p = mix(float4(c.zy, K.wz), float4(c.yz, K.xy), float4(step(c.z, c.y)));
    float4 q = mix(float4(p.xyw, c.x), float4(c.x, p.yzx), float4(step(p.x, c.x)));
    float d = q.x - fast::min(q.w, q.y);
    float e = 1.0000000133514319600180897396058e-10;
    return float3(abs(q.z + ((q.w - q.y) / ((6.0 * d) + e))), d / (q.x + e), q.x);
}

static inline __attribute__((always_inline))
float3 hsv2rgb_smooth(thread const float3& c)
{
    float3 rgb = fast::clamp(abs(mod(float3(c.x * 6.0) + float3(0.0, 4.0, 2.0), float3(6.0)) - float3(3.0)) - float3(1.0), float3(0.0), float3(1.0));
    rgb = (rgb * rgb) * (float3(3.0) - (rgb * 2.0));
    return mix(float3(1.0), rgb, float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformseeb04e6930133& _213, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_213.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _213.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_213.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _213.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_213.refScreen.x, _213.refScreen.y);
            float2 iMouse = float2(0.5);
            float _346;
            if (_213.autop != 0u)
            {
                _346 = _213.PROGRESS + (_213.refScreen.z * _213.SPEED);
            }
            else
            {
                _346 = _213.PROGRESS;
            }
            float iTime = _346;
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _213.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _213.refScreen.xy).y) * _213.refScreen.xy) - float2(_213.refLayer.x + (_213.refLayer.z * 0.5), (_213.refScreen.y - _213.refLayer.y) - (_213.refLayer.w * 0.5))) / _213.refLayer.zw;
            syamjaidtz.y *= (_213.refLayer.w / _213.refLayer.z);
            syamjaidtz /= float2(_213.scale);
            float param_3 = (0.0 + _213.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _213.position.x, 0.0 + _213.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_213.scale * _213.stretch.x, _213.scale * _213.stretch.y);
            syamjaidtz /= scaleVec;
            float2 uv = syamjaidtz;
            float3 cz = float3(0.0, 0.0, 1.0);
            float3 cx = fast::normalize(cross(cz, float3(0.0, 1.0, 0.0)));
            float3 cy = fast::normalize(cross(cx, cz));
            float3 z = ((cx * uv.x) + (cy * uv.y)) + (cz * 0.1500000059604644775390625);
            float3 pos = float3(0.0);
            float d = 0.0;
            float att = 0.0;
            for (int i = 0; i < 32; i++)
            {
                float3 param_4 = pos;
                d = map(param_4, _213);
                if (d < 9.9999997473787516355514526367188e-05)
                {
                    break;
                }
                if (d > 10000.0)
                {
                    break;
                }
                pos += (z * d);
                att += (0.20000000298023223876953125 / (abs(d) + 0.20000000298023223876953125));
            }
            float3 param_5 = float3(0.75, 0.20000000298023223876953125, 0.100000001490116119384765625);
            float3 color = rgb2hsv(param_5);
            color.x = (pos.z * 0.00999999977648258209228515625) + sin((-iTime) * 0.0500000007450580596923828125);
            float3 param_6 = color;
            color = hsv2rgb_smooth(param_6);
            if (d < 10000.0)
            {
                color *= (0.300000011920928955078125 + (att * 0.006000000052154064178466796875));
            }
            color *= (1.0 - length(uv));
            float4 fragColor = float4(color, 1.0);
            float hardness = _213.HRD;
            float4 factor = mix(texColorX, fragColor, float4(1.0));
            float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            float4 gradmap = mix(_213.color1, _213.color2, float4(luminance)) * fragColor.w;
            if (_213.GRADMAP != 0u)
            {
                hardness += 2.0;
                factor = mix(texColorX, gradmap, float4(1.0));
            }
            float4 resultfinal;
            if (_213.blendMode == 0)
            {
                resultfinal = (factor * hardness) * texColor.w;
            }
            else
            {
                if (_213.blendMode == 1)
                {
                    factor *= hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_213.blendMode == 2)
                    {
                        factor *= hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_213.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_eeb04e6930133_out refAM35_eeb04e6930133(constant ReferenceUniformseeb04e6930133& _213 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eeb04e6930133_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_213, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _706 = any(isnan(referenceColor));
    bool _713;
    if (!_706)
    {
        _713 = any(isinf(referenceColor));
    }
    else
    {
        _713 = _706;
    }
    if (_713)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _726 = referenceColor;
    float3 _732 = fast::clamp(_726.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _732.x;
    referenceColor.y = _732.y;
    referenceColor.z = _732.z;
    out.finalColor = referenceColor;
    return out;
}

