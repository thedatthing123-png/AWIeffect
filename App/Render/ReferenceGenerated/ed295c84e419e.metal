// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/warpgeid.xml
// Original source comments and attribution:
// Helper function for 2D rotation
// Center UVs to -0.5 to 0.5
// Maintain aspect ratio
// --- Rotozoom ---
// Exponential zoom for smoother effect
// Apply rotation
// Apply zoom
// --- Warp Effect (using sine waves) ---
// This adds a subtle, wave-like distortion
// --- Create the Grid ---
// Take the fractional part of UVs multiplied by gridSize.
// This creates a repeating pattern where each cell goes from 0 to 1.
// Calculate the thickness of the grid lines
// 5% of the cell size
// Check if the pixel is near the edge of a grid cell
// We're looking for values close to 0 or 1 for both x and y.
// Combine X and Y lines (if either is a line, it's a grid line)
// Clamp to 1.0 for clean white lines
// Interpolate between background and grid color
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ReferenceUniformsed295c84e419e
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float gridSize;
    char _m6_pad[12];
    float rotationSpeed;
    char _m7_pad[12];
    float zoomSpeed;
    char _m8_pad[12];
    float warpAmount;
    char _m9_pad[12];
    float warpFrequency;
    float4 gridColor;
    float4 bgColor;
};

struct refAM35_ed295c84e419e_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float2x2 rotate2d(thread const float& angle)
{
    return float2x2(float2(cos(angle), -sin(angle)), float2(sin(angle), cos(angle)));
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformsed295c84e419e& _42, thread float4& referenceColor)
{
    float2 uv = (gl_FragCoord.xy - _42.refLayer.xy) / _42.refLayer.zw;
    uv -= float2(0.5);
    uv.x *= (_42.refLayer.z / _42.refLayer.w);
    float time = _42.refScreen.z;
    float zoom = exp(time * _42.zoomSpeed);
    float angle = time * _42.rotationSpeed;
    float param = angle;
    uv = rotate2d(param) * uv;
    uv *= zoom;
    uv.x += (sin((uv.y * _42.warpFrequency) + (time * 0.5)) * _42.warpAmount);
    uv.y += (cos((uv.x * _42.warpFrequency) - (time * 0.300000011920928955078125)) * _42.warpAmount);
    float2 grid = fract(uv * _42.gridSize);
    float lineWidth = 0.0500000007450580596923828125;
    float lineX = step(1.0 - lineWidth, grid.x) + (step(lineWidth, grid.x) * step(grid.x, lineWidth));
    float lineY = step(1.0 - lineWidth, grid.y) + (step(lineWidth, grid.y) * step(grid.y, lineWidth));
    float isGridLine = fast::min(lineX + lineY, 1.0);
    float3 finalColor = mix(_42.bgColor.xyz, _42.gridColor.xyz, float3(isGridLine));
    referenceColor = float4(finalColor, 1.0);
}

fragment refAM35_ed295c84e419e_out refAM35_ed295c84e419e(constant ReferenceUniformsed295c84e419e& _42 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_ed295c84e419e_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _42, referenceColor);
    bool _206 = any(isnan(referenceColor));
    bool _213;
    if (!_206)
    {
        _213 = any(isinf(referenceColor));
    }
    else
    {
        _213 = _206;
    }
    if (_213)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _226 = referenceColor;
    float3 _232 = fast::clamp(_226.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _232.x;
    referenceColor.y = _232.y;
    referenceColor.z = _232.z;
    out.finalColor = referenceColor;
    return out;
}

