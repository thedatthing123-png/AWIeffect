#include <metal_stdlib>
using namespace metal;

// Batch 27: print, ink, film/TV and the remaining glitch looks.
//  - fxPrint27: antialiased print screens driven by tone (dots of any shape, line screens, CMYK, hatching,
//    stipple, woodcut). The tone is read from a slightly blurred copy so dots never alias.
//  - fxInk27:   manga ink from a difference of Gaussians (clean tapered lines + solid blacks), pencil, cel.
//  - fxFilm27:  film burn, analog TV, scan distort, CRT and film grain. Noise is always monochrome
//    (or dye-correlated for color grain): never random rainbow pixels.
//  - fxGlitch27: slice, interlace, displacement and VHS tracking with coherent damage and burst timing.
// rgba16Float premultiplied, sRGB-encoded.
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s27e(address::clamp_to_edge, filter::linear, coord::pixel);
constexpr sampler s27z(address::clamp_to_zero, filter::linear, coord::pixel);

static inline uint pcg27(uint v) {
    uint s = v * 747796405u + 2891336453u;
    uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
    return (w >> 22u) ^ w;
}
/// Stable hash of an integer cell and a salt.
static inline float h27(float2 cell, float salt) {
    int2 q = int2(floor(cell));
    uint h = pcg27(uint(q.x) + pcg27(uint(q.y) + pcg27(uint(int(floor(salt * 7.0)) + 1013904223))));
    return float(h) * (1.0 / 4294967295.0);
}
static inline float h27b(float x, float salt) { return h27(float2(x, 0.0), salt); }
static inline float lum27(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static inline float4 S27(texture2d<half, access::sample> t, float2 p) { return float4(t.sample(s27e, p)); }
static inline float4 Z27(texture2d<half, access::sample> t, float2 p) { return float4(t.sample(s27z, p)); }
static inline float3 straight27(float4 s) { return s.a > 1e-5 ? saturate(s.rgb / s.a) : float3(0.0); }

static inline float vn27(float2 p, float salt) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = h27(i, salt), b = h27(i + float2(1.0, 0.0), salt);
    float c = h27(i + float2(0.0, 1.0), salt), d = h27(i + float2(1.0, 1.0), salt);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
static inline float fbm27(float2 p, float salt) {
    float s = 0.0, w = 0.5;
    for (int o = 0; o < 5; o++) {
        s += vn27(p, salt + float(o) * 13.0) * w;
        p = p * 2.03 + float2(17.3, 9.1);
        w *= 0.5;
    }
    return s / 0.96875;
}

// MARK: - Print screens

/// Darkness 0-1 of a tone sample for one channel: 0-2 = R/G/B dots, 3 = luma, 4-7 = C/M/Y/K.
/// Transparent areas read as paper.
static inline float dark27(float4 s, int ch, float con, float bias) {
    float3 c = saturate(s.rgb + (1.0 - saturate(s.a)));
    float d;
    if (ch < 3) {
        d = 1.0 - c[ch];
    } else if (ch == 3) {
        d = 1.0 - lum27(c);
    } else {
        float k = 1.0 - max(c.r, max(c.g, c.b));
        if (ch == 7) {
            d = k;
        } else {
            float v = ch == 4 ? c.r : (ch == 5 ? c.g : c.b);
            d = (1.0 - v - k) / max(1.0 - k, 1e-4);
        }
    }
    return saturate((d - 0.5) * con + 0.5 + bias);
}

/// Flat screentone levels: paper, a few flat dot percentages, solid black.
static inline float q27(float dk, float levels) {
    float n = max(levels, 2.0);
    float idx = min(floor(dk * n), n - 1.0);
    return idx / (n - 1.0);
}

/// Coverage of one dot (offset f from its cell center, in cell units) at darkness dk. Radii are chosen so the
/// inked area matches dk and full black closes every gap.
static inline float spot27(float2 f, float dk, int shape, float aa) {
    if (dk <= 0.002) return 0.0;
    if (dk >= 0.998) return 1.0;
    float ax = abs(f.x), ay = abs(f.y);
    float d, r;
    switch (shape) {
    case 1: d = max(ax, ay); r = 0.5 * sqrt(dk); break;
    case 2: d = ax + ay; r = sqrt(dk * 0.5) * (1.0 + 0.414 * smoothstep(0.5, 1.0, dk)); break;
    case 4: d = length(f * float2(0.8, 1.25)); r = sqrt(dk / M_PI_F) * (1.0 + 0.3 * smoothstep(0.6, 1.0, dk)); break;
    default: d = length(f); r = sqrt(dk / M_PI_F) * (1.0 + 0.26 * smoothstep(0.6, 1.0, dk)); break;
    }
    return 1.0 - smoothstep(r - aa, r + aa, d);
}

/// A rotated print screen centered on `org`. Each nearby cell draws its dot from the tone at its own center, so
/// dots stay round and clean; lines (shape 3) and crosses (shape 5) read the tone continuously along the line.
static inline float screen27(texture2d<half, access::sample> tone, float2 c, float2 org, float cell, float ang,
                             int shape, int ch, float con, float bias, float levels) {
    float ca = cos(ang), sa = sin(ang);
    float2 rel = c - org;
    float2 g = float2(ca * rel.x + sa * rel.y, -sa * rel.x + ca * rel.y) / cell;
    float2 base = floor(g);
    float aa = 0.7 / cell;
    if (shape == 3 || shape == 5) {
        float cov = 0.0;
        for (int k = -1; k <= 1; k++) {
            // Horizontal lines of the screen.
            float2 ctr = float2(g.x, base.y + float(k) + 0.5);
            float2 w = ctr * cell;
            float dk = dark27(S27(tone, org + float2(ca * w.x - sa * w.y, sa * w.x + ca * w.y)), ch, con, bias);
            if (levels > 1.5) dk = q27(dk, levels);
            float r = shape == 3 ? 0.5 * dk : 0.5 * (1.0 - sqrt(max(1.0 - dk, 0.0)));
            float lc = dk <= 0.002 ? 0.0 : (dk >= 0.998 ? 1.0 : 1.0 - smoothstep(r - aa, r + aa, abs(g.y - ctr.y)));
            cov = max(cov, lc);
            if (shape == 5) {
                float2 ctr2 = float2(base.x + float(k) + 0.5, g.y);
                float2 w2 = ctr2 * cell;
                float dk2 = dark27(S27(tone, org + float2(ca * w2.x - sa * w2.y, sa * w2.x + ca * w2.y)), ch, con, bias);
                if (levels > 1.5) dk2 = q27(dk2, levels);
                float r2 = 0.5 * (1.0 - sqrt(max(1.0 - dk2, 0.0)));
                float lc2 = dk2 <= 0.002 ? 0.0 : (dk2 >= 0.998 ? 1.0 : 1.0 - smoothstep(r2 - aa, r2 + aa, abs(g.x - ctr2.x)));
                cov = max(cov, lc2);
            }
        }
        return saturate(cov);
    }
    float cov = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 ctr = base + float2(float(x), float(y)) + 0.5;
            float2 w = ctr * cell;
            float2 pos = org + float2(ca * w.x - sa * w.y, sa * w.x + ca * w.y);
            float dk = dark27(S27(tone, pos), ch, con, bias);
            if (levels > 1.5) dk = q27(dk, levels);
            cov += spot27(g - ctr, dk, shape, aa);
        }
    }
    return saturate(cov);
}

/// textures: 0 src, 1 dst, 2 tone (blurred src).
/// a = (cell / spacing px, angle rad, contrast, mix 0-1), b = ink (straight), c = paper (straight),
/// d = (tone bias, keep color 0-1, mode value 1, mode value 2), i = (mode, shape, flags, levels)
/// modes: 0 dot screen (flags bit0 = per-channel color dots), 1 line screen, 2 CMYK, 3 cross hatch, 4 stipple, 5 woodcut
kernel void fxPrint27(texture2d<half, access::sample> src [[texture(0)]],
                      texture2d<half, access::write> dst [[texture(1)]],
                      texture2d<half, access::sample> tone [[texture(2)]],
                      constant EffectParams& p [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float2 org = size * 0.5;
    float4 s = S27(src, c);
    float3 col = straight27(s);
    float cell = max(p.a.x, 1.0), ang = p.a.y, con = max(p.a.z, 0.0), mixAmt = saturate(p.a.w);
    float bias = p.d.x, keep = saturate(p.d.y);
    int shape = int(p.i.y);
    float levels = float(p.i.w);
    float3 tc = straight27(S27(tone, c));
    float3 ink = mix(p.b.rgb, tc * 0.9, keep);
    float3 paper = p.c.rgb;
    float3 res;
    switch (p.i.x) {
    case 0: {
        if ((p.i.z & 1u) != 0u) {
            float3 cv = float3(screen27(tone, c, org, cell, ang, shape, 0, con, bias, levels),
                               screen27(tone, c, org, cell, ang, shape, 1, con, bias, levels),
                               screen27(tone, c, org, cell, ang, shape, 2, con, bias, levels));
            res = mix(paper, p.b.rgb, cv);
        } else {
            float cv = screen27(tone, c, org, cell, ang, shape, 3, con, bias, levels);
            res = mix(paper, ink, cv);
        }
        break; }
    case 1: {
        float cv = screen27(tone, c, org, cell, ang, 3, 3, con, bias, levels);
        res = mix(paper, ink, cv);
        break; }
    case 2: {
        // Process inks overprint (multiply) on paper at the classic screen angles.
        float cC = screen27(tone, c, org, cell, ang, shape, 4, con, bias, 0.0);
        float cM = screen27(tone, c, org, cell, ang + 1.0472, shape, 5, con, bias, 0.0);
        float cY = screen27(tone, c, org, cell, ang - 0.2618, shape, 6, con, bias, 0.0);
        float cK = screen27(tone, c, org, cell, ang + 0.5236, shape, 7, con, bias, 0.0);
        float3 r = paper;
        r *= mix(float3(1.0), float3(0.0, 0.62, 0.90), cC);
        r *= mix(float3(1.0), float3(0.92, 0.0, 0.50), cM);
        r *= mix(float3(1.0), float3(1.0, 0.92, 0.0), cY);
        r *= mix(float3(1.0), float3(0.12, 0.11, 0.13), cK);
        res = r;
        break; }
    case 3: {
        // Pen hatching: up to four stroke layers switch on as the tone darkens; strokes wobble a little and break
        // into separate pen strokes in the lighter layers.
        float dk = dark27(S27(tone, c), 3, con, bias);
        float lw = max(p.d.z, 0.4);
        float wob = (vn27(c / (cell * 7.0), 3.0) - 0.5) * 0.5;
        float angs[4] = { 0.785398, -0.785398, 0.0, 1.570796 };
        float cov = 0.0;
        for (int j = 0; j < 4; j++) {
            float th = 0.1 + 0.2 * float(j);
            float ramp = smoothstep(th, th + 0.22, dk);
            if (ramp <= 0.0) continue;
            float a2 = ang + angs[j];
            float2 dir = float2(cos(a2), sin(a2));
            float2 rel = c - org;
            float v = dot(rel, float2(-dir.y, dir.x)) / cell + wob + float(j) * 0.37;
            float u = dot(rel, dir) / cell;
            float lineId = floor(v);
            float segLen = 5.0 + 5.0 * h27b(lineId, float(j) + 2.0);
            float seg = h27(float2(floor(u / segLen + h27b(lineId, float(j) + 9.0)), lineId), float(j) + 5.0);
            float present = smoothstep(seg - 0.2, seg + 0.05, ramp * 1.25);
            float d = abs(fract(v) - 0.5) * cell;
            float w = lw * (0.4 + 0.6 * ramp) * 0.5;
            cov = max(cov, (1.0 - smoothstep(w - 0.55, w + 0.55, d)) * present);
        }
        res = mix(mix(paper, mix(tc, float3(1.0), 0.3), keep), ink, cov);
        break; }
    case 4: {
        // Stipple: one jittered dot per cell, present with a probability that follows darkness; dots grow and
        // merge only in the deepest shadows.
        float dens = max(p.d.z, 0.0);
        float2 g = c / cell;
        float2 base = floor(g);
        float cov = 0.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                float2 id = base + float2(float(x), float(y));
                float2 pos = (id + 0.15 + 0.7 * float2(h27(id, 1.0), h27(id, 2.0))) * cell;
                float dk = dark27(S27(tone, pos), 3, con, bias) * dens;
                if (h27(id, 3.0) > saturate(dk * 1.35)) continue;
                float r = cell * (0.3 + 0.4 * smoothstep(0.55, 1.1, dk)) * (0.85 + 0.3 * h27(id, 4.0));
                cov = max(cov, 1.0 - smoothstep(r - 0.6, r + 0.6, length(c - pos)));
            }
        }
        res = mix(mix(paper, mix(tc, float3(1.0), 0.3), keep), ink, cov);
        break; }
    default: {
        // Woodcut: carved lines bend with the forms (tone + slow flow), black line width follows darkness,
        // deepest shadows stay solid wood, highlights are gouged clean, and edges are cut in black.
        float warp = p.d.z, edgeAmt = p.d.w;
        float dk = dark27(S27(tone, c), 3, con, bias);
        float e = cell * 0.5;
        float gx = dark27(S27(tone, c + float2(e, 0.0)), 3, 1.0, 0.0) - dark27(S27(tone, c - float2(e, 0.0)), 3, 1.0, 0.0);
        float gy = dark27(S27(tone, c + float2(0.0, e)), 3, 1.0, 0.0) - dark27(S27(tone, c - float2(0.0, e)), 3, 1.0, 0.0);
        float grad = length(float2(gx, gy));
        float flow = (vn27(c / (cell * 9.0), 7.0) - 0.5) * 2.0;
        float ca = cos(ang), sa = sin(ang);
        float2 rel = c - org;
        float v = (dot(rel, float2(-sa, ca)) + (0.5 - dk) * warp * 2.0 + flow * warp) / cell;
        float d = abs(fract(v) - 0.5) * 2.0;
        float chisel = (vn27(float2(dot(rel, float2(ca, sa)) / (cell * 4.0), floor(v)), 9.0) - 0.5) * 0.25;
        float w = saturate(dk * 1.1 - 0.05 + chisel);
        float aa = 1.2 / cell;
        float inkL = 1.0 - smoothstep(w - aa, w + aa, d);
        inkL = max(inkL, smoothstep(0.84, 0.92, dk));
        inkL *= smoothstep(0.04, 0.1, dk);
        float edge = smoothstep(0.1, 0.22, grad) * edgeAmt;
        res = mix(paper, ink, saturate(max(inkL, edge)));
        break; }
    }
    float3 o = mix(col, saturate(res), mixAmt);
    dst.write(half4(float4(o * s.a, s.a)), gid);
}

// MARK: - Ink

/// textures: 0 src, 1 dst, 2 small blur (A), 3 wider blur (B = 1.6 x A). DoG = B - A is positive on the dark side
/// of every edge, so ink lands where an artist draws it, with natural taper.
/// i.x = mode: 0 ink sketch, 1 pencil, 2 cel shading, 3 cartoon outline.
kernel void fxInk27(texture2d<half, access::sample> src [[texture(0)]],
                    texture2d<half, access::write> dst [[texture(1)]],
                    texture2d<half, access::sample> ga [[texture(2)]],
                    texture2d<half, access::sample> gb [[texture(3)]],
                    constant EffectParams& p [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 s = S27(src, c);
    float3 col = straight27(s);
    float4 A = S27(ga, c), B = S27(gb, c);
    float la = saturate(lum27(A.rgb) + (1.0 - saturate(A.a)));
    float lb = saturate(lum27(B.rgb) + (1.0 - saturate(B.a)));
    float dog = lb - la;
    float3 res;
    switch (p.i.x) {
    case 0: {
        // Ink Sketch: a = (strength, detail threshold, paper 0-1, solid blacks 0-1), b = ink, c = paper
        float thr = max(p.a.y, 0.0);
        float line = smoothstep(thr * 0.06, thr * 0.06 + 0.03, dog);
        float fillT = p.a.w * 0.32;
        float blacks = p.a.w > 0.001 ? 1.0 - smoothstep(fillT - 0.03, fillT + 0.03, la) : 0.0;
        float inkAmt = saturate(max(line, blacks)) * saturate(p.a.x);
        float3 base = mix(col, p.c.rgb, saturate(p.a.z));
        res = mix(base, p.b.rgb, inkAmt);
        break; }
    case 1: {
        // Pencil: a = (strength, hatch spacing px, outlines, -), b = paper, c = pencil.
        float sp = max(p.a.y, 1.5);
        float dk = saturate(1.0 - la);
        float tooth = vn27(c * 0.6, 11.0);
        float2 d1 = float2(cos(0.95), sin(0.95)), d2 = float2(cos(-0.6), sin(-0.6));
        float v1 = dot(c, float2(-d1.y, d1.x)) / sp + (vn27(c / (sp * 6.0), 2.0) - 0.5) * 0.6;
        float v2 = dot(c, float2(-d2.y, d2.x)) / sp + (vn27(c / (sp * 6.0), 4.0) - 0.5) * 0.6;
        float st1 = 1.0 - smoothstep(0.12, 0.42, abs(fract(v1) - 0.5));
        float st2 = 1.0 - smoothstep(0.12, 0.42, abs(fract(v2) - 0.5));
        // Graphite streaks along each stroke direction.
        float g1 = vn27(float2(dot(c, d1) / (sp * 3.0), floor(v1)), 6.0);
        float g2 = vn27(float2(dot(c, d2) / (sp * 3.0), floor(v2)), 8.0);
        float shade = dk * 0.3 + st1 * smoothstep(0.2, 0.6, dk) * (0.45 + 0.35 * g1) + st2 * smoothstep(0.5, 0.9, dk) * (0.4 + 0.35 * g2);
        shade *= 0.7 + 0.6 * tooth;
        float lines = smoothstep(0.006, 0.05, dog) * p.a.z;
        float cov = saturate(shade * p.a.x + lines * 0.85);
        res = mix(p.b.rgb, p.c.rgb, cov);
        break; }
    case 2: {
        // Cel Shading: a = (levels, edge threshold, -, -), b = line color. Brightness snaps to flat bands (hue kept),
        // with a narrow soft step so band borders stay clean, plus ink lines.
        float3 ca = straight27(A);
        float L = lum27(ca);
        float lv = max(floor(p.a.x), 2.0);
        float band = L * lv;
        float Lq = (floor(band) + smoothstep(0.44, 0.56, fract(band))) / lv;
        Lq = max(Lq, 0.5 / lv);
        float3 cel = ca * (Lq / max(L, 1e-3));
        float m = max(cel.r, max(cel.g, cel.b));
        if (m > 1.0) cel /= m;
        float y = lum27(cel);
        cel = saturate(mix(float3(y), cel, 1.15));
        float thr = max(p.a.y, 0.0);
        float line = smoothstep(thr * 0.05, thr * 0.05 + 0.03, dog);
        res = mix(cel, p.b.rgb, line);
        break; }
    default: {
        // Cartoon Outline: a = (-, threshold, color boost 0-1, -), b = ink. Thick tapered lines, punchier fills.
        float3 ca = mix(col, straight27(A), 0.5);
        float y = lum27(ca);
        float3 fill = saturate(mix(float3(y), ca, 1.0 + p.a.z * 1.2));
        float thr = max(p.a.y, 0.0);
        float line = smoothstep(thr * 0.12, thr * 0.12 + 0.035, dog);
        res = mix(fill, p.b.rgb, line);
        break; }
    }
    dst.write(half4(float4(saturate(res) * s.a, s.a)), gid);
}

// MARK: - Film / TV

static inline float3 heat27(float h) {
    float3 r = mix(float3(0.45, 0.02, 0.0), float3(0.95, 0.25, 0.02), smoothstep(0.0, 0.4, h));
    r = mix(r, float3(1.0, 0.62, 0.15), smoothstep(0.35, 0.7, h));
    return mix(r, float3(1.0, 0.93, 0.75), smoothstep(0.75, 1.0, h));
}

/// Barrel-curved CRT glass: returns the source position, and the glass mask in `m` (1 inside, 0 outside, AA).
static inline float2 glass27(float2 c, float2 size, float k, thread float& m) {
    float2 uv = c / size * 2.0 - 1.0;
    float2 w = uv * (1.0 + k * dot(uv, uv));
    float2 ed = (1.0 - abs(w)) * size * 0.5;
    m = saturate(min(ed.x, ed.y) / 1.5);
    return (w * 0.5 + 0.5) * size;
}

/// textures: 0 src, 1 dst, 2 aux (blurred src for CRT bloom, else src). d = (time, unit, frame index, -)
/// i.x = mode: 0 film burn, 1 analog TV, 2 scan distort, 3 CRT, 4 film grain.
kernel void fxFilm27(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     texture2d<half, access::sample> aux [[texture(2)]],
                     constant EffectParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float t = p.d.x, u = max(p.d.y, 0.25), fr = p.d.z;
    float4 s = S27(src, c);
    float a0 = s.a;
    float3 col = straight27(s);
    float3 x;
    switch (p.i.x) {
    case 0: {
        // Film Burn: a = (intensity, speed, size 0-1). Light leaks in from the edges, mostly from one side that
        // drifts over time: deep red, orange, then a white-hot core right at the edge. The middle stays picture.
        float2 uv = c / size;
        float asp = size.x / max(size.y, 1.0);
        float tt = t * p.a.y;
        float2 dd = min(uv, 1.0 - uv) * float2(asp, 1.0);
        float e = min(dd.x, dd.y);
        float an = tt * 0.23 + 0.7;
        float side = dot(uv - 0.5, float2(cos(an), sin(an))) * 0.7 + 0.5;
        float2 np = float2(uv.x * asp, uv.y);
        float n = fbm27(np * 3.0 + float2(tt * 0.35, -tt * 0.2), 1.0);
        float n2 = fbm27(np * 9.0 - float2(0.0, tt * 0.6), 4.0);
        float reach = p.a.z * 0.6 * (0.3 + 0.9 * n + 0.25 * n2) * (0.35 + side);
        float heat = saturate((reach - e) / max(reach * 0.65, 0.02));
        heat = heat * heat * (3.0 - 2.0 * heat);
        heat *= 0.85 + 0.15 * vn27(float2(tt * 8.0, 0.0), 9.0);
        float I = max(p.a.x, 0.0);
        float3 light = saturate(heat27(heat) * heat * I);
        float3 exposed = saturate(col * (1.0 + heat * 1.2 * I));
        x = 1.0 - (1.0 - exposed) * (1.0 - light);
        // The burn adds light even past the layer's shape (it is light on the film).
        float aOut = max(a0, saturate(max(light.r, max(light.g, light.b))));
        float3 pm = x * a0 + light * (aOut - a0);
        dst.write(half4(float4(min(pm, float3(aOut)), aOut)), gid);
        return; }
    case 1: {
        // Analog TV: a = (noise 0-1, roll speed, chroma bleed px). Sharp luma with low-resolution, delayed chroma,
        // a faint ghost, vertical roll with a black blanking bar, a hum bar and monochrome snow.
        float nz = saturate(p.a.x);
        float roll = fract(t * p.a.y) * size.y;
        float yy = c.y - roll;
        yy -= floor(yy / size.y) * size.y;
        float lineN = floor(yy / max(u, 1.0));
        float jit = (h27b(lineN, fr) - 0.5) * nz * 2.5 * u;
        float2 q = float2(c.x + jit, yy);
        float4 L = (S27(src, q - float2(u, 0.0)) + S27(src, q) * 2.0 + S27(src, q + float2(u, 0.0))) * 0.25;
        float Y = lum27(straight27(L));
        float bleed = max(p.a.z, u);
        float3 ch = float3(0.0);
        for (int k = 0; k < 8; k++) ch += straight27(S27(src, q - float2(bleed * (0.3 + float(k) / 7.0), 0.0)));
        ch /= 8.0;
        float3 chroma = (ch - lum27(ch)) * (1.0 - 0.55 * nz);
        float ghost = lum27(straight27(S27(src, q - float2(bleed * 2.0 + 7.0 * u, 0.0))));
        Y = mix(Y, ghost, 0.12);
        x = float3(Y) + chroma;
        float g1 = h27(floor(c / float2(1.5 * u, u)), fr * 3.0 + 1.0), g2 = h27(floor(c / float2(1.5 * u, u)), fr * 3.0 + 2.0);
        float snow = (g1 + g2 - 1.0);
        x = mix(x, float3(0.5), nz * 0.25) + snow * nz * 0.55;
        float streak = step(1.0 - nz * 0.03, h27b(floor(c.y / u), fr + 4.0));
        x += streak * 0.35 * h27b(floor(c.x / (40.0 * u)), fr + floor(c.y));
        float hum = 0.5 + 0.5 * sin((c.y / size.y - t * 0.12) * 6.2832);
        x *= 1.0 - 0.1 * hum * step(0.001, p.a.y + nz);
        x *= 0.93 + 0.07 * cos(c.y / max(u, 1.0) * 3.14159);
        float blank = p.a.y > 0.001 ? smoothstep(size.y * 0.94, size.y * 0.95, yy) : 0.0;
        x *= 1.0 - blank;
        break; }
    case 2: {
        // Scan Distort: a = (roll speed, sync wobble px, scanlines 0-1, curvature 0-1). Curved glass with black
        // outside, a rolling picture with a black blanking bar at the seam, smooth sync wobble near a moving bar.
        float m;
        float2 q = glass27(c, size, p.a.w * 0.3, m);
        float y = q.y + fract(t * p.a.x) * size.y;
        y -= floor(y / size.y) * size.y;
        float barPos = fract(t * 0.35) * 1.3 - 0.15;
        float dyb = (q.y / size.y - barPos) / 0.07;
        float bar = exp(-dyb * dyb);
        float wob = bar * (sin(q.y * 0.045 / u + t * 7.0) * 0.7 + (h27b(floor(q.y / (2.0 * u)), fr) - 0.5) * 0.6)
                  + 0.12 * sin(q.y * 0.013 / u + t * 2.1);
        float2 sq = float2(q.x + wob * p.a.y, y);
        float4 v = Z27(src, sq);
        x = v.rgb * (1.0 + 0.18 * bar);
        float per = max(2.5 * u, 2.0);
        x *= 1.0 - p.a.z * 0.55 * (0.5 - 0.5 * cos(c.y / per * 6.2832));
        float2 uv = c / size * 2.0 - 1.0;
        x *= (1.0 - 0.25 * p.a.w * dot(uv, uv)) * m;
        float blank = p.a.x > 0.001 ? smoothstep(size.y * 0.955, size.y * 0.965, y) : 0.0;
        x *= 1.0 - blank;
        dst.write(half4(float4(min(saturate(x), float3(a0)), a0)), gid);
        return; }
    case 3: {
        // CRT: a = (strength 0-1, line px, curvature 0-1). Gaussian beam per scanline (bright beams bloom wider),
        // aperture grille that keeps white balance, halation from the blurred copy, curved glass.
        float st = saturate(p.a.x);
        float m;
        float2 q = glass27(c, size, p.a.z * 0.3, m);
        float4 v = Z27(src, q);
        float3 bl = straight27(S27(aux, q)) * S27(aux, q).a;
        float per = max(p.a.y, 1.0);
        float fy = fract(q.y / per) - 0.5;
        float Lm = lum27(v.rgb);
        float sg = mix(0.2, 0.42, sqrt(saturate(Lm)));
        float beam = exp(-fy * fy / (2.0 * sg * sg)) / (sg * 2.5066);
        float3 scan = v.rgb * mix(1.0, beam, st);
        float colI = fmod(floor(c.x / max(1.0, per / 3.0)), 3.0);
        float3 mask = float3(colI < 0.5 ? 1.0 : 0.0, (colI >= 0.5 && colI < 1.5) ? 1.0 : 0.0, colI >= 1.5 ? 1.0 : 0.0);
        scan *= mix(float3(1.0), mask * 2.4 + 0.2, st * 0.4);
        scan += bl * 0.22 * st;
        float2 uv = c / size * 2.0 - 1.0;
        x = scan * (1.0 - 0.22 * st * dot(uv, uv)) * m;
        dst.write(half4(float4(min(saturate(x), float3(a0)), a0)), gid);
        return; }
    default: {
        // Film grain: a = (amount 0-1, grain size px, color 0/1, frame). Soft clumped grain, strongest in the
        // midtones. Color grain = dye clouds that mostly agree, never rainbow pixels.
        float gs = max(p.a.y, 0.5);
        float f = p.a.w;
        float2 g = c / gs + float2(h27b(f, 1.0), h27b(f, 2.0)) * 97.0;
        float sl = f * 0.37;
        float n = (vn27(g, sl) - 0.5) + (vn27(g * 2.1, sl + 3.0) - 0.5) * 0.5 + (h27(floor(c), sl + 5.0) - 0.5) * 0.3;
        n *= 1.6;
        float L = lum27(col);
        float w = 0.35 + 2.2 * L * (1.0 - L);
        float amt = p.a.x * w * 0.6;
        if (p.a.z > 0.5) {
            float3 dye = float3(vn27(g * 1.3, sl + 7.0), vn27(g * 1.3, sl + 8.0), vn27(g * 1.3, sl + 9.0)) - 0.5;
            x = col + (n + (dye - (dye.r + dye.g + dye.b) / 3.0) * 0.7) * amt;
        } else {
            x = col + n * amt;
        }
        break; }
    }
    dst.write(half4(float4(saturate(x) * a0, a0)), gid);
}

// MARK: - Glitch

static inline float burst27(float t, float rate, float len, float seed) {
    float r = max(rate, 0.01);
    float s = floor(t * r), ph = fract(t * r);
    bool fire = fmod(s, 2.0) >= 1.0 || h27b(s * 1.37, seed) < 0.45;
    if (!fire) return 0.0;
    return exp(-ph / max(len, 0.02) * 2.5) * (0.6 + 0.4 * h27b(s * 3.1, seed + 1.0));
}
static inline float k27(float t, float4 b) {
    return b.x + burst27(t, b.y, b.z, b.w) + burst27(t, b.y * 3.7, b.z * 0.5, b.w + 17.0) * 0.35;
}
/// Codec-style mixed-size blocks: (origin, size).
static inline float4 block27(float2 c, float2 big, float minSize, float salt, float split) {
    float2 s = max(big, float2(1.0));
    float2 o = floor(c / s) * s;
    for (int l = 0; l < 4; l++) {
        if (min(s.x, s.y) * 0.5 < minSize) break;
        if (h27(o / max(minSize, 1.0), salt + float(l) * 31.0) > split) break;
        s *= 0.5;
        o += step(o + s, c) * s;
    }
    return float4(o, s);
}
static inline float4 split27(texture2d<half, access::sample> t, float2 q, float2 d) {
    float4 g = S27(t, q);
    if (dot(d, d) < 1e-4) return g;
    float4 r = S27(t, q + d), b = S27(t, q - d);
    float a = max(g.a, max(r.a, b.a));
    return float4(min(float3(r.r, g.g, b.b), float3(a)), a);
}

/// textures: 0 src, 1 dst. b = timing (always on, bursts/s, length, seed), c.x = extra, d = (time, unit, -, -)
/// i.x = mode: 0 slice, 1 interlace, 2 displacement, 3 VHS tracking.
kernel void fxGlitch27(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float t = p.d.x, u = max(p.d.y, 0.25);
    float k = k27(t, p.b);
    float fr = floor(t * 12.0) + p.b.w * 7.0;
    float4 o;
    switch (p.i.x) {
    case 0: {
        // Slice: a = (offset px, slices, rgb px). Bands of mixed heights jump sideways; some freeze on one row.
        float bh = size.y / max(p.a.y, 1.0);
        float band = floor(c.y / bh);
        float sub = 1.0 + floor(h27b(band, fr + 3.0) * 3.99);
        float sh = bh / sub;
        float sb = floor((c.y - band * bh) / sh);
        float2 id = float2(band, sb);
        float on = step(h27(id, fr), 0.3 + 0.4 * saturate(k)) * step(0.02, k);
        float off = (h27(id, fr + 1.0) - 0.5) * 2.0 * p.a.x * k * on;
        float2 q = c + float2(off, 0.0);
        if (on > 0.5 && h27(id, fr + 2.0) < 0.15) q.y = band * bh + sb * sh + 0.5;
        o = split27(src, q, float2(p.a.z * k * (0.2 + 0.8 * on), 0.0));
        break; }
    case 1: {
        // Interlace / Bad TV: a = (split px, wobble px, scanlines 0-1). The two fields comb apart, the other field
        // lags behind as a ghost, line groups tear on bursts.
        float fh = max(1.0, floor(u + 0.5));
        float field = fmod(floor(c.y / fh), 2.0);
        float sgn = field > 0.5 ? 1.0 : -1.0;
        float wob = sin(c.y / size.y * 12.0 + t * 6.0) * p.a.y * min(k, 1.5);
        float grp = floor(c.y / (fh * 24.0));
        float tear = step(h27b(grp, fr), 0.25 * saturate(k)) * (h27b(grp, fr + 1.0) - 0.5) * 6.0 * p.a.x * k;
        float2 q = c + float2(sgn * p.a.x * 0.5 * k + wob + tear, 0.0);
        o = S27(src, q);
        float4 prev = S27(src, c + float2(-sgn * p.a.x * 0.5 * k + wob * 0.6, 0.0));
        o = mix(o, prev, 0.22 * saturate(k));
        o.rgb *= 1.0 - p.a.z * 0.45 * field;
        break; }
    case 2: {
        // Displacement: a = (amount px, block px, steps/s, vertical 0-1). Mixed-size blocks jump in quantized steps.
        float bs = max(p.a.y, 2.0);
        float st = floor(t * max(p.a.z, 1.0)) + p.b.w * 3.0;
        float4 blk = block27(c, float2(bs * 4.0, bs * 2.0), bs * 0.5, st, 0.55);
        float2 id = blk.xy / max(blk.zw, float2(1.0));
        float on = step(h27(id, st + 1.0), 0.1 + 0.45 * saturate(k)) * step(0.01, k);
        float nx = h27(id, st + 2.0) - 0.5, ny = h27(id, st + 3.0) - 0.5;
        float2 dv = float2(round(nx * 4.0) / 4.0, round(ny * 4.0) / 4.0 * p.a.w) * 2.0 * p.a.x * k * on;
        o = split27(src, c + dv, float2(on * bs * 0.15 * saturate(k), 0.0));
        break; }
    default: {
        // VHS Tracking: a = (tracking px, band 0-1, roll speed, noise 0-1), c.x = bleed px. A rolling tracking band
        // drags lines sideways, luma/chroma separate, mono tape noise and white dropouts live in the band.
        float bandY = fract(t * p.a.z * 0.25 + p.b.w * 0.1) * (size.y * 1.4) - size.y * 0.2;
        float bh = max(p.a.y * size.y * 0.5, 2.0);
        float dyb = (c.y - bandY) / bh;
        float inBand = exp(-dyb * dyb);
        float line = floor(c.y / u);
        float jit = h27b(line, fr) - 0.5;
        float wav = sin(c.y / size.y * 40.0 + t * 9.0) * 0.3;
        float kk = min(k, 1.5);
        float off = (inBand * (1.2 * jit + wav) + 0.08 * jit) * p.a.x * kk;
        off += inBand * inBand * p.a.x * 0.6 * kk * smoothstep(-1.0, 1.0, dyb);
        float2 q = c + float2(off, 0.0);
        float4 Ls = (S27(src, q - float2(u, 0.0)) + S27(src, q) * 2.0 + S27(src, q + float2(u, 0.0))) * 0.25;
        float bleed = p.c.x * (0.6 + 0.4 * saturate(k)) + u;
        float4 Cs = float4(0.0);
        for (int s = 0; s < 8; s++) Cs += S27(src, q - float2(bleed * float(s) / 7.0, 0.0));
        Cs /= 8.0;
        float a = Ls.a;
        float3 x = lum27(Ls.rgb) + (Cs.rgb - lum27(Cs.rgb));
        float nzv = (h27(float2(floor(c.x / (3.0 * u)), line), fr + 5.0) - 0.5) * p.a.w * (0.12 + 0.6 * inBand);
        x += nzv * a;
        if (h27b(line, fr + 6.0) < p.a.w * 0.12 * inBand) {
            float x0 = h27b(line, fr + 7.0) * size.x;
            float len = (30.0 + h27b(line, fr + 8.0) * 120.0) * u;
            if (c.x > x0 && c.x < x0 + len) x = mix(x, float3(a), 0.8);
        }
        o = float4(clamp(x, 0.0, a), a);
        break; }
    }
    dst.write(half4(o), gid);
}
