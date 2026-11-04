#include <metal_stdlib>
using namespace metal;
struct Params23 { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler sample23(coord::pixel, address::clamp_to_zero, filter::linear);
constexpr sampler edge23(coord::pixel, address::clamp_to_edge, filter::linear);

kernel void fx23(texture2d<half, access::sample> src [[texture(0)]],
                 texture2d<half, access::write> dst [[texture(1)]],
                 constant Params23& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 xy = float2(gid) + 0.5;
    float4 original = float4(src.sample(sample23, xy)), result = original;
    float2 extent = max(p.d.zw, float2(1));
    float2 uv = (xy - p.d.xy) / extent;
    if (p.i.x == 0) {
        // Measure radial distance in layer-height units so circles stay circular on wide layers.
        float2 delta = (uv - p.b.xy) * float2(extent.x / extent.y, 1);
        float distance = length(delta), r = distance * p.a.w;
        float wave = r * p.a.y - p.a.z;
        float attenuation = exp(-r * p.b.z);
        float2 direction = distance > 1e-6 ? delta / distance : float2(0);
        float2 displacement = direction * sin(wave) * attenuation * p.a.x * extent.y;
        float4 bent = float4(src.sample(sample23, xy + displacement));
        // Narrow luminous crests are independent of displacement, including on a solid layer.
        float highlight = pow(abs(cos(wave)), p.c.w) * attenuation * p.b.w * 0.5;
        bent.rgb += p.c.rgb * highlight * bent.a;
        result = mix(original, bent, float(p.i.y) / 10000.0);
    } else if (p.i.x == 1) {
        float coordinate = dot(uv - 0.5, float2(cos(p.a.w), -sin(p.a.w))) + 0.5;
        float thresholdPosition = coordinate - p.b.x * (1 + p.a.y);
        float threshold = p.a.y > 1e-6 ? smoothstep(-p.a.y, 0.0, thresholdPosition) : step(0.0, thresholdPosition);
        float cell = fract(coordinate * p.a.x);
        float coverage = p.a.z > 1e-6 ? smoothstep(threshold, threshold + p.a.z, cell) : step(threshold, cell);
        if (p.i.y != 0) coverage = 1 - coverage;
        result = p.i.z == 1 ? float4(coverage) : original * coverage;
    } else {
        // Antialiased print screen. Centering on the layer keeps padding changes from moving dots.
        float ca = cos(p.a.y), sa = sin(p.a.y);
        float2x2 rotation = float2x2(ca, sa, -sa, ca);
        float cellSize = max(p.a.x, p.i.w == 1 ? 0.01 : 1.0);
        float2 grid = rotation * (xy - p.d.xy - extent * 0.5) / cellSize;
        float row = floor(grid.y), shift = (int(row) & 1) != 0 ? p.a.w : 0;
        float2 center = float2(floor(grid.x - shift) + shift + 0.5, row + 0.5);
        if (p.i.w == 1) {
            float nearestRow = floor(grid.y + 0.5);
            float rowShift = (int(nearestRow) & 1) != 0 ? p.a.w : 0;
            center = float2(floor(grid.x + rowShift + 0.5) - rowShift, nearestRow);
        }
        float2 samplePoint = transpose(rotation) * (center * cellSize) + p.d.xy + extent * 0.5;
        samplePoint = clamp(samplePoint, p.d.xy + 0.5, p.d.xy + extent - 0.5);
        float4 inkSample = float4(src.sample(edge23, samplePoint));
        float3 color = inkSample.a > 1e-6 ? saturate(inkSample.rgb / inkSample.a) : float3(1);
        float3 darkness = p.i.y != 0 ? 1 - color : float3(1 - dot(color, float3(0.2126, 0.7152, 0.0722)));
        darkness = pow(saturate(darkness), float3(p.a.z));
        float3 radius = sqrt(darkness / M_PI_F);
        // Full black and white must remain full black and white, even at grid corners.
        float3 coverage = 1 - smoothstep(radius - 0.65 / cellSize, radius + 0.65 / cellSize, float3(length(grid - center)));
        coverage = select(coverage, float3(0), darkness <= 0.00001);
        coverage = select(coverage, float3(1), darkness >= 0.99999);
        if (p.i.w == 1) {
            float3 tone = p.i.y != 0 ? inkSample.rgb : float3(dot(inkSample.rgb, float3(0.2126, 0.7152, 0.0722)));
            coverage = 1 - smoothstep(float3(0.4), float3(0.6), tone + (1 - inkSample.a) + length(grid - center) + p.a.z - 0.5);
        }
        float4 ink = float4(p.b.rgb * p.b.a, p.b.a), paper = float4(p.c.rgb * p.c.a, p.c.a);
        float4 screen = mix(paper, ink, float4(coverage, dot(coverage, float3(0.3333333))));
        float3 channelAlpha = mix(float3(paper.a), float3(ink.a), coverage);
        screen.a = max(channelAlpha.r, max(channelAlpha.g, channelAlpha.b));
        screen *= original.a;
        result = mix(original, screen, float(p.i.z) / 10000.0);
    }
    dst.write(half4(result), gid);
}
