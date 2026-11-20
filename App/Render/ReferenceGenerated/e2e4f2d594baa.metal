// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxtvdamage.xml
// Original source comments and attribution:
/////////////////////////
// Noise generation functions borrowed from: 
// https://github.com/ashima/webgl-noise/blob/master/src/noise2D.glsl
// (3.0-sqrt(3.0))/6.0
// 0.5*(sqrt(3.0)-1.0)
// -1.0 + 2.0 * C.x
// 1.0 / 41.0
// First corner
// Other corners
//i1.x = step( x0.y, x0.x ); // x0.x > x0.y ? 1.0 : 0.0
//i1.y = 1.0 - i1.x;
// x0 = x0 - 0.0 + 0.0 * C.xx ;
// x1 = x0 - i1 + 1.0 * C.xx ;
// x2 = x0 - 1.0 + 2.0 * C.xx ;
// Permutations
// Avoid truncation effects in permutation
// Gradients: 41 points uniformly over a line, mapped onto a diamond.
// The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)
// Normalise gradients implicitly by scaling m
// Approximation of: m *= inversesqrt( a0*a0 + h*h );
// Compute final noise value at P
// syamjaidtz *= rot2m(angle*0.0174533);
// vec2 syamjaidtz = l2s(st);
/////////////////////////
// vec2 syamjaidtz =  acScreenNorm;
// float fuzzOffset = snoise(vec2(seed*15.0,syamjaidtz.y*80.0))*0.003;
// float largeFuzzOffset = snoise(vec2(wave*1.0,syamjaidtz.y*25.0))*0.004;
/// DONT TOUCH
/// ---------------
// float scanline = sin(syamjaidtz.y*800.0)*0.04*scalinesOpt;
////////////////////////
///////////////////////
// vec4 texColorOri = texture2DCv(inputImg.texture,syamjaidtz);
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

struct ReferenceUniformse2e4f2d594baa
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float alpha;
    char _m6_pad[12];
    float scalinesOpt;
    char _m7_pad[12];
    float scalinesOpta;
    char _m8_pad[12];
    float scalinesOptb;
    char _m9_pad[12];
    float bottomStaticOpt;
    char _m10_pad[12];
    float rgbOffsetOpt;
    char _m11_pad[12];
    float horzFuzzOpt;
    char _m12_pad[12];
    float seed;
    char _m13_pad[12];
    float ggg;
    char _m14_pad[12];
    float wave;
    char _m15_pad[12];
    float hardoff;
};

struct refAM35_e2e4f2d594baa_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2 mod289(thread const float2& x)
{
    return x - (floor(x * 0.00346020772121846675872802734375) * 289.0);
}

static inline __attribute__((always_inline))
float3 mod289(thread const float3& x)
{
    return x - (floor(x * 0.00346020772121846675872802734375) * 289.0);
}

static inline __attribute__((always_inline))
float3 permute(thread const float3& x)
{
    float3 param = ((x * 34.0) + float3(1.0)) * x;
    return mod289(param);
}

static inline __attribute__((always_inline))
float snoise(thread const float2& v)
{
    float2 i = floor(v + float2(dot(v, float2(0.3660254180431365966796875))));
    float2 x0 = (v - i) + float2(dot(i, float2(0.211324870586395263671875)));
    float2 i1 = select(float2(0.0, 1.0), float2(1.0, 0.0), bool2(x0.x > x0.y));
    float4 x12 = x0.xyxy + float4(0.211324870586395263671875, 0.211324870586395263671875, -0.57735025882720947265625, -0.57735025882720947265625);
    float4 _119 = x12;
    float2 _121 = _119.xy - i1;
    x12.x = _121.x;
    x12.y = _121.y;
    float2 param = i;
    i = mod289(param);
    float3 param_1 = float3(i.y) + float3(0.0, i1.y, 1.0);
    float3 param_2 = (permute(param_1) + float3(i.x)) + float3(0.0, i1.x, 1.0);
    float3 p = permute(param_2);
    float3 m = fast::max(float3(0.5) - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), float3(0.0));
    m *= m;
    m *= m;
    float3 x = (fract(p * float3(0.024390242993831634521484375)) * 2.0) - float3(1.0);
    float3 h = abs(x) - float3(0.5);
    float3 ox = floor(x + float3(0.5));
    float3 a0 = x - ox;
    m *= (float3(1.792842864990234375) - (((a0 * a0) + (h * h)) * 0.8537347316741943359375));
    float3 g;
    g.x = (a0.x * x0.x) + (h.x * x0.y);
    float2 _236 = (a0.yz * x12.xz) + (h.yz * x12.yw);
    g.y = _236.x;
    g.z = _236.y;
    return 130.0 * dot(m, g);
}

static inline __attribute__((always_inline))
float staticV(thread const float2& syamjaidtz)
{
    float2 param = float2(9.0, 4.19999980926513671875);
    float staticHeight = (snoise(param) * 0.300000011920928955078125) + 5.0;
    float2 param_1 = float2(1.0, -4.80000019073486328125);
    float staticAmount = (snoise(param_1) * 0.100000001490116119384765625) + 0.300000011920928955078125;
    float2 param_2 = float2(-9.75, -2.400000095367431640625);
    float staticStrength = (snoise(param_2) * 2.0) + 2.0;
    float2 param_3 = float2(5.0 + powr(syamjaidtz.x * 7.0, 1.2000000476837158203125), powr(((101.0 * syamjaidtz.y) * 0.300000011920928955078125) + 3.0, staticHeight));
    return (1.0 - step(snoise(param_3), staticAmount)) * staticStrength;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformse2e4f2d594baa& _310, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _310.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float2 syamjaidtz = gl_FragCoord.xy / _310.refScreen.xy;
    syamjaidtz -= float2(0.5);
    syamjaidtz.x *= (_310.refScreen.x / _310.refScreen.y);
    syamjaidtz /= float2(1.0);
    syamjaidtz.x /= (_310.refScreen.x / _310.refScreen.y);
    syamjaidtz += float2(0.5);
    float rad = 0.0;
    float2 v = fast::normalize(float2(cos(rad), -sin(rad)));
    float2 param_1 = float2(1.2999999523162841796875, 5.0);
    float jerkOffset = (1.0 - step(snoise(param_1), 0.800000011920928955078125)) * 0.0500000007450580596923828125;
    float2 param_2 = float2(_310.seed * 15.0, syamjaidtz.y * 80.0);
    float fuzzOffset = snoise(param_2) * 0.100000001490116119384765625;
    float2 param_3 = float2(_310.wave * 1.0, syamjaidtz.y * 25.0);
    float largeFuzzOffset = snoise(param_3) * _310.ggg;
    float2 param_4 = float2(0.20000000298023223876953125, 8.0);
    float vertMovementOn = (1.0 - step(snoise(param_4), 0.4000000059604644775390625)) * 1.0;
    float2 param_5 = float2(1.5, 5.0);
    float vertJerk = (1.0 - step(snoise(param_5), 0.60000002384185791015625)) * 1.0;
    float2 param_6 = float2(5.5, 5.0);
    float vertJerk2 = (1.0 - step(snoise(param_6), 0.20000000298023223876953125)) * 1.0;
    float yOffset = (3.36588382720947265625 * vertMovementOn) + ((vertJerk * vertJerk2) * 0.300000011920928955078125);
    float y = mod(syamjaidtz.y + yOffset, _310.hardoff);
    float xOffset = (fuzzOffset + largeFuzzOffset) * _310.horzFuzzOpt;
    float staticVal = 0.0;
    for (float y_1 = -1.0; y_1 <= 1.0; y_1 += 1.0)
    {
        float maxDist = 0.02500000037252902984619140625;
        float dist = y_1 / 200.0;
        float2 param_7 = float2(syamjaidtz.x, syamjaidtz.y + dist);
        staticVal += ((staticV(param_7) * (maxDist - abs(dist))) * 1.7000000476837158203125);
    }
    staticVal *= _310.bottomStaticOpt;
    float2 param_8 = float2((syamjaidtz.x + xOffset) - (0.00999999977648258209228515625 * _310.rgbOffsetOpt), y);
    float red = texture2DCv(refInput, refInputSmplr, param_8).x + staticVal;
    float2 param_9 = float2(syamjaidtz.x + xOffset, y);
    float green = texture2DCv(refInput, refInputSmplr, param_9).y + staticVal;
    float2 param_10 = float2((syamjaidtz.x + xOffset) + (0.00999999977648258209228515625 * _310.rgbOffsetOpt), y);
    float blue = texture2DCv(refInput, refInputSmplr, param_10).z + staticVal;
    float3 color = float3(red, green, blue);
    float scanline = (sin(syamjaidtz.y * _310.scalinesOptb) * _310.scalinesOpta) * _310.scalinesOpt;
    color -= float3(scanline);
    float4 result = float4(color, 1.0);
    float2 param_11 = gl_FragCoord.xy / _310.refScreen.xy;
    float4 texColorOri = texture2DCv(refInput, refInputSmplr, param_11);
    float4 final = result * texColor.w;
    referenceColor = mix(texColor, final, float4(_310.alpha));
}

fragment refAM35_e2e4f2d594baa_out refAM35_e2e4f2d594baa(constant ReferenceUniformse2e4f2d594baa& _310 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e2e4f2d594baa_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _310, referenceColor);
    bool _604 = any(isnan(referenceColor));
    bool _611;
    if (!_604)
    {
        _611 = any(isinf(referenceColor));
    }
    else
    {
        _611 = _604;
    }
    if (_611)
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

