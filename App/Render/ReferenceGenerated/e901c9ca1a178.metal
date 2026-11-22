// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/active_blackhole.xml
// Original source comments and attribution:
// Vector from center to current pixel
// Aspect Ratio Correction (essential for circular shape)
// Scale size relative to aspect roughly or just keep raw units?
// circlewipe.xml just uses raw dist.
// But usually 'size' feels more natural if it scales.
// Logic from user: radius (size).
// Warp Logic (Only outside the hole)
// Pull factor: 1.0 at edge, approaches 0.0 further away
// Square it for stronger gravity near edge
// Direction to pull: towards center. 
// p is (current - center), so normalize(p) points AWAY from center.
// We want to pull UVs towards center?
// Actually, to PULL the image content IN, we need to look up pixels from FURTHER OUT?
// No, a black hole sucks things IN.
// If I am at pixel X (near hole), I want to see content that was significantly further away at pixel Y.
// So I should sample from a position CLOSER to the image source?
// Let's stick to the user's shadertoy logic:
// warpedUV -= normalize(p) * offsetAmount;
// normalize(p) is direction FROM center.
// subtracting it moves the lookup point TOWARDS the center.
// Wait, if I look up a point closer to center, I see what's INSIDE the hole?
// If the hole is black, looking towards the center sees black?
// The Shadertoy says: "Move the UV towards the center (sucking effect)"
// Re-verification of user logic:
// vec2 p = uv - 0.5; (vector from center)
// warpedUV -= normalize(p) * offsetAmount;
// If I'm at (0.6, 0.5) (right of center), p is (0.1, 0).
// warpedUV becomes (0.6, 0.5) - (1,0)*offset = (0.55, 0.5).
// I read from (0.55), which is CLOSER to the center.
// Visual effect: The pixel at 0.6 displays the color of the pixel at 0.55.
// This means the content at 0.55 has been "stretched" out to 0.6.
// Yes, that looks like space expanding/stretching near the hole.
// However, we need to handle aspect correction in the warp vector too if we want it perfect?
// The user logic just uses 'p' which WAS aspect corrected for distance.
// But specifically: `uv -= normalize(p) * offset`.
// If we use the aspect-corrected p for direction, it's correct for the shape.
// But the MAGNITUDE `offsetAmount` applies to UV space directly.
// Since UV space is non-square (0-1), a uniform shift looks oval.
// Usually we un-aspect the shift.
// Account for non-square UV pixels
// Note: User code didn't do `shift.x /= aspect`. It did `p.x *= aspect` then `norm(p)`.
// Let's stick closest to user logic first.
// User code: `warpedUV -= normalize(p) * offsetAmount;`
// `p` had x multiplied.
// Let's replicate exact user math.
// p is aspect corrected
// The shift in UV space:
// Correction for Alight Motion UVs (if distinct from Shadertoy's square-ish pixels logic? 
// Shadertoy `fragCoord/res` is 0-1 non-square.
// User's code: `p.x *= aspect`. `warpedUV -= normalize(p) * ...`
// This implies the shift is applied directly.
// However, `normalize(p)` will have the skew of the aspect.
// If we apply it to `WarppedUV` (0-1 space), X moves 'less' visually than Y because X is wider?
// Actually, if screen is wide, 0.1 in X is MORE pixels than 0.1 in Y.
// Let's act strictly on the user code provided.
// But wait! Shadertoy user output:
// `p` is aspect corrected.
// `normalize(p)` is unit vector in that corrected space.
// `warpedUV` is 0-1.
// Subtracting a unit-ish vector from 0-1 UVs usually distorts.
// But the user code IS the source of truth requested. I will follow it.
// EXCEPT: I must un-aspect the shift X component if I want to match visual intent on non-1:1 screens?
// The user says "Fix aspect ratio (keeps black hole circular)". 
// They did that for 'p', which controls 'dist'.
// They reused 'p' for logical direction.
// I'll add aspect compensation to the shift to be safe, creating a perfect circular pull.
// Sample
// Mask
// User: `smoothstep(radius - 0.005, radius + 0.005, dist)`
// We use 'size' and 'feather'.
// Apply mask (Inside is black/transparent)
// User code: col *= mask (creates black hole).
// Does user want transparency or black?
// "edge of mask act as black hole".
// Alight Motion usually uses transparency for "nothing".
// If I return opacity 1 and color 0, it's black.
// If I multiply alpha, it's transparent.
// circlewipe uses transparency.
// I will multiply the whole vec4.
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformse901c9ca1a178
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float size;
    char _m6_pad[12];
    float distortion;
    char _m7_pad[12];
    float feather;
    char _m8_pad[12];
    float centerX;
    char _m9_pad[12];
    float centerY;
    char _m10_pad[12];
    uint invert;
};

struct refAM35_e901c9ca1a178_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 texture2DCv(texture2d<float> source, sampler sourceSmplr, thread const float2& uv)
{
    return source.sample(sourceSmplr, uv);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse901c9ca1a178& _34, texture2d<float> refInput, sampler refInputSmplr, thread float4& referenceColor)
{
    float2 uv = gl_FragCoord.xy / _34.refScreen.xy;
    float2 center = float2(_34.centerX, _34.centerY);
    float2 p = uv - center;
    float aspect = _34.refScreen.x / _34.refScreen.y;
    p.x *= aspect;
    float dist = length(p);
    float2 warpedUV = uv;
    if (dist > _34.size)
    {
        float pull = _34.size / dist;
        float offsetAmount = powr(pull, 2.0) * _34.distortion;
        float2 shift = fast::normalize(p) * offsetAmount;
        shift.x /= aspect;
        float2 dir = fast::normalize(p);
        float2 shiftVector = dir * offsetAmount;
        shiftVector.x /= aspect;
        warpedUV -= shiftVector;
    }
    float2 param = warpedUV;
    float4 tex = texture2DCv(refInput, refInputSmplr, param);
    float mask = smoothstep(_34.size - _34.feather, _34.size + _34.feather, dist);
    if (_34.invert != 0u)
    {
        mask = 1.0 - mask;
    }
    referenceColor = tex * mask;
}

fragment refAM35_e901c9ca1a178_out refAM35_e901c9ca1a178(constant ReferenceUniformse901c9ca1a178& _34 [[buffer(0)]], texture2d<float> refInput [[texture(0)]], sampler refInputSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e901c9ca1a178_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _34, refInput, refInputSmplr, referenceColor);
    bool _161 = any(isnan(referenceColor));
    bool _168;
    if (!_161)
    {
        _168 = any(isinf(referenceColor));
    }
    else
    {
        _168 = _161;
    }
    if (_168)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _183 = referenceColor;
    float3 _189 = fast::clamp(_183.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _189.x;
    referenceColor.y = _189.y;
    referenceColor.z = _189.z;
    out.finalColor = referenceColor;
    return out;
}

