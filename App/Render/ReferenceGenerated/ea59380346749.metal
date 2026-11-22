// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/skexnxxshexagonlens.xml
// Original source comments and attribution:
//////////////////////////
/////////////////////////
//Use bluenoise texture for fast lds random values in range [0,1]
// Produces a regular polygon defined by N points on the unit circle.
//filter negative vals.
//filter negative vals.
//filter negative vals.
//filter negative vals.
// NOTE: This function still needs some work.
//adjust as needed.
// Rotate which channels are being offset per iteration (i).
//vec3 of ints ranged [-1,1]
// Create a big circle, ring, small circle, and hexagon and control blending with a vec4.
//adjust as necessary per-object.
//vec2(0.0);//<== rings around light source.
//<== ring halos in light ray.
// Draws hexagons in order closest to light to farthest.
// Slightly offset colors to simulate chromatic abberration.
//prevent division by val < 1.
//square value to produce appropriate warping effect
// Intended to map values in range d = (0,1] to range (1,0] to rolloff values by distance.
//////////////////////////
/////////////////////////
// vec3 uv = vec3(fragCoord/iResolution.xy,0)-0.5;
// aspect correct
// Get screen space light position.
//hardcoded for shader
// vec3 lightPosition = 0.25*(vec3(orient,-0.1) - 0.5);//hardcoded for shader
//vec3 lightPos = modelToScreen(lightPosition3D)-0.5; <== implementation for world space light pos	
// aspect correct
// float distToLight = length(lightPosition - (ROTATE/100.0));
// float distToLight = length(lightPosition - cameraPosition);
// Bail early conditions.
// Calculate lens flare effect.
// Post-process, scaling strength by distance of observer to light source.
//Adjust lens flare for camera distance to light.
// exposure tone mapping
//remove negative values
// Add faked light source.
// Add rays from light source -- a rough approximation of volumetric light rays.
// Output final color.
//optional alpha blending.
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsea59380346749
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float2 position;
    char _m6_pad[8];
    float2 orient;
    char _m7_pad[8];
    float MAX_ITERATIONS;
    float4 bgColor;
    float4 lightColor;
    float XXK;
    char _m11_pad[12];
    float XXH;
    char _m12_pad[12];
    float XXI;
    char _m13_pad[12];
    float lensFlareScale;
    char _m14_pad[12];
    float XXA;
    char _m15_pad[12];
    float XXB;
    char _m16_pad[12];
    float XXC;
    char _m17_pad[12];
    float XXD;
    char _m18_pad[12];
    float XXE;
    char _m19_pad[12];
    float lensFlareExposure;
    char _m20_pad[12];
    float lensFlareBrightness;
    char _m21_pad[12];
    float scale;
    char _m22_pad[12];
    float angle;
    char _m23_pad[8];
    float2 stretch;
    char _m24_pad[8];
    float alpha;
    char _m25_pad[12];
    float hardness;
    char _m26_pad[12];
    int blendMode;
};

struct refAM35_ea59380346749_out
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
float scaleDepth(thread const float& depth)
{
    return exp(-abs((depth * 1.0) * 0.00999999977648258209228515625));
}

static inline __attribute__((always_inline))
float rnd(thread const float& w, texture2d<float> refImage1, sampler refImage1Smplr)
{
    return refImage1.sample(refImage1Smplr, float2(w)).x;
}

static inline __attribute__((always_inline))
float renderBigCircle(thread const float2& pos, thread const float2& ltpos, thread const float& dist, thread const float2& offsetFromCenter, thread const float& size, constant ReferenceUniformsea59380346749& _196)
{
    float2 coord = (pos + (ltpos * dist)) + offsetFromCenter;
    float radiusVal = _196.XXB - powr(length(coord), size * 1.39999997615814208984375);
    radiusVal = fast::max(radiusVal, 0.0);
    return radiusVal;
}

static inline __attribute__((always_inline))
float renderRing(thread const float& r, thread const float& offsetFromCenter, thread const float& fade, constant ReferenceUniformsea59380346749& _196)
{
    float radiusVal = (0.001000000047497451305389404296875 - powr(r - offsetFromCenter, 1.0 / fade)) + sin(r * 30.0);
    radiusVal = fast::max(radiusVal, 0.0);
    return radiusVal * _196.XXC;
}

static inline __attribute__((always_inline))
float renderSmallCircle(thread const float2& pos, thread const float2& ltpos, thread const float& dist, thread const float2& offsetFromCenter, thread const float& size, constant ReferenceUniformsea59380346749& _196)
{
    float2 coord = (pos - ((ltpos * dist) / float2(2.0))) + offsetFromCenter;
    float radiusVal = (_196.XXA / length(coord)) * size;
    radiusVal = fast::max(radiusVal, 0.0);
    return radiusVal;
}

static inline __attribute__((always_inline))
float regularPolygon(thread const float2& p, thread const int& N)
{
    float a = precise::atan2(p.x, p.y) + 0.20000000298023223876953125;
    float b = 6.2831897735595703125 / float(N);
    return smoothstep(0.5, 0.5099999904632568359375, cos((floor(0.5 + (a / b)) * b) - a) * length(p));
}

static inline __attribute__((always_inline))
float renderHexagon(thread const float2& uv, thread const float2& lightPos, thread const float2& offsetFromCenter, thread const float& hexagonIntervalDist, thread const float& size)
{
    float2 hexagonCoord = ((uv * size) + ((lightPos * hexagonIntervalDist) * size)) + offsetFromCenter;
    float2 param = hexagonCoord;
    int param_1 = 6;
    float hexValue = 0.00999999977648258209228515625 - regularPolygon(param, param_1);
    hexValue = fast::max(hexValue, 0.0);
    return hexValue;
}

static inline __attribute__((always_inline))
float3 chromaticAberration(thread const float3& color, thread const float2& pos, thread const float2& ltpos, thread const int& iter, texture2d<float> refImage1, sampler refImage1Smplr, constant ReferenceUniformsea59380346749& _196)
{
    float intensity = _196.XXD;
    float param = float(iter) * 0.712999999523162841796875;
    float amount = ((intensity * length(pos - ltpos)) * rnd(param, refImage1, refImage1Smplr)) * float(iter);
    float3 cyclic_amt = float3(-0.949999988079071044921875, -0.980000019073486328125, -1.0) + (float3(float(iter / 3), float((iter + 1) / 3), float((iter + 2) / 3)) * amount);
    float3 col = color + cyclic_amt;
    return col * (1.0 - (amount * 0.5));
}

static inline __attribute__((always_inline))
float3 LensHighlight(thread const float2& pos, thread const float2& lightPos, thread float3& color, thread const float& size, thread const float& dist, thread const int& i, texture2d<float> refImage1, sampler refImage1Smplr, constant ReferenceUniformsea59380346749& _196)
{
    float bigCircle_size = (size * _196.XXE) * float(i);
    float2 bigCircle_offset = (-lightPos) * float2(2.0);
    float2 param = pos;
    float2 param_1 = lightPos;
    float param_2 = dist;
    float2 param_3 = bigCircle_offset;
    float param_4 = bigCircle_size;
    float bigCircle = renderBigCircle(param, param_1, param_2, param_3, param_4, _196) * 25.0;
    float ring_fade = 7.0 * float(i);
    float2 ring_offset = ((-lightPos) * float2(2.5)) * float(i);
    float ring_size = (size * 5.0) * float(i);
    float lt_coord = length((pos - lightPos) - ring_offset);
    float ring_radius = lt_coord + ring_size;
    float param_5 = ring_radius;
    float param_6 = ring_size;
    float param_7 = ring_fade;
    float ring = renderRing(param_5, param_6, param_7, _196) * 0.20000000298023223876953125;
    float2 smallCircle_offset = lightPos * float2(0.01590000092983245849609375);
    float smallCircle_size = 84.0;
    float2 param_8 = pos;
    float2 param_9 = lightPos;
    float param_10 = dist;
    float2 param_11 = smallCircle_offset;
    float param_12 = smallCircle_size;
    float smallCircle = renderSmallCircle(param_8, param_9, param_10, param_11, param_12, _196) * 0.014999999664723873138427734375;
    float2 hexagon_offset = (((-lightPos) * float2(1.5)) * float(i)) + (lightPos * 0.319999992847442626953125);
    float hexagon_size = 11.0 - (_196.XXH * float(i));
    float hexagon_fade = _196.XXI * powr(float(i), 2.5);
    float2 param_13 = pos;
    float2 param_14 = lightPos;
    float2 param_15 = hexagon_offset;
    float param_16 = dist;
    float param_17 = hexagon_size;
    float hexagon = (renderHexagon(param_13, param_14, param_15, param_16, param_17) * hexagon_fade) * 20.0;
    float3 param_18 = color;
    float2 param_19 = pos;
    float2 param_20 = lightPos;
    int param_21 = i;
    color = chromaticAberration(param_18, param_19, param_20, param_21, refImage1, refImage1Smplr, _196);
    return color * (((smallCircle + bigCircle) + ring) + hexagon);
}

static inline __attribute__((always_inline))
float3 Lensflare(thread const float2& currPos, thread const float2& lightPos, thread const float& distToLight, texture2d<float> refImage1, sampler refImage1Smplr, constant ReferenceUniformsea59380346749& _196)
{
    float3 flareColor = float3(0.0);
    float lt_dist = distToLight + 1.0;
    float proximity_divisor = length(currPos - lightPos);
    float loopVal = 1.0;
    int i = 1;
    for (;;)
    {
        bool _514 = loopVal > 9.9999997473787516355514526367188e-05;
        bool _523;
        if (_514)
        {
            _523 = i < int(_196.MAX_ITERATIONS);
        }
        else
        {
            _523 = _514;
        }
        if (_523)
        {
            float xnxx = float(i);
            float2 pos = currPos;
            float2 lpos = lightPos;
            float param = xnxx * 3.09130001068115234375;
            float3 color_rand = float3(rnd(param, refImage1, refImage1Smplr)) * (2.0 * xnxx);
            float3 col = _196.lightColor.xyz + fast::clamp(color_rand, float3(0.0), float3(1.0));
            float param_1 = xnxx * 21.7730007171630859375;
            float flareSize = ((xnxx * xnxx) * powr(rnd(param_1, refImage1, refImage1Smplr) * 1.7999999523162841796875, 1.0)) + 0.5;
            float param_2 = xnxx * 7.110000133514404296875;
            float flareInterval = (((_196.lensFlareScale + 0.00999999977648258209228515625) / lt_dist) * powr(rnd(param_2, refImage1, refImage1Smplr) * 3.0, _196.XXK)) + 0.0500000007450580596923828125;
            float2 param_3 = pos;
            float2 param_4 = lpos;
            float3 param_5 = col;
            float param_6 = flareSize;
            float param_7 = flareInterval;
            int param_8 = i;
            float3 _600 = LensHighlight(param_3, param_4, param_5, param_6, param_7, param_8, refImage1, refImage1Smplr, _196);
            float3 passColor = _600;
            passColor *= (_196.lensFlareBrightness / (xnxx * 1.14999997615814208984375));
            flareColor += passColor;
            loopVal /= proximity_divisor;
            i++;
            continue;
        }
        else
        {
            break;
        }
    }
    return flareColor;
}

static inline __attribute__((always_inline))
float4 newLayer(thread const float4& a, thread const float4& b)
{
    return (a * (1.0 - b.w)) + b;
}

static inline __attribute__((always_inline))
void referenceMain(texture2d<float> refImage1, sampler refImage1Smplr, constant ReferenceUniformsea59380346749& _196, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr, thread float4& gl_FragCoord)
{
    if (as_type<int>(_196.refComposition.z) == 0)
    {
        float2 param = gl_FragCoord.xy / _196.refScreen.xy;
        referenceColor = texture2DCv(refInput, refInputSmplr, param);
    }
    else
    {
        if (as_type<int>(_196.refComposition.z) == 1)
        {
            float2 param_1 = gl_FragCoord.xy / _196.refScreen.xy;
            float4 texColor = texture2DCv(refInput, refInputSmplr, param_1);
            float4 texColorX = float4(0.0, 0.0, 0.0, 1.0) * texColor.w;
            float2 param_2 = float2(int2(refInput.get_width(), refInput.get_height()));
            float2 image_size = getTexSize(param_2);
            float2 iResolution = float2(_196.refScreen.x, _196.refScreen.y);
            float2 iMouse = float2(0.5);
            float2 syamjaidtz = ((float2((gl_FragCoord.xy / _196.refScreen.xy).x, 1.0 - (gl_FragCoord.xy / _196.refScreen.xy).y) * _196.refScreen.xy) - float2(_196.refLayer.x + (_196.refLayer.z * 0.5), (_196.refScreen.y - _196.refLayer.y) - (_196.refLayer.w * 0.5))) / _196.refLayer.zw;
            syamjaidtz.y *= (_196.refLayer.w / _196.refLayer.z);
            syamjaidtz /= float2(_196.scale);
            float param_3 = (0.0 + _196.angle) * 0.01745329983532428741455078125;
            syamjaidtz *= rot2m(param_3);
            syamjaidtz += ((float2(0.0 + _196.position.x, 0.0 - _196.position.y) * float2(-1.0, 1.0)) / float2(500.0));
            float2 scaleVec = float2(_196.scale * _196.stretch.x, _196.scale * _196.stretch.y);
            syamjaidtz /= scaleVec;
            float3 uv = float3(syamjaidtz, 0.0);
            uv.x *= (_196.refScreen.x / _196.refScreen.y);
            float3 lightPosition = (float3(float2(_196.orient.x + 1.4500000476837158203125, _196.orient.y - 0.85000002384185791015625), -0.100000001490116119384765625) - float3(0.5)) * 0.25;
            float3 lightPos = lightPosition;
            lightPos.x *= (_196.refScreen.x / _196.refScreen.y);
            float distToLight = length(lightPosition - float3(0.0));
            if (((_196.lensFlareScale + 0.00999999977648258209228515625) <= 9.9999999747524270787835121154785e-07) || (distToLight <= 9.9999997473787516355514526367188e-06))
            {
                return;
            }
            float param_4 = distToLight;
            float depthFade = scaleDepth(param_4);
            float2 param_5 = uv.xy;
            float2 param_6 = lightPos.xy;
            float param_7 = distToLight;
            float3 color = Lensflare(param_5, param_6, param_7, refImage1, refImage1Smplr, _196);
            color *= depthFade;
            color = float3(1.0) - exp(((-color) * _196.lensFlareExposure) * depthFade);
            color = fast::max(color, float3(0.0));
            float uvDistToLight = length(uv.xy - lightPos.xy);
            float lightsrc = fast::clamp(1.0 - (uvDistToLight * 7.0), 0.0, 1.0);
            float ray_factor = 1.0;
            float a = ray_factor * precise::atan2(uv.y - lightPos.y, uv.x - lightPos.x);
            lightsrc += ((fast::max(0.100000001490116119384765625 / powr(abs(uvDistToLight) * 5.0, 5.0), 0.0) * abs(sin((a * 5.0) + cos(a * 9.0)))) / 20.0);
            lightsrc += (fast::max(0.100000001490116119384765625 / powr(abs(uvDistToLight) * 10.0, 0.0500000007450580596923828125), 0.0) + (((abs(sin((a * 3.0) + cos(a * 9.0))) / 8.0) * abs(sin(a * 9.0))) / 1.0));
            float lightsrc_attenuation = (depthFade * (1.0 - (uvDistToLight * uvDistToLight))) * 1.0;
            color += float3(lightsrc * lightsrc_attenuation);
            float alphax = (depthFade * ((color.x + color.y) + color.z)) / 3.0;
            float4 fragColor = float4(color, alphax);
            float4 factorx = mix(texColorX, fragColor, float4(1.0));
            float4 param_8 = _196.bgColor;
            float4 param_9 = factorx;
            float4 factor = newLayer(param_8, param_9);
            float4 resultfinal;
            if (_196.blendMode == 0)
            {
                resultfinal = (factor * _196.hardness) * texColor.w;
            }
            else
            {
                if (_196.blendMode == 1)
                {
                    factor *= _196.hardness;
                    float4 c = factor + (float4(1.0) * (1.0 - factor.w));
                    resultfinal = float4((texColor.xyz / float3(texColor.w)) * c.xyz, 1.0) * texColor.w;
                }
                else
                {
                    if (_196.blendMode == 2)
                    {
                        factor *= _196.hardness;
                        resultfinal = float4(float3(1.0) - ((float3(1.0) - (texColor.xyz / float3(texColor.w))) * (float3(1.0) - factor.xyz)), 1.0) * texColor.w;
                    }
                    else
                    {
                        if (_196.blendMode == 3)
                        {
                            factor *= _196.hardness;
                            float4 param_10 = texColor;
                            float4 param_11 = factor;
                            resultfinal = newLayer(param_10, param_11) * texColor.w;
                        }
                    }
                }
            }
            referenceColor = mix(texColor, resultfinal, float4(_196.alpha)) * texColor.w;
        }
    }
}

fragment refAM35_ea59380346749_out refAM35_ea59380346749(constant ReferenceUniformsea59380346749& _196 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], texture2d<float> refImage1 [[texture(1)]], sampler refInputSmplr [[sampler(0)]], sampler refImage1Smplr [[sampler(1)]], float4 gl_FragCoord [[position]])
{
    refAM35_ea59380346749_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(refImage1, refImage1Smplr, _196, referenceColor, refInput, refInputSmplr, gl_FragCoord);
    bool _1109 = any(isnan(referenceColor));
    bool _1116;
    if (!_1109)
    {
        _1116 = any(isinf(referenceColor));
    }
    else
    {
        _1116 = _1109;
    }
    if (_1116)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _1129 = referenceColor;
    float3 _1135 = fast::clamp(_1129.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _1135.x;
    referenceColor.y = _1135.y;
    referenceColor.z = _1135.z;
    out.finalColor = referenceColor;
    return out;
}

