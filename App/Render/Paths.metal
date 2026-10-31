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


// ---------- Extended blend modes (After Effects / W3C set, straight colors 0-1) ----------
static inline float bxLum(float3 c) { return dot(c, float3(0.3, 0.59, 0.11)); }
static inline float3 bxClipColor(float3 c) {
    float l = bxLum(c), n = min(c.r, min(c.g, c.b)), x = max(c.r, max(c.g, c.b));
    if (n < 0.0) c = l + (c - l) * l / max(l - n, 1e-6);
    if (x > 1.0) c = l + (c - l) * (1.0 - l) / max(x - l, 1e-6);
    return c;
}
static inline float3 bxSetLum(float3 c, float l) { return bxClipColor(c + (l - bxLum(c))); }
static inline float bxSat(float3 c) { return max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b)); }
static inline float3 bxSetSat(float3 c, float s) {
    float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
    return mx > mn ? (c - mn) * s / (mx - mn) : float3(0.0);
}
static inline float3 bxBurn(float3 b, float3 s) { return select(1.0 - min(float3(1.0), (1.0 - b) / max(s, float3(1e-6))), float3(0.0), s <= 0.0); }
static inline float3 bxDodge(float3 b, float3 s) { return select(min(float3(1.0), b / max(1.0 - s, float3(1e-6))), float3(1.0), s >= 1.0); }
static float3 blendExtra(float3 Cb, float3 Cs, uint mode) {
    switch (mode) {
        case 8: return bxBurn(Cb, Cs);                                                    // color burn
        case 9: return max(Cb + Cs - 1.0, float3(0.0));                                   // linear burn
        case 10: return bxLum(Cs) < bxLum(Cb) ? Cs : Cb;                                  // darker color
        case 11: return bxDodge(Cb, Cs);                                                  // color dodge
        case 12: return min(Cb + Cs, float3(1.0));                                        // linear dodge
        case 13: return bxLum(Cs) > bxLum(Cb) ? Cs : Cb;                                  // lighter color
        case 14: {                                                                        // soft light
            float3 d = select(sqrt(Cb), ((16.0 * Cb - 12.0) * Cb + 4.0) * Cb, Cb <= 0.25);
            return select(Cb + (2.0 * Cs - 1.0) * (d - Cb), Cb - (1.0 - 2.0 * Cs) * Cb * (1.0 - Cb), Cs <= 0.5);
        }
        case 15: return select(1.0 - 2.0 * (1.0 - Cs) * (1.0 - Cb), 2.0 * Cs * Cb, Cs <= 0.5); // hard light
        case 16: return clamp(Cb + 2.0 * Cs - 1.0, 0.0, 1.0);                             // linear light
        case 17: return select(bxDodge(Cb, 2.0 * Cs - 1.0), bxBurn(Cb, 2.0 * Cs), Cs <= 0.5); // vivid light
        case 18: return select(max(Cb, 2.0 * Cs - 1.0), min(Cb, 2.0 * Cs), Cs <= 0.5);    // pin light
        case 19: return select(float3(0.0), float3(1.0), Cb + Cs >= 1.0);                 // hard mix
        case 20: return Cb + Cs - 2.0 * Cb * Cs;                                          // exclusion
        case 21: return max(Cb - Cs, float3(0.0));                                        // subtract
        case 22: return select(min(float3(1.0), Cb / max(Cs, float3(1e-6))), float3(1.0), Cs <= 0.0); // divide
        case 23: return bxSetLum(bxSetSat(Cs, bxSat(Cb)), bxLum(Cb));                     // hue
        case 24: return bxSetLum(bxSetSat(Cb, bxSat(Cs)), bxLum(Cb));                     // saturation
        case 25: return bxSetLum(Cs, bxLum(Cb));                                          // color
        case 26: return bxSetLum(Cb, bxLum(Cs));                                          // luminosity
        default: return Cs;
    }
}

static float3 blendPath(float3 Cb, float3 Cs, uint mode) {
    switch (mode) {
        case 1: return Cb + Cs;
        case 2: return Cb + Cs - Cb * Cs;
        case 3: return Cb * Cs;
        case 4: { float3 lo = 2.0 * Cs * Cb; float3 hi = 1.0 - 2.0 * (1.0 - Cs) * (1.0 - Cb); return select(hi, lo, Cb <= 0.5); }
        case 5: return max(Cb, Cs);
        case 6: return min(Cb, Cs);
        case 7: return abs(Cb - Cs);
        default: return blendExtra(Cb, Cs, mode);
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

// ---------- AI cutout matte ----------
// Must match CutoutParams in Renderer+Cutout.swift.
struct CutoutParams {
    float4 invRow0;   // buffer px -> layer local px
    float4 invRow1;
    float4 geom;      // halfSize.x, halfSize.y, edgeShift (-0.5..0.5), edgeSoftness (0.01..0.5)
    uint4  flags;     // invert, _, _, _
};

kernel void cutoutApply(texture2d<half, access::read_write> layer [[texture(0)]],
                        texture2d<half, access::sample> matte [[texture(1)]],
                        constant CutoutParams& p [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= layer.get_width() || gid.y >= layer.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float2 q = float2(dot(p.invRow0.xy, c) + p.invRow0.z, dot(p.invRow1.xy, c) + p.invRow1.z);
    float2 uv = q / (2.0 * max(p.geom.xy, float2(1e-3))) + 0.5;
    constexpr sampler s(address::clamp_to_zero, filter::linear);
    float m = float(matte.sample(s, uv).r);
    // Edge contrast: squeeze the soft transition toward a clean cut.
    float ec = float(p.flags.y) / 100.0;
    if (ec > 0.0) { float hw = 0.5 * (1.0 - ec * 0.92); m = smoothstep(0.5 - hw, 0.5 + hw, m); }
    // Choke/grow + soften the matte edge.
    float soft = max(p.geom.w, 0.01);
    m = clamp((m - 0.5 + p.geom.z) / (2.0 * soft) + 0.5, 0.0, 1.0);
    if (p.flags.x != 0) m = 1.0 - m;
    layer.write(layer.read(gid) * half(m), gid);
}
