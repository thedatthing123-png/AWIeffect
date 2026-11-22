// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/halftone_dots2.xml
// Original source comments and attribution:
// Halftone Light Dots - built on Halftone Dots reference schema
// Animated light influences dot size per grid cell (ported from provided Shadertoy)
// Simple 3x3 box smooth of luminance controlled by smoothSource (copied from reference)
// Dot screen pattern from reference
// mapping from reference
// Build a rotated, AR-aware grid space similar to Shadertoy for cell addressing
// pixel space, rotated
// Convert to a normalized grid space for cell operations
// normalize roughly by height for AR stability
// Static light at center (avoid time dependency for stability)
// Distance from cell center to light position in grid space
// Shadertoy falloff constants
// Compare base distance to ndotl using a small edge width derived from sharpness
// Optional lighten offset
// Mode swap
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL radians() function
template<typename T>
inline T radians(T d)
{
    return d * T(0.01745329251);
}

struct ReferenceUniformse24809c908d0e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    int dotsMode;
    char _m6_pad[12];
    float dotsFrequency;
    char _m7_pad[12];
    float dotsAngle;
    char _m8_pad[12];
    float dotsRelWidth;
    char _m9_pad[12];
    float dotsSharpness;
    char _m10_pad[12];
    float dotsLighten;
    char _m11_pad[12];
    float smoothSource;
    float4 color1;
    float4 color0;
    float shiftX;
    char _m15_pad[12];
    float shiftY;
    char _m16_pad[12];
    float alpha;
};

struct refAM35_e24809c908d0e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float greyScale(thread const float3& c)
{
    return dot(c, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
}

static inline __attribute__((always_inline))
float2 getTexSize(thread const float2& size)
{
    return size;
}

static inline __attribute__((always_inline))
float smoothLum(thread const float2& uv, constant ReferenceUniformse24809c908d0e& _78, texture2d<float> refInput, sampler refInputSmplr)
{
    if (_78.smoothSource <= 0.0)
    {
        float2 param = uv;
        float3 param_1 = texture2DCv(refInput, refInputSmplr, param).xyz;
        return greyScale(param_1);
    }
    float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
    float2 texel = float2(1.0) / getTexSize(param_2);
    float r = fast::clamp(_78.smoothSource, 0.0, 2.0);
    float2 o = texel * r;
    float acc = 0.0;
    float w = 0.0;
    for (int j = -1; j <= 1; j++)
    {
        for (int i = -1; i <= 1; i++)
        {
            float ww = ((i == 0) && (j == 0)) ? 2.0 : 1.0;
            float2 param_3 = uv + (float2(float(i), float(j)) * o);
            float3 param_4 = texture2DCv(refInput, refInputSmplr, param_3).xyz;
            acc += (greyScale(param_4) * ww);
            w += ww;
        }
    }
    return acc / fast::max(w, 1.0);
}

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
void referenceMain(constant ReferenceUniformse24809c908d0e& _78, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _78.refScreen.xy;
    float2 param = uv;
    float4 src = texture2DCv(refInput, refInputSmplr, param);
    float2 param_1 = uv;
    float grey = smoothLum(param_1, _78, refInput, refInputSmplr);
    float ang = radians(_78.dotsAngle);
    float scale = _78.dotsFrequency * 0.0599999986588954925537109375;
    float2 shiftPx = float2(_78.shiftX, -_78.shiftY);
    float2 uvShift = uv + (shiftPx / _78.refScreen.xy);
    float2 p = (uvShift - float2(0.5)) * _78.refScreen.xy;
    float param_2 = ang;
    float2 s = rot(param_2) * p;
    float st_scale = fast::max(_78.dotsFrequency, 9.9999997473787516355514526367188e-05);
    float2 st = s / float2(fast::max(_78.refScreen.y, 1.0));
    float2 i_st = floor(st * st_scale);
    float2 f_st = fract(st * st_scale);
    float dist = distance(f_st, float2(0.5));
    float2 light_loc = float2(0.5);
    float param_3 = ang;
    light_loc = rot(param_3) * light_loc;
    float pct = distance(i_st / float2(st_scale), light_loc);
    float fallCenter = 0.1319999992847442626953125;
    float fallUpper = 1.203999996185302734375;
    float fallLower = 0.3319999873638153076171875;
    float s_max = 0.60000002384185791015625;
    float s_min = 0.100000001490116119384765625;
    float ndotl = smoothstep(fallCenter - fallLower, fallCenter + fallUpper, pct);
    ndotl = fast::clamp(ndotl, s_min, s_max);
    float edge = 0.00999999977648258209228515625 / fast::max(_78.dotsSharpness, 9.9999997473787516355514526367188e-05);
    float mask = smoothstep(ndotl, ndotl + edge, dist);
    mask = fast::clamp(mask + _78.dotsLighten, 0.0, 1.0);
    if (_78.dotsMode == 1)
    {
        mask = 1.0 - mask;
    }
    float3 c0 = _78.color0.xyz;
    float3 c1 = _78.color1.xyz;
    float3 halftone = mix(c0, c1, float3(mask));
    float a = src.w * _78.alpha;
    referenceColor = float4(halftone, 1.0) * a;
}

fragment refAM35_e24809c908d0e_out refAM35_e24809c908d0e(constant ReferenceUniformse24809c908d0e& _78 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e24809c908d0e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(_78, refInput, refInputSmplr, gl_FragCoord, referenceColor);
    bool _367 = any(isnan(referenceColor));
    bool _374;
    if (!_367)
    {
        _374 = any(isinf(referenceColor));
    }
    else
    {
        _374 = _367;
    }
    if (_374)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _387 = referenceColor;
    float3 _393 = fast::clamp(_387.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _393.x;
    referenceColor.y = _393.y;
    referenceColor.z = _393.z;
    out.finalColor = referenceColor;
    return out;
}

