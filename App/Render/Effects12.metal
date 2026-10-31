#include <metal_stdlib>
using namespace metal;

// Batch 12: abstract backgrounds & particles 2 (anime edit / AMV favourites) — plexus, constellation, fireworks,
// bubbles, rain ripples, vortex dust, neural network, metaballs, voronoi shapes, isolines, cosmic nebula, glow tunnel,
// wave lines, hex grid glow, light trails, sunburst, kaleido mandala, grid warp, liquid gradient, ink smoke,
// crystal shards, spiral galaxy, orbit rings, heartbeat line, sparkle dust.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
// Common: d.x = time, d.y = blend 0-1, d.z = only (1 = drop the input), i.x = mode, i.y = 0 additive / 1 over.
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler sg12Zero(address::clamp_to_zero, filter::linear, coord::pixel);

static inline float lum12(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float hsh12(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float hsh12v(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static float nz12(float3 x) {
    float3 i = floor(x), f = fract(x); float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hsh12v(i), hsh12v(i + float3(1, 0, 0)), u.x), mix(hsh12v(i + float3(0, 1, 0)), hsh12v(i + float3(1, 1, 0)), u.x), u.y),
               mix(mix(hsh12v(i + float3(0, 0, 1)), hsh12v(i + float3(1, 0, 1)), u.x), mix(hsh12v(i + float3(0, 1, 1)), hsh12v(i + float3(1, 1, 1)), u.x), u.y), u.z);
}
static float fbm12(float3 x, int oct) {
    float v = 0.0, a = 0.5;
    for (int k = 0; k < oct; k++) { v += a * nz12(x); x = x * 2.03 + float3(17.1, 9.2, 3.3); a *= 0.5; }
    return v;
}
static inline float2 rot12(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(v.x * cs - v.y * sn, v.x * sn + v.y * cs); }
static inline float3 hsv12(float h, float s, float v) {
    float3 k = clamp(abs(fract(h + float3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    return v * mix(float3(1.0), k, s);
}
static inline float fm12(float x, float y) { return x - y * floor(x / y); }
static inline float2 fm12(float2 x, float2 y) { return x - y * floor(x / y); }
// Distance from p to segment ab; h = position along the segment (0-1).
static inline float seg12(float2 p, float2 a, float2 b, thread float& h) {
    float2 pa = p - a, ba = b - a;
    h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}
static inline float ecgb12(float f, float m, float s) { float q = (f - m) / s; return exp(-q * q); }
static float ecg12(float f) {
    return 0.12 * ecgb12(f, 0.18, 0.03) - 0.15 * ecgb12(f, 0.40, 0.012) + 1.0 * ecgb12(f, 0.44, 0.012)
         - 0.28 * ecgb12(f, 0.48, 0.012) + 0.25 * ecgb12(f, 0.68, 0.045);
}
static inline float smin12(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / max(k, 1e-3), 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}
// Metaball SDF: a = (blob size frac, speed, gooeyness, count), sd = seed.
static float mbsd12(float2 q, float2 size, float t, float4 a, float sd) {
    float mn = max(min(size.x, size.y), 1.0);
    int n = int(clamp(floor(a.w), 2.0, 12.0));
    float rr = max(a.x, 0.005) * mn;
    float k = rr * max(a.z, 0.05) * 0.9;
    float d = 1e5;
    for (int i = 0; i < 12; i++) {
        if (i >= n) break;
        float fi = float(i);
        float h1 = hsh12(float2(fi, sd + 1.0)), h2 = hsh12(float2(fi * 1.3 + 4.0, sd)), h3 = hsh12(float2(fi * 0.7 + 9.0, sd * 1.1)), h4 = hsh12(float2(fi + 17.0, sd * 0.9));
        float sp = a.y;
        float2 o = float2(sin(t * sp * (0.5 + h1) + h2 * 6.283) + 0.35 * sin(t * sp * 1.7 * (0.4 + h3) + h4 * 6.283),
                          cos(t * sp * (0.45 + h3) + h4 * 6.283) + 0.35 * cos(t * sp * 1.3 * (0.5 + h2) + h1 * 6.283)) / 1.35;
        float2 ctr = size * 0.5 + o * max(size * 0.5 - rr * 0.5, float2(1.0));
        float ri = rr * (0.6 + 0.7 * h3) * (1.0 + 0.08 * sin(t * 2.0 + h1 * 6.283));
        d = smin12(d, length(q - ctr) - ri, k);
    }
    return d;
}
// Animated Voronoi site for cell cid.
static inline float2 vpt12(float2 cid, float sd, float t, float sp) {
    float ha = hsh12(cid + sd), hb = hsh12(cid * 1.4 + 6.6);
    return cid + 0.5 + 0.38 * float2(sin(t * sp * 1.5 + ha * 6.283), cos(t * sp * 1.2 + hb * 6.283));
}
static inline float2 cpt12(float2 cid, float sd) {
    return cid + 0.15 + 0.7 * float2(hsh12(cid + sd), hsh12(cid * 1.9 + 3.7));
}
// Curated cosine palettes: 0 twilight, 1 sunset, 2 mint, 3 neon, 4 gold.
static float3 pal12(float x, float sel) {
    int k = int(clamp(floor(sel + 0.5), 0.0, 4.0));
    float3 a = float3(0.35, 0.40, 0.62), b = float3(0.30, 0.30, 0.35), cc = float3(1.0), d = float3(0.60, 0.70, 0.80);
    if (k == 1) { a = float3(0.70, 0.42, 0.45); b = float3(0.30, 0.30, 0.25); cc = float3(1.0, 1.0, 0.8); d = float3(0.0, 0.12, 0.25); }
    else if (k == 2) { a = float3(0.40, 0.62, 0.58); b = float3(0.28, 0.30, 0.30); d = float3(0.30, 0.42, 0.55); }
    else if (k == 3) { a = float3(0.55, 0.40, 0.65); b = float3(0.45, 0.40, 0.35); d = float3(0.75, 0.30, 0.95); }
    else if (k == 4) { a = float3(0.60, 0.48, 0.32); b = float3(0.38, 0.30, 0.20); d = float3(0.0, 0.08, 0.18); }
    return clamp(a + b * cos(6.2831853 * (cc * x + d)), 0.0, 1.0);
}

// Hue rotation around the gray axis (Rodrigues) for gradient palettes.
static inline float3 hrot12q(float3 c, float a) {
    float3 k = float3(0.57735027); float cs = cos(a);
    return max(c * cs + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cs), float3(0.0));
}

kernel void fxAbstract12(texture2d<half, access::sample> src [[texture(0)]],
                         texture2d<half, access::write> dst [[texture(1)]],
                         texture2d<half, access::sample> aux [[texture(2)]],
                         constant EffectParams& p [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(sg12Zero, c));
    float t = p.d.x;
    float mn = max(min(size.x, size.y), 1.0);
    float3 g = float3(0.0);
    float ga = 0.0;
    switch (p.i.x) {
        case 0: { // plexus: a = (spacing, speed, link dist px, point size px), b = color, c = (seed, line width px)
            float cl = max(p.a.x, 6.0);
            float2 q = c + p.c.x * 31.7;
            float2 id = floor(q / cl);
            float2 pts[9];
            int k = 0;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cid = id + float2(float(i), float(j));
                    float ha = hsh12(cid + p.c.x * 1.31), hb = hsh12(cid * 1.7 + 3.1 + p.c.x), ph = hsh12(cid * 0.37 + 7.7 + p.c.x * 0.3) * 6.283;
                    pts[k] = (cid + 0.5 + 0.38 * float2(sin(t * p.a.y * (0.6 + ha) * 2.0 + ph), cos(t * p.a.y * (0.5 + hb) * 2.0 + ph * 1.3))) * cl;
                    k++;
                }
            }
            float L = clamp(p.a.z, 1.0, cl * 1.45);
            float w = max(p.c.y, 0.2);
            float r = max(p.a.w, 0.3);
            float acc = 0.0;
            for (int m = 0; m < 9; m++) {
                float2 dv = q - pts[m];
                acc += exp(-dot(dv, dv) / (r * r)) * 1.5;
                for (int n = m + 1; n < 9; n++) {
                    float h;
                    float d = seg12(q, pts[m], pts[n], h);
                    float len = length(pts[n] - pts[m]);
                    float link = 1.0 - smoothstep(L * 0.5, L, len);
                    acc += (1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, d)) * link * 0.7;
                }
            }
            g = p.b.rgb * acc;
            ga = clamp(acc, 0.0, 1.0);
            break;
        }
        case 1: { // constellation: a = (spacing, twinkle speed, star size, line opacity), b = color, c = (seed, line width, connections)
            float cl = max(p.a.x, 6.0);
            float2 q = c + p.c.x * 27.3;
            float2 id = floor(q / cl);
            float2 pts[9]; float2 cids[9]; float ex[9];
            int k = 0;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cid = id + float2(float(i), float(j));
                    float ha = hsh12(cid + p.c.x * 2.17), hb = hsh12(cid * 1.3 + 8.1 + p.c.x);
                    pts[k] = (cid + 0.15 + 0.7 * float2(ha, hb)) * cl;
                    cids[k] = cid;
                    ex[k] = step(0.35, hsh12(cid * 0.81 + 4.4 + p.c.x * 0.7));
                    k++;
                }
            }
            float r = max(p.a.z, 0.3);
            float w = max(p.c.y, 0.2);
            float acc = 0.0;
            for (int m = 0; m < 9; m++) {
                float2 dv = q - pts[m];
                float tw = 0.5 + 0.5 * sin(t * p.a.y * (0.6 + hsh12(cids[m] + 2.2)) * 3.0 + hsh12(cids[m] * 2.1) * 6.283);
                float d2 = dot(dv, dv);
                float flare = exp(-abs(dv.x) * abs(dv.y) / (r * r * 0.3)) * exp(-sqrt(d2) / (r * 3.0)) * 0.6;
                acc += (exp(-d2 / (r * r)) * 1.6 + flare) * mix(0.3, 1.0, tw) * ex[m];
                for (int n = m + 1; n < 9; n++) {
                    float pr = hsh12(cids[m] + cids[n] + p.c.x * 0.53) ;
                    float len = length(pts[n] - pts[m]);
                    float on = ex[m] * ex[n] * step(pr, clamp(p.c.z, 0.0, 1.0)) * (1.0 - step(cl * 1.5, len));
                    if (on < 0.5) continue;
                    float h;
                    float d = seg12(q, pts[m], pts[n], h);
                    acc += (1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, d)) * clamp(p.a.w, 0.0, 1.0);
                }
            }
            g = p.b.rgb * acc;
            ga = clamp(acc, 0.0, 1.0);
            break;
        }
        case 2: { // fireworks: a = (burst radius frac, period s, gravity frac/s^2, spark size px), b.x = bursts, c = (seed, saturation, trail)
            float per = max(p.a.y, 0.1);
            float R = max(p.a.x, 0.01) * mn;
            float gv = max(p.a.z, 0.0) * mn;
            float r = max(p.a.w, 0.3);
            int nb = int(clamp(floor(p.b.x), 1.0, 8.0));
            float trl = clamp(p.c.z, 0.0, 3.0);
            float sat = clamp(p.c.y, 0.0, 1.0);
            float reach = R * 1.1 + 0.5 * gv * per * per + r * 12.0;
            for (int b = 0; b < 8; b++) {
                if (b >= nb) break;
                float fb = float(b);
                float tc = t / per + fb / float(nb) + 0.3 * hsh12(float2(fb * 3.7, p.c.x * 1.3 + 0.5));
                float cyc = floor(tc);
                float a01 = tc - cyc;
                float2 ctr = float2(0.15 + 0.7 * hsh12(float2(cyc + fb * 13.1, p.c.x + 0.7)),
                                    0.12 + 0.5 * hsh12(float2(cyc * 1.7 + 3.0, fb * 2.1 + p.c.x))) * size;
                float2 dc = c - ctr;
                if (dot(dc, dc) > reach * reach) continue;
                float hue = hsh12(float2(cyc * 0.37 + fb, p.c.x + 9.0));
                float3 bc = hsv12(hue, sat, 1.0);
                float3 bc2 = hsv12(hue + 0.08, sat * 0.9, 1.0);
                float fade = pow(1.0 - a01, 1.5);
                float dcl = length(dc);
                // ignition flash + bloom
                g += mix(float3(1.0), bc, 0.5) * exp(-a01 * 12.0) * (exp(-dcl / (R * 0.1 + 1.0)) * 1.6 + exp(-dcl / (R * 0.45 + 1.0)) * 0.35);
                float aT = max(a01 - 0.22 * trl - 0.02, 0.0);
                float aM = (a01 + aT) * 0.5;
                float eH = 1.0 - pow(1.0 - a01, 3.0), eM = 1.0 - pow(1.0 - aM, 3.0), eT = 1.0 - pow(1.0 - aT, 3.0);
                float pp = per * per * 0.5 * gv;
                float sH = pp * a01 * a01, sM = pp * aM * aM, sT = pp * aT * aT;
                for (int k = 0; k < 28; k++) {
                    float fk = float(k);
                    float hk = hsh12(float2(fk + fb * 31.0, cyc + p.c.x * 2.0));
                    float an = (fk + 0.7 * hk) / 28.0 * 6.2831853;
                    float2 dir = float2(cos(an), sin(an)) * R * (0.6 + 0.4 * hk);
                    float2 pH = ctr + dir * eH + float2(0.0, sH);
                    float2 pM = ctr + dir * eM + float2(0.0, sM);
                    float2 pT = ctr + dir * eT + float2(0.0, sT);
                    float h0, h1;
                    float d0 = seg12(c, pT, pM, h0);
                    float d1 = seg12(c, pM, pH, h1);
                    float sAl = d1 < d0 ? 0.5 + 0.5 * h1 : 0.5 * h0;
                    float d = min(d0, d1);
                    float wr = r * (0.35 + 0.65 * sAl);
                    float m = exp(-d * d / (wr * wr)) * sAl * sAl + exp(-d / (r * 3.0)) * sAl * 0.18;
                    float2 dh = c - pH;
                    float hd2 = dot(dh, dh);
                    float head = exp(-hd2 / (r * r * 1.2));
                    float flick = 0.75 + 0.25 * sin(t * 37.0 + hk * 40.0);
                    float3 col = mix(bc2 * 0.8, bc, sAl);
                    g += (col * (m + exp(-sqrt(hd2) / (r * 2.5)) * 0.45) + mix(bc, float3(1.0), 0.75) * head * 1.8) * fade * flick;
                }
            }
            ga = clamp(lum12(g), 0.0, 1.0);
            break;
        }
        case 3: { // bubbles: a = (spacing, size, rise speed, wobble), b = color, c.x = seed
            float acc = 0.0;
            for (int L = 0; L < 2; L++) {
                float fl = float(L);
                float cl = max(p.a.x, 6.0) * (1.0 + fl * 0.6);
                float2 q = c + float2(0.0, p.a.z * (0.7 + 0.3 * fl) * t) + fl * 53.0 + p.c.x * 19.0;
                float2 id = floor(q / cl);
                for (int j = -1; j <= 1; j++) {
                    for (int i = -1; i <= 1; i++) {
                        float2 cid = id + float2(float(i), float(j));
                        float ha = hsh12(cid + fl * 7.0 + p.c.x), hb = hsh12(cid * 1.5 + 2.9), hc = hsh12(cid * 0.6 + 7.3 + p.c.x);
                        float2 ctr = (cid + 0.5 + (float2(ha, hb) - 0.5) * 0.4) * cl;
                        ctr.x += sin(t * 2.5 * (0.6 + hc) + ha * 6.283) * clamp(p.a.w, 0.0, 2.0) * cl * 0.12;
                        float rr = clamp(p.a.y * (0.6 + 0.6 * hc) * (1.0 + fl * 0.3), 1.0, cl * 0.45);
                        float2 dv = q - ctr;
                        float d = length(dv);
                        float wr = max(rr * 0.12, 0.7);
                        float ring = exp(-(d - rr) * (d - rr) / (wr * wr));
                        float fill = (1.0 - smoothstep(rr - 1.0, rr, d)) * 0.08;
                        float2 hl = dv + rr * 0.38;
                        float spec = exp(-dot(hl, hl) / max(rr * rr * 0.03, 0.3));
                        acc += (ring + fill + spec) * (0.85 - fl * 0.25);
                    }
                }
            }
            g = p.b.rgb * acc;
            ga = clamp(acc, 0.0, 1.0);
            break;
        }
        case 4: { // raindrop ripples: a = (spacing, speed, ring count, ring width), b = color, c = (seed, flatten)
            float cl = max(p.a.x, 8.0);
            float fy = clamp(p.c.y, 0.1, 1.0);
            float2 q = float2(c.x, c.y / fy) + p.c.x * 23.0;
            float2 id = floor(q / cl);
            float w = max(p.a.w, 0.3);
            float gap = w * 4.0;
            float acc = 0.0;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cid = id + float2(float(i), float(j));
                    float ha = hsh12(cid + p.c.x * 1.9), hb = hsh12(cid * 1.3 + 5.5), hc = hsh12(cid * 0.7 + 1.1 + p.c.x);
                    float2 ctr = (cid + 0.2 + 0.6 * float2(ha, hb)) * cl;
                    float ph = t * p.a.y * (0.6 + 0.8 * hc) + hc * 3.7 + ha;
                    float age = fract(ph);
                    float rad = age * cl * 0.95;
                    float d = length(q - ctr);
                    float dd = rad - d;
                    float env = smoothstep(0.0, gap * 0.5, dd + gap * 0.5) * (1.0 - smoothstep(gap * (max(p.a.z, 1.0) - 0.5), gap * max(p.a.z, 1.0), dd));
                    float wave = 0.5 + 0.5 * cos(dd / gap * 6.2831853);
                    acc += pow(wave, 3.0) * env * pow(1.0 - age, 1.5) * 1.3;
                }
            }
            g = p.b.rgb * acc;
            ga = clamp(acc, 0.0, 1.0);
            break;
        }
        case 5: { // vortex dust: a = (cx, cy, speed, twist), b = color, c = (density, size px, seed, inflow), d.w = streak
            float2 d = c - p.a.xy;
            float r = max(length(d), 1.0);
            float ang = atan2(d.y, d.x);
            float lr = log(r / mn);
            float rr = max(p.c.y, 0.3);
            float stk = clamp(p.d.w, 1.0, 6.0);
            float armPh = ang + t * p.a.z + p.a.w * lr;
            float acc = 0.0;
            for (int L = 0; L < 3; L++) { // depth layers: near = big/bright/fast, far = fine/dim/slow
                float fl = float(L);
                float cells = max(floor(p.c.x * 4.0 * (1.0 + fl * 0.6)), 4.0);
                float spd = 1.0 - fl * 0.25;
                float u = (ang + t * p.a.z * spd + p.a.w * lr) / 6.2831853 * cells;
                float v = (lr + t * p.c.w * spd) * cells / 6.2831853 + fl * 0.37;
                float2 uv = float2(u, v);
                float2 id = floor(uv);
                float cellPx = r * 6.2831853 / cells;
                float rl = rr * (1.0 - fl * 0.25);
                float br = 1.4 - fl * 0.35;
                for (int j = -1; j <= 1; j++) {
                    for (int i = -1; i <= 1; i++) {
                        float2 cid = id + float2(float(i), float(j));
                        float2 hid = float2(fm12(cid.x, cells), cid.y);
                        float ha = hsh12(hid + p.c.z * 1.7 + fl * 11.0), hb = hsh12(hid * 1.9 + 3.3 + p.c.z), hc = hsh12(hid * 0.5 + 8.8 + fl);
                        if (hc < 0.25) continue;
                        float2 pos = cid + 0.2 + 0.6 * float2(ha, hb);
                        float2 ov = (uv - pos) * cellPx;
                        ov.x /= stk * (0.6 + 0.8 * hc);
                        float d2 = dot(ov, ov);
                        acc += (exp(-d2 / (rl * rl)) * 1.6 + exp(-sqrt(d2) / (rl * 2.5)) * 0.25) * (0.5 + 0.7 * hc) * br;
                    }
                }
            }
            float arms = pow(0.5 + 0.5 * cos(3.0 * armPh), 2.0);
            float2 rq = rot12(d / mn, t * p.a.z + p.a.w * lr);
            float fog = fbm12(float3(rq * 4.0, p.c.z * 1.3), 4);
            float rad = smoothstep(mn * 0.02, mn * 0.15, r) * exp(-r / (mn * 0.55));
            acc *= rad * (0.55 + 0.6 * arms);
            float fogv = arms * (0.4 + fog) * rad * 0.45 + exp(-r / (mn * 0.06)) * 0.7;
            g = p.b.rgb * acc + p.b.rgb * float3(0.8, 0.6, 1.1) * fogv + float3(max(acc - 1.2, 0.0) * 0.5);
            ga = clamp(lum12(g) * 1.5, 0.0, 1.0);
            break;
        }
        case 6: { // neural network: a = (spacing, pulse speed, node size, line width), b = line color, c = pulse color, d.w = seed
            float cl = max(p.a.x, 8.0);
            float2 q = c + p.d.w * 29.1;
            float2 id = floor(q / cl);
            float2 pts[9]; float2 cids[9];
            int k = 0;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cid = id + float2(float(i), float(j));
                    float ha = hsh12(cid + p.d.w * 1.37), hb = hsh12(cid * 1.6 + 4.2 + p.d.w);
                    pts[k] = (cid + 0.2 + 0.6 * float2(ha, hb) + 0.06 * float2(sin(t + ha * 6.283), cos(t * 0.8 + hb * 6.283))) * cl;
                    cids[k] = cid;
                    k++;
                }
            }
            float w = max(p.a.w, 0.2);
            float rn = max(p.a.z, 0.3);
            float3 col = float3(0.0);
            for (int m = 0; m < 9; m++) {
                float2 dv = q - pts[m];
                float hm = hsh12(cids[m] * 0.9 + 6.1);
                float beat = 0.6 + 0.4 * sin(t * p.a.y * 4.0 + hm * 6.283);
                col += (p.b.rgb * 0.6 + p.c.rgb * 0.6) * exp(-dot(dv, dv) / (rn * rn)) * 1.6 * beat;
                for (int n = m + 1; n < 9; n++) {
                    float len = length(pts[n] - pts[m]);
                    if (len > cl * 1.5) continue;
                    float h;
                    float d = seg12(q, pts[m], pts[n], h);
                    float line = 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, d);
                    if (line <= 0.0) continue;
                    float hp = hsh12(cids[m] + cids[n] + p.d.w * 0.41);
                    float pp = fract(t * p.a.y * (0.5 + hp) + hp * 7.0);
                    float pq = (h - pp) * len / 6.0;
                    float pulse = exp(-pq * pq);
                    col += line * (p.b.rgb * 0.35 + p.c.rgb * pulse * 1.6);
                }
            }
            g = col;
            ga = clamp(lum12(col), 0.0, 1.0);
            break;
        }
        case 7: { // metaballs (over): a = (blob size frac, speed, gooeyness, count), b = color 1, c = color 2, d.w = seed
            float rr = max(p.a.x, 0.005) * mn;
            float d0 = mbsd12(c, size, t, p.a, p.d.w);
            float ddx = mbsd12(c + float2(1.0, 0.0), size, t, p.a, p.d.w) - d0;
            float ddy = mbsd12(c + float2(0.0, 1.0), size, t, p.a, p.d.w) - d0;
            float2 gr = normalize(float2(ddx, ddy) + 1e-5);
            float e = clamp(1.0 + d0 / (rr * 0.8), 0.0, 1.0);
            float3 n = normalize(float3(gr * e, sqrt(max(1.0 - e * e, 0.0)) + 0.08));
            float3 L = normalize(float3(-0.45, -0.6, 0.75));
            float dif = max(dot(n, L), 0.0);
            float3 H = normalize(L + float3(0.0, 0.0, 1.0));
            float spc = pow(max(dot(n, H), 0.0), 70.0);
            float fr = pow(clamp(1.0 - n.z, 0.0, 1.0), 2.5);
            float2 uvv = c / size;
            float gm = clamp(uvv.x * 0.55 + uvv.y * 0.45 + 0.2 * sin(t * 0.7 + uvv.y * 3.0) - 0.1, 0.0, 1.0);
            float3 bc7 = mix(p.b.rgb, p.c.rgb, gm);
            float3 col = bc7 * (0.35 + 0.75 * dif) + mix(p.c.rgb, float3(1.0), 0.5) * fr * 0.9 + float3(1.0) * spc * 1.2;
            col += bc7 * 0.25 * (1.0 - e);
            float inside = 1.0 - smoothstep(-0.75, 0.75, d0);
            float glow = exp(-max(d0, 0.0) / (rr * 0.3)) * 0.6;
            g = mix(bc7 * 1.2, col, inside);
            ga = clamp(max(inside, glow), 0.0, 1.0);
            break;
        }
        case 8: { // voronoi shapes (over): a = (cell size, speed, border px, saturation), c = (seed, palette)
            float cl = max(p.a.x, 4.0);
            float2 uv = c / cl + p.c.x * 3.1;
            float2 id = floor(uv);
            float md = 9.0;
            float2 mr = float2(0.0), best = id;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cid = id + float2(float(i), float(j));
                    float2 rv = vpt12(cid, p.c.x, t, p.a.y) - uv;
                    float dd = dot(rv, rv);
                    if (dd < md) { md = dd; mr = rv; best = cid; }
                }
            }
            float ed = 9.0;
            for (int j = -2; j <= 2; j++) {
                for (int i = -2; i <= 2; i++) {
                    float2 cid = best + float2(float(i), float(j));
                    float2 rv = vpt12(cid, p.c.x, t, p.a.y) - uv;
                    float2 dr = rv - mr;
                    if (dot(dr, dr) > 1e-6) ed = min(ed, dot(0.5 * (mr + rv), normalize(dr)));
                }
            }
            float edPx = ed * cl;
            float bw = max(p.a.z, 0.0);
            float inner = smoothstep(bw * 0.5 - 0.6, bw * 0.5 + 0.6, edPx);
            float bev = max(cl * 0.2, 2.0);
            float hgt = smoothstep(bw * 0.5, bw * 0.5 + bev, edPx);
            float2 outv = normalize(-mr + 1e-5);
            float bli = dot(outv, normalize(float2(-0.6, -0.8))) * (1.0 - hgt);
            float hc = hsh12(best * 0.73 + p.c.x * 0.37);
            float3 pc = pal12(hc * 0.6 + uv.y * cl / mn * 0.25 + t * p.a.y * 0.03, p.c.y);
            pc = mix(float3(lum12(pc)), pc, clamp(p.a.w, 0.0, 1.0));
            float dcn = sqrt(md);
            float3 col = pc * (0.55 + 0.45 * hgt) * (0.8 + 0.35 * (1.0 - dcn));
            col += float3(1.0) * max(bli, 0.0) * 0.4;
            col *= 1.0 + min(bli, 0.0) * 0.55;
            col += mix(pc, float3(1.0), 0.6) * pow(hgt, 3.0) * max(0.0, 0.5 - dcn) * 0.3;
            col = mix(pc * 0.07, col, inner);
            float eline = exp(-abs(edPx - bw * 0.5) / 1.1);
            col += mix(pc, float3(1.0), 0.45) * (eline * 0.7 + exp(-max(edPx - bw * 0.5, 0.0) / (bev * 0.8)) * 0.12);
            g = col;
            ga = 1.0;
            break;
        }
        case 9: { // isolines: a = (scale px, speed, line count, line width), b = color 1, c = color 2, d.w = seed
            float sc = max(p.a.x, 2.0);
            float z = t * p.a.y * 0.5 + p.d.w * 1.7;
            float3 o = float3(p.d.w * 3.3, p.d.w * 1.9, z);
            float n0 = fbm12(float3(c / sc, 0.0) + o, 4);
            float nx = fbm12(float3((c + float2(1.0, 0.0)) / sc, 0.0) + o, 4);
            float ny = fbm12(float3((c + float2(0.0, 1.0)) / sc, 0.0) + o, 4);
            float cnt = max(p.a.z, 1.0);
            float v = n0 * cnt * 2.0;
            float gr = length(float2(nx - n0, ny - n0)) * cnt * 2.0;
            float dpx = abs(fract(v) - 0.5) / max(gr, 1e-4);
            dpx = min(abs(fract(v + 0.5) - 0.5), 0.5) / max(gr, 1e-4);
            float w = max(p.a.w, 0.2);
            float line = 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, dpx);
            float glow = exp(-dpx / (w * 2.5)) * 0.35;
            float3 col = mix(p.b.rgb, p.c.rgb, clamp(n0 * 1.6 - 0.3, 0.0, 1.0));
            g = col * (line + glow) * 1.3;
            ga = clamp(line + glow, 0.0, 1.0);
            break;
        }
        case 10: { // cosmic nebula: a = (scale, speed, intensity, stars), b = color 1, c = color 2, d.w = seed
            float sc = max(p.a.x, 2.0);
            float2 uv = c / sc;
            float z = t * p.a.y * 0.4 + p.d.w * 1.3;
            float2 w = float2(fbm12(float3(uv, z), 4), fbm12(float3(uv + 5.2, z + 1.7), 4));
            float n = fbm12(float3(uv + w * 2.0 + p.d.w * 0.7, z * 0.5), 5);
            float dens = pow(clamp(n * 1.4 - 0.15, 0.0, 1.0), 2.0) * max(p.a.z, 0.0);
            float3 col = mix(p.b.rgb, p.c.rgb, clamp(w.x * 1.8 - 0.4, 0.0, 1.0)) * dens * 1.6;
            col += float3(1.0, 0.9, 1.0) * pow(dens * 0.6, 3.0);
            float2 cid = floor(c);
            float hs = hsh12(cid + p.d.w * 7.3);
            float st = step(1.0 - max(p.a.w, 0.0) * 0.01, hs);
            float tw = 0.6 + 0.4 * sin(t * 5.0 + hsh12(cid * 1.7) * 6.283);
            col += float3(st * tw * 1.4);
            g = col;
            ga = clamp(lum12(col) * 1.5, 0.0, 1.0);
            break;
        }
        case 11: { // glow tunnel: a = (cx, cy, speed, ring density), c = (sides, glow, hue speed, seed)
            float2 d = c - p.a.xy;
            float N = max(floor(p.c.x), 3.0);
            float ang = atan2(d.y, d.x) + t * 0.3;
            float sg = 6.2831853 / N;
            float rp = length(d) * cos(3.14159265 / N) / max(cos(fm12(ang, sg) - sg * 0.5), 0.2);
            float z = mn * 0.25 / max(rp, 1.0);
            float zz = z * max(p.a.w, 0.05) + t * p.a.z;
            float e = 0.03 * max(p.c.y, 0.0) / (abs(fract(zz) - 0.5) + 0.03);
            e *= smoothstep(0.0, mn * 0.08, rp) * min(z * 3.0, 1.5);
            float hue = fract(floor(zz) * 0.13 + t * p.c.z * 0.15 + hsh12(float2(p.c.w, 1.7)));
            g = hsv12(hue, 0.8, 1.0) * e;
            ga = clamp(e, 0.0, 1.0);
            break;
        }
        case 12: { // wave lines: a = (count, amplitude px, frequency, speed), b = color 1, c = color 2, d.w = width px
            float cnt = max(p.a.x, 1.0);
            float sp = size.y / cnt;
            float k0 = floor(c.y / sp);
            float w = max(p.d.w, 0.2);
            float fq = p.a.z * 6.2831853 / mn;
            float xn = c.x / max(size.x, 1.0);
            float edge = smoothstep(0.0, 0.18, xn) * smoothstep(0.0, 0.18, 1.0 - xn);
            float3 col = float3(0.0);
            for (int kk = -3; kk <= 3; kk++) {
                float k = k0 + float(kk);
                float dep = 0.35 + 0.65 * hsh12(float2(k, 4.7));            // per-line depth: far lines dimmer + softer
                float ph = c.x * fq + t * p.a.w * (0.6 + 0.4 * dep) + k * 0.45;
                float am = p.a.y * (0.6 + 0.4 * sin(k * 1.7 + t * 0.7));
                float yk = (k + 0.5) * sp + am * (sin(ph) * 0.8 + 0.2 * sin(ph * 2.3 + k));
                float dydx = am * (cos(ph) * 0.8 + 0.46 * cos(ph * 2.3 + k)) * fq;
                float dist = abs(c.y - yk) / sqrt(1.0 + dydx * dydx);
                float lw = w * mix(1.6, 1.0, dep);
                float core = 1.0 - smoothstep(lw * 0.3, lw * 0.3 + 1.0, dist);
                float inner = exp(-dist / (lw * 1.4)) * 0.5;
                float outer = exp(-dist / (lw * 6.0)) * 0.16;
                float gt = fract(k / cnt + xn * 0.35 + t * 0.05);
                gt = 0.5 - 0.5 * cos(gt * 6.2831853);
                float3 lc = mix(p.b.rgb, p.c.rgb, gt);
                float bright = mix(0.3, 1.0, dep * dep) * (0.75 + 0.25 * sin(ph * 0.5 + t * 2.0 + k));
                col += (lc * (inner + outer) + mix(lc, float3(1.0), 0.6) * core * mix(0.5, 1.0, dep)) * bright;
            }
            col *= mix(0.25, 1.0, edge);
            g = col;
            ga = clamp(lum12(col) * 1.5, 0.0, 1.0);
            break;
        }
        case 13: { // hex grid glow: a = (hex size, pulse speed, line width, glow), b = color, c.x = seed
            float hs = max(p.a.x, 3.0);
            float2 r = float2(1.0, 1.7320508);
            float2 hh = r * 0.5;
            float2 uv = (c - size * 0.5) / hs + p.c.x * 0.37;
            float2 A = fm12(uv, r) - hh;
            float2 B = fm12(uv - hh, r) - hh;
            float2 gv = dot(A, A) < dot(B, B) ? A : B;
            float2 id = uv - gv;
            float hd = max(dot(abs(gv), float2(0.5, 0.8660254)), abs(gv.x));
            float ed = (0.5 - hd) * hs;
            float w = max(p.a.z, 0.2);
            float core = 1.0 - smoothstep(w * 0.35, w * 0.35 + 1.0, ed);
            float lg = exp(-max(ed, 0.0) / (w * 1.5)) * 0.45 + exp(-max(ed, 0.0) / (w * 5.0)) * 0.15;
            float wd = length(id - p.c.x * 0.37);
            float wave = 0.5 + 0.5 * sin(wd * 0.9 - t * p.a.y * 4.0);
            float w3 = wave * wave * wave;
            float fl = step(0.85, hsh12(id * 3.1 + floor(t * p.a.y * 3.0 + hsh12(id) * 5.0) + p.c.x));
            // color gradient across the grid, shifted by the pulse front
            float2 uvn = (c - size * 0.5) / mn;
            float3 cA = p.b.rgb, cB = hrot12q(p.b.rgb, 1.9), cC = hrot12q(p.b.rgb, -1.2);
            float gp = clamp(0.5 + 0.6 * (uvn.x - uvn.y * 0.5) + 0.25 * w3, 0.0, 1.0);
            float3 col = gp < 0.5 ? mix(cC, cA, gp * 2.0) : mix(cA, cB, gp * 2.0 - 1.0);
            // depth fade: cells dim and soften toward the frame edges
            float dep = 1.0 - smoothstep(0.25, 0.85, length(uvn));
            float cellFill = (1.0 - smoothstep(0.0, 0.5, hd)) * (0.08 * w3 + fl * 0.22);
            float gl = max(p.a.w, 0.0);
            float lineI = (core * 0.8 + lg) * (0.2 + 0.95 * w3) * mix(0.35, 1.0, dep);
            float3 e = (col * (lineI + cellFill) + float3(1.0) * core * w3 * 0.35 * dep) * gl;
            e += col * fl * 0.12 * gl;
            g = e;
            ga = clamp(max(e.r, max(e.g, e.b)), 0.0, 1.0);
            break;
        }
        case 14: { // light trails: a = (spacing, speed px/s, length frac, thickness px), b = color, c = (angle rad, seed, hue spread), d.w = curve
            float2 q = rot12(c - size * 0.5, -p.c.x);
            float len = max(p.a.z * max(size.x, size.y), 2.0);
            float w = max(p.a.w, 0.2);
            float cur = clamp(p.d.w, 0.0, 1.0);
            float3 col = float3(0.0);
            for (int L = 0; L < 3; L++) { // depth layers: near = thick/bright/fast
                float fl = float(L);
                float dep = 1.0 - fl * 0.3;
                float sp = max(p.a.x, 2.0) * (1.0 + fl * 0.6);
                float wl = w * dep;
                float fq = 6.2831853 / (mn * (0.9 + 0.4 * fl));
                float lane0 = floor(q.y / sp + fl * 0.37);
                for (int dl = -1; dl <= 1; dl++) {
                    float lane = lane0 + float(dl);
                    float h = hsh12(float2(lane, fl * 7.0 + p.c.y * 3.1));
                    float h2 = hsh12(float2(lane * 1.7 + 2.0, fl + p.c.y));
                    float amp = cur * sp * 0.9;
                    float ph = q.x * fq + h * 6.283 + t * 0.4;
                    float yc = (lane + 0.5 - fl * 0.37) * sp + amp * sin(ph);
                    float slope = amp * fq * cos(ph);
                    float dy = abs(q.y - yc) / sqrt(1.0 + slope * slope);
                    if (dy > wl * 14.0 + 2.0) continue;
                    float cyc = len * 1.7 + mn * 0.4;
                    float v = q.x - t * p.a.y * (0.6 + 0.8 * h) * dep + h2 * 977.0;
                    float fy = fm12(v, cyc);
                    float on = step(0.35, hsh12(float2(lane * 0.9 + fl, floor(v / cyc) + p.c.y)));
                    if (on < 0.5) continue;
                    float s01 = clamp(fy / len, 0.0, 1.0) * (1.0 - step(len, fy));
                    float wy = wl * (0.3 + 0.7 * s01);
                    float m = exp(-dy * dy / (wy * wy)) * pow(s01, 1.6) + exp(-dy / (wl * 3.5)) * s01 * s01 * 0.35;
                    float hd = length(float2(fy - len, dy));
                    float head = exp(-hd * hd / (wl * wl * 3.0)) * 2.2 + exp(-hd / (wl * 5.0)) * 0.5;
                    float3 bc = mix(p.b.rgb, hsv12(h2, 0.75, 1.0), clamp(p.c.z, 0.0, 1.0));
                    float3 tailc = mix(bc, bc.zxy, 0.5) * 0.7;
                    float3 headc = mix(bc, float3(1.0), 0.55);
                    col += (mix(tailc, headc, s01 * s01) * m + headc * head) * (1.25 - fl * 0.35);
                }
            }
            g = col;
            ga = clamp(lum12(col) * 1.5, 0.0, 1.0);
            break;
        }
        case 15: { // sunburst (over): a = (cx, cy, rays, rotation speed), b = (color 1, ray length frac), c = (color 2, opacity), d.w = softness
            float2 d = c - p.a.xy;
            float r = length(d);
            float n = max(floor(p.a.z), 2.0);
            float ang = atan2(d.y, d.x) + t * p.a.w;
            float sf = clamp(p.d.w, 0.0, 1.0);
            float sv = 0.5 + 0.5 * cos(ang * n);
            float ray = smoothstep(0.5 - 0.5 * sf - 0.03, 0.5 + 0.5 * sf + 0.03, sv);
            float ray2 = pow(0.5 + 0.5 * cos(ang * n * 2.0 + 1.3 - t * p.a.w * 1.6), 10.0) * 0.4;
            float rays = mix(0.5, max(ray, ray2), smoothstep(0.0, mn * 0.05, r));
            float fade = exp(-r / (max(p.b.w, 0.02) * mn));
            float bloom = exp(-r / (mn * 0.1)) * 0.9 + exp(-r * r / (mn * mn * 0.003));
            float op = clamp(p.c.w, 0.0, 1.0);
            float3 col = mix(p.c.rgb, p.b.rgb, rays) * (1.0 + 0.5 * fade) + mix(p.b.rgb, float3(1.0), 0.6) * bloom * 0.6;
            g = col;
            ga = clamp(op * fade * (0.18 + 0.82 * rays) + bloom * op * 0.9, 0.0, 1.0);
            break;
        }
        case 16: { // kaleido mandala: a = (segments, speed, scale px, complexity), c = (seed, saturation)
            float2 d = c - size * 0.5;
            float sc = max(p.a.z, 2.0);
            float r = length(d) / sc;
            float N = max(floor(p.a.x), 2.0);
            float sg = 6.2831853 / N;
            float ang = atan2(d.y, d.x) + t * p.a.y * 0.3;
            ang = abs(fm12(ang, sg) - sg * 0.5);
            float2 pp = float2(cos(ang), sin(ang)) * r;
            float cx = max(p.a.w, 0.05);
            float v = sin(pp.x * cx * 6.0 + t * p.a.y) * sin(pp.y * cx * 6.0 - t * p.a.y * 0.7) + 0.5 * sin(r * cx * 4.0 - t * p.a.y * 2.0);
            float e = 0.05 / (abs(v) + 0.05);
            e *= exp(-r * 0.25);
            float hue = fract(r * 0.15 + hsh12(float2(p.c.x, 3.3)) + t * 0.05);
            g = hsv12(hue, clamp(p.c.y, 0.0, 1.0), 1.0) * e;
            ga = clamp(e, 0.0, 1.0);
            break;
        }
        case 17: { // grid warp: a = (cell px, warp px, speed, line width), b = color, c.x = seed
            float cl = max(p.a.x, 3.0);
            float ws = cl * 3.0;
            float z = t * p.a.z * 0.5 + p.c.x * 1.3;
            float2 wv = float2(fbm12(float3(c / ws, z), 3), fbm12(float3(c / ws + 9.1, z + 3.7), 3)) - 0.5;
            float2 q = c + wv * p.a.y * 2.0;
            float2 f = abs(fract(q / cl + 0.5) - 0.5) * cl;
            float dd = min(f.x, f.y);
            float w = max(p.a.w, 0.2);
            float core = 1.0 - smoothstep(w * 0.35, w * 0.35 + 1.0, dd);
            float glow = exp(-dd / (w * 1.6)) * 0.45 + exp(-dd / (w * 5.0)) * 0.15;
            float node = exp(-length_squared(f) / (w * w * 2.5 + 1.0)) * 0.9;     // glowing intersections
            // "height" of the fabric: bulges toward the viewer read brighter / warmer
            float ht = clamp(0.5 + (wv.x + wv.y) * 1.6, 0.0, 1.0);
            float2 uvn = (c - size * 0.5) / mn;
            float gp = clamp(0.5 + 0.5 * (uvn.y - uvn.x) * 0.9 + (ht - 0.5) * 0.7, 0.0, 1.0);
            float3 cA = p.b.rgb, cB = hrot12q(p.b.rgb, 1.4), cC = hrot12q(p.b.rgb, -1.3);
            float3 col = gp < 0.5 ? mix(cC, cA, gp * 2.0) : mix(cA, cB, gp * 2.0 - 1.0);
            float dep = mix(0.3, 1.0, ht) * (1.0 - 0.55 * smoothstep(0.3, 0.9, length(uvn)));
            float3 e = (col * (glow + node * 0.6) + mix(col, float3(1.0), 0.55) * (core + node * 0.5)) * 1.2 * dep;
            g = e;
            ga = clamp(max(e.r, max(e.g, e.b)), 0.0, 1.0);
            break;
        }
        case 18: { // liquid gradient (over): a = (color 1, speed), b = (color 2, warp), c = (color 3, softness), i.z = color 4 packed, d.w = seed
            float3 c4 = float3(float((p.i.z >> 16) & 255u), float((p.i.z >> 8) & 255u), float(p.i.z & 255u)) / 255.0;
            float2 uv = c / size;
            float z = t * p.a.w * 0.5 + p.d.w;
            uv += (float2(nz12(float3(uv * 2.5, z)), nz12(float3(uv * 2.5 + 7.7, z))) - 0.5) * clamp(p.b.w, 0.0, 1.0) * 0.8;
            float3 acc = float3(0.0);
            float ws = 0.0;
            float pw = max(p.c.w, 0.1);
            for (int k = 0; k < 4; k++) {
                float fk = float(k);
                float h1 = hsh12(float2(fk, p.d.w + 2.0)), h2 = hsh12(float2(fk + 5.0, p.d.w * 1.3)), h3 = hsh12(float2(fk * 2.0 + 1.0, p.d.w * 0.7));
                float2 ctr = 0.5 + 0.38 * float2(sin(t * p.a.w * (0.6 + h1) + h2 * 6.283), cos(t * p.a.w * (0.5 + h3) + h1 * 6.283));
                float2 dv = uv - ctr;
                float wk = pow(1.0 / (dot(dv, dv) + 0.02), pw);
                float3 ck = k == 0 ? p.a.rgb : (k == 1 ? p.b.rgb : (k == 2 ? p.c.rgb : c4));
                acc += ck * wk;
                ws += wk;
            }
            g = acc / max(ws, 1e-6);
            ga = 1.0;
            break;
        }
        case 19: { // ink smoke (over): a = (scale px, speed, density, softness), b = color, c.x = seed
            float sc = max(p.a.x, 2.0);
            float2 uv = (c + float2(0.0, t * p.a.y * sc * 0.6)) / sc;
            float z = t * p.a.y * 0.3 + p.c.x * 1.7;
            float2 w = float2(fbm12(float3(uv, z), 3), fbm12(float3(uv + 4.3, z + 2.1), 3)) - 0.5;
            float n = fbm12(float3(uv + w * 1.8, z * 0.7 + 5.0), 5);
            float th = 0.62 - clamp(p.a.z, 0.0, 1.0) * 0.4;
            float sf = max(p.a.w, 0.01) * 0.4;
            float m = smoothstep(th, th + sf, n);
            g = p.b.rgb * (0.65 + 0.5 * n);
            ga = clamp(m, 0.0, 1.0);
            break;
        }
        case 20: { // crystal shards (over): a = (shard size, speed, edge glow, contrast), b = tint, c = (seed, refraction)
            float cl = max(p.a.x, 4.0);
            float2 uv = c / cl + p.c.x * 2.3;
            float2 id = floor(uv);
            float md = 9.0;
            float2 mr = float2(0.0), best = id;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cid = id + float2(float(i), float(j));
                    float2 rv = cpt12(cid, p.c.x) - uv;
                    float dd = dot(rv, rv);
                    if (dd < md) { md = dd; mr = rv; best = cid; }
                }
            }
            float ed = 9.0;
            for (int j = -2; j <= 2; j++) {
                for (int i = -2; i <= 2; i++) {
                    float2 rv = cpt12(best + float2(float(i), float(j)), p.c.x) - uv;
                    float2 dr = rv - mr;
                    if (dot(dr, dr) > 1e-6) ed = min(ed, dot(0.5 * (mr + rv), normalize(dr)));
                }
            }
            float2 rel = -mr; // pixel relative to the shard apex, in cell units
            float hb = hsh12(best * 0.61 + 9.9 + p.c.x);
            float F = 5.0 + floor(hb * 3.0);
            float rotk = hb * 6.2831853;
            float an = atan2(rel.y, rel.x) + rotk + 6.2831853;
            float sec = 6.2831853 / F;
            float fi = floor(an / sec);
            float fa = (fi + 0.5) * sec - rotk;
            float fh = hsh12(best + fi * 7.13 + p.c.x * 0.3);
            float tilt = 0.5 + 0.9 * fh;
            float3 nrm = normalize(float3(cos(fa) * tilt, sin(fa) * tilt, 1.0));
            float fd = (sec * 0.5 - abs(fm12(an, sec) - sec * 0.5)) * length(rel) * cl;
            float lt = t * p.a.y * 1.2;
            float3 L = normalize(float3(cos(lt), sin(lt) * 0.8, 0.9));
            float dif = max(dot(nrm, L), 0.0);
            float spc = pow(max(dot(nrm, normalize(L + float3(0.0, 0.0, 1.0))), 0.0), 48.0);
            float con = clamp(p.a.w, 0.0, 1.0);
            float refr = clamp(p.c.y, 0.0, 1.0);
            float shade = mix(0.75, 0.25 + 1.1 * dif, con);
            float2 sc2 = clamp(c + nrm.xy * cl * 0.6 * refr, float2(0.5), size - 0.5);
            float3 rf = float3(src.sample(sg12Zero, sc2).rgb);
            float3 col = mix(p.b.rgb * shade, rf * mix(float3(1.0), p.b.rgb * 1.3, 0.6) * (0.6 + 0.6 * dif), refr * 0.75);
            col += float3(1.0) * spc * (0.6 + con);
            float edPx = ed * cl;
            float eg = max(p.a.z, 0.0);
            col *= 0.7 + 0.3 * smoothstep(0.0, cl * 0.25, edPx);
            col += mix(p.b.rgb, float3(1.0), 0.7) * (exp(-edPx / 1.2) * 0.9 + exp(-edPx / 5.0) * 0.25) * eg;
            col += mix(p.b.rgb, float3(1.0), 0.5) * exp(-fd / 0.8) * 0.35 * eg * (0.4 + dif);
            float sk = hsh12(best * 1.37 + 4.4 + p.c.x);
            float flick = pow(max(sin(t * 3.0 * (0.5 + sk) + sk * 30.0), 0.0), 8.0) * step(0.55, sk);
            float2 dv = rel * cl;
            col += float3(1.0) * flick * (exp(-dot(dv, dv) / 2.0) * 1.5 + exp(-abs(dv.x) / 0.8) * exp(-abs(dv.y) / (cl * 0.3))
                                          + exp(-abs(dv.y) / 0.8) * exp(-abs(dv.x) / (cl * 0.3)));
            g = col;
            ga = 1.0;
            break;
        }
        case 21: { // spiral galaxy: a = (cx, cy, size frac, rotation speed), b = arm color, c = (arms, twist, seed), i.z = core color
            float3 cc = float3(float((p.i.z >> 16) & 255u), float((p.i.z >> 8) & 255u), float(p.i.z & 255u)) / 255.0;
            float2 d = c - p.a.xy;
            d.y /= 0.8;
            float R = max(p.a.z, 0.01) * mn;
            float r = length(d) / R;
            float ang = atan2(d.y, d.x);
            float rot = t * p.a.w;
            float N = max(floor(p.c.x), 1.0);
            float sa = 0.5 + 0.5 * cos(N * (ang - rot - p.c.y * log(r + 0.08)));
            float2 rd = rot12(d / R, -rot);
            float n1 = fbm12(float3(rd * 3.0, p.c.z * 1.7), 5);
            float n2 = fbm12(float3(rd * 10.0 + 3.3, p.c.z * 0.9 + 2.0), 3);
            float disk = exp(-r * 2.4);
            float arm = pow(sa, 3.0), armW = pow(sa, 1.2);
            float dust = clamp(n1 * 1.7 - 0.4, 0.0, 1.0);
            float lanes = smoothstep(0.5, 0.75, n2) * smoothstep(0.3, 0.9, sa) * smoothstep(0.08, 0.3, r);
            float light = disk * (armW * 0.35 + arm * (0.5 + 1.3 * dust)) * (1.0 - 0.6 * lanes) * 2.0;
            float3 colR = mix(cc, p.b.rgb, smoothstep(0.05, 0.55, r));
            colR = mix(colR, p.b.rgb * float3(0.7, 0.9, 1.2), smoothstep(0.5, 1.2, r));
            float knots = smoothstep(0.78, 0.9, n2) * arm * disk * 1.5;
            float core = exp(-r * r * 45.0) * 2.5 + exp(-r * 7.0) * 0.7;
            float halo = exp(-r * 1.3) * 0.15;
            float2 sc = floor(rd * R / 1.2);
            float st = step(0.975, hsh12(sc + p.c.z * 5.1)) * (0.25 + 1.6 * arm) * exp(-r * 1.1) * (0.5 + 0.5 * hsh12(sc * 1.3 + 2.0)) * 1.5;
            g = colR * light + cc * core + p.b.rgb * halo + float3(1.0, 0.45, 0.75) * knots + float3(st);
            ga = clamp(lum12(g) * 1.5, 0.0, 1.0);
            break;
        }
        case 22: { // orbit rings: a = (cx, cy, radius frac, speed), b = color, c = (rings, tilt, width, dot size), d.w = seed
            float2 d = c - p.a.xy;
            int n = int(clamp(floor(p.c.x), 1.0, 8.0));
            float ty = clamp(p.c.y, 0.05, 1.0);
            float w = max(p.c.z, 0.2);
            float ds = max(p.c.w, 0.3);
            float R = max(p.a.z, 0.01) * mn;
            float dl = length(d);
            float coreR = R * 0.13;
            float body = 1.0 - smoothstep(coreR - 1.0, coreR + 1.0, dl);
            float3 col = mix(p.b.rgb, float3(1.0), 0.6) * (0.6 + 0.6 * clamp(1.0 - dl / coreR, 0.0, 1.0)) * body
                       + p.b.rgb * (exp(-dl / (coreR * 1.2)) * 0.8 + exp(-dl / (R * 0.6)) * 0.12);
            for (int k = 0; k < 8; k++) {
                if (k >= n) break;
                float fk = float(k);
                float hk = hsh12(float2(fk, p.d.w + 0.5)), hk2 = hsh12(float2(fk * 1.7 + 3.0, p.d.w));
                float rk = R * (0.4 + 0.6 * (fk + 1.0) / float(n));
                float ta = (fk - float(n) * 0.5) * 0.22 + (hk - 0.5) * 0.3 - 0.3;
                float tyk = clamp(ty * (0.8 + 0.4 * hk2), 0.04, 1.0);
                float2 dr = rot12(d, -ta);
                float2 e = float2(dr.x, dr.y / tyk);
                float le = max(length(e), 1e-3);
                float2 gr = float2(e.x, e.y / tyk) / le;
                float dist = abs(le - rk) / max(length(gr), 1e-3);
                float sth = e.y / le; // > 0 = front half of the ring
                float th = atan2(e.y, e.x);
                float depth = 0.45 + 0.55 * (0.5 + 0.5 * sth);
                float occl = sth < 0.0 ? 1.0 - body : 1.0;
                float3 rc = mix(p.b.rgb, float3(1.0, 0.6, 0.95), fk / max(float(n - 1), 1.0) * 0.4);
                float spd = t * p.a.w / sqrt(fk + 1.0);
                float beads = pow(0.5 + 0.5 * cos(th * (18.0 + floor(hk * 14.0)) - spd * 6.0 + hk * 20.0), 10.0);
                float line = exp(-dist * dist / (w * w)) + exp(-dist / (w * 4.0)) * 0.3;
                col += rc * line * (0.55 + 1.4 * beads) * depth * occl;
                float ths = spd * 1.6 + hk * 6.2831853;
                float2 pos = rot12(float2(cos(ths), sin(ths) * tyk) * rk, ta);
                float2 dv = d - pos;
                float sd2 = dot(dv, dv);
                float sdep = 0.45 + 0.55 * (0.5 + 0.5 * sin(ths));
                float socc = sin(ths) < 0.0 ? 1.0 - body : 1.0;
                col += mix(rc, float3(1.0), 0.6) * (exp(-sd2 / (ds * ds)) * 2.0 + exp(-sqrt(sd2) / (ds * 2.5)) * 0.5) * sdep * socc;
            }
            g = col;
            ga = clamp(lum12(col) * 1.5, 0.0, 1.0);
            break;
        }
        case 23: { // heartbeat ECG: a = (y 0-1, amplitude px, beat width px, sweep speed), b = color, c = (line width px, trail 0-1, grid 0-1)
            float y0 = p.a.x * size.y;
            float bw = max(p.a.z, 4.0);
            float dist = 1e5;
            float yPrev = y0 - p.a.y * ecg12(fract((c.x - 2.0) / bw));
            for (int k = -1; k <= 2; k++) {
                float xk = c.x + float(k);
                float yk = y0 - p.a.y * ecg12(fract(xk / bw));
                float hh;
                dist = min(dist, seg12(c, float2(xk - 1.0, yPrev), float2(xk, yk), hh));
                yPrev = yk;
            }
            float w = max(p.c.x, 0.2);
            float head = fract(t * p.a.w) * size.x;
            float behind = fm12(head - c.x, size.x) / size.x;
            float trail = exp(-behind * 3.0 / max(p.c.y, 0.02)) * (1.0 - smoothstep(0.97, 1.0, behind));
            float core = exp(-dist * dist / (w * w * 0.25));
            float mid = exp(-dist * dist / (w * w * 2.0));
            float glow = exp(-dist / (w * 5.0)) * 0.55;
            float3 lc = p.b.rgb;
            float3 col = (mix(lc, float3(1.0), 0.75) * core + lc * (mid * 0.9 + glow)) * trail * 1.3;
            float2 hv = c - float2(head, y0 - p.a.y * ecg12(fract(head / bw)));
            float hd2 = dot(hv, hv);
            col += mix(lc, float3(1.0), 0.7) * exp(-hd2 / (w * w * 2.5)) * 2.5 + lc * exp(-sqrt(hd2) / (w * 6.0)) * 0.9
                 + lc * exp(-abs(hv.y) / (w * 0.7)) * exp(-abs(hv.x) / (w * 30.0)) * 0.35;
            float gs = max(bw * 0.25, 6.0);
            float2 gf = abs(fract(c / gs + 0.5) - 0.5) * gs;
            float2 gF = abs(fract(c / (gs * 4.0) + 0.5) - 0.5) * gs * 4.0;
            float gl = (1.0 - smoothstep(0.0, 1.0, min(gf.x, gf.y))) * 0.35 + (1.0 - smoothstep(0.0, 1.2, min(gF.x, gF.y))) * 0.6;
            col += lc * gl * clamp(p.c.z, 0.0, 1.0) * 0.35;
            g = col;
            ga = clamp(lum12(col) * 1.5, 0.0, 1.0);
            break;
        }
        case 24: { // sparkle dust: a = (spacing, size, flash speed, drift px/s), b = color, c = (seed, color variance)
            float3 col = float3(0.0);
            for (int L = 0; L < 2; L++) {
                float fl = float(L);
                float cl = max(p.a.x, 4.0) * (1.0 + fl * 0.6);
                float2 q = c + float2(0.3, -1.0) * p.a.w * t * (1.0 - fl * 0.3) + fl * 37.0 + p.c.x * 13.0;
                float2 id = floor(q / cl);
                for (int j = -1; j <= 1; j++) {
                    for (int i = -1; i <= 1; i++) {
                        float2 cid = id + float2(float(i), float(j));
                        float ha = hsh12(cid + fl * 5.0 + p.c.x), hb = hsh12(cid * 1.7 + 2.3), hc = hsh12(cid * 0.4 + 8.1 + p.c.x);
                        float2 ctr = (cid + 0.2 + 0.6 * float2(ha, hb)) * cl;
                        float2 dv = q - ctr;
                        float r = max(p.a.y * (0.5 + 0.7 * hc) * (1.0 - fl * 0.3), 0.5);
                        float fls = pow(max(sin(t * p.a.z * (0.5 + ha) * 6.2831853 + hb * 6.2831853), 0.0), 6.0);
                        float core = exp(-dot(dv, dv) / (r * r * 0.12));
                        float crs = exp(-abs(dv.x) / (r * 0.12)) * exp(-abs(dv.y) / r) + exp(-abs(dv.y) / (r * 0.12)) * exp(-abs(dv.x) / r);
                        float m = core * (0.25 + fls) + crs * fls * 0.8;
                        col += mix(p.b.rgb, hsv12(hc, 0.7, 1.0), clamp(p.c.y, 0.0, 1.0)) * m * 1.4;
                    }
                }
            }
            g = col;
            ga = clamp(lum12(col) * 1.5, 0.0, 1.0);
            break;
        }
    }
    float4 base = p.d.z > 0.5 ? float4(0.0) : s;
    float bl = clamp(p.d.y, 0.0, 1.0);
    float4 o;
    if (p.i.y == 0u) {
        float3 Lg = max(g, float3(0.0)) * bl;
        o = float4(base.rgb + Lg, max(base.a, clamp(max(ga * bl, lum12(Lg)), 0.0, 1.0)));
    } else {
        float a = clamp(ga, 0.0, 1.0) * bl;
        o = float4(clamp(g, 0.0, 4.0) * a + base.rgb * (1.0 - a), a + base.a * (1.0 - a));
    }
    o = select(o, float4(0.0), isnan(o));
    dst.write(half4(o), gid);
}
