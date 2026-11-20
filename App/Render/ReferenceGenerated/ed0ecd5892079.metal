// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxlinescape.xml
// Original source comments and attribution:
/////////////////////////
// Noise from IQ
// Create a 4x4 view matrix from the right, up, forward and eye position vectors
/////////////////////////
// syamjaidtz += vec2((-250.0+position.x), (200.0+position.y))*vec2(-1.,1.)/500.;
/////////////////////////
// Background
// vec3 bkg = vec3(0.0,0.0,0.0) + p.y*0.1;
// col += bkg;
// Vignetting
// vec4 factor = mix(texColorX,fragColor,alpha);
// normal
// multiply
// screen
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsed0ecd5892079
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float AMOUNT;
    char _m6_pad[12];
    float progressa;
    char _m7_pad[12];
    float progressb;
    char _m8_pad[12];
    float scale;
    char _m9_pad[12];
    float bright;
    char _m10_pad[12];
    float alpha;
    char _m11_pad[12];
    float angle;
    float4 color1;
    float4 color2;
    int blendMode;
};

struct refAM35_ed0ecd5892079_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
float2x2 rot2m(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float4x4 CreatePerspectiveMatrix(thread const float& fov, thread const float& aspect, thread const float& near, thread const float& far)
{
    float4x4 m = float4x4(float4(0.0), float4(0.0), float4(0.0), float4(0.0));
    float angle = (fov / 180.0) * 3.1415927410125732421875;
    float f = 1.0 / tan(angle * 0.5);
    m[0].x = f / aspect;
    m[1].y = f;
    m[2].z = (far + near) / (near - far);
    m[2].w = -1.0;
    m[3].z = ((2.0 * far) * near) / (near - far);
    return m;
}

static inline __attribute__((always_inline))
float4x4 CamControl(thread const float3& eye, thread const float& pitch)
{
    float cosPitch = cos(pitch);
    float sinPitch = sin(pitch);
    float3 xaxis = float3(1.0, 0.0, 0.0);
    float3 yaxis = float3(0.0, cosPitch, sinPitch);
    float3 zaxis = float3(0.0, -sinPitch, cosPitch);
    float4x4 viewMatrix = float4x4(float4(float4(xaxis.x, yaxis.x, zaxis.x, 0.0)), float4(float4(xaxis.y, yaxis.y, zaxis.y, 0.0)), float4(float4(xaxis.z, yaxis.z, zaxis.z, 0.0)), float4(float4(-dot(xaxis, eye), -dot(yaxis, eye), -dot(zaxis, eye), 1.0)));
    return viewMatrix;
}

static inline __attribute__((always_inline))
float2 hash(thread float2& p)
{
    p = float2(dot(p, float2(127.09999847412109375, 311.70001220703125)), dot(p, float2(269.5, 183.3000030517578125)));
    return float2(-1.0) + (fract(sin(p) * 43758.546875) * 2.0);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p + float2((p.x + p.y) * 0.3660254180431365966796875));
    float2 a = (p - i) + float2((i.x + i.y) * 0.211324870586395263671875);
    float2 o = select(float2(0.0, 1.0), float2(1.0, 0.0), bool2(a.x > a.y));
    float2 b = (a - o) + float2(0.211324870586395263671875);
    float2 c = (a - float2(1.0)) + float2(0.42264974117279052734375);
    float3 h = fast::max(float3(0.5) - float3(dot(a, a), dot(b, b), dot(c, c)), float3(0.0));
    float2 param = i + float2(0.0);
    float2 _180 = hash(param);
    float2 param_1 = i + o;
    float2 _187 = hash(param_1);
    float2 param_2 = i + float2(1.0);
    float2 _194 = hash(param_2);
    float3 n = (((h * h) * h) * h) * float3(dot(a, _180), dot(b, _187), dot(c, _194));
    return dot(n, float3(70.0));
}

static inline __attribute__((always_inline))
float fbm4(thread float2& p)
{
    float f = 0.0;
    float2 param = p;
    f += (0.5 * _noise(param));
    p = (float2x2(float2(0.800000011920928955078125, 0.60000002384185791015625), float2(-0.60000002384185791015625, 0.800000011920928955078125)) * p) * 2.019999980926513671875;
    float2 param_1 = p;
    f += (0.25 * _noise(param_1));
    p = (float2x2(float2(0.800000011920928955078125, 0.60000002384185791015625), float2(-0.60000002384185791015625, 0.800000011920928955078125)) * p) * 2.0299999713897705078125;
    float2 param_2 = p;
    f += (0.125 * _noise(param_2));
    p = (float2x2(float2(0.800000011920928955078125, 0.60000002384185791015625), float2(-0.60000002384185791015625, 0.800000011920928955078125)) * p) * 2.0099999904632568359375;
    float2 param_3 = p;
    f += (0.0625 * _noise(param_3));
    return f;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsed0ecd5892079& _387, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _387.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _387.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _387.refScreen.xy).y) * _387.refScreen.xy) - float2(_387.refLayer.x + (_387.refLayer.z * 0.5), (_387.refScreen.y - _387.refLayer.y) - (_387.refLayer.w * 0.5))) / _387.refLayer.zw;
    syamjaidtz.y *= (_387.refLayer.w / _387.refLayer.z);
    syamjaidtz /= float2(_387.scale);
    float param_1 = ((-180.0) + _387.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += float2(0.5, 0.4000000059604644775390625);
    float2 uv = syamjaidtz;
    float2 p = (uv * 2.0) - float2(1.0);
    p.x *= (_387.refScreen.x / _387.refScreen.y);
    float3 eye = float3(0.0, 0.25 + (0.25 * cos(0.5 * _387.progressa)), -1.0);
    float param_2 = 50.0;
    float param_3 = _387.refScreen.x / _387.refScreen.y;
    float param_4 = 0.100000001490116119384765625;
    float param_5 = 10.0;
    float4x4 projmat = CreatePerspectiveMatrix(param_2, param_3, param_4, param_5);
    float3 param_6 = eye;
    float param_7 = -0.08726646006107330322265625;
    float4x4 viewmat = CamControl(param_6, param_7);
    float4x4 vpmat = viewmat * projmat;
    float3 col = float3(0.0);
    float3 acc = float3(0.0);
    float4 pos = float4(0.0);
    float lh = -_387.refScreen.y;
    float off = 0.100000001490116119384765625 * _387.progressb;
    float h = 0.0;
    float z = 0.100000001490116119384765625;
    float zi = 0.0500000007450580596923828125;
    float _588;
    for (float i = 0.0; i < _387.AMOUNT; i += 1.0)
    {
        float2 param_8 = float2(eye.x + p.x, z + off) * 0.5;
        float _563 = fbm4(param_8);
        pos = float4(p.x, 0.5 * _563, eye.z + z, 1.0);
        h = (vpmat * pos).y - p.y;
        if (h > lh)
        {
            float d = abs(h);
            if (d < 0.004999999888241291046142578125)
            {
                _588 = smoothstep(1.0, 0.0, d * 192.0);
            }
            else
            {
                _588 = 0.0;
            }
            col = float3(_588);
            col *= exp((-0.100000001490116119384765625) * i);
            acc += col;
            lh = h;
        }
        z += zi;
    }
    col = sqrt(fast::clamp(acc, float3(0.0), float3(1.0)));
    float3 bkg = float3(0.0);
    float2 r = float2(-1.0) + (uv * 2.0);
    float vb = fast::max(abs(r.x), abs(r.y));
    col *= (0.1500000059604644775390625 + (0.85000002384185791015625 * (1.0 - exp((-(1.0 - vb)) * 30.0))));
    float4 fragColor = float4(col, 1.0);
    float luminance = dot(fragColor.xyz, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float4 gradmap = mix(_387.color1, _387.color2, float4(luminance)) * fragColor.w;
    float4 factor = mix(texColorX, gradmap, float4(_387.alpha));
    float4 resultfinal;
    if (_387.blendMode == 0)
    {
        resultfinal = (factor * _387.bright) * texColor.w;
    }
    else
    {
        if (_387.blendMode == 1)
        {
            factor *= _387.bright;
            float4 c = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_387.blendMode == 2)
            {
                factor *= _387.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    referenceColor = resultfinal;
}

fragment refAM35_ed0ecd5892079_out refAM35_ed0ecd5892079(constant ReferenceUniformsed0ecd5892079& _387 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed0ecd5892079_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refInput, refInputSmplr, gl_FragCoord, _387, referenceColor);
    bool _769 = any(isnan(referenceColor));
    bool _776;
    if (!_769)
    {
        _776 = any(isinf(referenceColor));
    }
    else
    {
        _776 = _769;
    }
    if (_776)
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

