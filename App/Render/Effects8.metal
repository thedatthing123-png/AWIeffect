#include <metal_stdlib>
using namespace metal;

// Batch 8: color grading, blurs and painterly / drawing styles — grade wheels, HSL secondary, selective color,
// split toning, channel mixer, film stocks (bleach bypass, cross process, infrared, sepia, vintage fade), thermal,
// night vision, cel shading, oil paint, watercolor, pencil, CMYK halftone, tiles, crystallize, pointillism,
// box / spin / frosted / tilt-shift blurs, star + anamorphic streaks, sharpen pro and long shadow.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s8Zero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler s8Edge(address::clamp_to_edge, filter::linear, coord::pixel);

static inline float3 u8(float4 c) { return c.a > 1e-6 ? c.rgb / c.a : float3(0.0); }
static inline float l8(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float h8(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float vn8(float2 x) {
    float2 i = floor(x), f = fract(x); float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(h8(i), h8(i + float2(1, 0)), u.x), mix(h8(i + float2(0, 1)), h8(i + float2(1, 1)), u.x), u.y);
}
static float2 rot8(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(cs * v.x - sn * v.y, sn * v.x + cs * v.y); }
static float3 rgb2hsv8(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-6;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
static float3 hsv2rgb8(float3 c) {
    float3 p = abs(fract(float3(c.x) + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(float3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
static float lumAt8(texture2d<half, access::sample> t, float2 c) { return l8(u8(float4(t.sample(s8Edge, c)))); }
static float sobel8(texture2d<half, access::sample> t, float2 c, float w) {
    float tl = lumAt8(t, c + float2(-w, -w)), tr = lumAt8(t, c + float2(w, -w));
    float bl = lumAt8(t, c + float2(-w, w)), br = lumAt8(t, c + float2(w, w));
    float l = lumAt8(t, c + float2(-w, 0)), r = lumAt8(t, c + float2(w, 0));
    float u = lumAt8(t, c + float2(0, -w)), d = lumAt8(t, c + float2(0, w));
    float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl), gy = (bl + 2.0 * d + br) - (tl + 2.0 * u + tr);
    return length(float2(gx, gy));
}
static float3 thermal8(float v) {
    float x = clamp(v, 0.0, 1.0) * 5.0;
    float3 r = mix(float3(0.0, 0.0, 0.1), float3(0.25, 0.0, 0.6), clamp(x, 0.0, 1.0));
    r = mix(r, float3(0.9, 0.0, 0.35), clamp(x - 1.0, 0.0, 1.0));
    r = mix(r, float3(1.0, 0.5, 0.0), clamp(x - 2.0, 0.0, 1.0));
    r = mix(r, float3(1.0, 0.95, 0.3), clamp(x - 3.0, 0.0, 1.0));
    return mix(r, float3(1.0), clamp(x - 4.0, 0.0, 1.0));
}
static float dot8(float2 c, float a, float sz, float v) {
    float2 r = rot8(c, a) / sz;
    float2 l = fract(r) - 0.5;
    float rad = sqrt(clamp(v, 0.0, 1.0)) * 0.7;
    float aa = 1.0 / sz;
    return (1.0 - smoothstep(rad - aa, rad + aa, length(l))) * step(0.01, v);
}

kernel void fxStyle8(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     texture2d<half, access::sample> aux [[texture(2)]],
                     constant EffectParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s8Zero, c));
    float4 o = s;
    float t = p.d.x;
    float3 col = u8(s);
    switch (p.i.x) {
        case 0: { // grade wheels: a = lift color, b = gamma color, c = gain color (0.5 = neutral), d.y = strength
            float3 lift = (p.a.rgb - 0.5) * 0.6;
            float3 gain = 1.0 + (p.c.rgb - 0.5) * 1.2;
            float3 gex = exp2((p.b.rgb - 0.5) * -2.0);
            float3 g = clamp(col + lift * (1.0 - col), 0.0, 1.0) * gain;
            g = pow(max(g, float3(0.0)), gex);
            o = float4(clamp(mix(col, g, p.d.y), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 1: { // HSL secondary: a = (hue 0-1, half range 0-0.5, softness, shift 0-1), b = (sat, light) -1..1
            float3 hsv = rgb2hsv8(col);
            float dh = abs(fract(hsv.x - p.a.x + 0.5) - 0.5);
            float w = (1.0 - smoothstep(p.a.y, p.a.y + p.a.z + 1e-3, dh)) * smoothstep(0.03, 0.15, hsv.y);
            float3 h2 = float3(fract(hsv.x + p.a.w), clamp(hsv.y * (1.0 + p.b.x), 0.0, 1.0), clamp(hsv.z * (1.0 + p.b.y), 0.0, 1.0));
            o = float4(clamp(mix(col, hsv2rgb8(h2), w), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 2: { // selective color: a = (cyan, magenta, yellow, black) -1..1, b.x = target hue 0-1
            float3 hsv = rgb2hsv8(col);
            float dh = abs(fract(hsv.x - p.b.x + 0.5) - 0.5);
            float w = (1.0 - smoothstep(0.04, 0.12, dh)) * smoothstep(0.02, 0.3, hsv.y);
            float3 r = col - p.a.rgb * w * 0.6;
            r *= 1.0 - p.a.w * w * 0.6;
            o = float4(clamp(r, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 3: { // split toning: a = shadow color, b = highlight color, c = (balance -1..1, amount)
            float k = smoothstep(0.0, 1.0, clamp(l8(col) + p.c.x * 0.5, 0.0, 1.0));
            float3 tint = mix(p.a.rgb, p.b.rgb, k);
            o = float4(clamp(col + (tint - l8(tint)) * p.c.y, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 4: { // channel mixer: a/b/c = output R/G/B rows, i.y = monochrome
            float3 m = float3(dot(col, p.a.rgb), dot(col, p.b.rgb), dot(col, p.c.rgb));
            if (p.i.y == 1) m = float3(m.r);
            o = float4(clamp(m, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 5: { // temperature / tint: a = (temp, tint) -1..1
            float3 k = float3(1.0 + 0.3 * p.a.x + 0.1 * p.a.y, 1.0 - 0.25 * p.a.y, 1.0 - 0.3 * p.a.x + 0.1 * p.a.y);
            o = float4(clamp(col * k, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 6: { // bleach bypass: a = (amount, contrast)
            float lum = l8(col);
            float3 lo = 2.0 * col * lum, hi = 1.0 - 2.0 * (1.0 - col) * (1.0 - lum);
            float3 ov = mix(lo, hi, step(0.5, lum));
            ov = (ov - 0.5) * (1.0 + p.a.y) + 0.5;
            o = float4(clamp(mix(col, ov, p.a.x), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 7: { // cross process: a = (amount, yellow highlights)
            float3 x = float3(smoothstep(0.02, 0.95, col.r), pow(max(col.g, 0.0), 0.8) * 1.05, col.b * 0.7 + 0.18);
            x.b -= p.a.y * 0.3 * l8(col);
            o = float4(clamp(mix(col, clamp(x, 0.0, 1.0), p.a.x), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 8: { // infrared: a = (amount, foliage glow)
            float v = clamp(col.r * 0.35 + col.g * (0.3 + p.a.y * 1.1) - col.b * 0.15, 0.0, 1.0);
            float3 ir = float3(v, v * 0.88, v * 0.95);
            o = float4(clamp(mix(col, ir, p.a.x), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 9: { // thermal: a = (amount, palette offset)
            float v = fract(clamp(l8(col), 0.0, 1.0) * 0.98 + p.a.y);
            o = float4(clamp(mix(col, thermal8(v), p.a.x), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 10: { // night vision: a = (gain, noise, scanlines, vignette)
            float n = (h8(c + floor(t * 30.0) * 31.7) - 0.5) * p.a.y;
            float scan = 1.0 - p.a.z * (0.5 + 0.5 * sin(c.y * 2.1));
            float vig = 1.0 - p.a.w * smoothstep(0.3, 0.95, length((c / size - 0.5) * 1.6));
            float g = clamp(l8(col) * p.a.x + n, 0.0, 1.0) * scan * vig;
            o = float4(clamp(float3(0.15, 1.0, 0.25) * g + float3(0.0, 0.04, 0.0), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 11: { // sepia plus: a = (amount, warmth, fade)
            float lum = l8(col);
            float w = p.a.y;
            float3 tone = clamp(float3(lum * (1.0 + 0.25 * w), lum * (1.0 - 0.03 * w), lum * (1.0 - 0.4 * w)), 0.0, 1.0);
            float3 r = mix(col, tone, p.a.x);
            r = r * (1.0 - p.a.z * 0.35) + p.a.z * 0.2;
            o = float4(clamp(r, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 12: { // cel shading: a = (levels, edge threshold, line width px), b = line color
            float lv = max(floor(p.a.x), 2.0) - 1.0;
            float3 q = floor(col * lv + 0.5) / lv;
            float e = sobel8(src, c, max(p.a.z, 0.5));
            float line = smoothstep(p.a.y, p.a.y + 0.1, e);
            o = float4(clamp(mix(q, p.b.rgb, line), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 13: { // oil paint (Kuwahara, 4 x 3x3 taps): a = (radius px, strength)
            float r = max(p.a.x, 0.5) * 0.5;
            float4 best = s; float bestV = 1e9;
            for (int qd = 0; qd < 4; qd++) {
                float2 sg = float2((qd & 1) ? 1.0 : -1.0, (qd & 2) ? 1.0 : -1.0);
                float4 m = float4(0.0); float sl = 0.0, sl2 = 0.0;
                for (int j = 0; j < 3; j++) {
                    for (int i = 0; i < 3; i++) {
                        float4 q = float4(src.sample(s8Edge, c + sg * float2(float(i), float(j)) * r));
                        float lq = l8(u8(q));
                        m += q; sl += lq; sl2 += lq * lq;
                    }
                }
                m /= 9.0; sl /= 9.0;
                float v = sl2 / 9.0 - sl * sl;
                if (v < bestV) { bestV = v; best = m; }
            }
            o = mix(s, best, p.a.y);
            break;
        }
        case 14: { // watercolor combine: aux = blurred, a = (edge darkening, paper, wobble px)
            float2 off = (float2(vn8(c * 0.08), vn8(c * 0.08 + 5.3)) - 0.5) * 2.0 * p.a.z;
            float4 b = float4(aux.sample(s8Zero, c + off));
            float3 ub = u8(b);
            float edge = abs(l8(col) - l8(ub));
            float3 r = ub * (1.0 - clamp(p.a.x * edge * 1.5, 0.0, 0.8));
            r = mix(r, float3(1.0), 0.06);
            r *= 1.0 - p.a.y * 0.35 * vn8(c * 0.35) - p.a.y * 0.15 * h8(c);
            o = float4(clamp(r, 0.0, 1.0) * b.a, b.a);
            break;
        }
        case 15: { // pencil sketch: a = (strength, spacing px, edges), b = paper, c = pencil
            float tone = 1.0 - clamp(l8(col), 0.0, 1.0);
            float sp = max(p.a.y, 1.0);
            float wob = vn8(c * 0.05) * sp * 0.5;
            float h1 = abs(fract((dot(c, float2(0.7071, 0.7071)) + wob) / sp) - 0.5) * 2.0;
            float h2 = abs(fract((dot(c, float2(0.7071, -0.7071)) + wob) / sp) - 0.5) * 2.0;
            float h3 = abs(fract((c.y + wob) / sp) - 0.5) * 2.0;
            float hatch = (1.0 - smoothstep(0.15, 0.45, h1)) * smoothstep(0.2, 0.35, tone);
            hatch = max(hatch, (1.0 - smoothstep(0.15, 0.45, h2)) * smoothstep(0.45, 0.6, tone));
            hatch = max(hatch, (1.0 - smoothstep(0.15, 0.45, h3)) * smoothstep(0.7, 0.85, tone));
            float e = sobel8(src, c, 1.0) * p.a.z;
            float ink = clamp((hatch * 0.8 + e) * p.a.x, 0.0, 1.0);
            o = float4(mix(p.b.rgb, p.c.rgb, ink) * s.a, s.a);
            break;
        }
        case 16: { // CMYK halftone: a = (dot size px, angle rad, mix)
            float sz = max(p.a.x, 2.0);
            float k = 1.0 - max(col.r, max(col.g, col.b));
            float3 cmy = clamp((1.0 - col - k) / (1.0 - k + 1e-4), 0.0, 1.0);
            float a0 = p.a.y;
            float ic = dot8(c, a0 + 0.2618, sz, cmy.r), im = dot8(c, a0 + 1.309, sz, cmy.g);
            float iy = dot8(c, a0, sz, cmy.b), ik = dot8(c, a0 + 0.7854, sz, k);
            float3 r = float3(1.0 - ic, 1.0 - im, 1.0 - iy) * (1.0 - ik);
            o = float4(clamp(mix(col, r, p.a.z), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 17: { // mosaic tiles: a = (tile px, grout 0-1, bevel), b = grout color
            float sz = max(p.a.x, 1.0);
            float2 cell = floor(c / sz);
            float4 q = float4(src.sample(s8Edge, (cell + 0.5) * sz));
            float2 lc = (c - cell * sz) / sz;
            float e = min(min(lc.x, 1.0 - lc.x), min(lc.y, 1.0 - lc.y));
            float aa = 1.0 / sz;
            float grout = 1.0 - smoothstep(p.a.y * 0.5 - aa, p.a.y * 0.5 + aa, e);
            float shade = 1.0 + p.a.z * ((0.5 - lc.x) + (0.5 - lc.y)) * 0.6;
            float3 r = mix(u8(q) * shade, p.b.rgb, grout);
            o = float4(clamp(r, 0.0, 1.0) * q.a, q.a);
            break;
        }
        case 18: { // crystallize (voronoi): a = (cell px, jitter, edge)
            float sz = max(p.a.x, 1.0);
            float2 g = c / sz, ig = floor(g);
            float d1 = 1e9, d2 = 1e9; float2 bp = ig + 0.5;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cp = ig + float2(float(i), float(j));
                    float2 pt = cp + 0.5 + (float2(h8(cp), h8(cp + 17.3)) - 0.5) * p.a.y;
                    float d = length(g - pt);
                    if (d < d1) { d2 = d1; d1 = d; bp = pt; } else if (d < d2) { d2 = d; }
                }
            }
            float4 q = float4(src.sample(s8Edge, bp * sz));
            float border = 1.0 - smoothstep(0.0, p.a.z * 0.5 + 1e-3, d2 - d1);
            o = float4(clamp(u8(q) * (1.0 - border * 0.6), 0.0, 1.0) * q.a, q.a);
            break;
        }
        case 19: { // pointillism: a = (dot px, jitter, dot scale), b = paper
            float sz = max(p.a.x, 1.0);
            float2 g = c / sz, ig = floor(g);
            float3 r = p.b.rgb; float al = s.a;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cp = ig + float2(float(i), float(j));
                    float2 pt = cp + 0.5 + (float2(h8(cp + 3.1), h8(cp + 9.7)) - 0.5) * p.a.y;
                    float rad = p.a.z * 0.5 * (0.75 + 0.5 * h8(cp + 5.1));
                    float cov = 1.0 - smoothstep(rad - 1.0 / sz, rad + 1.0 / sz, length(g - pt));
                    float4 q = float4(src.sample(s8Zero, pt * sz));
                    float3 qc = u8(q);
                    qc = clamp(mix(float3(l8(qc)), qc, 1.3), 0.0, 1.0);
                    r = mix(r, qc, cov * q.a);
                    al = max(al, cov * q.a);
                }
            }
            o = float4(clamp(r, 0.0, 1.0) * al, al);
            break;
        }
        case 20: { // box blur pass: a = (dir x, dir y, radius px)
            float4 acc = float4(0.0);
            const int N = 32;
            for (int k = 0; k < N; k++) {
                float f = (float(k) / float(N - 1) * 2.0 - 1.0) * p.a.z;
                acc += float4(src.sample(s8Zero, c + p.a.xy * f));
            }
            o = acc / float(N);
            break;
        }
        case 21: { // spin blur: a = (cx, cy, angle rad)
            float2 d = c - p.a.xy;
            float4 acc = float4(0.0);
            const int N = 48;
            for (int k = 0; k < N; k++) {
                float ang = (float(k) / float(N - 1) - 0.5) * p.a.z;
                acc += float4(src.sample(s8Zero, p.a.xy + rot8(d, ang)));
            }
            o = acc / float(N);
            break;
        }
        case 22: { // star streaks: a = (length px, threshold, intensity, rotation), b = tint, i.y = points
            int dirs = max(int(p.i.y), 1);
            int n = max(64 / dirs, 1);
            float3 acc = float3(0.0);
            for (int dd = 0; dd < dirs; dd++) {
                float ang = p.a.w + float(dd) * 6.2831853 / float(dirs);
                float2 dir = float2(cos(ang), sin(ang));
                for (int k = 1; k <= n; k++) {
                    float f = float(k) / float(n);
                    float4 q = float4(src.sample(s8Zero, c - dir * f * p.a.x));
                    float3 qc = u8(q);
                    float b = max(l8(qc) - p.a.y, 0.0) / max(1.0 - p.a.y, 1e-3);
                    acc += qc * q.a * b * (1.0 - f) * (1.0 - f);
                }
            }
            float3 light = acc / float(n) * p.a.z * p.b.rgb;
            o = float4(s.rgb + light, max(s.a, clamp(l8(light), 0.0, 1.0)));
            break;
        }
        case 23: { // bright pass: a.x = threshold, b = tint
            float b = max(l8(col) - p.a.x, 0.0) / max(1.0 - p.a.x, 1e-3);
            o = float4(p.b.rgb * b * s.a, b * s.a);
            break;
        }
        case 24: { // add aux * a.x
            float4 l = float4(aux.sample(s8Zero, c)) * p.a.x;
            o = float4(s.rgb + l.rgb, clamp(s.a + l.a * (1.0 - s.a), 0.0, 1.0));
            break;
        }
        case 25: { // frosted glass: a = (amount px, grain px)
            float2 cell = floor(c / max(p.a.y, 1.0));
            float4 acc = float4(0.0);
            const int N = 16;
            for (int k = 0; k < N; k++) {
                float fk = float(k);
                float2 off = (float2(h8(cell + fk * 1.7), h8(cell * 1.3 + fk * 2.9 + 7.0)) - 0.5) * 2.0 * p.a.x;
                acc += float4(src.sample(s8Zero, c + off));
            }
            o = acc / float(N);
            break;
        }
        case 26: { // tilt-shift combine: aux = blurred, a = (cx, cy, half width px, falloff px), b = (angle, saturation)
            float2 nrm = float2(-sin(p.b.x), cos(p.b.x));
            float dist = abs(dot(c - p.a.xy, nrm));
            float m = smoothstep(p.a.z, p.a.z + p.a.w + 1e-3, dist);
            float4 r = mix(s, float4(aux.sample(s8Zero, c)), m);
            float3 rc = u8(r);
            rc = mix(float3(l8(rc)), rc, 1.0 + p.b.y);
            o = float4(clamp(rc, 0.0, 1.0) * r.a, r.a);
            break;
        }
        case 27: { // sharpen pro: aux = blurred, a = (amount, threshold)
            float4 b = float4(aux.sample(s8Edge, c));
            float3 d = s.rgb - b.rgb;
            float mag = max(abs(d.r), max(abs(d.g), abs(d.b)));
            float w = smoothstep(p.a.y, p.a.y + 0.04, mag);
            o = float4(clamp(s.rgb + d * p.a.x * w, 0.0, max(s.a, 0.0)), s.a);
            break;
        }
        case 28: { // vintage fade: a = (fade, warmth -1..1, desaturate)
            float3 r = mix(col, float3(l8(col)), p.a.z);
            r = r * (1.0 - p.a.x * 0.3) + p.a.x * 0.15;
            r *= float3(1.0 + 0.12 * p.a.y, 1.0 + 0.02 * p.a.y, 1.0 - 0.15 * p.a.y);
            o = float4(clamp(r, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 29: { // long shadow: a = (dir x, dir y, length px, opacity), b = color, c.x = fade
            float sa = 0.0;
            const int N = 48;
            for (int k = 1; k <= N; k++) {
                float f = float(k) / float(N);
                float q = float(src.sample(s8Zero, c - p.a.xy * p.a.z * f).a);
                sa = max(sa, q * (1.0 - p.c.x * f));
            }
            float sh = clamp(sa * p.a.w, 0.0, 1.0) * (1.0 - s.a);
            o = float4(s.rgb + p.b.rgb * sh, s.a + sh);
            break;
        }
    }
    dst.write(half4(o), gid);
}
