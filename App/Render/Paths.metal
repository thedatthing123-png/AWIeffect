#include <metal_stdlib>
using namespace metal;

// Bezier paths arrive flattened into line segments (x0, y0, x1, y1) in layer-local pixels.
// Must match PathParams in PathRenderer.swift.
struct PathParams {
    float4 invRow0;   // target px -> local px (affine row 0)
    float4 invRow1;   // row 1
    float4 fill;      // straight RGBA fill (a = 0 -> no fill)
    float4 stroke;    // straight RGBA stroke
    float4 geom;      // strokeWidth, opacity (0-1), aa (local px per target px), feather (masks)
    float4 geom2;     // expansion (masks), maskOpacity, initial acc (first mask), _
    uint4  info;      // segCount, strokeSegStart, strokeSegCount, mode/blend
    uint4  info2;     // inverted, region.x, region.y, _
    uint4  region;    // x0, y0, w, h
};

// Signed distance (negative inside) to the path using even-odd/nonzero winding.
static float pathDistance(float2 q, device const float4* segs, uint count, thread int& winding) {
    float d = 1e20;
    winding = 0;
    for (uint i = 0; i < count; i++) {
        float2 a = segs[i].xy, b = segs[i].zw;
        float2 e = b - a, w = q - a;
        float h = clamp(dot(w, e) / max(dot(e, e), 1e-12), 0.0, 1.0);
        d = min(d, length(w - e * h));
        // Nonzero winding (crossing test).
        if (a.y <= q.y) {
            if (b.y > q.y && (e.x * w.y - e.y * w.x) > 0.0) winding++;
        } else {
            if (b.y <= q.y && (e.x * w.y - e.y * w.x) < 0.0) winding--;
        }
    }
    return d;
}

static float strokeDistance(float2 q, device const float4* segs, uint start, uint count) {
    float d = 1e20;
    for (uint i = start; i < start + count; i++) {
        float2 a = segs[i].xy, b = segs[i].zw;
        float2 e = b - a, w = q - a;
        float h = clamp(dot(w, e) / max(dot(e, e), 1e-12), 0.0, 1.0);
        d = min(d, length(w - e * h));
    }
    return d;
}

// ---------- Shape layer: fill + stroke, composited with a blend mode ----------

static float3 blendPath(float3 Cb, float3 Cs, uint mode) {
    switch (mode) {
        case 1: return Cb + Cs;
        case 2: return Cb + Cs - Cb * Cs;
        case 3: return Cb * Cs;
        case 4: { float3 lo = 2.0 * Cs * Cb; float3 hi = 1.0 - 2.0 * (1.0 - Cs) * (1.0 - Cb); return select(hi, lo, Cb <= 0.5); }
        case 5: return max(Cb, Cs);
        case 6: return min(Cb, Cs);
        case 7: return abs(Cb - Cs);
        default: return Cs;
    }
}

kernel void drawPath(texture2d<half, access::read_write> target [[texture(0)]],
                     device const float4* segs [[buffer(1)]],
                     constant PathParams& p [[buffer(0)]],
                     uint2 tid [[thread_position_in_grid]]) {
    if (tid.x >= p.region.z || tid.y >= p.region.w) return;
    uint2 gid = tid + p.region.xy;
    if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float2 q = float2(dot(p.invRow0.xy, c) + p.invRow0.z, dot(p.invRow1.xy, c) + p.invRow1.z);
    float aa = max(p.geom.z, 1e-4);
    int wind;
    float d = pathDistance(q, segs, p.info.x, wind);
    float fillCov = (p.fill.a > 0.0) ? clamp((wind != 0 ? 0.5 + d / aa : 0.5 - d / aa), 0.0, 1.0) : 0.0;
    float strokeCov = 0.0;
    if (p.stroke.a > 0.0 && p.geom.x > 0.0 && p.info.z > 0) {
        float sd = strokeDistance(q, segs, p.info.y, p.info.z);
        strokeCov = clamp(0.5 - (sd - p.geom.x * 0.5) / aa, 0.0, 1.0);
    }
    // Stroke over fill.
    float fa = p.fill.a * fillCov, sa = p.stroke.a * strokeCov;
    float a = sa + fa * (1.0 - sa);
    if (a <= 0.0) return;
    float3 rgb = (p.stroke.rgb * sa + p.fill.rgb * fa * (1.0 - sa)) / a;
    a *= p.geom.y;
    float4 src = float4(rgb * a, a);
    float4 dst = float4(target.read(gid));
    float as = src.a, ab = dst.a;
    float3 Cs = src.rgb / max(as, 1e-6);
    float3 Cb = ab > 0.0 ? dst.rgb / ab : float3(0.0);
    float3 B = blendPath(Cb, Cs, p.info.w);
    float3 co = src.rgb * (1.0 - ab) + dst.rgb * (1.0 - as) + as * ab * B;
    target.write(half4(float4(co, as + ab * (1.0 - as))), gid);
}

// ---------- Masks ----------
// acc: running mask (r channel). info.w = mode: 0 add, 1 subtract, 2 intersect, 3 lighten, 4 darken, 5 difference, 6 none.
kernel void maskAccumulate(texture2d<half, access::read_write> acc [[texture(0)]],
                           device const float4* segs [[buffer(1)]],
                           constant PathParams& p [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= acc.get_width() || gid.y >= acc.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float2 q = float2(dot(p.invRow0.xy, c) + p.invRow0.z, dot(p.invRow1.xy, c) + p.invRow1.z);
    int wind;
    float d = pathDistance(q, segs, p.info.x, wind);
    float sd = (wind != 0 ? -d : d) - p.geom2.x;          // expansion grows the mask
    float aa = max(p.geom.z, 1e-4);
    float soft = aa + max(p.geom.w, 0.0);                  // feather widens the edge falloff
    float m = clamp(0.5 - sd / soft, 0.0, 1.0);
    if (p.info2.x != 0) m = 1.0 - m;
    m *= p.geom2.y;
    float prev = p.geom2.z >= 0.0 ? p.geom2.z : float(acc.read(gid).r);
    float o;
    switch (p.info.w) {
        case 1: o = prev * (1.0 - m); break;
        case 2: o = prev * m; break;
        case 3: o = max(prev, m); break;
        case 4: o = min(prev, m); break;
        case 5: o = abs(prev - m); break;
        case 6: o = prev; break;
        default: o = prev + m - prev * m; break;
    }
    acc.write(half4(half(o), 0, 0, 1), gid);
}

kernel void maskApply(texture2d<half, access::read_write> layer [[texture(0)]],
                      texture2d<half, access::read> acc [[texture(1)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= layer.get_width() || gid.y >= layer.get_height()) return;
    float m = float(acc.read(gid).r);
    layer.write(layer.read(gid) * half(m), gid);
}
