#include <metal_stdlib>
using namespace metal;

// Batch 6: distortion & glitch — fisheye, lens distortion, glass, liquid, ripples, rain on glass, heat haze,
// bulge/pinch, squeeze, bend, swirl, hex tiles, shatter, slice, glitch blocks/lines, digital noise, datamosh smear,
// pixel stretch, luminance displacement, kaleidoscope, wobble, signal interference, CRT scan distort.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches). Time arrives in p.d.x.
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s6Edge(address::clamp_to_edge, filter::linear, coord::pixel);
constexpr sampler s6Zero(address::clamp_to_zero, filter::linear, coord::pixel);

static inline float4 tap6(texture2d<half, access::sample> t, float2 c) { return float4(t.sample(s6Edge, c)); }
static inline float lum6(float4 c) { float3 u = c.a > 1e-6 ? c.rgb / c.a : float3(0.0); return dot(u, float3(0.2126, 0.7152, 0.0722)); }
static float hash6(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float hash63(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static float noise63(float3 x) {
    float3 i = floor(x), f = fract(x); float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash63(i), hash63(i + float3(1, 0, 0)), u.x), mix(hash63(i + float3(0, 1, 0)), hash63(i + float3(1, 1, 0)), u.x), u.y),
               mix(mix(hash63(i + float3(0, 0, 1)), hash63(i + float3(1, 0, 1)), u.x), mix(hash63(i + float3(0, 1, 1)), hash63(i + float3(1, 1, 1)), u.x), u.y), u.z);
}
static float fbm63(float3 x) {
    float v = 0.0, amp = 0.5;
    for (int k = 0; k < 4; k++) { v += noise63(x) * amp; x = x * 2.03 + float3(1.7, 9.2, 0.0); amp *= 0.5; }
    return v / 0.9375;
}
static inline float2 rot6(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(v.x * cs - v.y * sn, v.x * sn + v.y * cs); }
static inline float2 seed6(float2 cell, float s) { return float2(hash6(cell + s * 3.7), hash6(cell.yx + s * 5.3 + 17.0)); }

kernel void fxDistort6(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       texture2d<half, access::sample> aux [[texture(2)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 o = tap6(src, c);
    float t = p.d.x;
    float hmin6 = max(min(size.x, size.y) * 0.5, 1.0);
    switch (p.i.x) {
        case 0: { // fisheye / anti-fisheye: a = (amount -1..1, radius 0-1.5 of half-min, cx, cy)
            float R = max(p.a.y * hmin6, 1.0);
            float2 d = (c - p.a.zw) / R;
            float r = length(d);
            if (r < 1.0 && r > 1e-4) {
                float e = max(1.0 + p.a.x * 1.5, 0.2);
                float rs = pow(r, e);
                o = tap6(src, p.a.zw + d / r * rs * R);
            }
            break;
        }
        case 1: { // lens distortion: a = (k1, k2, chroma 0-1, zoom), b.xy = center
            float R = max(length(size) * 0.5, 1.0);
            float2 d = (c - p.b.xy) / R;
            float r2 = dot(d, d);
            float f = (1.0 + p.a.x * r2 + p.a.y * r2 * r2) / max(p.a.w, 0.05);
            float ch = p.a.z * 0.08 * sqrt(r2);
            float4 g = tap6(src, p.b.xy + d * f * R);
            float4 rr = tap6(src, p.b.xy + d * f * (1.0 + ch) * R);
            float4 bb = tap6(src, p.b.xy + d * f * (1.0 - ch) * R);
            o = float4(rr.r, g.g, bb.b, max(g.a, max(rr.a, bb.a)));
            break;
        }
        case 2: { // glass refraction: a = (strength px, scale px, speed, seed)
            float sc = max(p.a.y, 1.0);
            float3 q = float3(c / sc, t * p.a.z + p.a.w * 1.37);
            const float e = 0.15;
            float2 g = float2(fbm63(q + float3(e, 0, 0)) - fbm63(q - float3(e, 0, 0)),
                              fbm63(q + float3(0, e, 0)) - fbm63(q - float3(0, e, 0))) / (2.0 * e);
            o = tap6(src, c + g * p.a.x);
            float spec = pow(clamp(0.5 + 0.5 * dot(normalize(float3(-g, 1.0)), normalize(float3(0.4, -0.6, 1.0))), 0.0, 1.0), 24.0);
            o.rgb += spec * 0.25 * o.a;
            break;
        }
        case 3: { // liquid warp (domain warping): a = (amount px, scale px, speed, seed)
            float sc = max(p.a.y, 1.0);
            float z = t * p.a.z * 0.5 + p.a.w * 2.13;
            float2 u = c / sc;
            float2 q = float2(fbm63(float3(u, z)), fbm63(float3(u + float2(5.2, 1.3), z)));
            float2 w = float2(fbm63(float3(u + q * 3.0 + float2(1.7, 9.2), z * 1.3)), fbm63(float3(u + q * 3.0 + float2(8.3, 2.8), z * 1.3)));
            o = tap6(src, c + (w - 0.5) * 2.0 * p.a.x);
            break;
        }
        case 4: { // water ripples: a = (amplitude px, wavelength px, speed, decay), b.xy = center
            float2 d = c - p.b.xy;
            float r = length(d);
            float2 dir = d / max(r, 1e-3);
            float ph = r / max(p.a.y, 1.0) * 6.2831853 - t * p.a.z * 6.2831853;
            float env = exp(-p.a.w * 3.0 * r / hmin6);
            o = tap6(src, c + dir * sin(ph) * p.a.x * env);
            o.rgb *= 1.0 + 0.12 * cos(ph) * env * min(p.a.x, 10.0) / 10.0;
            break;
        }
        case 5: { // rain on glass: a = (cell px, drop size 0-1, refraction, speed), c.x = seed
            float cs = max(p.a.x, 2.0);
            float4 acc = o;
            for (int layer = 0; layer < 2; layer++) {
                float lsz = cs * (layer == 0 ? 1.0 : 1.7);
                float col = floor(c.x / lsz);
                float fall = t * p.a.w * (0.4 + hash6(float2(col, p.c.x + float(layer) * 11.0))) * 1.5;
                float2 uv = float2(c.x / lsz, c.y / lsz - fall);
                float2 id = floor(uv);
                float2 f = fract(uv) - 0.5;
                float2 r = seed6(id + float(layer) * 31.0, p.c.x);
                float2 off = (r - 0.5) * 0.45;
                float rad = p.a.y * 0.4 * (0.5 + 0.5 * hash6(id * 1.3 + p.c.x));
                float2 dd = f - off;
                float l = length(dd);
                if (r.x > 0.25 && l < rad && rad > 1e-3) {
                    float k = l / rad;
                    float2 lens = -dd / rad * (1.0 - k * k) * p.a.z * lsz * 0.5;
                    float4 q = tap6(src, c + lens * 2.0 - dd * lsz * p.a.z * 0.6);
                    float hl = smoothstep(0.35, 0.0, length(dd / rad - float2(-0.35, -0.35)));
                    q.rgb = q.rgb * (0.85 + 0.15 * k) + hl * 0.35 * q.a;
                    acc = mix(acc, q, smoothstep(1.0, 0.85, k));
                }
            }
            o = acc;
            break;
        }
        case 6: { // heat haze: a = (amount px, scale px, speed, seed)
            float sc = max(p.a.y, 1.0);
            float3 q = float3(c.x / sc, c.y / sc + t * p.a.z, p.a.w * 1.91);
            float nx = noise63(q) - 0.5;
            float ny = noise63(q * 1.7 + float3(3.1, 7.7, 1.0)) - 0.5;
            o = tap6(src, c + float2(nx * 2.0, ny) * p.a.x);
            break;
        }
        case 7: { // bulge / pinch: a = (amount -1..1, radius 0-1.5 of half-min, cx, cy)
            float R = max(p.a.y * hmin6, 1.0);
            float2 d = (c - p.a.zw) / R;
            float r = length(d);
            if (r < 1.0) {
                float k = clamp(p.a.x, -1.0, 1.0) * 0.9;
                float tt = 1.0 - r;
                o = tap6(src, p.a.zw + d * (1.0 - k * tt * tt) * R);
            }
            break;
        }
        case 8: { // squeeze: a = (amount -1..1, curve, 0, 0), i.y = 0 horizontal / 1 vertical
            float2 ctr = size * 0.5;
            bool vert = p.i.y == 1;
            float across = vert ? (c.x / size.x * 2.0 - 1.0) : (c.y / size.y * 2.0 - 1.0);
            float prof = pow(clamp(1.0 - across * across, 0.0, 1.0), max(p.a.y, 0.05));
            float s = max(1.0 + clamp(p.a.x, -1.0, 1.0) * 0.8 * prof, 0.05);
            float2 d = c - ctr;
            if (vert) d.y *= s; else d.x *= s;
            o = tap6(src, ctr + d);
            break;
        }
        case 9: { // bend: a = (amount px, axis angle rad, 0, 0)
            float2 ctr = size * 0.5;
            float2 d = rot6(c - ctr, -p.a.y);
            float u = d.x / hmin6;
            d.y -= p.a.x * u * u;
            d.x *= 1.0 + 0.002 * p.a.x * u * d.y / hmin6;
            o = tap6(src, ctr + rot6(d, p.a.y));
            break;
        }
        case 10: { // swirl+: a = (twist rad, radius 0-1.5 of half-min, falloff, spin rad/s), b.xy = center
            float R = max(p.a.y * hmin6, 1.0);
            float2 d = c - p.b.xy;
            float r = length(d) / R;
            if (r < 1.0) {
                float a = (p.a.x + p.a.w * t) * pow(1.0 - r, max(p.a.z, 0.05));
                o = tap6(src, p.b.xy + rot6(d, a));
            }
            break;
        }
        case 11: { // hex tiles: a = (size px, max rotation rad, max offset px, seed), b.x = gap px
            float sz = max(p.a.x, 2.0);
            const float2 r6 = float2(1.0, 1.7320508);
            float2 g = c / sz;
            float2 h = r6 * 0.5;
            float2 a1 = g - r6 * floor(g / r6) - h;
            float2 gg = g - h;
            float2 a2 = gg - r6 * floor(gg / r6) - h;
            float2 l = dot(a1, a1) < dot(a2, a2) ? a1 : a2;
            float2 hc = (g - l) * sz;
            float2 id = floor(hc + 0.5);
            float2 rn = seed6(id, p.a.w);
            float ang = (rn.x - 0.5) * 2.0 * p.a.y;
            float2 off = (float2(hash6(id + 7.1 + p.a.w), rn.y) - 0.5) * 2.0 * p.a.z;
            o = tap6(src, hc + rot6(c - hc, ang) + off);
            float hd = max(dot(abs(l), float2(0.5, 0.8660254)), abs(l.x));
            float edge = smoothstep(0.5 - p.b.x / sz, 0.5 - p.b.x / sz * 0.3, hd) * step(1e-3, p.b.x);
            o.rgb *= 1.0 - edge * 0.85;
            break;
        }
        case 12: { // shatter: a = (progress 0-1, cell px, spread, seed), b.xy = center
            float cs = max(p.a.y, 4.0);
            float2 base = floor(c / cs);
            float4 res = float4(0.0);
            bool hit = false;
            for (int j = -2; j <= 2 && !hit; j++) {
                for (int i = -2; i <= 2 && !hit; i++) {
                    float2 k = base + float2(i, j);
                    float2 kp = (k + 0.15 + 0.7 * seed6(k, p.a.w)) * cs;
                    float2 away = kp - p.b.xy;
                    float dl = length(away);
                    float2 dir = dl > 1e-3 ? away / dl : float2(0.0, 1.0);
                    float pr = p.a.x * (0.6 + 0.8 * hash6(k + 3.3 + p.a.w));
                    float2 disp = dir * pr * p.a.z * (cs * 0.6 + dl * 0.35);
                    float ang = (hash6(k + 9.1 + p.a.w) - 0.5) * 2.0 * pr * 1.2;
                    float2 q = kp + rot6(c - disp - kp, -ang);
                    // is q nearest to seed k?
                    float2 qb = floor(q / cs);
                    float best = 1e9; float2 bk = qb;
                    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
                        float2 m = qb + float2(x, y);
                        float2 mp = (m + 0.15 + 0.7 * seed6(m, p.a.w)) * cs;
                        float dd = dot(q - mp, q - mp);
                        if (dd < best) { best = dd; bk = m; }
                    }
                    if (all(bk == k)) {
                        res = tap6(src, q);
                        res.rgb *= 1.0 - 0.35 * pr * hash6(k + 1.7);
                        hit = true;
                    }
                }
            }
            o = res;
            break;
        }
        case 13: { // perfect slice: a = (offset px, angle rad, cx, cy)
            float2 n = float2(-sin(p.a.y), cos(p.a.y));
            float2 tg = float2(cos(p.a.y), sin(p.a.y));
            float sd = dot(c - p.a.zw, n);
            float side = smoothstep(-0.75, 0.75, sd);
            float4 aSide = tap6(src, c - tg * p.a.x * 0.5);
            float4 bSide = tap6(src, c + tg * p.a.x * 0.5);
            o = mix(aSide, bSide, side);
            break;
        }
        case 14: { // glitch blocks: a = (amount px, block px, probability 0-1, rate fps), c.x = seed, c.y = rgb split px
            float frame = floor(t * p.a.w) + p.c.x * 7.0;
            float bs = max(p.a.y, 2.0);
            float2 cellSz = float2(bs * (1.0 + 3.0 * hash6(float2(floor(c.y / bs), frame))), bs);
            float2 cell = floor(c / cellSz);
            float r = hash6(cell + frame * 1.31);
            float2 shift = float2(0.0);
            float split = 0.0;
            if (r < p.a.z) {
                shift = float2((hash6(cell * 2.1 + frame) - 0.5) * 2.0 * p.a.x, (hash6(cell * 3.7 - frame) - 0.5) * p.a.x * 0.25);
                split = p.c.y * (0.5 + hash6(cell + 5.5));
            }
            float4 g = tap6(src, c + shift);
            float4 rr = tap6(src, c + shift + float2(split, 0));
            float4 bb = tap6(src, c + shift - float2(split, 0));
            o = float4(rr.r, g.g, bb.b, max(g.a, max(rr.a, bb.a)));
            break;
        }
        case 15: { // glitch lines: a = (amount px, line height px, density 0-1, rate fps), c.x = seed, c.y = chroma px
            float frame = floor(t * p.a.w) + p.c.x * 11.0;
            float lh = max(p.a.y, 1.0);
            float row = floor(c.y / lh);
            float band = floor(c.y / (lh * 6.0));
            float on = step(1.0 - p.a.z, hash6(float2(band, frame))) * step(0.3, hash6(float2(row, frame + 2.0)));
            float dx = (hash6(float2(row * 1.7, frame)) - 0.5) * 2.0 * p.a.x * on;
            float4 g = tap6(src, c + float2(dx, 0));
            float4 rr = tap6(src, c + float2(dx + p.c.y * on, 0));
            float4 bb = tap6(src, c + float2(dx - p.c.y * on, 0));
            o = float4(rr.r, g.g, bb.b, max(g.a, max(rr.a, bb.a)));
            break;
        }
        case 16: { // digital noise glitch: a = (intensity 0-1, block px, rate fps, seed)
            float frame = floor(t * p.a.z) + p.a.w * 13.0;
            float bs = max(p.a.y, 1.0);
            float2 big = floor(c / (bs * 6.0));
            float2 cell = floor(c / bs);
            float zone = step(1.0 - p.a.x * 0.6, hash6(big + frame * 0.77));
            float4 q = tap6(src, c + float2((hash6(big + frame) - 0.5) * bs * 4.0 * zone, 0));
            float3 nz = float3(hash6(cell + frame), hash6(cell + frame + 1.3), hash6(cell + frame + 2.6));
            float sel = step(0.5, hash6(cell * 0.71 + frame));
            float3 col = q.a > 1e-6 ? q.rgb / q.a : float3(0.0);
            float3 post = floor(col * 4.0 + nz * 0.9) / 4.0;
            float3 g = mix(post, nz, sel * 0.7);
            float spark = step(1.0 - p.a.x * 0.08, hash6(c + frame * 3.1));
            float a = max(q.a, spark);
            float3 outc = mix(col, g, zone);
            outc = mix(outc, nz, spark);
            o = float4(clamp(outc, 0.0, 1.0) * a, a);
            break;
        }
        case 17: { // datamosh smear: a = (length px, angle rad, block px, chaos 0-1), c.x = seed
            float bs = max(p.a.z, 2.0);
            float2 blk = floor(c / bs);
            float fr = floor(t * 8.0) + p.c.x * 5.0;
            float bn = hash6(blk + fr);
            float ang = p.a.y + (bn - 0.5) * p.a.w * 3.1415926;
            float len = p.a.x * (0.3 + 0.7 * hash6(blk * 1.9 + fr + 4.0)) * (0.25 + 0.75 * step(0.35 * p.a.w, bn));
            float2 dir = float2(cos(ang), sin(ang));
            float4 best = o; float bl = lum6(o) * o.a;
            const int N = 20;
            for (int k = 1; k <= N; k++) {
                float f = float(k) / float(N);
                float4 q = tap6(src, c - dir * len * f);
                float l = (lum6(q) * q.a) * (1.0 - 0.5 * f);
                if (l > bl) { bl = l; best = q; }
            }
            o = best;
            break;
        }
        case 18: { // pixel stretch: a = (position 0-1, jitter px, 0, 0), i.y = direction (0 right, 1 left, 2 down, 3 up), c.x = seed
            uint dirm = p.i.y;
            bool horiz = dirm < 2;
            float along = horiz ? c.x : c.y;
            float lineP = p.a.x * (horiz ? size.x : size.y);
            float crossC = horiz ? c.y : c.x;
            float j = (noise63(float3(crossC / 6.0, t * 3.0, p.c.x)) - 0.5) * 2.0 * p.a.y;
            float lp = lineP + j;
            bool past = (dirm == 0 || dirm == 2) ? (along > lp) : (along < lp);
            if (past) {
                float2 q = horiz ? float2(lp, c.y) : float2(c.x, lp);
                o = tap6(src, q);
            }
            break;
        }
        case 19: { // displace by luminance: a = (amount px, angle rad, 0, 0), i.y = 0 along angle / 1 radial
            float l = lum6(o) * o.a;
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            if (p.i.y == 1) { float2 d = c - size * 0.5; dir = d / max(length(d), 1e-3); }
            float4 q = tap6(src, c + dir * (l - 0.35) * p.a.x);
            o = tap6(src, c + dir * ((lum6(q) * q.a) * 0.5 + l * 0.5 - 0.35) * p.a.x);
            break;
        }
        case 20: { // kaleidoscope+: a = (segments, rotation rad, spin rad/s, zoom), b.xy = center, i.y = mirror
            float n = max(round(p.a.x), 2.0);
            float seg = 6.2831853 / n;
            float2 d = c - p.b.xy;
            float r = length(d) / max(p.a.w, 0.05);
            float rotA = p.a.y + p.a.z * t;
            float th = atan2(d.y, d.x) - rotA;
            th = th - seg * floor(th / seg);
            if (p.i.y == 1) th = abs(th - seg * 0.5);
            th += rotA;
            o = tap6(src, p.b.xy + float2(cos(th), sin(th)) * r);
            break;
        }
        case 21: { // wobble: a = (amplitude px, wavelength px, speed, 0)
            float wl = max(p.a.y, 1.0);
            float ph = t * p.a.z * 6.2831853;
            float2 off = float2(sin(c.y / wl * 6.2831853 + ph), cos(c.x / wl * 8.17 + ph * 0.8 + 1.3)) * p.a.x;
            o = tap6(src, c + off);
            break;
        }
        case 22: { // signal interference: a = (strength px, bands, speed, chroma px), b.x = noise 0-1, c.x = seed
            float y = c.y / size.y;
            float ph = y * p.a.y * 6.2831853 - t * p.a.z * 6.2831853;
            float band = sin(ph);
            float sharp = pow(abs(band), 6.0) * sign(band);
            float fr = floor(t * 30.0) + p.c.x * 9.0;
            float rn = (hash6(float2(floor(c.y), fr)) - 0.5) * p.b.x * 2.0;
            float dx = (sharp + rn) * p.a.x;
            float4 g = tap6(src, c + float2(dx, 0));
            float4 rr = tap6(src, c + float2(dx + p.a.w, 0));
            float4 bb = tap6(src, c + float2(dx - p.a.w, 0));
            o = float4(rr.r, g.g, bb.b, max(g.a, max(rr.a, bb.a)));
            o.rgb *= 1.0 + 0.18 * band * min(p.a.x / 10.0, 1.0);
            break;
        }
        case 23: { // CRT scan distort: a = (roll speed, bar strength px, scanlines 0-1, curvature 0-1)
            float2 uv = c / size * 2.0 - 1.0;
            float k = p.a.w * 0.35;
            uv *= 1.0 + k * dot(uv, uv);
            float2 q = (uv * 0.5 + 0.5) * size;
            float y = q.y + t * p.a.x * size.y;
            y = y - size.y * floor(y / size.y);
            float barY = fract(t * 0.6 + 0.2) * size.y;
            float dyb = (y - barY) / max(size.y * 0.08, 1.0);
            float bar = exp(-dyb * dyb);
            float wav = sin(y * 0.35 + t * 20.0);
            q.x += (bar * 1.0 + 0.15) * wav * p.a.y;
            float inside = step(0.0, q.x) * step(q.x, size.x) * step(abs(uv.y), 1.0) * step(abs(uv.x), 1.0);
            float4 s = float4(src.sample(s6Zero, float2(q.x, y))) * inside;
            float scan = 1.0 - p.a.z * 0.6 * (0.5 + 0.5 * sin(c.y * 3.1415926));
            s.rgb *= scan * (1.0 + 0.25 * bar);
            o = s;
            break;
        }
    }
    dst.write(half4(o), gid);
}
