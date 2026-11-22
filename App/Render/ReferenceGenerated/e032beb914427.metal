// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/1vhs.xml
// Original source comments and attribution:

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

struct ReferenceUniformse032beb914427
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float lumaShrink;
    char _m6_pad[12];
    float chromaShrink;
    char _m7_pad[12];
    float unsharpAmount;
    char _m8_pad[12];
    float unsharpRadius;
    char _m9_pad[12];
    float unsharpThreshold;
    char _m10_pad[12];
    float blackLevel;
    char _m11_pad[12];
    float whiteLevel;
    char _m12_pad[12];
    float saturation;
    float4 shadowTint;
    float sourceFps;
    char _m15_pad[12];
    float lineHeight;
    char _m16_pad[12];
    float noiseGrain;
    char _m17_pad[12];
    float noiseBlend;
    char _m18_pad[12];
    float trackingSpeed;
    char _m19_pad[12];
    float trackingOffset;
    char _m20_pad[12];
    float trackingJitter;
    char _m21_pad[12];
    float waveFreq;
    char _m22_pad[12];
    float waveOffset;
    char _m23_pad[12];
    float bottomWarpH;
    char _m24_pad[12];
    float bottomWarpOff;
    char _m25_pad[12];
    float bottomWarpJit;
    char _m26_pad[12];
    float noiseLineThick;
    char _m27_pad[12];
    float noiseLineOpac;
    char _m28_pad[12];
    uint showOriginal;
};

struct refAM35_e032beb914427_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float4 ref_sample(thread const float2& uv, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 param = uv;
    return texture2DCv(refInput, refInputSmplr, param);
}

static inline __attribute__((always_inline))
float gold(thread const float2& xy, thread const float& seed)
{
    return fract(sin(dot(xy * seed, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 trackingUV(thread const float& speed, thread const float& offset, thread const float& jitter, thread const float2& fragCoord, constant ReferenceUniformse032beb914427& _378)
{
    float t = 1.0 - (mod(_378.refScreen.z, speed) / speed);
    float start = mod(t * _378.refScreen.y, _378.refScreen.y);
    float2 param = float2(5000.0);
    float param_1 = 10.0 + fract(_378.refScreen.z);
    float j = gold(param, param_1) * jitter;
    start += j;
    float2 uv;
    if (fragCoord.y > start)
    {
        uv = (fragCoord + float2(offset, 0.0)) / _378.refScreen.xy;
    }
    else
    {
        uv = fragCoord / _378.refScreen.xy;
    }
    return uv;
}

static inline __attribute__((always_inline))
float2 waveUV(thread const float& freq, thread const float& offset, thread const float2& fragCoord, thread const float2& uv, constant ReferenceUniformse032beb914427& _378)
{
    float phase = floor(fragCoord.y / (_378.refScreen.y / freq));
    float2 param = float2(1.0 + phase, phase);
    float param_1 = 10.0;
    float onm = gold(param, param_1);
    float off = sin((((uv.y + fract(_378.refScreen.z * 0.0500000007450580596923828125)) * 3.1415927410125732421875) * 2.0) * freq) * ((offset * onm) / _378.refScreen.x);
    return uv + float2(off, 0.0);
}

static inline __attribute__((always_inline))
float4 shrink(thread const float2& fragCoord, thread const float& shrinkRatio, texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse032beb914427& _378)
{
    float scale = 1.0 / _378.refScreen.x;
    float numBands = _378.refScreen.x * shrinkRatio;
    float bandWidth = _378.refScreen.x / numBands;
    float t = mod(fragCoord.x, bandWidth) / bandWidth;
    float2 uv = fragCoord / _378.refScreen.xy;
    float2 param = uv;
    float4 a = ref_sample(param, refInput, refInputSmplr);
    uv.x += (bandWidth * scale);
    float2 param_1 = uv;
    float4 b = ref_sample(param_1, refInput, refInputSmplr);
    return mix(a, b, float4(t));
}

static inline __attribute__((always_inline))
float lum4(thread const float4& c)
{
    return dot(c.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float lum(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float3 clipColor(thread float3& c)
{
    float3 param = c;
    float l = lum(param);
    float n = fast::min(c.x, fast::min(c.y, c.z));
    float x = fast::max(c.x, fast::max(c.y, c.z));
    if (n < 0.0)
    {
        c.x = l + (((c.x - l) * l) / (l - n));
        c.y = l + (((c.y - l) * l) / (l - n));
        c.z = l + (((c.z - l) * l) / (l - n));
    }
    if (x > 1.0)
    {
        c.x = l + (((c.x - l) * (1.0 - l)) / (x - l));
        c.y = l + (((c.y - l) * (1.0 - l)) / (x - l));
        c.z = l + (((c.z - l) * (1.0 - l)) / (x - l));
    }
    return c;
}

static inline __attribute__((always_inline))
float3 setLum(thread float3& c, thread const float& l)
{
    float3 param = c;
    float d = l - lum(param);
    c += float3(d);
    float3 param_1 = c;
    float3 _328 = clipColor(param_1);
    return _328;
}

static inline __attribute__((always_inline))
float4 blendLum(thread const float4& base, thread const float4& blend)
{
    float4 param = blend;
    float3 param_1 = base.xyz;
    float param_2 = lum4(param);
    float3 _358 = setLum(param_1, param_2);
    float3 c = _358;
    return float4(c, blend.w);
}

static inline __attribute__((always_inline))
float4 blendColor(thread const float4& base, thread const float4& blend)
{
    float4 param = base;
    float3 param_1 = blend.xyz;
    float param_2 = lum4(param);
    float3 _339 = setLum(param_1, param_2);
    float3 c = _339;
    return float4(c, blend.w);
}

static inline __attribute__((always_inline))
float4 gaussianBlur(thread const float2& uv, thread const float& radius, texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse032beb914427& _378)
{
    float2 s = float2(1.0) / _378.refScreen.xy;
    float r = fast::max(radius, 0.5);
    float4 c = float4(0.0);
    float wsum = 0.0;
    for (int j = -4; j <= 4; j++)
    {
        for (int i = -4; i <= 4; i++)
        {
            float dx = float(i);
            float dy = float(j);
            float w = exp((-((dx * dx) + (dy * dy))) / ((2.0 * r) * r));
            float2 param = uv + float2(dx * s.x, dy * s.y);
            c += (ref_sample(param, refInput, refInputSmplr) * w);
            wsum += w;
        }
    }
    return c / float4(wsum);
}

static inline __attribute__((always_inline))
float soft(thread const float& b, thread const float& l)
{
    float _140;
    if (l < 0.5)
    {
        _140 = ((2.0 * b) * l) + ((b * b) * (1.0 - (2.0 * l)));
    }
    else
    {
        _140 = (sqrt(b) * ((2.0 * l) - 1.0)) + ((2.0 * b) * (1.0 - l));
    }
    return _140;
}

static inline __attribute__((always_inline))
float4 soft4(thread const float4& base, thread const float4& blend)
{
    float param = base.x;
    float param_1 = blend.x;
    float param_2 = base.y;
    float param_3 = blend.y;
    float param_4 = base.z;
    float param_5 = blend.z;
    return float4(soft(param, param_1), soft(param_2, param_3), soft(param_4, param_5), 1.0);
}

static inline __attribute__((always_inline))
float4 warpBottom(thread const float& height, thread const float& offset, thread const float& jitter, thread const float2& uv, texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse032beb914427& _378)
{
    float h = height / _378.refScreen.y;
    if (uv.y > h)
    {
        float2 param = uv;
        return ref_sample(param, refInput, refInputSmplr);
    }
    float t = uv.y / h;
    float off = t * (offset / _378.refScreen.x);
    float2 param_1 = float2(500.0);
    float param_2 = fract(_378.refScreen.z);
    float j = (gold(param_1, param_2) * jitter) / _378.refScreen.x;
    float2 u = float2((uv.x - off) - j, uv.y);
    float2 param_3 = u;
    float4 px = ref_sample(param_3, refInput, refInputSmplr);
    return px * t;
}

static inline __attribute__((always_inline))
float4 whiteNoise(thread const float& thick, thread const float& opac, thread const float4& px, thread const float2& fragCoord, constant ReferenceUniformse032beb914427& _378)
{
    float2 param = float2(600.0, 500.0);
    float param_1 = fract(_378.refScreen.z) * 10.0;
    if (gold(param, param_1) > 0.9700000286102294921875)
    {
        float2 param_2 = float2(800.0, 50.0);
        float param_3 = fract(_378.refScreen.z);
        float start = floor(gold(param_2, param_3) * _378.refScreen.y);
        float endv = floor(start + thick);
        bool _711 = floor(fragCoord.y) >= start;
        bool _719;
        if (_711)
        {
            _719 = floor(fragCoord.y) < endv;
        }
        else
        {
            _719 = _711;
        }
        if (_719)
        {
            float2 param_4 = float2(850.0, 50.0);
            float param_5 = fract(_378.refScreen.z);
            float freq = (gold(param_4, param_5) * 3.0) + 1.0;
            float2 param_6 = float2(900.0, 51.0);
            float param_7 = fract(_378.refScreen.z);
            float off = gold(param_6, param_7);
            float x = (floor(fragCoord.x) / floor(_378.refScreen.x)) + off;
            float w = powr(cos((3.1415927410125732421875 * fract(x * freq)) / 2.0), 10.0) * opac;
            float2 param_8 = float2(floor(fragCoord.x / 3.0), 800.0);
            float param_9 = fract(_378.refScreen.z);
            float grit = gold(param_8, param_9);
            w = fast::max(w - (grit * 0.300000011920928955078125), 0.0);
            return px + float4(w);
        }
    }
    return px;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, constant ReferenceUniformse032beb914427& _378, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    if (_378.showOriginal != 0u)
    {
        float2 param = gl_FragCoord.xy / _378.refScreen.xy;
        float4 o = ref_sample(param, refInput, refInputSmplr);
        referenceColor = o;
        return;
    }
    float2 fragCoord = (gl_FragCoord.xy / _378.refScreen.xy) * _378.refScreen.xy;
    float param_1 = _378.trackingSpeed;
    float param_2 = _378.trackingOffset;
    float param_3 = _378.trackingJitter;
    float2 param_4 = fragCoord;
    float2 uv = trackingUV(param_1, param_2, param_3, param_4, _378);
    float param_5 = _378.waveFreq;
    float param_6 = _378.waveOffset;
    float2 param_7 = fragCoord;
    float2 param_8 = uv;
    uv = waveUV(param_5, param_6, param_7, param_8, _378);
    float2 param_9 = fragCoord;
    float param_10 = _378.lumaShrink;
    float4 luma = shrink(param_9, param_10, refInput, refInputSmplr, _378);
    float4 param_11 = float4(0.5, 0.5, 0.5, 1.0);
    float4 param_12 = luma;
    luma = blendLum(param_11, param_12);
    float2 param_13 = fragCoord;
    float param_14 = _378.chromaShrink;
    float4 chroma = shrink(param_13, param_14, refInput, refInputSmplr, _378);
    float4 param_15 = luma;
    float4 param_16 = chroma;
    chroma = blendColor(param_15, param_16);
    float4 pre = chroma;
    float2 param_17 = uv;
    float param_18 = _378.unsharpRadius;
    float4 blur = gaussianBlur(param_17, param_18, refInput, refInputSmplr, _378);
    float4 param_19 = pre;
    float4 param_20 = blur;
    float ld = abs(lum4(param_19) - lum4(param_20));
    float4 pixel = pre;
    if (ld >= _378.unsharpThreshold)
    {
        pixel = pre + ((pre - blur) * _378.unsharpAmount);
    }
    pixel = mix(pixel, float4(1.0), float4(_378.blackLevel));
    pixel = mix(pixel, float4(0.0, 0.0, 0.0, 1.0), float4(1.0 - _378.whiteLevel));
    float3 inten = float3(dot(pixel.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)));
    pixel = float4(mix(inten, pixel.xyz, float3(_378.saturation)), 1.0);
    float3 st = _378.shadowTint.xyz;
    float ref_powr = 1.5;
    if (st.x > 0.0)
    {
        pixel.x = mix(pixel.x, 1.0 - powr(abs(pixel.x - 1.0), ref_powr), st.x);
    }
    if (st.y > 0.0)
    {
        pixel.y = mix(pixel.y, 1.0 - powr(abs(pixel.y - 1.0), ref_powr), st.y);
    }
    if (st.z > 0.0)
    {
        pixel.z = mix(pixel.z, 1.0 - powr(abs(pixel.z - 1.0), ref_powr), st.z);
    }
    float fps = _378.sourceFps;
    bool updateOdd = mod(floor(fract(_378.refScreen.z) * fps), 2.0) < 1.0;
    bool oddLine = mod(floor(fragCoord.y), 2.0 * _378.lineHeight) >= _378.lineHeight;
    float4 noisePx = pixel;
    bool _1039 = oddLine && updateOdd;
    bool _1048;
    if (!_1039)
    {
        _1048 = (!oddLine) && (!updateOdd);
    }
    else
    {
        _1048 = _1039;
    }
    if (_1048)
    {
        noisePx = pixel;
    }
    else
    {
        noisePx = pixel;
    }
    float grainSize = fast::max(1.0, _378.noiseGrain);
    float _1062;
    if (fps > 0.0)
    {
        _1062 = floor(fract(_378.refScreen.z) * fps) / fps;
    }
    else
    {
        _1062 = _378.refScreen.z;
    }
    float seed = _1062;
    float2 uvNoise = fragCoord / _378.refScreen.xy;
    if (grainSize > 1.0)
    {
        uvNoise.x = floor(fragCoord.x / grainSize) / _378.refScreen.x;
        uvNoise.y = floor(fragCoord.y / grainSize) / _378.refScreen.y;
    }
    float2 param_21 = uvNoise * (seed + 1.0);
    float param_22 = 1.0;
    float r = gold(param_21, param_22);
    float g = r;
    float b = r;
    float4 grain = float4(r, g, b, 1.0);
    float4 param_23 = noisePx;
    float4 param_24 = grain;
    noisePx = (soft4(param_23, param_24) * _378.noiseBlend) + (noisePx * (1.0 - _378.noiseBlend));
    float param_25 = _378.bottomWarpH;
    float param_26 = _378.bottomWarpOff;
    float param_27 = _378.bottomWarpJit;
    float2 param_28 = uv;
    float4 warped = warpBottom(param_25, param_26, param_27, param_28, refInput, refInputSmplr, _378);
    float4 outPx = noisePx;
    float param_29 = _378.noiseLineThick;
    float param_30 = _378.noiseLineOpac;
    float4 param_31 = outPx;
    float2 param_32 = fragCoord;
    outPx = whiteNoise(param_29, param_30, param_31, param_32, _378);
    float vign = powr(((uv.x * (1.0 - uv.x)) * uv.y) * (1.0 - uv.y), 0.25) * 2.2000000476837158203125;
    outPx *= vign;
    referenceColor = outPx;
}

fragment refAM35_e032beb914427_out refAM35_e032beb914427(constant ReferenceUniformse032beb914427& _378 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e032beb914427_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, _378, gl_FragCoord, referenceColor);
    bool _1194 = any(isnan(referenceColor));
    bool _1201;
    if (!_1194)
    {
        _1201 = any(isinf(referenceColor));
    }
    else
    {
        _1201 = _1194;
    }
    if (_1201)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1214 = referenceColor;
    float3 _1220 = fast::clamp(_1214.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1220.x;
    referenceColor.y = _1220.y;
    referenceColor.z = _1220.z;
    out.finalColor = referenceColor;
    return out;
}

