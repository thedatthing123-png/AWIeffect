// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxpartx.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
// vec4 fragColor;
//position += mouse - 0.5; // use this for mouse panning
// vec3 color;
// color.r = .03*white1 + white*(0.3 + 5.0*angleDist);
// color.b = white*(0.1 + .5*angleToRandZ);
// color.g = 1.5*white;
// fragColor = vec4( color, 0.0);
// normal
// multiply
// screen
// screen
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9dd30289c4d2
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 colorfg;
    float4 colorbg;
    uint autop;
    char _m8_pad[12];
    float EVO;
    char _m9_pad[12];
    float kStarDensity;
    char _m10_pad[12];
    float kMotionBlur;
    char _m11_pad[12];
    float kNumAngles;
    char _m12_pad[12];
    float scale;
    char _m13_pad[8];
    float2 positionn;
    char _m14_pad[8];
    float2 stretch;
    char _m15_pad[8];
    float bright;
    char _m16_pad[12];
    float alpha;
    char _m17_pad[12];
    float angle;
    char _m18_pad[12];
    int blendMode;
};

struct refAM35_e9dd30289c4d2_out
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
float getBeat()
{
    return 1.0;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse9dd30289c4d2& _88, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _88.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param_1);
    float2 iRes = float2(_88.refScreen.x, _88.refScreen.y);
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _88.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _88.refScreen.xy).y) * _88.refScreen.xy) - float2(_88.refLayer.x + (_88.refLayer.z * 0.5), (_88.refScreen.y - _88.refLayer.y) - (_88.refLayer.w * 0.5))) / _88.refLayer.zw;
    syamjaidtz.y *= (_88.refLayer.w / _88.refLayer.z);
    syamjaidtz /= float2(_88.scale);
    float param_2 = (0.0 + _88.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_2);
    syamjaidtz += ((float2(0.0 + _88.positionn.x, 0.0 + _88.positionn.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 scaleVec = float2(_88.scale * _88.stretch.x, _88.scale * _88.stretch.y);
    syamjaidtz /= scaleVec;
    float ff = getBeat();
    float2 resolution = iRes;
    float _232;
    if (_88.autop != 0u)
    {
        _232 = _88.EVO + (_88.refScreen.z * 0.5);
    }
    else
    {
        _232 = _88.EVO;
    }
    float time = _232;
    float2 p = syamjaidtz;
    p.x = (p.x * _88.refScreen.x) / _88.refScreen.y;
    float2 position = p;
    float speed = 5.19999980926513671875 + smoothstep(0.800000011920928955078125, 12.0, ff);
    float A = precise::atan2(position.y, position.x);
    float angle0 = A / 6.283185482025146484375;
    float angle = fract(angle0 + (0.00019999999494757503271102905273438 * time));
    float rad = 0.4000000059604644775390625 * length(position);
    float angleFract = fract(angle * _88.kNumAngles);
    float angleStep = floor(angle * _88.kNumAngles);
    float angleToRandZ = 10.0 * fract((angleStep * fract(angleStep * 0.7534999847412109375)) * 45.09999847412109375);
    float angleSquareDist = fract((angleStep * fract(angleStep * 0.826569974422454833984375)) * 13.72399997711181640625);
    float t = (speed * time) - angleToRandZ;
    float angleDist = angleSquareDist + 0.100000001490116119384765625;
    float adist = (angleDist / rad) * _88.kStarDensity;
    float dist = abs(fract((t * 0.100000001490116119384765625) + adist) - 0.5);
    float white1 = fast::max(0.0, 1.0 - ((dist * 100.0) / ((_88.kMotionBlur * speed) + adist)));
    float white2 = fast::max(0.0, ((0.5 - (0.5 * cos(6.283185482025146484375 * angleFract))) * 1.0) / fast::max(0.60000002384185791015625, (2.0 * adist) * angleDist));
    float white = white1 * white2;
    float4 fragColor = mix(_88.colorbg, _88.colorfg, float4(white));
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_88.blendMode == 0)
    {
        resultfinal = (factor * _88.bright) * texColor.w;
    }
    else
    {
        if (_88.blendMode == 1)
        {
            factor *= _88.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_88.blendMode == 2)
            {
                factor *= _88.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
            else
            {
                if (_88.blendMode == 3)
                {
                    factor *= _88.bright;
                    float4 param_3 = texColor;
                    float4 param_4 = factor;
                    resultfinal = (newLayer(param_3, param_4) * _88.bright) * texColor.w;
                }
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_88.alpha));
}

fragment refAM35_e9dd30289c4d2_out refAM35_e9dd30289c4d2(constant ReferenceUniformse9dd30289c4d2& _88 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9dd30289c4d2_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _88, referenceColor);
    bool _518 = any(isnan(referenceColor));
    bool _525;
    if (!_518)
    {
        _525 = any(isinf(referenceColor));
    }
    else
    {
        _525 = _518;
    }
    if (_525)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _538 = referenceColor;
    float3 _544 = fast::clamp(_538.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _544.x;
    referenceColor.y = _544.y;
    referenceColor.z = _544.z;
    out.finalColor = referenceColor;
    return out;
}

