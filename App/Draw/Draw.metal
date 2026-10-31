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

static float3 blendFn(float3 Cb, float3 Cs, uint mode) {
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
