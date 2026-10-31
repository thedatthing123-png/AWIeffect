#include <metal_stdlib>
using namespace metal;

// Draw Studio layers are rgba8Unorm, PREMULTIPLIED alpha.
// Must match DabParams in DrawEngine.swift.
struct DabParams {
    float4 color;      // straight RGBA (a = brush opacity * flow)
    float4 dab;        // center.x, center.y, radius (px), hardness (0-1)
    float4 extra;      // eraser (1/0), alphaLock (1/0), texture kind (0 round, 1 pencil grain, 2 airbrush), seed
    uint4  region;     // x0, y0, w, h
};

static float hash12(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

/// Stamps one brush dab. Normal brushes use "over"; the eraser removes alpha; alpha lock keeps coverage.
kernel void stampDab(texture2d<float, access::read_write> layer [[texture(0)]],
                     texture2d<float, access::read> selection [[texture(1)]],
                     constant DabParams& p [[buffer(0)]],
                     uint2 tid [[thread_position_in_grid]]) {
    if (tid.x >= p.region.z || tid.y >= p.region.w) return;
    uint2 gid = tid + p.region.xy;
    if (gid.x >= layer.get_width() || gid.y >= layer.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float r = max(p.dab.z, 0.5);
    float2 off = c - p.dab.xy;
    // Flat chisel: a thin slanted tip instead of a round one.
    float d = p.extra.z == 4.0 ? max(abs(off.x + off.y) / (r * 1.414), abs(off.x - off.y) / (r * 0.35)) : length(off) / r;
    if (d >= 1.0) return;
    // Hardness: flat core, smooth falloff to the edge.
    float h = clamp(p.dab.w, 0.0, 0.99);
    float a = 1.0 - smoothstep(h, 1.0, d);
    if (p.extra.z == 1.0) a *= step(0.35, hash12(c + p.extra.w));            // pencil grain
    if (p.extra.z == 2.0) a *= (1.0 - d) * (1.0 - d);                        // airbrush soft
    if (p.extra.z == 3.0) a *= step(0.88, hash12(c * 1.37 + p.extra.w));     // spray: scattered specks
    if (p.extra.z == 5.0) a = pow(1.0 - d, 2.2);                             // glow: wide soft light
    if (p.extra.z == 6.0) a *= 0.55 + 0.45 * smoothstep(0.55, 0.95, d);      // watercolor: pigment pools at the edge
    if (p.extra.z == 7.0) {                                                  // screentone: manga dot pattern
        float2 g = fract(c / 7.0) - 0.5;
        a *= 1.0 - smoothstep(0.28, 0.34, length(g));
    }
    if (p.extra.z == 8.0) a *= smoothstep(0.25, 0.8, hash12(floor(c * 0.6)));  // charcoal: fixed paper grain
    a *= p.color.a;
    // Selection restricts painting.
    a *= selection.read(gid).r;
    if (a <= 0.0) return;
    float4 dst = layer.read(gid);
    float4 o;
    if (p.extra.x > 0.5) {
        o = dst * (1.0 - a);                                                // erase
    } else if (p.extra.y > 0.5) {
        float3 rgb = mix(dst.a > 0.0 ? dst.rgb / dst.a : float3(0), p.color.rgb, a);
        o = float4(rgb * dst.a, dst.a);                                     // alpha lock: recolor only
    } else {
        o = float4(p.color.rgb * a, a) + dst * (1.0 - a);                   // premultiplied over
    }
    layer.write(o, gid);
}

// Must match LayerCompositeParams in DrawEngine.swift.
struct LayerCompositeParams {
    float4 info;   // opacity, clipping (1/0), _, _
    uint4  mode;   // blend mode index (same table as the main compositor)
};


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

static float3 blendFn(float3 Cb, float3 Cs, uint mode) {
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

/// Composites one draw layer over the running canvas. Clipping layers use the base layer's alpha.
kernel void compositeDrawLayer(texture2d<float, access::read_write> canvas [[texture(0)]],
                               texture2d<float, access::read> layer [[texture(1)]],
                               texture2d<float, access::read> clipBase [[texture(2)]],
                               constant LayerCompositeParams& p [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= canvas.get_width() || gid.y >= canvas.get_height()) return;
    float4 s = layer.read(gid) * p.info.x;
    if (p.info.y > 0.5) s *= clipBase.read(gid).a;
    if (s.a <= 0.0) return;
    float4 d = canvas.read(gid);
    float3 Cs = s.rgb / max(s.a, 1e-6);
    float3 Cb = d.a > 0.0 ? d.rgb / d.a : float3(0.0);
    float3 B = blendFn(Cb, Cs, p.mode.x);
    float3 co = s.rgb * (1.0 - d.a) + d.rgb * (1.0 - s.a) + s.a * d.a * B;
    canvas.write(float4(co, s.a + d.a * (1.0 - s.a)), gid);
}

kernel void fillCanvas(texture2d<float, access::write> canvas [[texture(0)]],
                       constant float4& color [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= canvas.get_width() || gid.y >= canvas.get_height()) return;
    canvas.write(float4(color.rgb * color.a, color.a), gid);
}

// Display: canvas over a transparency checkerboard with the selection outline tinted.
struct DrawVOut { float4 pos [[position]]; float2 uv; };

vertex DrawVOut drawDisplayVertex(uint vid [[vertex_id]], constant float4& rect [[buffer(0)]]) {
    // rect = NDC x0, y0, x1, y1
    float2 corners[4] = { float2(rect.x, rect.y), float2(rect.z, rect.y), float2(rect.x, rect.w), float2(rect.z, rect.w) };
    float2 uvs[4] = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
    DrawVOut o;
    o.pos = float4(corners[vid], 0, 1);
    o.uv = uvs[vid];
    return o;
}

fragment float4 drawDisplayFragment(DrawVOut in [[stage_in]],
                                    texture2d<float, access::sample> canvas [[texture(0)]],
                                    texture2d<float, access::sample> selection [[texture(1)]],
                                    constant float4& opts [[buffer(0)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::nearest);
    constexpr sampler sl(address::clamp_to_edge, filter::linear);
    float4 c = canvas.sample(sl, in.uv);
    float2 cell = floor(in.uv * float2(canvas.get_width(), canvas.get_height()) / 16.0);
    float check = fmod(cell.x + cell.y, 2.0) < 1.0 ? 0.92 : 0.82;
    float3 rgb = c.rgb + float3(check) * (1.0 - c.a);
    if (opts.x > 0.5) {
        // Marching tint outside the selection.
        float sel = selection.sample(s, in.uv).r;
        rgb = mix(rgb * 0.55 + float3(0.25, 0.1, 0.4) * 0.45, rgb, sel);
    }
    return float4(rgb, 1.0);
}
