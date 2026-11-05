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

vertex DrawVOut drawDisplayVertex(uint vid [[vertex_id]], constant float2* corners [[buffer(0)]]) {
    float2 uvs[4] = { float2(0, 1), float2(1, 1), float2(0, 0), float2(1, 0) };
    DrawVOut o;
    o.pos = float4(corners[vid], 0, 1);
    o.uv = uvs[vid];
    return o;
}

// opts = (has selection, background mode 0 checker / 1 color, selection view 0 dim / 1 red quick mask / 2 ants only, time)
// bg = background color for mode 1.
fragment float4 drawDisplayFragment(DrawVOut in [[stage_in]],
                                    texture2d<float, access::sample> canvas [[texture(0)]],
                                    texture2d<float, access::sample> selection [[texture(1)]],
                                    constant float4& opts [[buffer(0)]],
                                    constant float4& bg [[buffer(1)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::nearest);
    constexpr sampler sl(address::clamp_to_edge, filter::linear);
    float4 c = canvas.sample(sl, in.uv);
    float2 size = float2(canvas.get_width(), canvas.get_height());
    float2 cell = floor(in.uv * size / 16.0);
    float check = fmod(cell.x + cell.y, 2.0) < 1.0 ? 0.92 : 0.80;
    float3 back = opts.y > 0.5 ? bg.rgb : float3(check);
    float3 rgb = c.rgb + back * (1.0 - c.a);
    if (opts.x > 0.5) {
        float sel = selection.sample(sl, in.uv).r;
        if (opts.z < 0.5) rgb = mix(rgb * 0.5 + float3(0.25, 0.1, 0.4) * 0.5, rgb, sel);
        else if (opts.z < 1.5) rgb = mix(rgb, rgb * 0.45 + float3(1.0, 0.1, 0.15) * 0.55, sel);
        // Marching ants on the selection edge (all views).
        float2 px = 1.5 / size;
        float e = abs(selection.sample(s, in.uv + float2(px.x, 0)).r - selection.sample(s, in.uv - float2(px.x, 0)).r)
                + abs(selection.sample(s, in.uv + float2(0, px.y)).r - selection.sample(s, in.uv - float2(0, px.y)).r);
        if (e > 0.4) {
            float2 p = in.uv * size;
            float stripe = fmod(floor((p.x + p.y) / 5.0 + opts.w * 6.0), 2.0);
            rgb = stripe < 1.0 ? float3(1.0) : float3(0.0);
        }
    }
    return float4(rgb, 1.0);
}

// ---------- Stroke buffer: dabs build coverage in a float texture, the merge caps it at the brush opacity ----------
// (one stroke never builds past its opacity, the way pro paint apps behave).

static float dabCoverage(constant DabParams& p, float2 c) {
    float r = max(p.dab.z, 0.5);
    float2 off = c - p.dab.xy;
    float d = p.extra.z == 4.0 ? max(abs(off.x + off.y) / (r * 1.414), abs(off.x - off.y) / (r * 0.35)) : length(off) / r;
    if (d >= 1.0) return 0.0;
    float h = clamp(p.dab.w, 0.0, 0.99);
    float a = 1.0 - smoothstep(h, 1.0, d);
    if (p.extra.z == 1.0) a *= step(0.35, hash12(c + p.extra.w));
    if (p.extra.z == 2.0) a *= (1.0 - d) * (1.0 - d);
    if (p.extra.z == 3.0) a *= step(0.88, hash12(c * 1.37 + p.extra.w));
    if (p.extra.z == 5.0) a = pow(1.0 - d, 2.2);
    if (p.extra.z == 6.0) a *= 0.55 + 0.45 * smoothstep(0.55, 0.95, d);
    if (p.extra.z == 7.0) { float2 g = fract(c / 7.0) - 0.5; a *= 1.0 - smoothstep(0.28, 0.34, length(g)); }
    if (p.extra.z == 8.0) a *= smoothstep(0.25, 0.8, hash12(floor(c * 0.6)));
    return a;
}

kernel void stampWet(texture2d<float, access::read_write> wet [[texture(0)]],
                     constant DabParams& p [[buffer(0)]],
                     uint2 tid [[thread_position_in_grid]]) {
    if (tid.x >= p.region.z || tid.y >= p.region.w) return;
    uint2 gid = tid + p.region.xy;
    if (gid.x >= wet.get_width() || gid.y >= wet.get_height()) return;
    float a = dabCoverage(p, float2(gid) + 0.5) * p.color.a;
    if (a <= 0.0) return;
    float w = wet.read(gid).r;
    wet.write(float4(a + w * (1.0 - a)), gid);
}

// color = rgb + stroke opacity; flags.x erase, flags.y alpha lock; region = dirty box.
struct MergeParams { float4 color; float4 flags; uint4 region; };

kernel void mergeStroke(texture2d<float, access::write> layer [[texture(0)]],
                        texture2d<float, access::read> base [[texture(1)]],
                        texture2d<float, access::read> wet [[texture(2)]],
                        texture2d<float, access::read> selection [[texture(3)]],
                        constant MergeParams& p [[buffer(0)]],
                        uint2 tid [[thread_position_in_grid]]) {
    if (tid.x >= p.region.z || tid.y >= p.region.w) return;
    uint2 gid = tid + p.region.xy;
    if (gid.x >= layer.get_width() || gid.y >= layer.get_height()) return;
    float4 dst = base.read(gid);
    float a = wet.read(gid).r * p.color.a * selection.read(gid).r;
    float4 o;
    if (p.flags.x > 0.5) o = dst * (1.0 - a);
    else if (p.flags.y > 0.5) o = float4(mix(dst.a > 0.0 ? dst.rgb / dst.a : float3(0), p.color.rgb, a) * dst.a, dst.a);
    else o = float4(p.color.rgb * a, a) + dst * (1.0 - a);
    layer.write(o, gid);
}

kernel void clearWet(texture2d<float, access::write> wet [[texture(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= wet.get_width() || gid.y >= wet.get_height()) return;
    wet.write(float4(0), gid);
}

// Smudge / blur tools. color.a = strength, extra.xy = pull offset (px), extra.z = 0 smudge, 1 blur.
kernel void smudgeDab(texture2d<float, access::write> layer [[texture(0)]],
                      texture2d<float, access::sample> snapshot [[texture(1)]],
                      texture2d<float, access::read> selection [[texture(2)]],
                      constant DabParams& p [[buffer(0)]],
                      uint2 tid [[thread_position_in_grid]]) {
    constexpr sampler s(coord::pixel, address::clamp_to_edge, filter::linear);
    if (tid.x >= p.region.z || tid.y >= p.region.w) return;
    uint2 gid = tid + p.region.xy;
    if (gid.x >= layer.get_width() || gid.y >= layer.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float d = length(c - p.dab.xy) / max(p.dab.z, 0.5);
    if (d >= 1.0) return;
    float a = (1.0 - smoothstep(clamp(p.dab.w, 0.0, 0.99), 1.0, d)) * p.color.a * selection.read(gid).r;
    float4 dst = snapshot.sample(s, c), src;
    if (p.extra.z < 0.5) {
        src = snapshot.sample(s, c - p.extra.xy);
    } else {
        float k = max(1.5, p.dab.z * 0.25);
        src = dst * 0.2;
        for (int i = 0; i < 8; i++) {
            float t = float(i) * 0.7853982;
            src += snapshot.sample(s, c + float2(cos(t), sin(t)) * k) * 0.1;
        }
    }
    layer.write(mix(dst, src, a), gid);
}

// Live transform: untouched pixels + the lifted pixels through an inverse affine. Rows are (a, b, tx).
struct FloatParams { float4 row0; float4 row1; };

kernel void composeFloating(texture2d<float, access::write> layer [[texture(0)]],
                            texture2d<float, access::read> base [[texture(1)]],
                            texture2d<float, access::sample> floating [[texture(2)]],
                            constant FloatParams& p [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]]) {
    constexpr sampler s(coord::pixel, address::clamp_to_zero, filter::linear);
    if (gid.x >= layer.get_width() || gid.y >= layer.get_height()) return;
    float3 c = float3(float2(gid) + 0.5, 1.0);
    float4 f = floating.sample(s, float2(dot(p.row0.xyz, c), dot(p.row1.xyz, c)));
    layer.write(f + base.read(gid) * (1.0 - f.a), gid);
}

// Smudge with a carried tip. color.a = strength, extra.x = 1 on the stroke's first dab (the tip just picks up).
kernel void smudgeCarry(texture2d<float, access::read_write> layer [[texture(0)]],
                        texture2d<float, access::read_write> tip [[texture(1)]],
                        texture2d<float, access::read> selection [[texture(2)]],
                        constant DabParams& p [[buffer(0)]],
                        uint2 tid [[thread_position_in_grid]]) {
    if (tid.x >= p.region.z || tid.y >= p.region.w) return;
    uint2 gid = tid + p.region.xy;
    if (gid.x >= layer.get_width() || gid.y >= layer.get_height()) return;
    float2 off = float2(gid) + 0.5 - p.dab.xy;
    float r = max(p.dab.z, 0.5);
    float d = length(off) / r;
    if (d >= 1.0) return;
    // 1:1 for tips that fit, scaled down for bigger ones.
    uint2 t = uint2(clamp(off * min(1.0, 127.0 / r) + 128.0, 0.0, 255.0));
    float4 under = layer.read(gid);
    if (p.extra.x > 0.5) { tip.write(under, t); return; }
    float4 carried = tip.read(t);
    float a = (1.0 - smoothstep(clamp(p.dab.w, 0.0, 0.99), 1.0, d)) * p.color.a * selection.read(gid).r;
    layer.write(mix(under, carried, a), gid);
    // Low strength picks up more of what is underneath, so the paint runs out sooner.
    tip.write(mix(carried, under, (1.0 - p.color.a) * 0.5 + 0.02), t);
}
