// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/glow.xml
// Original source comments and attribution:
//float q = 11.0 - quality;
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
//vec4 offsetOriginal = texture2DCv(inputImg.texture,vec2(acScreenNorm.s + (-sdx)*(px/MULTISAMPLE),acScreenNorm.t + (sdy)*(py/MULTISAMPLE)));
//float nearestMid = max(nearestInside, nearestOutside);
//float qr = ((radius2/MULTISAMPLE)/4.0);
//float hr = ((radius2/MULTISAMPLE)/2.0);
//float nearestSolidInner = (max(0.0,hr - nearestInside) * (1.0-offsetOriginal.a))-max(0.0,nearestOutside-hr);
//vec4 outColor = radius2<0.003 ? vec4(0.0)  : mix(color*alpha,  vec4(0.0), smoothstep((1.0-1.5/radius2)*hardness,1.0,nearestOutside/(radius2/MULTISAMPLE)));
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse48384ac931a8
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float radius;
    char _m6_pad[12];
    float alpha;
    char _m7_pad[12];
    float hardness;
    float4 color;
    int blendMode;
};

struct refAM35_e48384ac931a8_out
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
void referenceMain(constant ReferenceUniformse48384ac931a8& _72, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor, thread float4& gl_FragCoord, texture2d<float> refBuffer1, sampler refBuffer1Smplr, texture2d<float> refReference, sampler refReferenceSmplr)
{
    float2 param = float2(int2(refInput.get_width(), refInput.get_height()));
    float radius2 = (_72.radius * length(getTexSize(param))) / 1448.1546630859375;
    if (radius2 < 0.5)
    {
        float2 param_1 = gl_FragCoord.xy / _72.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param_1);
        return;
    }
    float q = fast::max(powr(radius2, 1.2400000095367431640625) / radius2, radius2 / 40.0);
    float sdx = 0.0;
    float sdy = 0.0;
    int from = -max(1, int(radius2 / q));
    int to = max(1, int(radius2 / q));
    float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 imgSize = getTexSize(param_2);
    float px = 1.0 / imgSize.x;
    float py = 1.0 / imgSize.y;
    if (as_type<int>(_72.refComposition.z) == 0)
    {
        float nearestOutside = 16383.0;
        float nearestInside = 16383.0;
        float _210;
        float _225;
        for (int i = from; i < to; i++)
        {
            float x = float(i) * q;
            float2 param_3 = float2((gl_FragCoord.xy / _72.refScreen.xy).x + ((x - sdx) * (px / 1.0)), (gl_FragCoord.xy / _72.refScreen.xy).y);
            float4 ref_sample = texture2DCv(refInput, refInputSmplr, param_3);
            if (ref_sample.w > 0.0)
            {
                _210 = abs(x);
            }
            else
            {
                _210 = radius2 * 2.0;
            }
            float xdistOut = _210;
            if (ref_sample.w < 0.0030000000260770320892333984375)
            {
                _225 = abs(x);
            }
            else
            {
                _225 = radius2 * 2.0;
            }
            float xdistIn = _225;
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
            float y = float(i_1) * q;
            float2 param_6 = float2((gl_FragCoord.xy / _72.refScreen.xy).x, (gl_FragCoord.xy / _72.refScreen.xy).y + ((y + sdy) * (py / 1.0)));
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
        float pIn = nearestInside_1 / (radius2 / 1.0);
        float pOut = nearestOutside_1 / (radius2 / 1.0);
        float p = (0.5 + pIn) - pOut;
        if (p <= 9.9999997473787516355514526367188e-05)
        {
            discard_fragment();
        }
        float2 param_9 = gl_FragCoord.xy / _72.refScreen.xy;
        float4 original = texture2DCv(refInput, refInputSmplr, param_9);
        float2 param_10 = gl_FragCoord.xy / _72.refScreen.xy;
        float4 compColor = texture2DCv(refReference, refReferenceSmplr, param_10);
        float4 blendColor;
        if (_72.blendMode == 0)
        {
            blendColor = float4(_72.color.xyz, 1.0);
        }
        else
        {
            if (_72.blendMode == 1)
            {
                blendColor = float4(compColor.xyz * _72.color.xyz, 1.0);
            }
            else
            {
                blendColor = float4(float3(1.0) - ((float3(1.0) - compColor.xyz) * (float3(1.0) - _72.color.xyz)), 1.0);
            }
        }
        float4 _425;
        if (radius2 < 0.0030000000260770320892333984375)
        {
            _425 = float4(0.0);
        }
        else
        {
            _425 = mix(blendColor * _72.alpha, float4(0.0), float4(smoothstep((1.0 - (1.5 / radius2)) * _72.hardness, 1.0, 1.0 - p)));
        }
        float4 outColor = _425;
        float4 _453;
        if (_72.blendMode == 0)
        {
            _453 = float4(outColor.xyz, outColor.w * _72.color.w);
        }
        else
        {
            _453 = outColor;
        }
        float4 result = _453;
        result = original + (result * (1.0 - original.w));
        referenceColor = result;
    }
}

fragment refAM35_e48384ac931a8_out refAM35_e48384ac931a8(constant ReferenceUniformse48384ac931a8& _72 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], texture2d<float> refReference [[texture(2)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], sampler refReferenceSmplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    refAM35_e48384ac931a8_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_72, refInput, refInputSmplr, referenceColor, gl_FragCoord, refBuffer1, refBuffer1Smplr, refReference, refReferenceSmplr);
    bool _482 = any(isnan(referenceColor));
    bool _489;
    if (!_482)
    {
        _489 = any(isinf(referenceColor));
    }
    else
    {
        _489 = _482;
    }
    if (_489)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _502 = referenceColor;
    float3 _508 = fast::clamp(_502.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _508.x;
    referenceColor.y = _508.y;
    referenceColor.z = _508.z;
    out.finalColor = referenceColor;
    return out;
}

