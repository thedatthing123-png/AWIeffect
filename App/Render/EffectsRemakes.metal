#include <metal_stdlib>
using namespace metal;

struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

kernel void fxEdgeCurrent(texture2d<half, access::sample> input [[texture(0)]],
                          texture2d<half, access::write> output [[texture(1)]],
                          constant EffectParams& p [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    constexpr sampler sampleEdge(coord::normalized, address::clamp_to_zero, filter::linear);
    const float2 size = float2(input.get_width(), input.get_height());
    const float2 pixel = float2(gid) + 0.5;
    const float4 src = float4(input.sample(sampleEdge, pixel / size));
    const float2 relative = pixel - p.a.xy;
    const float bearing = atan2(relative.y, relative.x) / 6.28318530718;
    const float distance = abs(fract(bearing - p.a.z + 0.5) - 0.5);
    if (distance >= p.a.w) {
        output.write(half4(src), gid);
        return;
    }

    const float2 radius = max(0.5, p.b.x) / size;
    const float2 uv = pixel / size;
    const float2 directions[] = {
        float2(1, 0), float2(0, 1), float2(-1, 0), float2(0, -1),
        float2(0.7071, 0.7071), float2(-0.7071, 0.7071),
        float2(-0.7071, -0.7071), float2(0.7071, -0.7071)
    };
    float low = src.a;
    float high = src.a;
    for (uint index = 0; index < 8; ++index) {
        const float alpha = float(input.sample(sampleEdge, uv + radius * directions[index]).a);
        low = min(low, alpha);
        high = max(high, alpha);
    }
    const float arc = 1 - smoothstep(0.08 * p.a.w, p.a.w, distance);
    const float intensity = p.b.y * arc * p.c.a;
    const float outer = saturate((high - src.a) * intensity * 0.65) * (1 - src.a);
    const float inner = saturate((src.a - low) * intensity);
    const float3 lit = src.rgb + (src.a - min(src.rgb, src.a)) * saturate(p.c.rgb * inner);
    output.write(half4(float4(lit + p.c.rgb * outer, src.a + outer)), gid);
}

kernel void fxSyncRoll(texture2d<half, access::sample> input [[texture(0)]],
                       texture2d<half, access::write> output [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    constexpr sampler sampleFrame(coord::normalized, address::clamp_to_zero, filter::linear);
    const float2 size = float2(input.get_width(), input.get_height());
    const float2 pixel = float2(gid) + 0.5;
    const float4 src = float4(input.sample(sampleFrame, pixel / size));
    const float2 frameSize = max(p.a.zw, float2(1));
    const float2 local = (pixel - p.a.xy) / frameSize;
    if (any(local < 0) || any(local >= 1)) {
        output.write(half4(src), gid);
        return;
    }

    const float rightPhase = local.x >= p.c.y ? p.c.z : 0;
    const float y = fract(local.y - p.b.x - rightPhase);
    const float seam = p.b.y > 0 ? 1 - smoothstep(0.0, p.b.y, min(y, 1 - y)) : 0;
    const float2 samplePixel = p.a.xy + float2(local.x * frameSize.x + p.c.x * seam, y * frameSize.y);
    const float2 sampleLocal = (samplePixel - p.a.xy) / frameSize;
    float4 rolled = 0;
    if (sampleLocal.x >= 0 && sampleLocal.x < 1) {
        const float2 safePixel = clamp(samplePixel, p.a.xy + 0.5, p.a.xy + frameSize - 0.5);
        rolled = float4(input.sample(sampleFrame, safePixel / size));
        rolled.rgb *= 1 - seam * p.b.z;
    }
    output.write(half4(mix(src, rolled, p.b.w)), gid);
}

float remakeLuma(float4 color) {
    return dot(color.rgb / max(color.a, 0.0001), float3(0.2126, 0.7152, 0.0722));
}

kernel void fxLineHold(texture2d<half, access::sample> input [[texture(0)]],
                       texture2d<half, access::write> output [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    constexpr sampler linearSampler(coord::normalized, address::clamp_to_zero, filter::linear);
    const float2 size = float2(input.get_width(), input.get_height());
    const float2 pixel = float2(gid) + 0.5;
    const float4 src = float4(input.sample(linearSampler, pixel / size));
    const float2 layer = max(p.a.zw, float2(1));
    const float2 local = (pixel - p.a.xy) / layer;
    const float fromBand = local.y - p.b.y;
    if (any(local < 0) || any(local >= 1) || abs(fromBand) >= p.b.z) {
        output.write(half4(src), gid);
        return;
    }
    const float feather = min(p.b.z, max(0.5 / layer.y, p.b.w));
    const float weight = 1 - smoothstep(p.b.z - feather, p.b.z, abs(fromBand));
    const float2 sampleOffset = float2(pixel.x - p.a.x + fromBand / p.b.z * p.c.x, p.b.x * layer.y);
    const float2 line = p.a.xy + clamp(sampleOffset, float2(0.5), layer - 0.5);
    const float4 color = float4(input.sample(linearSampler, line / size));
    output.write(half4(mix(src, color, weight * p.c.y)), gid);
}

kernel void fxInkOverprint(texture2d<half, access::sample> input [[texture(0)]],
                           texture2d<half, access::write> output [[texture(1)]],
                           constant EffectParams& p [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    constexpr sampler linearSampler(coord::normalized, address::clamp_to_zero, filter::linear);
    const float2 size = float2(input.get_width(), input.get_height());
    const float2 pixel = float2(gid) + 0.5;
    const float4 src = float4(input.sample(linearSampler, pixel / size));
    if (src.a <= 0.0001) {
        output.write(half4(src), gid);
        return;
    }
    const float4 plate = as_type<float4>(p.i);
    const float4 shifted = float4(input.sample(linearSampler, (pixel - plate.xy) / size));
    const float black = 1 - smoothstep(p.a.x - 0.035, p.a.x + 0.035, remakeLuma(src));
    const float mid = (1 - smoothstep(p.a.y - 0.12, p.a.y, remakeLuma(shifted))) * shifted.a;
    const float pitch = max(2.0, p.a.z);
    const float2 raster = float2(dot(pixel, plate.zw), dot(pixel, float2(-plate.w, plate.z))) / pitch;
    const float radial = length(fract(raster) - 0.5);
    const float dotSize = 0.48 * sqrt(mid);
    const float aa = min(0.2, 0.5 / pitch);
    const float printDots = mid > 0 ? 1 - smoothstep(max(0.0, dotSize - aa), dotSize + aa, radial) : 0;
    const float3 ink = mix(p.d.rgb, p.c.rgb, printDots * p.c.a);
    const float3 result = mix(ink, ink * p.b.rgb, black * p.b.a);
    output.write(half4(mix(src, float4(result * src.a, src.a), p.a.w * p.d.a)), gid);
}

kernel void fxSortBands(texture2d<half, access::read> input [[texture(0)]],
                        texture2d<half, access::write> output [[texture(1)]],
                        constant EffectParams& p [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    const bool vertical = p.i.y == 1;
    const uint coordinate = vertical ? gid.y : gid.x;
    const uint blockLength = clamp(p.i.x, 2u, 32u);
    if (coordinate % blockLength != 0) return;
    const uint limit = vertical ? output.get_height() : output.get_width();
    const uint count = min(blockLength, limit - coordinate);
    const uint2 step = vertical ? uint2(0, 1) : uint2(1, 0);
    half4 originals[32];
    half4 ordered[32];
    float brightness[32];
    uint runStart = 0;
    const float direction = p.i.z == 1 ? -1.0 : 1.0;

    for (uint index = 0; index < count; ++index) {
        const half4 color = input.read(gid + index * step);
        originals[index] = color;
        const float luma = remakeLuma(float4(color));
        if (float(color.a) < 0.5 || luma < p.a.x) {
            ordered[index] = color;
            runStart = index + 1;
            continue;
        }
        const float key = luma * direction;
        uint position = index;
        while (position > runStart && brightness[position - 1] > key) {
            brightness[position] = brightness[position - 1];
            ordered[position] = ordered[position - 1];
            --position;
        }
        brightness[position] = key;
        ordered[position] = color;
    }
    for (uint index = 0; index < count; ++index) {
        output.write(half4(mix(float4(originals[index]), float4(ordered[index]), p.a.y)), gid + index * step);
    }
}

kernel void fxPanelFlash(texture2d<half, access::read> input [[texture(0)]],
                         texture2d<half, access::write> output [[texture(1)]],
                         constant EffectParams& p [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    const float4 src = float4(input.read(gid));
    const float distance = abs(dot(float2(gid) + 0.5 - p.a.xy, p.a.zw));
    const float feather = max(0.5, p.b.y);
    const float mask = 1 - smoothstep(p.b.x - feather * 0.5, p.b.x + feather * 0.5, distance);
    const float tone = smoothstep(p.b.z - 0.025, p.b.z + 0.025, remakeLuma(src));
    const float4 ink = mix(p.c, p.d, tone);
    output.write(half4(float4(mix(src.rgb, ink.rgb * src.a, mask * p.b.w * ink.a), src.a)), gid);
}
