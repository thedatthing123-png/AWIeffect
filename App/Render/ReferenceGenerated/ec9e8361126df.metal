// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/mosaic.xml
// Original source comments and attribution:
//st.x += tileSize.x / 2.;
//st.y += tileSize.y / 2.;
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

struct ReferenceUniformsec9e8361126df
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float size;
    char _m6_pad[8];
    float2 phase;
};

struct refAM35_ec9e8361126df_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformsec9e8361126df& _29, thread float4& gl_FragCoord, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor, texture2d<float> refBuffer1, sampler refBuffer1Smplr)
{
    float2 tileSize = float2(_29.size) / _29.refLayer.zw;
    float2 adjPhase = float2(-_29.phase.x, _29.phase.y);
    if (as_type<int>(_29.refComposition.z) == 0)
    {
        float2 st = (gl_FragCoord.xy - _29.refLayer.xy) / _29.refLayer.zw;
        float2 texelSize = float2(1.0) / _29.refLayer.zw;
        st -= float2(0.5);
        st.x -= mod(st.x + (adjPhase.x / _29.refLayer.z), tileSize.x);
        st += float2(0.5);
        float blur = (tileSize.x / texelSize.x) / 2.0;
        int nSamples = int(fast::clamp(blur, 1.0099999904632568359375, 100.01000213623046875));
        float2 param = (float4(st, 0.0, 1.0) * _29.refLayerToScreen).xy;
        float4 outColor = texture2DCv(refInput, refInputSmplr, param);
        for (int i = 1; i < nSamples; i++)
        {
            float2 offset = float2(tileSize.x, 0.0) * ((float(i) / float(nSamples - 1)) - 0.5);
            float2 param_1 = (float4(st - offset, 0.0, 1.0) * _29.refLayerToScreen).xy;
            outColor += texture2DCv(refInput, refInputSmplr, param_1);
        }
        referenceColor = outColor / float4(float(nSamples));
    }
    else
    {
        float2 st_1 = (gl_FragCoord.xy - _29.refLayer.xy) / _29.refLayer.zw;
        float2 texelSize_1 = float2(1.0) / _29.refLayer.zw;
        st_1 -= float2(0.5);
        st_1.y -= mod(st_1.y + (adjPhase.y / _29.refLayer.w), tileSize.y);
        st_1 += float2(0.5);
        float blur_1 = tileSize.y / texelSize_1.y;
        int nSamples_1 = int(fast::clamp(blur_1, 1.0099999904632568359375, 100.01000213623046875));
        float2 param_2 = (float4(st_1, 0.0, 1.0) * _29.refLayerToScreen).xy;
        float4 outColor_1 = texture2DCv(refInput, refInputSmplr, param_2);
        for (int i_1 = 1; i_1 < nSamples_1; i_1++)
        {
            float2 offset_1 = float2(0.0, tileSize.y) * ((float(i_1) / float(nSamples_1 - 1)) - 0.5);
            float2 param_3 = (float4(st_1 - offset_1, 0.0, 1.0) * _29.refLayerToScreen).xy;
            outColor_1 += texture2DCv(refBuffer1, refBuffer1Smplr, param_3);
        }
        referenceColor = outColor_1 / float4(float(nSamples_1));
    }
}

fragment refAM35_ec9e8361126df_out refAM35_ec9e8361126df(constant ReferenceUniformsec9e8361126df& _29 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refBuffer1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refBuffer1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec9e8361126df_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_29, gl_FragCoord, refInput, refInputSmplr, referenceColor, refBuffer1, refBuffer1Smplr);
    bool _287 = any(isnan(referenceColor));
    bool _294;
    if (!_287)
    {
        _294 = any(isinf(referenceColor));
    }
    else
    {
        _294 = _287;
    }
    if (_294)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _308 = referenceColor;
    float3 _314 = fast::clamp(_308.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _314.x;
    referenceColor.y = _314.y;
    referenceColor.z = _314.z;
    out.finalColor = referenceColor;
    return out;
}

