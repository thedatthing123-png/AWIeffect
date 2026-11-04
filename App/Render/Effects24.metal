#include <metal_stdlib>
using namespace metal;
struct Params24 { float4 a,b,c,d; uint4 i; };
constexpr sampler zero24(coord::pixel, address::clamp_to_zero, filter::linear);
constexpr sampler edge24(coord::pixel, address::clamp_to_edge, filter::linear);
float luma24(float4 c) { return dot(c.a > 1e-6 ? c.rgb / c.a : float3(0), float3(0.2126, 0.7152, 0.0722)); }
bool inside24(texture2d<half, access::read> image, int2 p) {
    return all(p >= 0) && p.x < int(image.get_width()) && p.y < int(image.get_height()) && image.read(uint2(p)).a >= 0.5h;
}
kernel void fx24Seed(texture2d<half, access::read> src [[texture(0)]], texture2d<float, access::write> dst [[texture(1)]], constant Params24& params [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 position = (float2(gid) + 0.5) * params.a.xy;
    int2 p = int2(floor(position)); bool inside = inside24(src, p);
    float2 seed = float2(-1);
    const int2 offsets[4] = {int2(-1,0),int2(1,0),int2(0,-1),int2(0,1)};
    for (int i = 0; i < 4; i++) {
        if (inside != inside24(src, int2(floor(position + float2(offsets[i]) * params.a.xy)))) { seed = position + float2(offsets[i]) * params.a.xy * 0.5; break; }
    }
    dst.write(float4(seed, 0, 1), gid);
}
kernel void fx24Jump(texture2d<float, access::read> src [[texture(0)]], texture2d<float, access::write> dst [[texture(1)]],
                      constant Params24& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 xy = (float2(gid) + 0.5) * p.a.xy, best = float2(-1); float score = INFINITY;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        int2 q = int2(gid) + int2(x,y) * int(p.i.x);
        if (any(q < 0) || q.x >= int(src.get_width()) || q.y >= int(src.get_height())) continue;
        float2 candidate = src.read(uint2(q)).xy;
        if (candidate.x < 0) continue;
        float distance = dot(candidate - xy, candidate - xy);
        if (distance < score) { score = distance; best = candidate; }
    }
    dst.write(float4(best, 0, 1), gid);
}
kernel void fx24Image(texture2d<half, access::sample> src [[texture(0)]], texture2d<half, access::write> dst [[texture(1)]],
                       texture2d<float, access::read> auxiliary [[texture(2)]], constant Params24& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 xy = float2(gid) + 0.5; float4 original = float4(src.sample(zero24, xy)), result = original;
    if (p.i.x <= 2) {
        uint2 fieldSize = uint2(auxiliary.get_width(), auxiliary.get_height());
        uint2 fieldPixel = min(uint2(xy / p.c.xy * float2(fieldSize)), fieldSize - 1);
        float2 nearest = auxiliary.read(fieldPixel).xy;
        float distance = nearest.x >= 0 ? length(xy-nearest) : 1e6;
        bool inside = original.a >= 0.5;
        float sign = inside ? 1.0 : -1.0;
        if (p.i.x == 0) {
            float value = saturate(0.5 + sign * distance / (2 * max(p.a.x, 0.01)) + p.a.y * 0.5);
            result = float4(float3(value), 1);
        } else if (p.i.x == 1) {
            float spacing = max(p.a.x, 0.1), phase = distance / spacing - p.a.z;
            float edgeDistance = abs(fract(phase + 0.5) - 0.5) * spacing;
            float band = (1 - smoothstep(max(0.0,p.a.y*0.5-0.75),p.a.y*0.5+0.75,edgeDistance)) * (1 - smoothstep(p.a.w-1,p.a.w+1,distance));
            if ((p.i.y == 1 && !inside) || (p.i.y == 2 && inside)) band = 0;
            float alpha = band * p.b.a;
            result = float4(p.b.rgb * alpha + original.rgb * (1-alpha), alpha + original.a*(1-alpha));
        } else {
            float2 direction = distance > 1e-5 && distance < 1e5 ? (xy-nearest)/distance*sign : float2(0);
            float fade = 1 - smoothstep(0.0,max(p.a.y,0.01),distance);
            result = float4(src.sample(zero24, xy + direction * p.a.x * fade));
        }
    } else if (p.i.x == 3) {
        float base = auxiliary.read(gid).a;
        float alpha = saturate(base * p.a.x + (original.a - base) * p.a.y);
        float3 color = original.a > 1e-5 ? original.rgb / original.a : float3(0);
        // Newly expanded pixels use the blurred premultiplied color, avoiding black fringes.
        if (original.a <= 1e-5) { float4 blurred = auxiliary.read(gid); color = blurred.a > 1e-5 ? blurred.rgb / blurred.a : float3(0); }
        result = float4(color * alpha, alpha);
    } else if (p.i.x == 4) {
        float delta = luma24(original) - luma24(auxiliary.read(gid));
        if (p.i.y != 0) delta = -delta;
        float coverage = smoothstep(p.a.x, p.a.x + max(p.a.y,0.0001), delta);
        result = original * mix(1.0, coverage, p.a.z);
    }
    dst.write(half4(result),gid);
}
