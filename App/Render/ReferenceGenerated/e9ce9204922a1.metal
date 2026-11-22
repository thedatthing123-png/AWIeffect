// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxvoronoi3.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
// float iTime = autop? PROGRESS + (acTime*SPEED) : PROGRESS;
// syamjaidtz = acScreenNorm; 
/////////////////////////
// vec4 xbuffer = texture2DCv(buff1.texture, acScreenNorm.st);
// resultfinal = min(factor, texColor) * texColor.a; }
// resultfinal = max(factor, texColor) * texColor.a; }
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse9ce9204922a1
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
    float hardness;
    char _m14_pad[12];
    int blendMode;
    char _m15_pad[12];
    uint GRADMAP;
    float4 color1;
    float4 color2;
};

struct refAM35_e9ce9204922a1_out
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
float2 voronoi_noise_randomVector(thread float2& UV, thread const float2& offset, constant ReferenceUniformse9ce9204922a1& _124)
{
    float2x2 m = float2x2(float2(15.270000457763671875, 47.630001068115234375), float2(99.410003662109375, 89.98000335693359375));
    UV = fract(sin(UV * m) * 46839.3203125);
    float _131;
    if (_124.autop != 0u)
    {
        _131 = _124.PROGRESS + (_124.refScreen.z * _124.SPEED);
    }
    else
    {
        _131 = _124.PROGRESS;
    }
    float iTime = _131;
    return float2((sin((UV.y * offset.x) * cos(iTime / 3.0)) * 0.5) + 0.5, (cos((UV.x * offset.y) * sin(iTime / 20.0)) * 0.5) + 0.5);
}

static inline __attribute__((always_inline))
float max_abs(thread const float2& p)
{
    return fast::max(abs(p.x), abs(p.y));
}

static inline __attribute__((always_inline))
void ChebychevVoronoi(thread const float2& UV, thread const float2& AngleOffset, thread const float2& CellDensity, thread float& Out, thread float& Cells, thread float& Lines, thread float& Points, constant ReferenceUniformse9ce9204922a1& _124)
{
    float2 g = floor(UV * CellDensity);
    float2 f = fract(UV * CellDensity);
    float res = 8.0;
    float md = 8.0;
    float2 mr;
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float2 lattice = float2(float(x), float(y));
            float2 param = lattice + g;
            float2 param_1 = AngleOffset;
            float2 _226 = voronoi_noise_randomVector(param, param_1, _124);
            float2 offset = _226;
            float2 r = (lattice + offset) - f;
            float2 param_2 = r;
            float d = max_abs(param_2);
            if (d < res)
            {
                res = d;
                mr = r;
            }
        }
    }
    res = 8.0;
    for (int y_1 = -1; y_1 <= 1; y_1++)
    {
        for (int x_1 = -1; x_1 <= 1; x_1++)
        {
            float2 lattice_1 = float2(float(x_1), float(y_1));
            float2 param_3 = lattice_1 + g;
            float2 param_4 = AngleOffset;
            float2 _278 = voronoi_noise_randomVector(param_3, param_4, _124);
            float2 offset_1 = _278;
            float2 r_1 = (lattice_1 + offset_1) - f;
            float2 param_5 = r_1;
            float d_1 = max_abs(param_5);
            if (d_1 < res)
            {
                res = d_1;
                Out = res;
                Cells = offset_1.x;
            }
            if (dot(mr - r_1, mr - r_1) > 9.9999997473787516355514526367188e-06)
            {
                md = fast::min(md, dot((mr + r_1) * 0.5, fast::normalize(r_1 - mr)));
            }
        }
    }
    Lines = mix(1.0, 0.0, smoothstep(0.02999999932944774627685546875, 0.0599999986588954925537109375, md));
    Points = 1.0 - smoothstep(0.0, 0.300000011920928955078125, res);
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse9ce9204922a1& _124, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _124.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 image_size = getTexSize(param_1);
    float2 iResolution = float2(_124.refScreen.x, _124.refScreen.y);
    float2 iMouse = float2(0.5);
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _124.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _124.refScreen.xy).y) * _124.refScreen.xy) - float2(_124.refLayer.x + (_124.refLayer.z * 0.5), (_124.refScreen.y - _124.refLayer.y) - (_124.refLayer.w * 0.5))) / _124.refLayer.zw;
    syamjaidtz.y *= (_124.refLayer.w / _124.refLayer.z);
    syamjaidtz /= float2(_124.scale);
    float param_2 = (0.0 + _124.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_2);
    syamjaidtz += ((float2(0.0 + _124.position.x, 0.0 + _124.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 scaleVec = float2(_124.scale * _124.stretch.x, _124.scale * _124.stretch.y);
    syamjaidtz /= scaleVec;
    float2 p = syamjaidtz;
    float2 param_3 = p;
    float2 param_4 = float2(7.0);
    float2 param_5 = float2(5.0);
    float param_6;
    float param_7;
    float param_8;
    float param_9;
    ChebychevVoronoi(param_3, param_4, param_5, param_6, param_7, param_8, param_9, _124);
    float a = param_6;
    float b = param_7;
    float c = param_8;
    float d = param_9;
    float3 col = float3(b);
    float4 fragColor = float4(col, 1.0);
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 gradmap = mix(_124.color1, _124.color2, float4(luminance)) * fragColor.w;
    if (_124.GRADMAP != 0u)
    {
        factor = mix(texColorX, gradmap, float4(1.0));
    }
    float4 resultfinal;
    if (_124.blendMode == 0)
    {
        resultfinal = (factor * _124.hardness) * texColor.w;
    }
    else
    {
        if (_124.blendMode == 1)
        {
            factor *= _124.hardness;
            float4 c_1 = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c_1.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_124.blendMode == 2)
            {
                factor *= _124.hardness;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
            else
            {
                if (_124.blendMode == 3)
                {
                    factor *= _124.hardness;
                    float4 param_10 = texColor;
                    float4 param_11 = factor;
                    resultfinal = (newLayer(param_10, param_11) * _124.hardness) * texColor.w;
                }
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_124.alpha)) * texColor.w;
}

fragment refAM35_e9ce9204922a1_out refAM35_e9ce9204922a1(constant ReferenceUniformse9ce9204922a1& _124 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e9ce9204922a1_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_124, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _658 = any(isnan(referenceColor));
    bool _665;
    if (!_658)
    {
        _665 = any(isinf(referenceColor));
    }
    else
    {
        _665 = _658;
    }
    if (_665)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _678 = referenceColor;
    float3 _684 = fast::clamp(_678.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _684.x;
    referenceColor.y = _684.y;
    referenceColor.z = _684.z;
    out.finalColor = referenceColor;
    return out;
}

