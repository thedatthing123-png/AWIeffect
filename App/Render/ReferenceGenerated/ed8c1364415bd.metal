// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxmoney.xml
// Original source comments and attribution:
/////////////////////////
/////////////////////////
/////////////////////////
// vec2 xy = fragCoord.xy / iResolution.yy;
// float amplitud = 0.03;
// float frecuencia = 10.0;
// x: seno del angulo, y: coseno del angulo, z: factor de suavizado
// -45
// 0
// 0
// 90
// 90
// 0
// vec4 color = texture2DCv(inputImg.texture, vec2(fragCoord.x / acScreenSize.x, xy.y));
// RotaciÃ³n del patrÃ³n
// Suavizado
// normal
// resultfinal = (newLayer(texColor, factor) * bright) * texColor.a;
// multiply
// screen
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wmissing-braces"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

template<typename T, size_t Num>
struct spvUnsafeArray
{
    T elements[Num ? Num : 1];
    
    thread T& operator [] (size_t pos) thread
    {
        return elements[pos];
    }
    constexpr const thread T& operator [] (size_t pos) const thread
    {
        return elements[pos];
    }
    
    device T& operator [] (size_t pos) device
    {
        return elements[pos];
    }
    constexpr const device T& operator [] (size_t pos) const device
    {
        return elements[pos];
    }
    
    constexpr const constant T& operator [] (size_t pos) const constant
    {
        return elements[pos];
    }
    
    threadgroup T& operator [] (size_t pos) threadgroup
    {
        return elements[pos];
    }
    constexpr const threadgroup T& operator [] (size_t pos) const threadgroup
    {
        return elements[pos];
    }
};

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

struct ReferenceUniformsed8c1364415bd
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float amplitud;
    char _m6_pad[12];
    float frecuencia;
    char _m7_pad[12];
    float xnxx;
    char _m8_pad[12];
    float nxnn;
    char _m9_pad[12];
    float bright;
    char _m10_pad[12];
    float alpha;
    char _m11_pad[12];
    int blendMode;
};

struct refAM35_ed8c1364415bd_out
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
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsed8c1364415bd& _43, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _43.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 param_1 = _43.refScreen.xy;
    float2 image_size = getTexSize(param_1);
    float2 iRes = float2(_43.refScreen.x, _43.refScreen.y);
    float maxF = fast::max(_43.refScreen.x, _43.refScreen.y);
    float2 texelSize = float2(1.0) / float2(maxF);
    float2 syamjaidtz = gl_FragCoord.xy / _43.refScreen.xy;
    float2 xy = syamjaidtz;
    float gris = 1.0;
    float divisor = _43.xnxx / _43.refScreen.y;
    float grosorInicial = divisor * _43.nxnn;
    spvUnsafeArray<float3, 6> datosPatron;
    datosPatron[0] = float3(-0.707099974155426025390625, 0.707099974155426025390625, 3.0);
    datosPatron[1] = float3(0.0, 1.0, 0.60000002384185791015625);
    datosPatron[2] = float3(0.0, 1.0, 0.5);
    datosPatron[3] = float3(1.0, 0.0, 0.4000000059604644775390625);
    datosPatron[4] = float3(1.0, 0.0, 0.300000011920928955078125);
    datosPatron[5] = float3(0.0, 1.0, 0.20000000298023223876953125);
    float2 param_2 = xy;
    float4 color = texture2DCv(refInput, refInputSmplr, param_2);
    float4 fragColor = color;
    for (int i = 0; i < 6; i++)
    {
        float coseno = datosPatron[i].x;
        float seno = datosPatron[i].y;
        float2 punto = float2((xy.x * coseno) - (xy.y * seno), (xy.x * seno) + (xy.y * coseno));
        float grosor = grosorInicial * float(i + 1);
        float dist = mod((punto.y + (grosor * 0.5)) - (sin(punto.x * _43.frecuencia) * _43.amplitud), divisor);
        float brillo = ((0.300000011920928955078125 * color.x) + (0.4000000059604644775390625 * color.y)) + (0.300000011920928955078125 * color.z);
        bool _226 = dist < grosor;
        bool _237;
        if (_226)
        {
            _237 = brillo < (0.75 - (0.119999997317790985107421875 * float(i)));
        }
        else
        {
            _237 = _226;
        }
        if (_237)
        {
            float k = datosPatron[i].z;
            float x = (grosor - dist) / grosor;
            float fx = abs((x - 0.5) / k) - ((0.5 - k) / k);
            gris = fast::min(fx, gris);
        }
    }
    fragColor = float4(gris, gris, gris, 1.0);
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_43.blendMode == 0)
    {
        resultfinal = (factor * _43.bright) * texColor.w;
    }
    else
    {
        if (_43.blendMode == 1)
        {
            factor *= _43.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_43.blendMode == 2)
            {
                factor *= _43.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = mix(texColor, resultfinal, float4(_43.alpha));
}

fragment refAM35_ed8c1364415bd_out refAM35_ed8c1364415bd(constant ReferenceUniformsed8c1364415bd& _43 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed8c1364415bd_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _43, referenceColor);
    bool _369 = any(isnan(referenceColor));
    bool _376;
    if (!_369)
    {
        _376 = any(isinf(referenceColor));
    }
    else
    {
        _376 = _369;
    }
    if (_376)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    out.finalColor = referenceColor;
    return out;
}

