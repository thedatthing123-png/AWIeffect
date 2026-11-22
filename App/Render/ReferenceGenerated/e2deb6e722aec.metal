// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/contour.xml
// Original source comments and attribution:
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
// Final pass
//float ow = offset + width;
//float outer = smoothstep(1.0-1.5/ow,1.0,nearestOutside/(ow/MULTISAMPLE));
//float inner = smoothstep(1.0-1.5/offset,1.0,nearestOutside/(offset/MULTISAMPLE));
//float p = (1.-outer)-(1.-inner);
//mask = smoothstep(0.,1.,p) * smoothstep(1., 1.-aa, p); // Fade inside
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

struct ReferenceUniformse2deb6e722aec
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float4 color;
    float offset;
    char _m7_pad[12];
    float width;
    char _m8_pad[12];
    float alpha;
    char _m9_pad[12];
    float fill;
    char _m10_pad[12];
    float count;
    char _m11_pad[12];
    float phase;
    char _m12_pad[12];
    uint fade;
};

struct refAM35_e2deb6e722aec_out
{
    float4 finalColor [[color(0)]];
};

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
float2 encodeFloat(thread const float& v)
{
    float2 enc = fract(float2(1.0, 255.0) * v);
    enc.x -= (enc.y / 255.0);
    return enc;
}

static inline __attribute__((always_inline))
float decodeFloat(thread const float2& v)
{
    return dot(v, float2(1.0, 0.0039215688593685626983642578125));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse2deb6e722aec& _71, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float offset2 = (_71.offset * length(getTexSize(param))) / 1448.1546630859375;
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float width2 = (_71.width * length(getTexSize(param_1))) / 1448.1546630859375;
    float radius = (offset2 + width2) * 1.0;
    int from = -max(1, int(radius));
    int to = max(1, int(radius));
    float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 imgSize = getTexSize(param_2);
    float px = 1.0 / imgSize.x;
    float py = 1.0 / imgSize.y;
    if (as_type<int>(_71.refComposition.z) == 0)
    {
        float nearestOutside = 16383.0;
        float nearestInside = 16383.0;
        float _192;
        float _207;
        for (int i = from; i < to; i++)
        {
            float x = float(i);
            float2 param_3 = float2((gl_FragCoord.xy / _71.refScreen.xy).x + (x * (px / 1.0)), (gl_FragCoord.xy / _71.refScreen.xy).y);
            float4 ref_sample = texture2DCv(refInput, refInputSmplr, param_3);
            if (ref_sample.w > 0.0)
            {
                _192 = abs(x);
            }
            else
            {
                _192 = radius * 2.0;
            }
            float xdistOut = _192;
            if (ref_sample.w < 0.0030000000260770320892333984375)
            {
                _207 = abs(x);
            }
            else
            {
                _207 = radius * 2.0;
            }
            float xdistIn = _207;
            nearestOutside = fast::min(nearestOutside, xdistOut);
            nearestInside = fast::min(nearestInside, xdistIn);
        }
        float param_4 = nearestOutside / 16383.0;
        float param_5 = nearestInside / 16383.0;
        referenceColor = float4(encodeFloat(param_4), encodeFloat(param_5));
    }
    else
    {
        float nearestOutside_1 = 16383.0;
        float nearestInside_1 = 16383.0;
        for (int i_1 = from; i_1 < to; i_1++)
        {
            float y = float(i_1);
            float2 param_6 = float2((gl_FragCoord.xy / _71.refScreen.xy).x, (gl_FragCoord.xy / _71.refScreen.xy).y + (y * (py / 1.0)));
            float4 ref_sample_1 = texture2DCv(refBuffer1, refBuffer1Smplr, param_6);
            float2 param_7 = ref_sample_1.xy;
            float xdistOut_1 = decodeFloat(param_7) * 16383.0;
            float2 param_8 = ref_sample_1.zw;
            float xdistIn_1 = decodeFloat(param_8) * 16383.0;
            float ydist = abs(y);
            float distOut = length(float2(xdistOut_1, ydist));
            float distIn = length(float2(xdistIn_1, ydist));
            nearestInside_1 = fast::min(nearestInside_1, distIn);
            nearestOutside_1 = fast::min(nearestOutside_1, distOut);
        }
        float nearestMid = fast::max(nearestInside_1, nearestOutside_1);
        float2 param_9 = gl_FragCoord.xy / _71.refScreen.xy;
        float4 original = texture2DCv(refInput, refInputSmplr, param_9);
        float aa = (1.0 / width2) / 2.0;
        float p = fast::clamp((nearestOutside_1 - offset2) / width2, 0.0, 1.0);
        float bands = (_71.count * 2.0) - 1.0;
        float mask;
        if (_71.fade != 0u)
        {
            mask = smoothstep(1.0, 0.0, p) * smoothstep(0.0, aa, p);
        }
        else
        {
            mask = smoothstep(0.0, aa, p) * smoothstep(1.0, 1.0 - aa, p);
        }
        p = smoothstep(1.0 + aa, 1.0 - aa, mod(mod(p + _71.phase, 1.0 + (1.0 / (_71.count * 2.0))) * bands, 2.0));
        p *= mask;
        float4 c = ((_71.color * _71.alpha) * p) * (1.0 - original.w);
        original *= _71.fill;
        referenceColor = (original * (1.0 - c.w)) + c;
    }
}

fragment refAM35_e2deb6e722aec_out refAM35_e2deb6e722aec(constant ReferenceUniformse2deb6e722aec& _71 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e2deb6e722aec_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_71, refInput, refInputSmplr, gl_FragCoord, referenceColor, refBuffer1, refBuffer1Smplr);
    bool _418 = any(isnan(referenceColor));
    bool _425;
    if (!_418)
    {
        _425 = any(isinf(referenceColor));
    }
    else
    {
        _425 = _418;
    }
    if (_425)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _439 = referenceColor;
    float3 _445 = fast::clamp(_439.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _445.x;
    referenceColor.y = _445.y;
    referenceColor.z = _445.z;
    out.finalColor = referenceColor;
    return out;
}

