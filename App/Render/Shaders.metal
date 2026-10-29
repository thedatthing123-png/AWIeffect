#include <metal_stdlib>
using namespace metal;

// Working space: sRGB-encoded float (matches After Effects' default, non-linearized blending).
// Comp textures are rgba16Float with PREMULTIPLIED alpha.

// Must match LayerParams in Renderer.swift (all 16-byte members, no padding surprises).
struct LayerParams {
    float4 invRow0;   // inverse affine row 0: (a, b, tx, _)  comp px -> layer local px
    float4 invRow1;   // inverse affine row 1: (c, d, ty, _)
    float4 color;     // straight RGBA fill
    float4 geom;      // halfSize.x, halfSize.y, opacity(0-1), cornerRadius
    float4 geom2;     // sides, innerRatio, aa (local px per comp px), _
    uint4  modes;     // shape kind, blend mode, content kind (0 shape, 1 solid, 2 image), _
    uint4  region;    // origin.x, origin.y, width, height (dispatch region in comp px)
};

// ---------- SDFs (Inigo Quilez) ----------

static float sdRoundBox(float2 p, float2 b, float r) {
    r = min(r, min(b.x, b.y));
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

static float sdEllipseApprox(float2 p, float2 r) {
    r = max(r, float2(1e-3));
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 < 1e-5 ? -min(r.x, r.y) : k0 * (k0 - 1.0) / k1;
}

static float sdRegularPolygon(float2 p, float r, float n) {
    n = max(3.0, n);
    float an = M_PI_F / n;
    float2 acs = float2(cos(an), sin(an));
    // rotate so a vertex points up
    float bn = fmod(atan2(p.x, -p.y) + 2.0 * M_PI_F, 2.0 * an) - an;
    p = length(p) * float2(cos(bn), abs(sin(bn)));
    p -= r * acs;
    p.y += clamp(-p.y, 0.0, r * acs.y);
    return length(p) * sign(p.x);
}

static float sdStar(float2 p, float r, float n, float innerRatio) {
    n = max(3.0, n);
    float an = M_PI_F / n;
    // fold so an outer point sits at bn == 0, pointing up
    float bn = fmod(atan2(p.x, -p.y) + an + 2.0 * M_PI_F, 2.0 * an) - an;
    p = length(p) * float2(cos(bn), abs(sin(bn)));
    float2 a = float2(r, 0.0);
    float2 b = float2(r * innerRatio * cos(an), r * innerRatio * sin(an));
    float2 e = b - a;
    float2 w = p - a;
    float h = clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
    float2 d = w - e * h;
    // inside test via cross product sign
    float s = (e.x * w.y - e.y * w.x) > 0.0 ? -1.0 : 1.0;
    return length(d) * s;
}

// ---------- Blend modes (W3C compositing, premultiplied) ----------

static float3 blendChannel(float3 Cb, float3 Cs, uint mode) {
    switch (mode) {
        case 1: return min(Cb + Cs, float3(1e4));                 // add (ae "Add" on straight colors)
        case 2: return Cb + Cs - Cb * Cs;                         // screen
        case 3: return Cb * Cs;                                   // multiply
        case 4: {                                                 // overlay
            float3 lo = 2.0 * Cs * Cb;
            float3 hi = 1.0 - 2.0 * (1.0 - Cs) * (1.0 - Cb);
            return select(hi, lo, Cb <= 0.5);
        }
        case 5: return max(Cb, Cs);                               // lighten
        case 6: return min(Cb, Cs);                               // darken
        case 7: return abs(Cb - Cs);                              // difference
        default: return Cs;                                       // normal
    }
}

static half4 composite(half4 dstH, float4 src, uint mode) {
    float4 dst = float4(dstH);
    float as = src.a, ab = dst.a;
    if (as <= 0.0) return dstH;
    float3 Cs = src.rgb / max(as, 1e-6);
    float3 Cb = ab > 0.0 ? dst.rgb / ab : float3(0.0);
    float3 B = blendChannel(Cb, Cs, mode);
    float3 co = src.rgb * (1.0 - ab) + dst.rgb * (1.0 - as) + as * ab * B;
    float ao = as + ab * (1.0 - as);
    return half4(float4(co, ao));
}

// ---------- Kernels ----------

kernel void clearComp(texture2d<half, access::write> comp [[texture(0)]],
                      constant float4& color [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= comp.get_width() || gid.y >= comp.get_height()) return;
    float4 c = color;
    comp.write(half4(half3(c.rgb * c.a), half(c.a)), gid);
}

kernel void drawLayer(texture2d<half, access::read_write> comp [[texture(0)]],
                      texture2d<half, access::sample> image [[texture(1)]],
                      constant LayerParams& p [[buffer(0)]],
                      uint2 tid [[thread_position_in_grid]]) {
    if (tid.x >= p.region.z || tid.y >= p.region.w) return;
    uint2 gid = tid + p.region.xy;
    if (gid.x >= comp.get_width() || gid.y >= comp.get_height()) return;

    float2 c = float2(gid) + 0.5;
    float2 q = float2(dot(p.invRow0.xy, c) + p.invRow0.z,
                      dot(p.invRow1.xy, c) + p.invRow1.z);
    float2 hs = p.geom.xy;
    float aa = max(p.geom2.z, 1e-4);
    float4 color = p.color;
    float coverage = 0.0;

    uint content = p.modes.z;
    if (content == 2) {
        // image: bilinear sample, edge AA against the box
        float d = sdRoundBox(q, hs, 0.0);
        coverage = clamp(0.5 - d / aa, 0.0, 1.0);
        if (coverage <= 0.0) return;
        constexpr sampler s(address::clamp_to_edge, filter::linear);
        float2 uv = q / (2.0 * hs) + 0.5;
        float4 tex = float4(image.sample(s, uv));
        // geom2.w == 1: source is a premultiplied effect buffer -> convert to straight.
        if (p.geom2.w > 0.5) tex.rgb = tex.a > 1e-6 ? tex.rgb / tex.a : float3(0.0);
        color = tex;
    } else {
        float d;
        if (content == 1) {
            d = sdRoundBox(q, hs, 0.0);
        } else {
            float r = min(hs.x, hs.y);
            switch (p.modes.x) {
                case 1: d = sdEllipseApprox(q, hs); break;
                case 2: d = sdRegularPolygon(q, r, p.geom2.x); break;
                case 3: d = sdStar(q, r, p.geom2.x, p.geom2.y); break;
                default: d = sdRoundBox(q, hs, p.geom.w); break;
            }
        }
        coverage = clamp(0.5 - d / aa, 0.0, 1.0);
        if (coverage <= 0.0) return;
    }

    float a = color.a * coverage * p.geom.z;
    if (a <= 0.0) return;
    float4 src = float4(color.rgb * a, a);
    comp.write(composite(comp.read(gid), src, p.modes.y), gid);
}

// Premultiplied float comp -> straight BGRA8 (for video export / thumbnails).
kernel void compToBGRA(texture2d<half, access::read> comp [[texture(0)]],
                       texture2d<half, access::write> outTex [[texture(1)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
    float4 c = float4(comp.read(gid));
    float3 rgb = c.a > 0.0 ? c.rgb / c.a : float3(0.0);
    // Video has no alpha: composite over black.
    rgb = clamp(rgb * c.a, 0.0, 1.0);
    outTex.write(half4(half3(rgb), 1.0h), gid);
}

// ---------- Preview display ----------

struct VOut { float4 pos [[position]]; float2 uv; };

vertex VOut displayVertex(uint vid [[vertex_id]]) {
    float2 pos[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
    VOut o;
    o.pos = float4(pos[vid], 0, 1);
    o.uv = float2((pos[vid].x + 1) * 0.5, 1 - (pos[vid].y + 1) * 0.5);
    return o;
}

fragment half4 displayFragment(VOut in [[stage_in]],
                               texture2d<half, access::sample> comp [[texture(0)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float4 c = float4(comp.sample(s, in.uv));
    // Show transparency as a subtle checkerboard (premultiplied over).
    float2 px = in.pos.xy / 12.0;
    float check = (fmod(floor(px.x) + floor(px.y), 2.0) < 1.0) ? 0.16 : 0.22;
    float3 rgb = c.rgb + float3(check) * (1.0 - c.a);
    return half4(half3(clamp(rgb, 0.0, 1.0)), 1.0h);
}
