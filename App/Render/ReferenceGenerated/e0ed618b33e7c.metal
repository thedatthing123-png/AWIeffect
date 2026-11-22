// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/jpegquality.xml
// Original source comments and attribution:
// DCT Compress Demo (single pass)
// - AM official style: fixed loops, only builtins
// Y, Cb, Cr in [0,1]
// JPEG-like luminance quant matrix (subset via function)
// Values from standard table
// Manually unrolled initialization for GLSL ES compatibility
// Kept coefficient mask for Low/Medium/High detail
// Low: (0,0),(1,0),(0,1)
// Medium: add (1,1),(2,0),(0,2)
// High: include first 10 zigzag approx
// Split view position in pixels
// Original on left
// Determine 8x8 block origin in pixel space
// 0..7 within block
// Build YCbCr samples for the block (centered around 0 for DCT)
// match shadertoy scaling
// 0,1,2
// larger -> stronger quantization
// Compute selected DCT coefficients per channel
// Compute F(u,v)
// Quantize using luma table scale (apply same to all channels for simplicity)
// Add this coefficient's contribution to current pixel via IDCT
// Back to rgb
// Optional block grid overlay
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

struct ReferenceUniformse0ed618b33e7c
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float quality;
    char _m6_pad[12];
    int detail;
    char _m7_pad[12];
    uint showGrid;
    char _m8_pad[12];
    float alpha;
};

struct refAM35_e0ed618b33e7c_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float3 rgb2ybr(thread const float3& rgb)
{
    float3 ybr = (float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625) * rgb.x) + float3(0.0);
    float y = dot(rgb, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float cb = ((rgb.z - y) * 0.56400001049041748046875) + 0.5;
    float cr = ((rgb.x - y) * 0.712999999523162841796875) + 0.5;
    return float3(y, cb, cr);
}

static inline __attribute__((always_inline))
bool keepCoeff(thread const int& u, thread const int& v, thread const int& mode)
{
    if (mode == 0)
    {
        bool _315 = (u == 0) && (v == 0);
        bool _324;
        if (!_315)
        {
            _324 = (u == 1) && (v == 0);
        }
        else
        {
            _324 = _315;
        }
        bool _333;
        if (!_324)
        {
            _333 = (u == 0) && (v == 1);
        }
        else
        {
            _333 = _324;
        }
        return _333;
    }
    else
    {
        if (mode == 1)
        {
            bool _344 = (u == 0) && (v == 0);
            bool _353;
            if (!_344)
            {
                _353 = (u == 1) && (v == 0);
            }
            else
            {
                _353 = _344;
            }
            bool _362;
            if (!_353)
            {
                _362 = (u == 0) && (v == 1);
            }
            else
            {
                _362 = _353;
            }
            bool _371;
            if (!_362)
            {
                _371 = (u == 1) && (v == 1);
            }
            else
            {
                _371 = _362;
            }
            bool _380;
            if (!_371)
            {
                _380 = (u == 2) && (v == 0);
            }
            else
            {
                _380 = _371;
            }
            bool _389;
            if (!_380)
            {
                _389 = (u == 0) && (v == 2);
            }
            else
            {
                _389 = _380;
            }
            if (_389)
            {
                return true;
            }
            return false;
        }
        else
        {
            int sum = u + v;
            bool _402 = sum <= 3;
            bool _411;
            if (!_402)
            {
                _411 = (u == 3) && (v == 0);
            }
            else
            {
                _411 = _402;
            }
            bool _420;
            if (!_411)
            {
                _420 = (u == 0) && (v == 3);
            }
            else
            {
                _420 = _411;
            }
            return _420;
        }
    }
}

static inline __attribute__((always_inline))
float aScale(thread const float& k)
{
    return (k == 0.0) ? 0.707106769084930419921875 : 1.0;
}

static inline __attribute__((always_inline))
float qLuma(thread const int& u, thread const int& v)
{
    int idx = (v * 8) + u;
    spvUnsafeArray<int, 64> qv;
    qv[0] = 16;
    qv[1] = 11;
    qv[2] = 10;
    qv[3] = 16;
    qv[4] = 24;
    qv[5] = 40;
    qv[6] = 51;
    qv[7] = 61;
    qv[8] = 12;
    qv[9] = 12;
    qv[10] = 14;
    qv[11] = 19;
    qv[12] = 26;
    qv[13] = 58;
    qv[14] = 60;
    qv[15] = 55;
    qv[16] = 14;
    qv[17] = 13;
    qv[18] = 16;
    qv[19] = 24;
    qv[20] = 40;
    qv[21] = 57;
    qv[22] = 69;
    qv[23] = 56;
    qv[24] = 14;
    qv[25] = 17;
    qv[26] = 22;
    qv[27] = 29;
    qv[28] = 51;
    qv[29] = 87;
    qv[30] = 80;
    qv[31] = 62;
    qv[32] = 18;
    qv[33] = 22;
    qv[34] = 37;
    qv[35] = 56;
    qv[36] = 68;
    qv[37] = 109;
    qv[38] = 103;
    qv[39] = 77;
    qv[40] = 24;
    qv[41] = 35;
    qv[42] = 55;
    qv[43] = 64;
    qv[44] = 81;
    qv[45] = 104;
    qv[46] = 113;
    qv[47] = 92;
    qv[48] = 49;
    qv[49] = 64;
    qv[50] = 78;
    qv[51] = 87;
    qv[52] = 103;
    qv[53] = 121;
    qv[54] = 120;
    qv[55] = 101;
    qv[56] = 72;
    qv[57] = 92;
    qv[58] = 95;
    qv[59] = 98;
    qv[60] = 112;
    qv[61] = 100;
    qv[62] = 103;
    qv[63] = 99;
    return float(qv[idx]);
}

static inline __attribute__((always_inline))
float3 ybr2rgb(thread const float3& ybr)
{
    float y = ybr.x;
    float cb = ybr.y - 0.5;
    float cr = ybr.z - 0.5;
    float r = y + (1.40299999713897705078125 * cr);
    float b = y + (1.7730000019073486328125 * cb);
    float g = ((y - (0.2989999949932098388671875 * r)) - (0.114000000059604644775390625 * b)) / 0.58700001239776611328125;
    return fast::clamp(float3(r, g, b), float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse0ed618b33e7c& _431, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _431.refScreen.xy;
    float2 texel = float2(1.0) / fast::max(_431.refScreen.xy, float2(1.0));
    float splitPx = 0.0 * _431.refScreen.x;
    float xPx = uv.x * _431.refScreen.x;
    float2 param = uv;
    float3 srcRGB = texture2DCv(refInput, refInputSmplr, param).xyz;
    if (xPx < splitPx)
    {
        referenceColor = float4(srcRGB, 1.0) * _431.alpha;
        return;
    }
    float2 pPx = floor(uv * _431.refScreen.xy);
    float2 blockBase = floor(pPx / float2(8.0)) * 8.0;
    float2 xy = pPx - blockBase;
    int k = 0;
    spvUnsafeArray<float3, 64> S;
    for (int j = 0; j < 8; j++)
    {
        for (int i = 0; i < 8; i++)
        {
            float2 sp = ((blockBase + float2(float(i), float(j))) + float2(0.5)) * texel;
            float2 param_1 = sp;
            float3 param_2 = texture2DCv(refInput, refInputSmplr, param_1).xyz;
            float3 ybr = rgb2ybr(param_2);
            S[k] = (ybr - float3(0.0, 0.5, 0.5)) * 256.0;
            k++;
        }
    }
    int mode = _431.detail;
    float qScale = _431.quality;
    float3 recon = float3(0.0);
    for (int v = 0; v < 8; v++)
    {
        for (int u = 0; u < 8; u++)
        {
            int param_3 = u;
            int param_4 = v;
            int param_5 = mode;
            if (!keepCoeff(param_3, param_4, param_5))
            {
                continue;
            }
            float3 F = float3(0.0);
            int idx = 0;
            for (int yb = 0; yb < 8; yb++)
            {
                for (int xb = 0; xb < 8; xb++)
                {
                    float cx = cos(((((2.0 * float(xb)) + 1.0) * float(u)) * 3.1415927410125732421875) / 16.0);
                    float cy = cos(((((2.0 * float(yb)) + 1.0) * float(v)) * 3.1415927410125732421875) / 16.0);
                    F += (S[idx] * (cx * cy));
                    idx++;
                }
            }
            float param_6 = float(u);
            float param_7 = float(v);
            F *= ((0.25 * aScale(param_6)) * aScale(param_7));
            int param_8 = u;
            int param_9 = v;
            float qv = qLuma(param_8, param_9) * qScale;
            F = floor((F / float3(qv)) + float3(0.5)) * qv;
            float cxp = cos(((((2.0 * xy.x) + 1.0) * float(u)) * 3.1415927410125732421875) / 16.0);
            float cyp = cos(((((2.0 * xy.y) + 1.0) * float(v)) * 3.1415927410125732421875) / 16.0);
            float param_10 = float(u);
            float param_11 = float(v);
            recon += ((((F * (cxp * cyp)) * 0.25) * aScale(param_10)) * aScale(param_11));
        }
    }
    float3 ybrRec = (recon / float3(256.0)) + float3(0.0, 0.5, 0.5);
    float3 param_12 = ybrRec;
    float3 rgbRec = ybr2rgb(param_12);
    if (_431.showGrid != 0u)
    {
        float2 g = fract(pPx / float2(8.0));
        float edge = ((step(g.x, 0.0199999995529651641845703125) + step(0.980000019073486328125, g.x)) + step(g.y, 0.0199999995529651641845703125)) + step(0.980000019073486328125, g.y);
        rgbRec = mix(rgbRec, float3(0.0), float3(fast::clamp(edge, 0.0, 1.0)));
    }
    referenceColor = float4(rgbRec, 1.0) * _431.alpha;
}

fragment refAM35_e0ed618b33e7c_out refAM35_e0ed618b33e7c(constant ReferenceUniformse0ed618b33e7c& _431 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e0ed618b33e7c_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _431, refInput, refInputSmplr, referenceColor);
    bool _770 = any(isnan(referenceColor));
    bool _777;
    if (!_770)
    {
        _777 = any(isinf(referenceColor));
    }
    else
    {
        _777 = _770;
    }
    if (_777)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _791 = referenceColor;
    float3 _797 = fast::clamp(_791.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _797.x;
    referenceColor.y = _797.y;
    referenceColor.z = _797.z;
    out.finalColor = referenceColor;
    return out;
}

