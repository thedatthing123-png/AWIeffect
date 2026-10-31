#include <metal_stdlib>
using namespace metal;

// Batch 16: stylize & drawing 2 — anime / manga / editing looks: anime shading, screentone, speed hatch, cartoon
// outline, contour lines / gradient, edge colorize, electric edges, glow scan, line screen, cross hatch, stipple,
// charcoal, chalkboard, blueprint, neon outline art, stained glass, pixel art, low poly, ASCII art, paper texture,
// torn edges, woodcut, graffiti spray and glitch color bands.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s16Zero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler s16Edge(address::clamp_to_edge, filter::linear, coord::pixel);

constant float hatchAng16[4] = { 0.785398, -0.785398, 0.0, 1.570796 };

static inline float3 u16(float4 c) { return c.a > 1e-6 ? c.rgb / c.a : float3(0.0); }
static inline float l16(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float h16(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float vn16(float2 x) {
    float2 i = floor(x), f = fract(x); float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(h16(i), h16(i + float2(1, 0)), u.x), mix(h16(i + float2(0, 1)), h16(i + float2(1, 1)), u.x), u.y);
}
static float2 rot16(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(cs * v.x - sn * v.y, sn * v.x + cs * v.y); }
static float3 rgb2hsv16(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-6;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
static float3 hsv2rgb16(float3 c) {
    float3 p = abs(fract(float3(c.x) + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(float3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
static float3 sat16(float3 c, float s) { float l = l16(c); return clamp(mix(float3(l), c, s), 0.0, 1.0); }
static float lumAt16(texture2d<half, access::sample> t, float2 c) { return l16(u16(float4(t.sample(s16Edge, c)))); }
static float2 sobel16(texture2d<half, access::sample> t, float2 c, float w) {
    float tl = lumAt16(t, c + float2(-w, -w)), tr = lumAt16(t, c + float2(w, -w));
    float bl = lumAt16(t, c + float2(-w, w)), br = lumAt16(t, c + float2(w, w));
    float l = lumAt16(t, c + float2(-w, 0)), r = lumAt16(t, c + float2(w, 0));
    float u = lumAt16(t, c + float2(0, -w)), d = lumAt16(t, c + float2(0, w));
    return float2((tr + 2.0 * r + br) - (tl + 2.0 * l + bl), (bl + 2.0 * d + br) - (tl + 2.0 * u + tr));
}
/// Luminance averaged over a ring of radius r (plus center) — cheap soft blur for contour effects.
static float blurLum16(texture2d<half, access::sample> t, float2 c, float r) {
    float s = lumAt16(t, c) * 2.0;
    for (int k = 0; k < 8; k++) {
        float an = float(k) * 0.785398;
        s += lumAt16(t, c + float2(cos(an), sin(an)) * r);
    }
    return s / 10.0;
}
static float glyph16(int g, float2 uv) {
    float2 d = abs(uv - 0.5);
    float m = max(d.x, d.y);
    switch (g) {
        case 1: return float(length(uv - float2(0.5, 0.72)) < 0.1);
        case 2: return float(d.y < 0.07 && d.x < 0.3);
        case 3: return float((d.y < 0.07 && d.x < 0.3) || (d.x < 0.07 && d.y < 0.3));
        case 4: return float(abs(d.x - d.y) < 0.08 && m < 0.32);
        case 5: return float((abs(d.x - 0.15) < 0.06 || abs(d.y - 0.15) < 0.06) && m < 0.36);
        case 6: { float r = length(uv - 0.5); return float(abs(r - 0.28) < 0.07 || r < 0.11); }
        default: return 0.0;
    }
}

kernel void fxDraw16(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     texture2d<half, access::sample> aux [[texture(2)]],
                     constant EffectParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s16Zero, c));
    float4 o = s;
    float t = p.d.x;
    float3 col = u16(s);
    switch (p.i.x) {
        case 0: { // anime shading: a = (tones, bias, strength), b = shadow color, c.xy = light direction
            float2 uv = c / size - 0.5;
            float v = l16(col) * 0.75 + dot(uv, p.c.xy) * 0.9 + p.a.y + 0.2;
            float tones = max(floor(p.a.x), 2.0);
            float band = floor(clamp(v, 0.0, 0.999) * tones) / (tones - 1.0);
            float mx = max(max(col.r, col.g), col.b);
            float3 base = col / max(mx, 0.05) * min(mx * 1.15 + 0.15, 1.0);
            float3 sh = mix(p.b.rgb * base, base, band) + smoothstep(0.95, 1.05, v) * 0.25;
            o = float4(clamp(mix(col, sh, p.a.z), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 1: { // manga screentone: a = (dot size, angle rad, tone bias, strength), b = ink, c = paper
            float sz = max(p.a.x, 1.0);
            float dark = clamp(1.0 - l16(col) + p.a.z, 0.0, 1.0);
            float2 f = fract(rot16(c, p.a.y) / sz) - 0.5;
            float rad = sqrt(dark) * 0.72, aa = 1.5 / sz;
            float dm = (1.0 - smoothstep(rad - aa, rad + aa, length(f))) * step(0.02, dark);
            float3 m = mix(p.c.rgb, p.b.rgb, dm);
            o = float4(clamp(mix(col, m, p.a.w), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 2: { // manga speed hatch: a = (line count, angle rad, strength, speed), b = ink
            float2 r = rot16(c - size * 0.5, p.a.y);
            float lh = size.y / max(p.a.x, 4.0);
            float idx = floor(r.y / lh), fy = fract(r.y / lh);
            float rnd = h16(float2(idx, 3.7));
            float dark = clamp(1.0 - l16(col), 0.0, 1.0);
            float dash = vn16(float2(r.x * 0.02 + rnd * 50.0 - t * p.a.w, idx));
            float on = step(rnd, dark * 1.1) * smoothstep(0.3, 0.6, dash);
            float th = 0.15 + 0.35 * dark;
            float ink = (1.0 - smoothstep(th, th + 0.15, abs(fy - 0.5) * 2.0)) * on;
            float3 paper = mix(float3(0.97, 0.96, 0.93), col, 0.25);
            float3 m = mix(paper, p.b.rgb, ink);
            o = float4(clamp(mix(col, m, p.a.z), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 3: { // cartoon outline: a = (width px, threshold, color boost), b = ink
            float l0 = l16(col), e = 0.0;
            for (int k = 0; k < 12; k++) {
                float an = float(k) * 0.523599;
                float2 d = float2(cos(an), sin(an)) * p.a.x;
                e = max(e, abs(lumAt16(src, c + d) - l0));
                e = max(e, abs(lumAt16(src, c + d * 0.5) - l0));
            }
            float ink = smoothstep(p.a.y, p.a.y + 0.08, e);
            float3 m = mix(sat16(col, 1.0 + p.a.z), p.b.rgb, ink);
            o = float4(clamp(m, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 4: { // contour lines: a = (levels, smooth px, width px, image), b = line color
            float r = max(p.a.y, 0.5), lv = max(p.a.x, 1.0);
            float v0 = blurLum16(src, c, r) * lv;
            float gx = (blurLum16(src, c + float2(1, 0), r) - blurLum16(src, c - float2(1, 0), r)) * 0.5 * lv;
            float gy = (blurLum16(src, c + float2(0, 1), r) - blurLum16(src, c - float2(0, 1), r)) * 0.5 * lv;
            float gl = max(length(float2(gx, gy)), 1e-4);
            float d = abs(fract(v0 + 0.5) - 0.5) / gl;
            float ln = (1.0 - smoothstep(p.a.z * 0.5, p.a.z * 0.5 + 1.0, d)) * smoothstep(0.0005, 0.003, gl);
            float3 m = mix(col * p.a.w, p.b.rgb, ln);
            o = float4(clamp(m, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 5: { // contour gradient: a = (levels, smooth px, strength), b = low color, c = high color
            float lv = max(floor(p.a.x), 2.0);
            float v = blurLum16(src, c, max(p.a.y, 0.5));
            float band = floor(clamp(v, 0.0, 0.999) * lv) / (lv - 1.0);
            float3 m = mix(p.b.rgb, p.c.rgb, band);
            m = hsv2rgb16(float3(fract(rgb2hsv16(m).x + band * 0.08), rgb2hsv16(m).y, rgb2hsv16(m).z));
            o = float4(clamp(mix(col, m, p.a.z), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 6: { // edge colorize: a = (width px, intensity, hue speed, background)
            float2 g = sobel16(src, c, max(p.a.x, 0.5));
            float e = clamp(length(g), 0.0, 2.0);
            float hue = fract(atan2(g.y, g.x + 1e-6) / 6.2831853 + (c.x + c.y) / (size.x + size.y) + t * p.a.z);
            float3 m = col * p.a.w + hsv2rgb16(float3(hue, 0.9, 1.0)) * e * p.a.y;
            o = float4(clamp(m, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 7: { // electric edges: a = (jitter px, intensity, speed, background), b = color
            float sp = t * p.a.z;
            float2 nc = c * 0.06;
            float2 off = float2(vn16(nc + sp), vn16(nc + 31.7 - sp)) - 0.5;
            float e = length(sobel16(src, c + off * 2.0 * p.a.x, 1.0));
            float crack = vn16(c * 0.15 + float2(sp * 3.0, -sp * 2.0));
            float flick = 0.5 + 0.5 * sin(sp * 17.0 + h16(floor(c / 8.0)) * 6.2831853);
            float bolt = smoothstep(0.3, 1.2, e) * (0.4 + 1.2 * crack) * (0.6 + 0.4 * flick);
            float3 m = col * p.a.w + p.b.rgb * bolt * p.a.y + float3(smoothstep(0.8, 1.6, e * crack)) * p.a.y * 0.5;
            o = float4(clamp(m, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 8: { // glow scan: a = (speed, width, intensity), b = color, c.xy = direction
            float u = dot(c / size - 0.5, p.c.xy) + 0.5;
            float pos = fract(t * p.a.x) * 1.2 - 0.1;
            float dd = (u - pos) / max(p.a.y, 0.005);
            float band = exp(-dd * dd);
            float e = clamp(length(sobel16(src, c, 1.0)), 0.0, 2.0);
            float3 m = col + p.b.rgb * band * (e * 1.5 + 0.12) * p.a.z;
            o = float4(clamp(m, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 9: { // halftone lines: a = (period px, angle rad, contrast, keep color), b = ink, c = paper
            float pr = max(p.a.x, 1.0);
            float dark = clamp((1.0 - l16(col) - 0.5) * p.a.z + 0.5, 0.0, 1.0);
            float f = abs(fract(rot16(c, p.a.y).y / pr) - 0.5) * 2.0;
            float aa = 2.0 / pr;
            float ln = (1.0 - smoothstep(dark - aa, dark + aa, f)) * step(0.01, dark);
            float3 m = p.a.w > 0.5 ? col * (1.0 - ln * 0.85) + (1.0 - ln) * 0.1 : mix(p.c.rgb, p.b.rgb, ln);
            o = float4(clamp(m, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 10: { // cross hatch: a = (spacing px, line width px, color mix), b = ink, c = paper
            float dark = clamp(1.0 - l16(col), 0.0, 1.0);
            float sp = max(p.a.x, 2.0), hatch = 0.0;
            for (int k = 0; k < 4; k++) {
                float thr = 0.15 + 0.2 * float(k);
                float f = abs(fract(rot16(c, hatchAng16[k]).y / sp) - 0.5) * sp;
                float ln = 1.0 - smoothstep(p.a.y * 0.5, p.a.y * 0.5 + 1.0, f);
                hatch = max(hatch, ln * smoothstep(thr, thr + 0.08, dark));
            }
            float3 paper = mix(p.c.rgb, col, p.a.z);
            o = float4(clamp(mix(paper, p.b.rgb, hatch), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 11: { // stipple: a = (cell px, density, color mix), b = ink, c = paper
            float cs = max(p.a.x, 2.0);
            float2 g = floor(c / cs), f = c / cs - g;
            float2 jp = 0.3 + 0.4 * float2(h16(g), h16(g + 17.3));
            float dark = clamp(1.0 - lumAt16(src, (g + jp) * cs), 0.0, 1.0);
            float on = step(h16(g + 41.1), dark * p.a.y);
            float rad = 0.22 + 0.12 * dark, aa = 1.0 / cs;
            float dm = (1.0 - smoothstep(rad - aa, rad + aa, length(f - jp))) * on;
            float3 paper = mix(p.c.rgb, col, p.a.z);
            o = float4(clamp(mix(paper, p.b.rgb, dm), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 12: { // charcoal: a = (edge strength, grain, smudge px), b = paper
            float e = length(sobel16(src, c, max(p.a.z, 0.5)));
            float2 r = rot16(c, 0.6);
            float streak = vn16(float2(r.x * 0.04, r.y * 0.5));
            float dark = clamp((1.0 - l16(col)) * 0.85 + e * p.a.x * 0.5, 0.0, 1.0);
            dark *= 0.75 + 0.5 * mix(0.5, streak, p.a.y);
            float v = clamp(1.0 - dark + (h16(c) - 0.5) * 0.15 * p.a.y, 0.0, 1.0);
            o = float4(clamp(p.b.rgb * v, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 13: { // chalkboard: a = (edge width px, fill, grain), b = board, c = chalk
            float e = clamp(length(sobel16(src, c, max(p.a.x, 0.5))), 0.0, 1.5);
            float n = vn16(rot16(c, 0.4) * float2(0.08, 0.9));
            float g = h16(c * 1.37);
            float chalk = clamp(e * 0.9 + l16(col) * p.a.y, 0.0, 1.0) * mix(1.0, (0.4 + 0.8 * n) * (0.6 + 0.6 * g), p.a.z);
            float3 board = p.b.rgb + 0.04 * vn16(c * 0.03);
            o = float4(clamp(mix(board, p.c.rgb, clamp(chalk, 0.0, 1.0)), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 14: { // blueprint: a = (grid px, line width px, grid opacity, ghost fill), b = paper blue
            float e = clamp(length(sobel16(src, c, max(p.a.y, 0.5))), 0.0, 1.0);
            float gs = max(p.a.x, 3.0);
            float2 gf = abs(fract(c / gs + 0.5) - 0.5) * gs;
            float2 gf5 = abs(fract(c / (gs * 5.0) + 0.5) - 0.5) * gs * 5.0;
            float gl = 1.0 - smoothstep(0.0, 1.2, min(gf.x, gf.y));
            float gl5 = 1.0 - smoothstep(0.0, 1.5, min(gf5.x, gf5.y));
            float3 m = p.b.rgb + float3(0.85, 0.92, 1.0) * (max(gl * 0.5, gl5) * p.a.z + l16(col) * p.a.w);
            m = mix(m, float3(0.92, 0.96, 1.0), e);
            o = float4(clamp(m, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 15: { // neon outline art: a = (core px, glow px, intensity), b = color, i.y = source hue, i.z = black bg
            float l0 = l16(col);
            float core = clamp(length(sobel16(src, c, max(p.a.x, 0.5))), 0.0, 1.5);
            float glow = 0.0;
            for (int k = 0; k < 12; k++) {
                float an = float(k) * 0.523599;
                float2 d = float2(cos(an), sin(an));
                for (int j = 1; j <= 3; j++) {
                    float w = 1.0 - float(j) * 0.25;
                    glow += abs(lumAt16(src, c + d * p.a.y * float(j) / 3.0) - l0) * w;
                }
            }
            glow /= 18.0;
            float3 neon = p.i.y == 1 ? hsv2rgb16(float3(rgb2hsv16(col).x, 0.85, 1.0)) : p.b.rgb;
            float3 base = p.i.z == 1 ? float3(0.0) : col * 0.35;
            float3 m = base + neon * glow * 1.6 * p.a.z + mix(neon, float3(1.0), 0.6) * core * p.a.z * 0.8;
            o = float4(clamp(m, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 16: { // stained glass: a = (cell px, lead px, saturation, light), b = lead color
            float cs = max(p.a.x, 3.0);
            float2 q = c / cs, gi = floor(q), best = gi;
            float d1 = 1e9, d2 = 1e9;
            for (int y = -1; y <= 1; y++) {
                for (int x = -1; x <= 1; x++) {
                    float2 cell = gi + float2(x, y);
                    float2 pt = cell + 0.15 + 0.7 * float2(h16(cell), h16(cell + 19.19));
                    float d = length(q - pt);
                    if (d < d1) { d2 = d1; d1 = d; best = pt; } else if (d < d2) { d2 = d; }
                }
            }
            float lead = 1.0 - smoothstep(p.a.y, p.a.y + 1.0, (d2 - d1) * cs * 0.5);
            float3 gc = sat16(u16(float4(src.sample(s16Edge, best * cs))), p.a.z);
            float shine = 1.0 + (h16(floor(best * 7.0)) - 0.5) * p.a.w + p.a.w * 0.6 * (1.0 - clamp(d1, 0.0, 1.0));
            float3 m = mix(clamp(gc * shine, 0.0, 1.0), p.b.rgb, lead);
            o = float4(clamp(m, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 17: { // pixel art: a = (pixel px, palette levels, outline threshold), b = outline color
            float ps = max(p.a.x, 1.0);
            float2 bi = floor(c / ps);
            float4 bc = float4(src.sample(s16Edge, (bi + 0.5) * ps));
            float3 bcol = u16(bc);
            float lv = max(floor(p.a.y), 2.0) - 1.0;
            float3 qc = floor(bcol * lv + 0.5) / lv;
            float bl = l16(bcol), nm = 0.0, na = 0.0;
            for (int k = 0; k < 4; k++) {
                float2 od = k == 0 ? float2(1, 0) : (k == 1 ? float2(-1, 0) : (k == 2 ? float2(0, 1) : float2(0, -1)));
                float4 nc = float4(src.sample(s16Edge, (bi + od + 0.5) * ps));
                nm = max(nm, l16(u16(nc)));
                na = max(na, nc.a);
            }
            float outline = step(p.a.z, nm - bl);
            float3 m = mix(qc, p.b.rgb, outline);
            float ao = max(bc.a, outline * na);
            o = float4(clamp(m, 0.0, 1.0) * ao, ao);
            break;
        }
        case 18: { // low poly: a = (facet px, shading, wireframe), b = wire color
            float sz = max(p.a.x, 3.0);
            float2 x = c / sz;
            float sk = (x.x + x.y) * 0.3660254;
            float2 ij = floor(x + sk);
            float2 xs = x + sk - ij;
            bool lower = xs.x > xs.y;
            float2 o1 = lower ? float2(1, 0) : float2(0, 1);
            float2 cs = ij + (o1 + float2(1.0)) / 3.0;
            float2 cu = cs - (cs.x + cs.y) * 0.2113249;
            float4 tc = float4(src.sample(s16Edge, cu * sz));
            float shade = 1.0 + (h16(ij * 1.7 + (lower ? 0.0 : 13.1)) - 0.5) * p.a.y;
            float ed = lower ? min(min(xs.y, 1.0 - xs.x), abs(xs.x - xs.y) * 0.7071)
                             : min(min(xs.x, 1.0 - xs.y), abs(xs.x - xs.y) * 0.7071);
            float wire = (1.0 - smoothstep(0.5, 1.5, ed * sz)) * p.a.z;
            float3 m = mix(clamp(u16(tc) * shade, 0.0, 1.0), p.b.rgb, wire);
            o = float4(clamp(m, 0.0, 1.0) * tc.a, tc.a);
            break;
        }
        case 19: { // ASCII art: a = (cell px, gain), b = text color, i.y = source color
            float cs = max(p.a.x, 3.0);
            float2 gi = floor(c / cs), uv = c / cs - gi;
            float4 bc = float4(src.sample(s16Edge, (gi + 0.5) * cs));
            float3 bcol = u16(bc);
            float lv = clamp(l16(bcol) * p.a.y, 0.0, 0.999);
            float gm = glyph16(int(lv * 7.0), uv);
            float mx = max(max(bcol.r, bcol.g), bcol.b);
            float3 tcol = p.i.y == 1 ? bcol / max(mx, 0.05) : p.b.rgb;
            o = float4(clamp(tcol * gm, 0.0, 1.0) * bc.a, bc.a);
            break;
        }
        case 20: { // paper texture: a = (amount, grain px, fibers), b = paper tint
            float gs = max(p.a.y, 0.5);
            float n = vn16(c / gs) * 0.5 + vn16(c / (gs * 4.0)) * 0.35 + h16(floor(c)) * 0.15;
            float2 r = rot16(c, 0.35);
            float fib = smoothstep(0.55, 0.9, vn16(float2(r.x / (gs * 12.0), r.y / (gs * 0.8))));
            float tex = clamp(0.82 + n * 0.25 - fib * 0.25 * p.a.z, 0.0, 1.0);
            float3 m = p.b.rgb * tex * (0.22 + 0.78 * col);
            o = float4(clamp(mix(col, m, p.a.x), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 21: { // torn edges: a = (amount px, roughness px, fringe px), b = fringe color
            float sc = max(p.a.y, 1.0);
            float2 off = (float2(vn16(c / sc), vn16(c / sc + 17.3)) - 0.5) * 2.0 * p.a.x;
            float fine = vn16(c / (sc * 0.25) + 5.1) - 0.5;
            float2 q = c + off;
            float4 ds = float4(src.sample(s16Zero, q));
            float ta = smoothstep(0.42, 0.58, ds.a + fine * 0.35);
            float fr = p.a.z;
            float er = min(min(float(src.sample(s16Zero, q + float2(fr, 0)).a), float(src.sample(s16Zero, q - float2(fr, 0)).a)),
                           min(float(src.sample(s16Zero, q + float2(0, fr)).a), float(src.sample(s16Zero, q - float2(0, fr)).a)));
            float fm = 1.0 - smoothstep(0.42, 0.58, er + fine * 0.35);
            float3 m = mix(u16(ds), p.b.rgb, fm);
            o = float4(clamp(m, 0.0, 1.0) * ta, ta);
            break;
        }
        case 22: { // woodcut: a = (period px, warp px, bias, edge ink), b = ink, c = paper
            float l = l16(col);
            float w = (vn16(c * 0.03) - 0.5) * 2.0 * p.a.y + (vn16(c * 0.011 + 7.0) - 0.5) * p.a.y;
            float2 r = rot16(c, 0.5 + l * 0.6);
            float f = abs(fract((r.y + w) / max(p.a.x, 2.0)) - 0.5) * 2.0;
            float dark = clamp(1.0 - l + p.a.z, 0.0, 1.0);
            float ink = (1.0 - smoothstep(dark - 0.08, dark + 0.08, f)) * step(0.02, dark);
            ink = max(ink, smoothstep(0.3, 0.8, length(sobel16(src, c, 1.0))) * p.a.w);
            o = float4(clamp(mix(p.c.rgb, p.b.rgb, ink), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 23: { // graffiti spray: a = (levels, noise, grain px, saturation)
            float gs = max(p.a.z, 1.0);
            float n = h16(floor(c / gs)) - 0.5;
            float n2 = vn16(c * 0.05) - 0.5;
            float3 v = sat16(col, p.a.w) + (n * 0.8 + n2 * 0.6) * p.a.y;
            float lv = max(floor(p.a.x), 2.0) - 1.0;
            float3 q = floor(clamp(v, 0.0, 1.0) * lv + 0.5) / lv;
            o = float4(clamp(q, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 24: { // glitch art color bands: a = (band px, amount, shift px, speed)
            float bh = max(p.a.x, 1.0);
            float bi = floor(c.y / bh);
            float seed = floor(t * p.a.w);
            float r1 = h16(float2(bi, seed)), r2 = h16(float2(bi * 1.3 + 5.0, seed + 3.0)), r3 = h16(float2(bi + 11.0, seed * 1.7 + 1.0));
            float on = step(r1, p.a.y);
            float dx = (r2 - 0.5) * 2.0 * p.a.z * on;
            float4 sh = float4(src.sample(s16Edge, c + float2(dx, 0.0)));
            float3 hsv = rgb2hsv16(u16(sh));
            hsv.x = fract(hsv.x + r3 * on);
            hsv.y = mix(hsv.y, 1.0, 0.6 * on);
            float3 g = hsv2rgb16(hsv);
            if (on > 0.5 && r3 > 0.66) g = g.brg; else if (on > 0.5 && r3 > 0.33) g = g.gbr;
            o = float4(clamp(g, 0.0, 1.0) * sh.a, sh.a);
            break;
        }
        default: break;
    }
    dst.write(half4(o), gid);
}
