#include <metal_stdlib>
using namespace metal;

// Working space: sRGB-encoded float (matches After Effects' default, non-linearized blending).
// Comp textures are rgba16Float with PREMULTIPLIED alpha.

// Must match LayerParams in Renderer.swift (all 16-byte members, no padding surprises).
struct LayerParams {
    float4 invRow0;   // inverse affine row 0: (a, b, tx, _)  comp px -> layer local px
    float4 invRow1;   // inverse affine row 1: (c, d, ty, _)
    float4 invRow2;   // inverse homography row 2 (0, 0, 1 for 2D layers)
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
        default: return blendExtra(Cb, Cs, mode);                                       // normal
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
    float3 hc = float3(c, 1.0);
    float w = dot(p.invRow2.xyz, hc);
    if (w <= 1e-6) return;   // behind the camera
    float2 q = float2(dot(p.invRow0.xyz, hc), dot(p.invRow1.xyz, hc)) / w;
    float2 hs = p.geom.xy;
    float aa = max(p.geom2.z, 1e-4);
    float4 color = p.color;
    float coverage = 0.0;

    uint content = p.modes.z;
    if (content == 3) {
        // glyph: tinted alpha mask
        float d = sdRoundBox(q, hs, 0.0);
        coverage = clamp(0.5 - d / aa, 0.0, 1.0);
        if (coverage <= 0.0) return;
        constexpr sampler gs(address::clamp_to_zero, filter::linear);
        float2 uv = q / (2.0 * hs) + 0.5;
        coverage *= float(image.sample(gs, uv).r);
        if (coverage <= 0.0) return;
    } else if (content == 2) {
        // image: trilinear sample (mipmaps) so scaled-down / moving footage never shimmers, edge AA against the box
        float d = sdRoundBox(q, hs, 0.0);
        coverage = clamp(0.5 - d / aa, 0.0, 1.0);
        if (coverage <= 0.0) return;
        constexpr sampler s(address::clamp_to_edge, filter::linear, mip_filter::linear);
        float2 uv = q / (2.0 * hs) + 0.5;
        // Source texels covered by one output pixel -> mip level (0 when magnified; textures without mips clamp to 0).
        float texelsPerPixel = max(aa * float(image.get_width()) / max(2.0 * hs.x, 1e-4), aa * float(image.get_height()) / max(2.0 * hs.y, 1e-4));
        float lod = clamp(log2(max(texelsPerPixel, 1.0)), 0.0, float(image.get_num_mip_levels() - 1));
        float4 tex = float4(image.sample(s, uv, level(lod)));
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

// Premultiplied float comp -> opaque RGB or straight RGBA (export / thumbnails).
kernel void compToBGRA(texture2d<half, access::read> comp [[texture(0)]],
                       texture2d<half, access::write> outTex [[texture(1)]],
                       constant uint& dither [[buffer(0)]],
                       constant uint& preserveAlpha [[buffer(1)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
    float4 c = float4(comp.read(gid));
    float3 rgb = c.a > 0.0 ? c.rgb / c.a : float3(0.0);
    // Ordinary video flattens over black; alpha exports keep straight color.
    float alpha = clamp(c.a, 0.0, 1.0);
    if (preserveAlpha == 0u) rgb *= alpha;
    // Triangular dither (±1 LSB) before 8-bit: smooth glows / gradients with no banding, like AE's high-bit render.
    float2 g = float2(gid);
    float n1 = fract(sin(dot(g, float2(12.9898, 78.233))) * 43758.5453);
    float n2 = fract(sin(dot(g, float2(39.3468, 11.1351))) * 24634.6345);
    rgb = clamp(rgb + (dither != 0u ? (n1 + n2 - 1.0) / 255.0 : 0.0), 0.0, 1.0);
    if (preserveAlpha != 0u && alpha == 0.0) rgb = float3(0.0);
    outTex.write(half4(half3(rgb), half(preserveAlpha != 0u ? alpha : 1.0)), gid);
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
