// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxelectricrough.xml
// Original source comments and attribution:
/////////////////////////
// texture based white noise
// procedural white noise	
//return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
//----------------------------------
// first pass: regular voronoi
//----------------------------------
//----------------------------------
// second pass: distance to borders
//----------------------------------
/////////////////////////
/////////////////////////
// if(progressa <= 0.0) { gl_FragColor = texture2DCv(inputImg.texture,acScreenNorm); }
// else if(progressa >= 0.0001) { 
// range 0-1
// p.x += - timeStep*6.0;
// p.y += - timeStep*3.0;    
// uv.x += 0.5*(2.0 * cellPos-1.0) * (uv.y-0.5);
// fragColor = vec4(2.5*(2.0 * cellPos-1.0) * (uv.y-0.5)); return;
// higher values zoom out further - don't go too high or the sine waves will become quite obvious...
// c.x = 1.0-pow(1.0-c.x, 2.0);
//edgeScale = fragCoord.x/iResolution.x ;
// float d = 1.0-abs(uv.y-c.x-0.25);
//float lineWidth *= 1.0- pow(1.0-(0.5*sinTimeOffset + 0.5), 2.0);
//fragColor += edgeScale*vec4(1,1,1.0,1 ) * smoothstep(1.0, 1.005, lineWidth);
// const vec3 luminanceWeighting = vec3(0.2126, 0.7152, 0.0722);
// vec4 gradmap;
// float luminance = dot(fragColor.rgb, luminanceWeighting);
// gradmap = mix(color1,color2,luminance)*fragColor.a;
// vec4 factorx = mix(fragColor,gradmap,alphab);
// normal
// multiply
// screen
// }
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsec2c84e7a71ac
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float progressa;
    char _m7_pad[12];
    float progressb;
    char _m8_pad[12];
    float progressd;
    char _m9_pad[12];
    float progresse;
    char _m10_pad[12];
    float scale;
    char _m11_pad[12];
    float bright;
    char _m12_pad[12];
    float alpha;
    char _m13_pad[12];
    float angle;
    float4 color1;
    float4 color2;
    float4 color3;
    float4 color4;
    int blendMode;
};

struct refAM35_ec2c84e7a71ac_out
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
float2 hash2(thread const float2& p, texture2d<float> refImage1, sampler refImage1Smplr)
{
    return refImage1.sample(refImage1Smplr, ((p + float2(0.5)) / float2(256.0)), bias(-100.0)).xy;
}

static inline __attribute__((always_inline))
float4 voronoi(thread const float2& x, texture2d<float> refImage1, sampler refImage1Smplr)
{
    float2 n = floor(x);
    float2 f = fract(x);
    float md = 8.0;
    float2 o;
    float2 mr;
    float2 mg;
    for (int j = -1; j <= 1; j++)
    {
        for (int i = -1; i <= 1; i++)
        {
            float2 g = float2(float(i), float(j));
            float2 param = n + g;
            o = hash2(param, refImage1, refImage1Smplr);
            float2 r = (g + o) - f;
            float d = dot(r, r);
            if (d < md)
            {
                md = d;
                mr = r;
                mg = g;
            }
        }
    }
    float oldDist = md;
    md = 8.0;
    for (int j_1 = -2; j_1 <= 2; j_1++)
    {
        for (int i_1 = -2; i_1 <= 2; i_1++)
        {
            float2 g_1 = mg + float2(float(i_1), float(j_1));
            float2 param_1 = n + g_1;
            o = hash2(param_1, refImage1, refImage1Smplr);
            float2 r_1 = (g_1 + o) - f;
            if (dot(mr - r_1, mr - r_1) > 9.9999997473787516355514526367188e-06)
            {
                md = fast::min(md, dot((mr + r_1) * 0.5, fast::normalize(r_1 - mr)));
            }
        }
    }
    return float4(md, mr, oldDist);
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refImage1, sampler refImage1Smplr, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord, constant ReferenceUniformsec2c84e7a71ac& _235, thread float4& referenceColor)
{
    float2 param = gl_FragCoord.xy / _235.refScreen.xy;
    float4 texColor = texture2DCv(refInput, refInputSmplr, param);
    float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
    float2 syamjaidtz = ((float2((gl_FragCoord.xy / _235.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _235.refScreen.xy).y) * _235.refScreen.xy) - float2(_235.refLayer.x + (_235.refLayer.z * 0.5), (_235.refScreen.y - _235.refLayer.y) - (_235.refLayer.w * 0.5))) / _235.refLayer.zw;
    syamjaidtz.y *= (_235.refLayer.w / _235.refLayer.z);
    syamjaidtz /= float2(_235.scale);
    float param_1 = (0.0 + _235.angle) * 0.01745329983532428741455078125;
    syamjaidtz *= rot2m(param_1);
    syamjaidtz += ((float2(0.0 + _235.position.x, 250.0 + _235.position.y) * float2(-1.0, 1.0)) / float2(500.0));
    float2 uv = syamjaidtz;
    float pauseFreq = _235.progressd;
    float pauseScale = 1.0;
    float scaledTime = _235.progressb * 0.5;
    scaledTime += (0.0500000007450580596923828125 * uv.x);
    float sinTime = sin(pauseFreq * scaledTime);
    float sinTimeOffset = sin((pauseFreq * scaledTime) - 1.57050001621246337890625);
    float timeStep = scaledTime + (pauseScale * (sinTime / pauseFreq));
    float2 p = uv;
    p *= 4.0;
    p.x = 0.5 - (timeStep * 3.0);
    p.y = 0.5 - (timeStep * 3.0);
    float2 param_2 = p;
    float4 c = voronoi(param_2, refImage1, refImage1Smplr);
    float cellPos = (p.y + c.z) + (timeStep * 3.0);
    uv.x += ((1.5 * ((2.0 * c.x) - 0.3300000131130218505859375)) * (uv.y - 0.5));
    uv.x *= 0.25;
    p = uv;
    p.y = fast::max(p.y, 0.5);
    p *= 12.0;
    p.x += (timeStep * 16.0);
    p.y += (timeStep * 32.0);
    float2 param_3 = p;
    c = voronoi(param_3, refImage1, refImage1Smplr);
    float4 fragColor = float4(c.x) * 0.5;
    float d = 0.0;
    float edgeScale = 1.0 - (2.0 * abs(_235.progressa - 0.5));
    float scaleMulti = powr((0.5 * sinTime) + 0.5, 2.0);
    float dScale = (2.0 * edgeScale) * (0.25 + (0.75 * powr((0.5 * sinTimeOffset) + 0.5, 2.0)));
    p.y = 6.0 + (timeStep * 3.0);
    float2 param_4 = p;
    c = voronoi(param_4, refImage1, refImage1Smplr) * dScale;
    d = (uv.y + c.x) - 0.75;
    p.x = (uv.x * 12.0) - (timeStep * 6.0);
    p.y = 54.0 - (timeStep * 3.0);
    float2 param_5 = p;
    c = voronoi(param_5, refImage1, refImage1Smplr) * dScale;
    d = mix(d, (uv.y - c.x) - 0.25, 0.5);
    d = 1.0 - abs(d);
    fragColor = float4(d);
    float lineWidth = d + ((_235.progresse * scaleMulti) * edgeScale);
    fragColor = mix(_235.color2, _235.color3, float4(scaleMulti)) * smoothstep(1.0, 1.00499999523162841796875, lineWidth);
    fragColor += (_235.color4 * ((edgeScale * powr(scaleMulti * smoothstep(0.75, 1.00499999523162841796875, lineWidth), 16.0)) * 0.5));
    fragColor += _235.color1;
    float4 factor = mix(texColorX, fragColor, float4(1.0));
    float4 resultfinal;
    if (_235.blendMode == 0)
    {
        resultfinal = (factor * _235.bright) * texColor.w;
    }
    else
    {
        if (_235.blendMode == 1)
        {
            factor *= _235.bright;
            float4 c_1 = factor + (float4(1.0) * (1.0 - factor.w));
            resultfinal = float4((texColor.xyz / float3(texColor.w)) * c_1.xyz, 1.0) * texColor.w;
        }
        else
        {
            if (_235.blendMode == 2)
            {
                factor *= _235.bright;
                resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
            }
        }
    }
    float4 gfinal = mix(texColor, resultfinal, float4(_235.alpha));
    float4 param_6 = texColor;
    float4 param_7 = gfinal;
    referenceColor = newLayer(param_6, param_7) * texColor.w;
}

fragment refAM35_ec2c84e7a71ac_out refAM35_ec2c84e7a71ac(constant ReferenceUniformsec2c84e7a71ac& _235 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ec2c84e7a71ac_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refImage1, refImage1Smplr, refInput, refInputSmplr, gl_FragCoord, _235, referenceColor);
    bool _677 = any(isnan(referenceColor));
    bool _684;
    if (!_677)
    {
        _684 = any(isinf(referenceColor));
    }
    else
    {
        _684 = _677;
    }
    if (_684)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _697 = referenceColor;
    float3 _703 = fast::clamp(_697.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _703.x;
    referenceColor.y = _703.y;
    referenceColor.z = _703.z;
    out.finalColor = referenceColor;
    return out;
}

