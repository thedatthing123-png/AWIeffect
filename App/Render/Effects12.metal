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
        case 2: { // fireworks: a = (burst radius, period s, gravity px/s^2, spark size), c = (seed, saturation, trail)
            float per = max(p.a.y, 0.1);
            float r = max(p.a.w, 0.3);
            for (int b = 0; b < 3; b++) {
                float fb = float(b);
                float off = hsh12(float2(fb * 3.7, p.c.x * 1.3 + 0.5));
                float tc = t / per + off + fb / 3.0;
                float cyc = floor(tc);
                float a01 = tc - cyc;
                float2 ctr = (0.2 + 0.6 * float2(hsh12(float2(cyc, fb + p.c.x)), hsh12(float2(cyc * 1.7 + 3.0, fb * 2.1 + p.c.x)))) * size;
                float hue = hsh12(float2(cyc * 0.37 + fb, p.c.x + 9.0));
                float age = a01 * per;
                float bright = (1.0 - a01) * (1.0 - a01) * 1.6;
                float a0 = max(a01 - 0.12 * max(p.c.z, 0.0), 0.0);
                for (int k = 0; k < 20; k++) {
                    float fk = float(k);
                    float hk = hsh12(float2(fk + fb * 31.0, cyc + p.c.x * 2.0));
                    float an = (fk + 0.5 * hk) / 20.0 * 6.2831853;
                    float2 dir = float2(cos(an), sin(an)) * p.a.x * (0.7 + 0.3 * hk);
                    float2 p1 = ctr + dir * (1.0 - pow(1.0 - a01, 3.0)) + float2(0.0, 0.5 * p.a.z * age * age);
                    float age0 = a0 * per;
                    float2 p0 = ctr + dir * (1.0 - pow(1.0 - a0, 3.0)) + float2(0.0, 0.5 * p.a.z * age0 * age0);
                    float h;
                    float d = seg12(c, p0, p1, h);
                    float m = exp(-d * d / (r * r)) * (0.3 + 0.7 * h) + exp(-dot(c - p1, c - p1) / (r * r * 2.0));
                    g += hsv12(hue + hk * 0.08, clamp(p.c.y, 0.0, 1.0), 1.0) * m * bright;
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
        case 5: { // vortex dust: a = (cx, cy, speed, twist), b = color, c = (density, size px, seed, inflow)
            float2 d = c - p.a.xy;
            float r = max(length(d), 1.0);
            float ang = atan2(d.y, d.x);
            float cells = max(floor(p.c.x * 4.0), 4.0);
            float lr = log(r / mn);
            float u = (ang + t * p.a.z + p.a.w * lr) / 6.2831853 * cells;
            float v = (lr + t * p.c.w) * cells / 6.2831853;
            float2 uv = float2(u, v);
            float2 id = floor(uv);
            float cellPx = r * 6.2831853 / cells;
            float rr = max(p.c.y, 0.3);
            float acc = 0.0;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cid = id + float2(float(i), float(j));
                    float2 hid = float2(fm12(cid.x, cells), cid.y);
                    float ha = hsh12(hid + p.c.z * 1.7), hb = hsh12(hid * 1.9 + 3.3 + p.c.z), hc = hsh12(hid * 0.5 + 8.8);
                    if (hc < 0.3) continue;
                    float2 pos = cid + 0.2 + 0.6 * float2(ha, hb);
                    float2 ov = (uv - pos) * cellPx;
                    float m = exp(-dot(ov, ov) / (rr * rr)) * (0.6 + 0.6 * hc);
                    acc += m;
                }
            }
            acc *= smoothstep(mn * 0.02, mn * 0.12, r) * 1.4;
            g = p.b.rgb * acc;
            ga = clamp(acc, 0.0, 1.0);
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
        case 7: { // metaballs (over): a = (ball size, speed, threshold, count), b = color 1, c = color 2, d.w = seed
            int n = int(clamp(floor(p.a.w), 2.0, 12.0));
            float rr = max(p.a.x, 1.0);
            float field = 0.0;
            for (int k = 0; k < 12; k++) {
                if (k >= n) break;
                float fk = float(k);
                float h1 = hsh12(float2(fk, p.d.w + 1.0)), h2 = hsh12(float2(fk * 1.3 + 4.0, p.d.w)), h3 = hsh12(float2(fk * 0.7 + 9.0, p.d.w * 1.1)), h4 = hsh12(float2(fk + 17.0, p.d.w * 0.9));
                float2 ctr = size * (0.5 + 0.36 * float2(sin(t * p.a.y * (0.7 + h1) + h2 * 6.283), cos(t * p.a.y * (0.6 + h3) + h4 * 6.283)));
                float2 dv = c - ctr;
                field += rr * rr / (dot(dv, dv) + 1.0);
            }
            float thr = max(p.a.z, 0.01);
            float m = smoothstep(thr * 0.92, thr * 1.08, field);
            float rim = exp(-abs(field - thr) / (thr * 0.15)) * 0.6;
            g = mix(p.b.rgb, p.c.rgb, clamp((field - thr) / (thr * 2.0), 0.0, 1.0)) + rim * float3(1.0);
            ga = clamp(max(m, rim * 0.5), 0.0, 1.0);
            break;
        }
        case 8: { // voronoi shapes (over): a = (cell size, speed, border px, saturation), c.x = seed
            float cl = max(p.a.x, 4.0);
            float2 uv = c / cl + p.c.x * 3.1;
            float2 id = floor(uv);
            float f1 = 9.0, f2 = 9.0;
            float2 best = id;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cid = id + float2(float(i), float(j));
                    float ha = hsh12(cid + p.c.x), hb = hsh12(cid * 1.4 + 6.6);
                    float2 pos = cid + 0.5 + 0.4 * float2(sin(t * p.a.y * 1.5 + ha * 6.283), cos(t * p.a.y * 1.2 + hb * 6.283));
                    float d = length(uv - pos);
                    if (d < f1) { f2 = f1; f1 = d; best = cid; } else if (d < f2) { f2 = d; }
                }
            }
            float edge = (f2 - f1) * cl * 0.5;
            float bw = max(p.a.z, 0.0);
            float border = 1.0 - smoothstep(bw * 0.5, bw * 0.5 + 1.0, edge);
            float hc = hsh12(best * 0.73 + p.c.x * 0.37);
            float3 col = hsv12(hc + t * 0.05, clamp(p.a.w, 0.0, 1.0), 0.95) * (1.0 - 0.35 * f1);
            g = mix(col, float3(0.02), border * 0.9);
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
            float3 col = float3(0.0);
            for (int kk = -3; kk <= 3; kk++) {
                float k = k0 + float(kk);
                float ph = c.x * fq + t * p.a.w + k * 0.45;
                float am = p.a.y * (0.6 + 0.4 * sin(k * 1.7 + t * 0.7));
                float yk = (k + 0.5) * sp + am * sin(ph);
                float dy = am * cos(ph) * fq;
                float dist = abs(c.y - yk) / sqrt(1.0 + dy * dy);
                float line = 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, dist);
                float glow = exp(-dist / (w * 3.0)) * 0.3;
                col += mix(p.b.rgb, p.c.rgb, fract(k / cnt)) * (line + glow);
            }
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
            float line = 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, ed);
            float lg = exp(-max(ed, 0.0) / (w * 2.0)) * 0.4;
            float wave = 0.5 + 0.5 * sin(length(id - p.c.x * 0.37) * 0.9 - t * p.a.y * 4.0);
            float fl = step(0.85, hsh12(id * 3.1 + floor(t * p.a.y * 3.0 + hsh12(id) * 5.0) + p.c.x));
            float e = (line + lg) * (0.25 + 0.9 * wave * wave * wave) * max(p.a.w, 0.0) + fl * 0.3 * max(p.a.w, 0.0);
            g = p.b.rgb * e;
            ga = clamp(e, 0.0, 1.0);
            break;
        }
        case 14: { // light trails: a = (spacing, speed px/s, length px, thickness px), b = color, c = (angle rad, seed, hue spread)
            float2 q = rot12(c - size * 0.5, -p.c.x);
            float len = max(p.a.z, 1.0);
            float w = max(p.a.w, 0.2);
            float3 col = float3(0.0);
            for (int L = 0; L < 2; L++) {
                float fl = float(L);
                float sp = max(p.a.x, 2.0) * (1.0 + fl * 0.7);
                float u = q.y / sp + fl * 0.5;
                float lane = floor(u);
                float h = hsh12(float2(lane, fl * 7.0 + p.c.y * 3.1));
                float h2 = hsh12(float2(lane * 1.7 + 2.0, fl + p.c.y));
                float dy = abs(fract(u) - 0.5) * sp;
                float cyc = len * 2.5 + mn * 0.6;
                float v = q.x - t * p.a.y * (0.6 + 0.8 * h) * (1.0 - fl * 0.3) + h2 * 977.0;
                float fy = fm12(v, cyc);
                float on = step(0.3, hsh12(float2(lane * 0.9 + fl, floor(v / cyc) + p.c.y)));
                float tail = smoothstep(0.0, len, fy) * (1.0 - step(len, fy));
                float wy = w * (0.5 + 0.5 * tail);
                float m = exp(-dy * dy / (wy * wy)) * tail * tail * on;
                float headd = length(float2(fy - len, dy));
                m += exp(-headd * headd / (w * w * 4.0)) * on * (1.0 - step(len + w * 3.0, fy));
                col += mix(p.b.rgb, hsv12(h2, 0.75, 1.0), clamp(p.c.z, 0.0, 1.0)) * m * (1.2 - fl * 0.4);
            }
            g = col;
            ga = clamp(lum12(col) * 1.5, 0.0, 1.0);
            break;
        }
        case 15: { // sunburst (over): a = (cx, cy, rays, rotation speed), b = color 1, c = color 2, d.w = softness
            float2 d = c - p.a.xy;
            float n = max(floor(p.a.z), 2.0);
            float ang = atan2(d.y, d.x) + t * p.a.w;
            float sv = sin(ang * n);
            float sf = max(p.d.w, 0.001);
            float m = smoothstep(-sf, sf, sv);
            float glow = exp(-length(d) / (mn * 0.35)) * 0.35;
            g = mix(p.b.rgb, p.c.rgb, m) + glow;
            ga = 1.0;
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
            float line = 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, dd);
            float glow = exp(-dd / (w * 2.5)) * 0.35;
            float e = (line + glow) * 1.2;
            g = p.b.rgb * e;
            ga = clamp(e, 0.0, 1.0);
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
        case 20: { // crystal shards (over): a = (shard size, speed, edge glow, contrast), b = tint, c.x = seed
            float cl = max(p.a.x, 4.0);
            float2 uv = c / cl + p.c.x * 2.3;
            float2 id = floor(uv);
            float f1 = 9.0, f2 = 9.0;
            float2 best = id, bpos = id;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cid = id + float2(float(i), float(j));
                    float2 pos = cid + 0.15 + 0.7 * float2(hsh12(cid + p.c.x), hsh12(cid * 1.9 + 3.7));
                    float d = length(uv - pos);
                    if (d < f1) { f2 = f1; f1 = d; best = cid; bpos = pos; } else if (d < f2) { f2 = d; }
                }
            }
            float na = hsh12(best * 0.61 + 9.9 + p.c.x) * 6.2831853;
            float2 nrm = float2(cos(na), sin(na));
            float2 ld = float2(cos(t * p.a.y * 1.5), sin(t * p.a.y * 1.5));
            float shade = 0.5 + 0.5 * dot(nrm, ld) + dot(uv - bpos, nrm) * 0.6;
            float spark = pow(clamp(dot(nrm, ld), 0.0, 1.0), 12.0);
            float edge = 1.0 - smoothstep(0.0, 2.0, (f2 - f1) * cl * 0.5);
            float3 col = p.b.rgb * mix(0.7, clamp(shade, 0.0, 1.5) * 1.4, clamp(p.a.w, 0.0, 1.0)) + spark * 0.6;
            col += edge * max(p.a.z, 0.0) * mix(p.b.rgb, float3(1.0), 0.6);
            g = col;
            ga = 1.0;
            break;
        }
        case 21: { // spiral galaxy: a = (cx, cy, size px, rotation speed), b = color, c = (arms, twist, seed)
            float2 d = c - p.a.xy;
            float R = max(p.a.z, 2.0);
            float r = length(d) / R;
            float ang = atan2(d.y, d.x) + t * p.a.w;
            float N = max(floor(p.c.x), 1.0);
            float sp = cos(N * (ang - p.c.y * log(r + 0.05)));
            float arm = pow(0.5 + 0.5 * sp, 4.0) * exp(-r * 2.0);
            float2 rd = rot12(d / R, t * p.a.w);
            float n = fbm12(float3(rd * 4.0, p.c.z * 1.7), 4);
            arm *= 0.4 + 1.2 * n;
            float core = exp(-r * r * 25.0) * 1.6;
            float2 cid = floor(c);
            float st = step(0.985, hsh12(cid + p.c.z * 5.1)) * exp(-r * 1.2);
            g = p.b.rgb * arm * 2.2 + float3(1.0, 0.94, 0.85) * (core + st);
            ga = clamp(lum12(g) * 1.5, 0.0, 1.0);
            break;
        }
        case 22: { // orbit rings: a = (cx, cy, radius, speed), b = color, c = (rings, tilt, width, dot size), d.w = seed
            float2 d = c - p.a.xy;
            int n = int(clamp(floor(p.c.x), 1.0, 8.0));
            float ty = clamp(p.c.y, 0.05, 1.0);
            float w = max(p.c.z, 0.2);
            float ds = max(p.c.w, 0.3);
            float acc = exp(-dot(d, d) / max(p.a.z * p.a.z * 0.01, 1.0)) * 1.2;
            for (int k = 0; k < 8; k++) {
                if (k >= n) break;
                float fk = float(k);
                float rk = max(p.a.z, 2.0) * (fk + 1.0) / float(n);
                float ta = fk * 0.35 - 0.3;
                float2 dr = rot12(d, -ta);
                float2 e = float2(dr.x, dr.y / ty);
                float dist = abs(length(e) - rk) * ty / max(ty, length(normalize(e + 1e-4) * float2(ty, 1.0)));
                acc += (1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, dist)) * 0.6;
                float th = t * p.a.w * 1.5 / (fk + 1.0) + hsh12(float2(fk, p.d.w + 0.5)) * 6.2831853;
                float2 pos = rot12(float2(cos(th), sin(th) * ty) * rk, ta);
                float2 dv = d - pos;
                acc += exp(-dot(dv, dv) / (ds * ds)) * 1.5;
            }
            g = p.b.rgb * acc;
            ga = clamp(acc, 0.0, 1.0);
            break;
        }
        case 23: { // heartbeat ECG: a = (y 0-1, amplitude px, beat width px, sweep speed), b = color, c = (line width px, trail 0-1)
            float y0 = p.a.x * size.y;
            float bw = max(p.a.z, 4.0);
            float y = y0 - p.a.y * ecg12(fract(c.x / bw));
            float y1 = y0 - p.a.y * ecg12(fract((c.x + 1.0) / bw));
            float dy = y1 - y;
            float dist = abs(c.y - y) / sqrt(1.0 + dy * dy);
            float w = max(p.c.x, 0.2);
            float line = 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, dist);
            float glow = exp(-dist / (w * 3.0)) * 0.5;
            float head = fract(t * p.a.w) * size.x;
            float behind = fm12(head - c.x, size.x) / size.x;
            float trail = exp(-behind * 3.0 / max(p.c.y, 0.02));
            float hg = exp(-length(float2(c.x - head, c.y - (y0 - p.a.y * ecg12(fract(head / bw))))) / (w * 3.0)) * 1.5;
            float e = (line + glow) * trail * 1.3 + hg;
            g = p.b.rgb * e;
            ga = clamp(e, 0.0, 1.0);
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
