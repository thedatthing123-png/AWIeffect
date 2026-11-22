// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/cclens.xml
// Original source comments and attribution:
// 1. NORMALIZE COORDINATES
// acScreenNorm is 0.0 to 1.0 (bottom-left to top-right).
// We want (0,0) to be in the CENTER for easier circle math.
// So we subtract 0.5. Range becomes -0.5 to 0.5.
// 2. ASPECT RATIO CORRECTION
// Screens are usually rectangles, not squares.
// If we draw a circle on a rectangle using raw 0-1 coords, it looks like an oval.
// We fix this by multiplying the X coordinate by the aspect ratio.
// 3. CALCULATE DISTANCE & ANGLE
// We convert Cartesian (x,y) to Polar (radius, angle) coordinates.
// How far from center?
// What direction?
// 4. CALCULATE SPHERICAL DISTORTION
// This is the core "Lens" math.
// We normalize the distance based on the 'size' parameter.
// size is a percentage, so we divide by 100.0.
// If the pixel is outside the lens radius, we don't distort it (or we mask it).
// For a true "Orb" effect, anything outside is transparent.
// You can choose to:
// a) Discard (transparent)
// b) Show original (return texture2DCv(inputImg.texture, acScreenNorm))
// Let's make it transparent for a clean Orb look.
// Map the 0->radius distance to 0->1 range for easier math
// Apply the distortion curve.
// A simple way to get a sphere look is using separate formulas for X and Y or 
// just using a power function on the distance.
// Here we simulate the surface of a sphere using cosine interpolation.
// As 'convergence' changes, we modify the curve.
// Height of the sphere at this point
// New distance from center
// Scale it back up
// Adjustment factor
// 5. CONVERT BACK TO UV
// New UV position based on the new distance 'r' and original 'angle'.
// Undo Aspect Ratio Correction
// Shift back to 0.0->1.0 range
// 6. SAMPLE & OUTPUT
// Read the texture at the distorted position.
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformseb87bbcbaa3b5
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float size;
    char _m6_pad[12];
    float convergence;
};

struct refAM35_eb87bbcbaa3b5_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformseb87bbcbaa3b5& _33, thread float4& referenceColor, texture2d<float> refInput, sampler refInputSmplr)
{
    float2 uv = (gl_FragCoord.xy / _33.refScreen.xy) - float2(0.5);
    float aspect = _33.refScreen.x / _33.refScreen.y;
    uv.x *= aspect;
    float dist = length(uv);
    float angle = precise::atan2(uv.y, uv.x);
    float radius = _33.size / 100.0;
    if (dist > radius)
    {
        referenceColor = float4(0.0);
        return;
    }
    float normalizedDist = dist / radius;
    float z = sqrt(1.0 - (normalizedDist * normalizedDist));
    float r = precise::atan2(normalizedDist, z * _33.convergence) / 3.1415927410125732421875;
    r *= 2.0;
    float2 newUV;
    newUV.x = r * cos(angle);
    newUV.y = r * sin(angle);
    newUV.x /= aspect;
    newUV += float2(0.5);
    float2 param = newUV;
    referenceColor = texture2DCv(refInput, refInputSmplr, param);
}

fragment refAM35_eb87bbcbaa3b5_out refAM35_eb87bbcbaa3b5(constant ReferenceUniformseb87bbcbaa3b5& _33 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_eb87bbcbaa3b5_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _33, referenceColor, refInput, refInputSmplr);
    bool _137 = any(isnan(referenceColor));
    bool _144;
    if (!_137)
    {
        _144 = any(isinf(referenceColor));
    }
    else
    {
        _144 = _137;
    }
    if (_144)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _159 = referenceColor;
    float3 _165 = fast::clamp(_159.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _165.x;
    referenceColor.y = _165.y;
    referenceColor.z = _165.z;
    out.finalColor = referenceColor;
    return out;
}

