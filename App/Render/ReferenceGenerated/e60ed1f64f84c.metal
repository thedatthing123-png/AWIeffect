// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/glow-inner.xml
// Original source comments and attribution:
//float q = 11.0 - quality;
// Size of a pixel
// Calculate distance on X-axis and encode in a texture
//float pIn = nearestInside/(radius2/MULTISAMPLE);
//float pOut = nearestOutside/(radius2/MULTISAMPLE);
//float p = smoothstep(0., 1., clamp(1. - pIn,0., 1.))/2.0;
////if( p <= 0.0001 )
////    discard;
//
//vec4 original = texture2DCvCv(inputImg.texture,acScreenNorm.st);
//vec4 compColor = original; // texture2DCvCv(comp.texture,acScreenNorm.st);
////vec4 offsetOriginal = texture2DCvCv(inputImg.texture,vec2(acScreenNorm.s + (-sdx)*(px/MULTISAMPLE),acScreenNorm.t + (sdy)*(py/MULTISAMPLE)));
//
////float nearestMid = max(nearestInside, nearestOutside);
////float qr = ((radius2/MULTISAMPLE)/4.0);
////float hr = ((radius2/MULTISAMPLE)/2.0);
////float nearestSolidInner = (max(0.0,hr - nearestInside) * (1.0-offsetOriginal.a))-max(0.0,nearestOutside-hr);
//
////vec4 outColor = radius2<0.003 ? vec4(0.0)  : mix(color*alpha,  vec4(0.0), smoothstep((1.0-1.5/radius2)*hardness,1.0,nearestOutside/(radius2/MULTISAMPLE)));
//
//vec4 blendColor;
//
//if( blendMode==0 ) {
//    blendColor = color;
//} else if( blendMode==1 ) {
//    blendColor = vec4( compColor.rgb * color.rgb, 1.0 );
//} else {
//    blendColor = vec4( 1.-( 1.-compColor.rgb) * (1.-color.rgb) , 1.0 );
//}
//
//vec4 outColor = radius2<0.003 ? vec4(0.0)  : mix(blendColor*alpha,  vec4(0.0), smoothstep((1.0-1.5/radius2)*hardness,1.0,1.0-p));
//
//vec4 result = outColor;
//result = original + result*original.a;
//gl_FragColor = result;
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse60ed1f64f84c
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

struct refAM35_e60ed1f64f84c_out
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
void referenceMain(constant ReferenceUniformse60ed1f64f84c& _71, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    if (_71.radius < 0.5)
    {
        float2 param = gl_FragCoord.xy / _71.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
        return;
    }
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float radius2 = (_71.radius * length(getTexSize(param_1))) / 1448.1546630859375;
    float q = fast::max(powr(radius2, 1.2400000095367431640625) / radius2, radius2 / 40.0);
    float sdx = 0.0;
    float sdy = 0.0;
    int from = -max(1, int(radius2 / q));
    int to = max(1, int(radius2 / q));
    float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 imgSize = getTexSize(param_2);
    float px = 1.0 / imgSize.x;
    float py = 1.0 / imgSize.y;
    if (as_type<int>(_71.refComposition.z) == 0)
    {
        float nearestOutside = 16383.0;
        float nearestInside = 16383.0;
        float _211;
        float _226;
        for (int i = from; i < to; i++)
        {
            float x = float(i) * q;
            float2 param_3 = float2((gl_FragCoord.xy / _71.refScreen.xy).x + ((x - sdx) * (px / 1.0)), (gl_FragCoord.xy / _71.refScreen.xy).y);
            float4 ref_sample = texture2DCv(refInput, refInputSmplr, param_3);
            if (ref_sample.w > 0.0)
            {
                _211 = abs(x);
            }
            else
            {
                _211 = radius2 * 2.0;
            }
            float xdistOut = _211;
            if (ref_sample.w < 0.0030000000260770320892333984375)
            {
                _226 = abs(x);
            }
            else
            {
                _226 = radius2 * 2.0;
            }
            float xdistIn = _226;
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
            float2 param_6 = float2((gl_FragCoord.xy / _71.refScreen.xy).x, (gl_FragCoord.xy / _71.refScreen.xy).y + ((y + sdy) * (py / 1.0)));
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
        float p = smoothstep(radius2 + 0.5099999904632568359375, (_71.hardness * radius2) - 0.5099999904632568359375, nearestInside_1);
        float2 param_9 = gl_FragCoord.xy / _71.refScreen.xy;
        float4 texColor = texture2DCv(refInput, refInputSmplr, param_9);
        float4 result;
        if (_71.blendMode == 1)
        {
            result = float4((texColor.xyz / float3(texColor.w)) * _71.color.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_71.blendMode == 2)
            {
                result = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - _71.color.xyz)), 1.0) * texColor.w;
            }
            else
            {
                result = float4(_71.color.xyz, 1.0) * texColor.w;
            }
        }
        referenceColor = mix(texColor, result, float4(_71.alpha * p));
    }
}

fragment refAM35_e60ed1f64f84c_out refAM35_e60ed1f64f84c(constant ReferenceUniformse60ed1f64f84c& _71 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_e60ed1f64f84c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_71, referenceColor, refInput, refInputSmplr, gl_FragCoord, refBuffer1, refBuffer1Smplr);
    bool _435 = any(isnan(referenceColor));
    bool _442;
    if (!_435)
    {
        _442 = any(isinf(referenceColor));
    }
    else
    {
        _442 = _435;
    }
    if (_442)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _455 = referenceColor;
    float3 _461 = fast::clamp(_455.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _461.x;
    referenceColor.y = _461.y;
    referenceColor.z = _461.z;
    out.finalColor = referenceColor;
    return out;
}

