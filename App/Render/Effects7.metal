#include <metal_stdlib>
using namespace metal;

// Batch 7: procedural generators & particles (anime / AMV staples) — starfield, twinkling stars, snow, rain, embers,
// bokeh, dust, fireflies, speed lines, manga focus lines, shockwave, beam, plasma, aurora, clouds, smoke, fire,
// electric arcs, code rain, retro grid, tunnel, equalizer, halftone, confetti.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
// Common: d.x = time, d.y = blend 0-1, d.z = only (1 = drop the input), i.x = mode, i.y = 0 additive / 1 over.
// Additive modes write premultiplied light into g; over modes write straight color into g and coverage into ga.
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler sg7Zero(address::clamp_to_zero, filter::linear, coord::pixel);

static inline float lg7(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float hg7(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float hg73(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static float ng7(float3 x) {
    float3 i = floor(x), f = fract(x); float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hg73(i), hg73(i + float3(1, 0, 0)), u.x), mix(hg73(i + float3(0, 1, 0)), hg73(i + float3(1, 1, 0)), u.x), u.y),
               mix(mix(hg73(i + float3(0, 0, 1)), hg73(i + float3(1, 0, 1)), u.x), mix(hg73(i + float3(0, 1, 1)), hg73(i + float3(1, 1, 1)), u.x), u.y), u.z);
}
static float fbmg7(float3 x, int oct) {
    float v = 0.0, a = 0.5;
    for (int k = 0; k < oct; k++) { v += a * ng7(x); x = x * 2.03 + float3(17.1, 9.2, 3.3); a *= 0.5; }
    return v;
}
static inline float2 rotg7(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(v.x * cs - v.y * sn, v.x * sn + v.y * cs); }
static inline float3 hsvg7(float h, float s, float v) {
    float3 k = clamp(abs(fract(h + float3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    return v * mix(float3(1.0), k, s);
}

// Soft round particles on a jittered grid, `layers` parallax layers (<= 3), 3x3 neighbours each (<= 27 iterations).
static float partg7(float2 c, float cell, float rad, float2 vel, float wob, float t, float seed, int layers,
                    float soft, float pulseFreq, float pulseAmt, thread float& hue) {
    float acc = 0.0, hw = 0.0;
    cell = max(cell, 2.0);
    soft = clamp(soft, 0.05, 1.0);
    wob = clamp(wob, 0.0, 1.0);
    for (int L = 0; L < layers; L++) {
        float ls = 1.0 + float(L) * 0.55;
        float cl = cell * ls;
        float rr = clamp(rad * ls, 0.3, cl * 0.45);
        float2 q = c - vel * (0.55 + 0.45 * ls) * t + float2(float(L) * 37.7, float(L) * 91.3) + seed * 17.0;
        float2 id = floor(q / cl);
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                float2 cid = id + float2(float(i), float(j));
                float ha = hg7(cid + float(L) * 13.7 + seed * 3.1);
                float hb = hg7(cid * 1.37 + 5.3 + seed);
                float hc = hg7(cid * 0.71 + 11.9 - seed * 1.7);
                float2 ctr = (cid + 0.5 + (float2(ha, hb) - 0.5) * 0.5) * cl;
                ctr += wob * cl * 0.18 * float2(sin(t * (1.0 + hc * 2.0) + ha * 6.283), cos(t * (0.8 + hb * 1.6) + hc * 6.283));
                float r = rr * (0.55 + 0.45 * hc);
                float d = length(q - ctr);
                float m = 1.0 - smoothstep(r * (1.0 - soft), r, d);
                float tw = 0.5 + 0.5 * sin(t * pulseFreq * (0.6 + ha) + hb * 6.283);
                m *= 1.0 - clamp(pulseAmt, 0.0, 1.0) * (1.0 - tw);
                acc += m;
                hw += m * hc;
            }
        }
    }
    hue = hw / max(acc, 1e-4);
    return acc;
}

static inline float sqg7(float x) { return x * x; }
// Ember heat ramp: dying red -> tint (orange) -> yellow -> white-hot core.
static float3 heatg7(float h, float3 tint) {
    float3 c = mix(float3(0.45, 0.03, 0.01), tint, smoothstep(0.05, 0.45, h));
    c = mix(c, float3(1.0, 0.82, 0.4), smoothstep(0.45, 0.8, h));
    return mix(c, float3(1.0, 0.97, 0.88), smoothstep(0.8, 1.0, h));
}
// Piecewise-linear value noise (straight segments = jagged lightning).
static inline float jagg7(float x, float y) { float i = floor(x), f = fract(x); return mix(hg7(float2(i, y)), hg7(float2(i + 1.0, y)), f); }
static float boltg7(float u, float k, float frame, float seed) {
    float n = 0.0, a = 1.0, f = 1.0;
    for (int o = 0; o < 5; o++) {
        n += (jagg7(u * f * 7.0 + float(o) * 13.1, k * 7.1 + seed * 3.3 + frame * 1.37 + float(o) * 5.7) - 0.5) * a;
        f *= 2.05; a *= 0.5;
    }
    return n;
}
static float eqHg7(float id, float tt, float seed) {
    float hv = ng7(float3(id * 0.37 + seed * 5.0, tt, 0.0)) * 0.7 + 0.3 * ng7(float3(id * 1.7, tt * 2.3, seed));
    return pow(clamp(hv * 1.25 - 0.1, 0.0, 1.0), 1.3);
}
static inline float sdRbg7(float2 q, float2 b, float r) {
    float2 d = abs(q) - b + r;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}
// Hue rotation around the gray axis (Rodrigues).
static inline float3 hrotg7(float3 c, float a) {
    float3 k = float3(0.57735027); float cs = cos(a);
    return c * cs + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cs);
}

// Premultiplied emission P + solid coverage A -> straight color / alpha for the "over" compositor (glows read as light).
static inline void ovr7q(float3 P, float A, thread float3& g, thread float& ga) {
    P = max(P, float3(0.0));
    ga = clamp(max(A, max(P.r, max(P.g, P.b))), 0.0, 1.0);
    g = P / max(ga, 1e-3);
}

kernel void fxGen7(texture2d<half, access::sample> src [[texture(0)]],
                   texture2d<half, access::write> dst [[texture(1)]],
                   texture2d<half, access::sample> aux [[texture(2)]],
                   constant EffectParams& p [[buffer(0)]],
                   uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(sg7Zero, c));
    float t = p.d.x;
    float mn = max(min(size.x, size.y), 1.0);
    float3 g = float3(0.0);
    float ga = 0.0;
    switch (p.i.x) {
        case 0: { // starfield warp: a = (cx, cy, speed, density), b = color, c = (size px, seed, streak, 0)
            float2 d = (c - p.a.xy) / mn;
            float dl = length(d);
            float2 dir = d / max(dl, 1e-4);
            float dens = max(p.a.w, 0.1);
            float acc = 0.0;
            for (int k = 0; k < 8; k++) {
                float z = fract(float(k) / 8.0 + t * p.a.z * 0.15);
                float sc = mix(6.0, 0.25, z) * dens;
                float2 uv = d * sc + float2(float(k) * 7.31, float(k) * 3.17) + p.c.y * 1.37;
                float2 id = floor(uv), f = fract(uv);
                float2 pos = 0.25 + 0.5 * float2(hg7(id + float(k) * 11.0), hg7(id * 1.3 + 7.0 + float(k)));
                float cellPx = mn / sc;
                float2 ov = (f - pos) * cellPx;
                float al = dot(ov, dir) / (1.0 + p.c.z * z * z);
                float pr = dot(ov, float2(-dir.y, dir.x));
                float r = max(p.c.x * (0.3 + 1.7 * z), 0.3);
                float m = exp(-(al * al + pr * pr) / (r * r));
                float fade = smoothstep(0.0, 0.3, z) * (1.0 - smoothstep(0.85, 1.0, z));
                acc += m * fade;
            }
            ga = clamp(acc, 0.0, 1.0);
            g = p.b.rgb * acc;
            break;
        }
        case 1: { // twinkling stars: a = (spacing px, size px, twinkle speed, brightness), b = color, c.x = seed
            float3 acc = float3(0.0);
            for (int L = 0; L < 2; L++) {
                float fl = float(L);
                float cl = max(p.a.x, 4.0) * (1.0 + fl * 0.7);
                float2 q = c + p.c.x * 23.0 + fl * 57.3;
                float2 id = floor(q / cl);
                for (int j = -1; j <= 1; j++) {
                    for (int i = -1; i <= 1; i++) {
                        float2 cid = id + float2(float(i), float(j));
                        float ha = hg7(cid + p.c.x * 3.3 + fl * 7.1), hb = hg7(cid * 1.7 + 4.1 + fl);
                        float hc = hg7(cid * 0.6 + 9.7 + p.c.x), hd = hg7(cid * 2.3 + 1.9 + fl * 3.0);
                        if (hc > 0.75) continue;
                        float2 ctr = (cid + 0.25 + 0.5 * float2(ha, hb)) * cl;
                        float near = clamp(fl * 0.6 + hc * 0.5, 0.0, 1.0);
                        float r = max(p.a.y * (0.4 + near), 0.3);
                        float2 dv = q - ctr;
                        float d2 = dot(dv, dv);
                        float tw = 0.5 + 0.5 * sin(t * p.a.z * (0.5 + ha) * 6.283 + hb * 6.283);
                        tw = tw * tw;
                        float core = exp(-d2 / (r * r * 0.6));
                        float halo = exp(-sqrt(d2) / (r * 1.8)) * 0.35;
                        // cross-flare glints (long 4-point + short diagonal on near stars), length breathes with the twinkle
                        float fLen = min(r * (3.0 + 6.0 * tw) * (0.6 + near), cl * 0.9);
                        float fw = r * 0.18 + 0.25;
                        float flare = (exp(-abs(dv.y) / fw - abs(dv.x) / fLen) + exp(-abs(dv.x) / fw - abs(dv.y) / fLen)) * 0.75;
                        float2 dg = float2(dv.x + dv.y, dv.x - dv.y) * 0.7071;
                        flare += (exp(-abs(dg.y) / fw - abs(dg.x) / (fLen * 0.45)) + exp(-abs(dg.x) / fw - abs(dg.y) / (fLen * 0.45))) * 0.25 * step(0.5, near);
                        float3 tint = p.b.rgb * mix(float3(0.75, 0.88, 1.2), float3(1.15, 0.95, 0.78), hd);
                        float depthB = mix(0.45, 1.0, near);
                        acc += tint * (core * 1.2 + halo + flare * mix(0.3, 1.0, tw)) * mix(0.2, 1.0, tw) * depthB * p.a.w;
                    }
                }
            }
            g = acc;
            ga = clamp(max(acc.r, max(acc.g, acc.b)), 0.0, 1.0);
            break;
        }
        case 2: { // snow: a = (spacing, size, fall speed, wind), b = color, c = (seed, wobble)
            float3 P = float3(0.0);
            float A = 0.0;
            float wob = clamp(p.c.y, 0.0, 2.0);
            for (int L = 0; L < 3; L++) {
                float fl = float(L);
                float ls = 1.0 + fl * 1.1;
                float cl = max(p.a.x, 2.0) * ls;
                float rr = clamp(p.a.y * ls, 0.3, cl * 0.42);
                float soft = mix(0.3, 0.9, fl * 0.5);          // depth of field: far flakes crisp, near flakes defocused
                float op = fl < 0.5 ? 0.65 : (fl < 1.5 ? 0.9 : 0.5);
                float2 vel = float2(p.a.w, p.a.z) * (0.45 + 0.4 * ls);
                float2 q = c - vel * t + float2(fl * 37.7, fl * 91.3) + p.c.x * 17.0;
                float2 id = floor(q / cl);
                float3 lc = mix(p.b.rgb * float3(0.82, 0.9, 1.05), p.b.rgb, fl * 0.5);
                for (int j = -1; j <= 1; j++) {
                    for (int i = -1; i <= 1; i++) {
                        float2 cid = id + float2(float(i), float(j));
                        float ha = hg7(cid + fl * 13.7 + p.c.x * 3.1), hb = hg7(cid * 1.37 + 5.3 + p.c.x), hc = hg7(cid * 0.71 + 11.9 - p.c.x * 1.7);
                        if (hc > 0.8) continue;
                        float2 ctr = (cid + 0.5 + (float2(ha, hb) - 0.5) * 0.5) * cl;
                        ctr.x += wob * cl * 0.22 * sin(t * (0.7 + hc * 1.4) + ha * 6.283);
                        ctr.y += wob * cl * 0.06 * cos(t * (0.9 + hb) + hc * 6.283);
                        float r = rr * (0.55 + 0.45 * hc);
                        float d = length(q - ctr);
                        float m = 1.0 - smoothstep(r * (1.0 - soft), r, d);
                        if (fl > 1.5) m *= 0.7 + 0.3 * smoothstep(r * 0.3, r * 0.95, d);   // bokeh rim
                        m += exp(-d / (r * 0.9 + 0.5)) * 0.18 * (1.0 - m);
                        m = clamp(m * op, 0.0, 1.0);
                        P += lc * m * (1.0 - A);
                        A += m * (1.0 - A);
                    }
                }
            }
            g = P / max(A, 1e-3);
            ga = A;
            break;
        }
        case 3: { // rain: a = (angle rad, speed px/s, length px, spacing px), b = color, c = (width px, seed, amount)
            float2 dir = float2(sin(p.a.x), cos(p.a.x));
            float2 pv = float2(dir.y, -dir.x);
            float along = dot(c, dir), across = dot(c, pv);
            float len = max(p.a.z, 1.0);
            float w = max(p.c.x, 0.2);
            float acc = 0.0;
            for (int L = 0; L < 3; L++) {
                float fl = float(L);
                float sp = max(p.a.w, 2.0) * (1.0 + fl * 0.5);
                float u = across / sp + fl * 0.37;
                float col = floor(u), fu = fract(u);
                float hcol = hg7(float2(col, fl * 5.0 + p.c.y * 3.7));
                float dx = abs(fu - (0.2 + 0.6 * hcol)) * sp;
                float seg = len * 3.0 * (1.0 + fl * 0.3);
                float v = along - t * p.a.y * (0.8 + 0.4 * hcol) * (0.7 + 0.3 * fl) + hcol * 1000.0;
                float cy = floor(v / seg);
                float fy = (v / seg - cy) * seg;
                float on = step(hg7(float2(col * 1.31 + p.c.y, cy + fl * 17.0)), p.c.z);
                float m = smoothstep(0.0, len, fy) * (1.0 - step(len, fy));
                m *= 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, dx);
                acc += m * on * (0.8 - fl * 0.15);
            }
            g = p.b.rgb;
            ga = clamp(acc, 0.0, 1.0);
            break;
        }
        case 4: { // embers: a = (spacing, size, rise speed, turbulence), b = color, c = (seed, flicker freq)
            float cl0 = max(p.a.x, 4.0), rad0 = max(p.a.y, 0.3), tb = p.a.w, fk = p.c.y, sd = p.c.x;
            float3 acc = float3(0.0);
            for (int L = 0; L < 3; L++) {
                float fl = float(L);
                float cl = cl0 * (1.0 + fl * 0.45);
                float rr = min(rad0 * (1.25 - fl * 0.3), cl * 0.14);
                float spf = 1.15 - fl * 0.3;
                float2 q = c + float2(0.0, p.a.z * spf * t) + float2(fl * 37.7 + sd * 17.0, fl * 91.3 + sd * 11.0);
                q.x += tb * cl * 0.25 * sin(q.y / (cl * 1.9) + t * 1.4 + fl * 2.1)
                     + tb * cl * 0.3 * (ng7(float3(q / (cl * 2.5), t * 0.45 + fl * 3.0)) - 0.5);
                float2 id = floor(q / cl);
                for (int j = -1; j <= 1; j++) {
                    for (int i = -1; i <= 1; i++) {
                        float2 cid = id + float2(float(i), float(j));
                        if (hg7(cid * 2.17 + 41.0 + fl) > 0.75) continue;
                        float ha = hg7(cid + fl * 13.7 + sd * 3.1), hb = hg7(cid * 1.37 + 5.3 + sd);
                        float hc = hg7(cid * 0.71 + 11.9 - sd * 1.7), hd = hg7(cid * 1.91 + 23.3 + fl);
                        float2 ctr = (cid + 0.5 + (float2(ha, hb) - 0.5) * 0.6) * cl;
                        ctr.x += tb * cl * 0.12 * sin(t * (1.3 + hc * 2.0) + ha * 6.283);
                        float life = fract(t * (0.25 + 0.35 * hb) + hc);
                        float fade = smoothstep(0.0, 0.08, life) * (1.0 - smoothstep(0.6, 1.0, life));
                        float spark = step(0.84, hd);
                        float heat = clamp((1.0 - life) * (0.55 + 0.45 * ha) + spark * 0.35, 0.0, 1.0);
                        float flk = 1.0 - 0.45 * (0.5 + 0.5 * sin(t * fk * (0.7 + ha) + hb * 6.283)) * smoothstep(0.0, 0.5, fk);
                        float r = max(rr * (0.45 + hc * hc) * mix(1.0, 0.6, spark), 0.3);
                        float2 dv = q - ctr;
                        float d2;
                        if (spark > 0.5) { // short motion streak trailing behind the spark
                            float2 sdir = normalize(float2((ha - 0.5) * tb * 0.8, -1.0));
                            float al = dot(dv, sdir), pr = dot(dv, float2(-sdir.y, sdir.x));
                            float tail = min(r * (3.0 + 5.0 * hb) * clamp(p.a.z / 120.0, 0.25, 2.0), cl * 0.8);
                            float a2 = al > 0.0 ? al / r : al / max(tail, r);
                            d2 = a2 * a2 + (pr * pr) / (r * r * 0.5);
                        } else {
                            d2 = dot(dv, dv) / (r * r);
                        }
                        float core = exp(-d2 * 1.6);
                        float halo = exp(-d2 * 0.12) * 0.32;
                        float3 hc3 = heatg7(heat, p.b.rgb);
                        float in1 = fade * flk * (1.0 - fl * 0.25);
                        acc += (hc3 * (core * (1.2 + heat) + halo) + float3(1.0, 0.95, 0.85) * core * core * heat * 1.2) * in1;
                    }
                }
            }
            g = acc * mix(0.5, 1.15, c.y / size.y);
            ga = clamp(lg7(g), 0.0, 1.0);
            break;
        }
        case 5: { // bokeh particles: a = (spacing, size, speed, softness), b = color, c = (hue variation, seed)
            float hue;
            float acc = partg7(c, p.a.x, p.a.y, float2(p.a.z * 0.3, -p.a.z), 1.0, t, p.c.y, 2, p.a.w, 0.0, 0.0, hue);
            float3 col = mix(p.b.rgb, hsvg7(hue, 0.6, 1.0), clamp(p.c.x, 0.0, 1.0));
            float e = acc * 0.5;
            g = col * e;
            ga = clamp(e, 0.0, 1.0);
            break;
        }
        case 6: { // dust motes: a = (spacing, size, drift speed, brightness), b = color, c.x = seed
            float cl0 = max(p.a.x, 4.0), rad0 = max(p.a.y, 0.2), sp = p.a.z, sd = p.c.x;
            float acc = 0.0, gl = 0.0;
            for (int L = 0; L < 3; L++) { // L0 = near (big, defocused), L2 = far (small, sharp)
                float fl = float(L);
                float cl = cl0 * (2.2 - fl * 0.7);
                float rr = min(rad0 * (3.2 - fl * 1.15), cl * 0.3);
                float soft = 0.85 - fl * 0.38;
                float alpha = 0.32 + fl * 0.3;
                float spf = 1.4 - fl * 0.4;
                float2 q = c - float2(sp, -sp * 0.3) * spf * t + float2(fl * 53.1 + sd * 19.0, fl * 27.7 + sd * 7.0);
                float2 id = floor(q / cl);
                for (int j = -1; j <= 1; j++) {
                    for (int i = -1; i <= 1; i++) {
                        float2 cid = id + float2(float(i), float(j));
                        float ha = hg7(cid + fl * 9.7 + sd * 2.3), hb = hg7(cid * 1.29 + 4.1 + sd);
                        float hc = hg7(cid * 0.83 + 15.7 - sd), hd = hg7(cid * 1.77 + 31.1 + fl);
                        if (hd > 0.55) continue;
                        float2 ctr = (cid + 0.5 + (float2(ha, hb) - 0.5) * 0.5) * cl;
                        ctr += cl * 0.2 * float2(sin(t * 0.5 * (0.5 + hc) + ha * 6.283), cos(t * 0.4 * (0.5 + hb) + hc * 6.283));
                        float r = rr * (0.6 + 0.6 * hc);
                        float d = length(q - ctr);
                        float disc = 1.0 - smoothstep(r * (1.0 - soft) - 0.5, r + 0.5, d);
                        float rim = 1.0 + 0.35 * soft * smoothstep(r * 0.4, r * 0.95, d);
                        float glint = pow(0.5 + 0.5 * sin(t * (1.2 + 2.0 * ha) + hb * 6.283), 10.0);
                        acc += disc * rim * alpha * (0.55 + 0.45 * glint * (1.0 - soft));
                        gl += disc * glint * (1.0 - soft) * alpha;
                    }
                }
            }
            float2 uv = c / size;
            float shaft = 0.55 + 0.45 * smoothstep(-0.5, 0.6, sin((uv.x * 0.8 + uv.y * 0.6) * 5.0 + ng7(float3(uv * 3.0, t * 0.2)) * 2.0));
            g = (p.b.rgb * acc + float3(1.0, 0.98, 0.92) * gl * 0.6) * shaft * p.a.w;
            ga = clamp(lg7(g), 0.0, 1.0);
            break;
        }
        case 7: { // fireflies: a = (spacing, size, wander speed, glow), b = color, c = (seed, pulse speed)
            float hue;
            float2 vel = float2(p.a.z * 0.4, -p.a.z * 0.6);
            float core = partg7(c, p.a.x, p.a.y, vel, 1.0, t, p.c.x, 2, 0.4, p.c.y, 0.85, hue);
            float halo = partg7(c, p.a.x, p.a.y * (1.0 + max(p.a.w, 0.0)), vel, 1.0, t, p.c.x, 2, 1.0, p.c.y, 0.85, hue);
            float3 col = p.b.rgb * (core + halo * 0.45) + float3(1.0, 1.0, 0.85) * core * 0.4;
            g = col;
            ga = clamp(core + halo * 0.45, 0.0, 1.0);
            break;
        }
        case 8: { // speed lines: a = (cx, cy, count, thickness 0-1), b = color, c = (inner 0-1, fps, seed, length jitter)
            float2 d = c - p.a.xy;
            float r = length(d);
            float R = max(0.5 * length(size), 1.0);
            float ang = atan2(d.y, d.x) / 6.2831853 + 0.5;
            float u = ang * max(p.a.z, 1.0);
            float id = floor(u), fu = fract(u);
            float frame = floor(t * max(p.c.y, 0.0));
            float ha = hg7(float2(id, frame + p.c.z * 7.7));
            float hb = hg7(float2(id * 1.3 + 3.1, frame * 1.7 + p.c.z));
            float w = max(p.a.w * (0.3 + 0.7 * ha), 0.002);
            float line = 1.0 - smoothstep(w * 0.35, w * 0.5, abs(fu - (0.25 + 0.5 * hb)));
            float r0 = R * (p.c.x + p.c.w * hb * 0.6);
            float fade = smoothstep(r0, r0 + R * 0.15 + 1.0, r);
            g = p.b.rgb;
            ga = line * fade * step(0.3, ha);
            break;
        }
        case 9: { // manga focus lines: a = (cx, cy, count, thickness 0-1), b = color, c = (inner 0-1, jitter fps, seed, aspect)
            float2 d = (c - p.a.xy) * float2(1.0, max(p.c.w, 0.05));
            float r = length(d);
            float R = max(0.5 * length(size), 1.0);
            float ang = atan2(d.y, d.x) / 6.2831853 + 0.5;
            float u = ang * max(p.a.z, 1.0);
            float id = floor(u), fu = fract(u);
            float frame = floor(t * max(p.c.y, 0.0));
            float ha = hg7(float2(id * 0.91, frame + p.c.z * 5.3));
            float hb = hg7(float2(id * 1.7 + 2.3, frame * 1.3 + p.c.z));
            float r0 = R * (p.c.x + (ha - 0.5) * 0.25);
            float taper = clamp((r - r0) / (R * 0.8 + 1.0), 0.0, 1.0);
            float w = max(p.a.w * (0.4 + 0.6 * hb) * taper, 0.001);
            float line = 1.0 - smoothstep(w * 0.6, w, abs(fu - 0.5) * 2.0);
            g = p.b.rgb;
            ga = line * step(r0, r);
            break;
        }
        case 10: { // shockwave: a = (cx, cy, progress 0-1, max radius px), b = color, c = (thickness, distortion px, glow, auto speed)
            float prog = p.a.z + t * max(p.c.w, 0.0);
            prog = p.c.w > 0.0 ? fract(prog) : clamp(prog, 0.0, 1.0);
            float rad = prog * p.a.w;
            float2 d = c - p.a.xy;
            float L = length(d);
            float2 dir = d / max(L, 1e-3);
            float th = max(p.c.x, 0.5);
            float x = (L - rad) / th;
            float gk = exp(-x * x);
            float fade = pow(1.0 - prog, 1.3) * smoothstep(0.0, 0.04, prog);
            float sec = clamp(p.d.w, 0.0, 1.0);
            float x2 = (L - rad * 0.7) / (th * 0.6);
            float gk2 = exp(-x2 * x2) * sec;
            float lens = (x * gk + x2 * gk2 * 0.6) * fade; // lens-like refraction across the band
            float2 off = dir * p.c.y * lens;
            float2 ch = dir * (gk + gk2 * 0.5) * fade * (1.5 + 0.06 * abs(p.c.y));
            float4 sR = float4(src.sample(sg7Zero, c - off * 1.15 - ch));
            float4 sG = float4(src.sample(sg7Zero, c - off));
            float4 sB = float4(src.sample(sg7Zero, c - off * 0.85 + ch));
            s = float4(sR.r, sG.g, sB.b, max(sG.a, max(sR.a, sB.a)));
            float wide = exp(-x * x / 6.0) * 0.35;
            float xr = (x - 0.55) * 2.0, xg = x * 2.0, xb = (x + 0.55) * 2.0;
            float3 fr = float3(exp(-xr * xr), exp(-xg * xg), exp(-xb * xb));
            float3 col = p.b.rgb;
            float inner = step(L, rad) * pow(1.0 - prog, 3.0) * 0.12 * smoothstep(0.0, 1.0, L / max(rad, 1.0));
            float3 ring = col * (gk * 0.55 + wide + gk2 * 0.5 + inner) + mix(col, float3(1.0), 0.55) * fr * 0.45;
            g = ring * p.c.z * fade;
            ga = clamp(lg7(g), 0.0, 1.0);
            break;
        }
        case 11: { // energy beam: a = (ax, ay, bx, by), b = color, c = (width px, glow, wiggle px, speed)
            float2 A = p.a.xy, B = p.a.zw, ab = B - A;
            float len = max(length(ab), 1.0);
            float2 dv = ab / len, nv = float2(-dv.y, dv.x);
            float2 rel = c - A;
            float ap = dot(rel, dv);
            float al = clamp(ap, 0.0, len);
            float perp = dot(rel, nv);
            float sp = p.c.w;
            float w = max(p.c.x, 0.5);
            float env = sin(3.14159265 * al / len);
            float wig = (ng7(float3(al / 40.0, t * sp, 0.0)) - 0.5) * 2.0 * p.c.z * env;
            float th = w * (0.7 + 0.6 * ng7(float3(al / (w * 5.0 + 4.0) - t * sp * 2.5, t * sp * 0.5, 1.7)));
            float py = perp - wig;
            float dd = length(float2(ap - al, py));
            float core = exp(-sqg7(dd / (th * 0.3)));
            float inner = exp(-sqg7(dd / th));
            float outer = exp(-dd / max(th * p.c.y * 1.2, 0.5)) * 0.55;
            float inside = step(0.0, ap) * step(ap, len);
            float ends = smoothstep(0.0, 0.1, al / len) * smoothstep(0.0, 0.1, 1.0 - al / len);
            float wisp = 0.0;
            for (int k = 0; k < 3; k++) { // crackling filaments twisting around the core
                float fk = float(k);
                float o = (ng7(float3(al / (18.0 + 10.0 * fk) - t * sp * (1.0 + 0.5 * fk), fk * 5.3, t * sp * 0.6)) - 0.5) * th * 5.0;
                float seg = smoothstep(0.5, 0.75, ng7(float3(al / 30.0 + fk * 3.7, t * sp * 1.3, fk * 2.0 + 9.0)));
                wisp += exp(-sqg7((py - o) / (0.6 + w * 0.08))) * seg;
            }
            wisp *= inside * ends;
            float cell = w * 3.0 + 4.0;
            float frm = floor(t * (8.0 + sp * 3.0));
            float sid = floor(ap / cell);
            float spk = 0.0;
            for (int k = -1; k <= 1; k++) { // short-lived sparks popping off the beam
                float id = sid + float(k);
                float h1 = hg7(float2(id, frm)), h2 = hg7(float2(id * 1.7 + 3.1, frm + 7.0)), h3 = hg7(float2(id * 0.7 + 9.0, frm * 1.3));
                if (h1 < 0.6) continue;
                float2 o2 = float2((id + h3) * cell - ap, (h2 - 0.5) * th * 6.0 - py);
                spk += exp(-dot(o2, o2) / (0.8 + w * 0.05)) * 1.5;
            }
            spk *= inside;
            float2 lA = float2(dot(c - A, dv), dot(c - A, nv)), lB = float2(dot(c - B, dv), dot(c - B, nv));
            float fr = exp(-length(lA) / (w * 2.5)) + exp(-length(lB) / (w * 2.5));
            float star = exp(-abs(lA.x) / (w * 0.3)) * exp(-abs(lA.y) / (w * 5.0)) + exp(-abs(lB.x) / (w * 0.3)) * exp(-abs(lB.y) / (w * 5.0));
            float flick = 0.85 + 0.15 * ng7(float3(t * (sp + 1.0) * 6.0, 0.0, 3.0));
            float3 col = p.b.rgb;
            float3 hot = mix(col, float3(1.0), 0.6);
            g = (float3(core * 1.6) + col * (inner * 1.3 + outer) + hot * (wisp * 0.8 + spk) + (col + 0.5) * (fr * 0.9 + star * 0.6)) * flick;
            ga = clamp(lg7(g), 0.0, 1.0);
            break;
        }
        case 12: { // plasma: a = (scale px, speed, hue shift 0-1, saturation)
            float sc = max(p.a.x, 1.0);
            float2 q = c / sc;
            float sp = t * p.a.y * 0.3;
            float2 w1 = float2(fbmg7(float3(q, sp), 4), fbmg7(float3(q + float2(5.2, 1.3), sp * 1.1), 4));
            float2 w2 = float2(fbmg7(float3(q + 3.0 * w1 + float2(1.7, 9.2), sp * 1.3), 4),
                               fbmg7(float3(q + 3.0 * w1 + float2(8.3, 2.8), sp * 0.9 + 4.0), 4));
            float v = fbmg7(float3(q + 3.0 * w2, sp * 0.7 + 2.0), 4);
            v = smoothstep(0.0, 1.0, clamp((v - 0.22) * 1.9, 0.0, 1.0));
            // curated gradient map: ink -> violet -> magenta -> cyan -> pale highlight
            float3 col = mix(float3(0.04, 0.02, 0.12), float3(0.32, 0.07, 0.55), smoothstep(0.0, 0.3, v));
            col = mix(col, float3(0.92, 0.22, 0.68), smoothstep(0.3, 0.55, v));
            col = mix(col, float3(0.25, 0.85, 1.0), smoothstep(0.55, 0.8, v));
            col = mix(col, float3(0.92, 0.97, 1.0), smoothstep(0.85, 1.0, v));
            col *= 0.8 + 0.4 * clamp(dot(w2, float2(0.7, 0.7)), 0.0, 1.0);
            col += float3(0.55, 0.85, 1.0) * smoothstep(0.7, 1.0, v) * 0.35;
            col = max(hrotg7(col, p.a.z * 6.2831853), float3(0.0));
            g = mix(float3(lg7(col)), col, clamp(p.a.w, 0.0, 1.0));
            ga = 1.0;
            break;
        }
        case 13: { // aurora: a = (bottom y 0-1, scale px, speed, intensity), b = color low, c = color high, d.w = seed
            float sc = max(p.a.y, 4.0);
            float3 acc = float3(0.0);
            for (int k = 0; k < 4; k++) {
                float fk = float(k);
                float yb = size.y * p.a.x + (ng7(float3(c.x / sc + fk * 1.7, t * p.a.z * 0.15 + fk, p.d.w)) - 0.5) * sc * 1.5;
                float h = sc * (1.2 + fk * 0.3);
                float dy = yb - c.y;
                float vert = smoothstep(0.0, sc * 0.08 + 1.0, dy) * exp(-max(dy, 0.0) / h);
                float rays = 0.5 + 0.5 * ng7(float3(c.x / (sc * 0.08 + 1.0) + fk * 11.0, t * p.a.z * 0.5, p.d.w * 1.3));
                acc += mix(p.b.rgb, p.c.rgb, clamp(dy / h, 0.0, 1.0)) * vert * rays * (1.0 - fk * 0.15);
            }
            g = acc * p.a.w;
            ga = clamp(lg7(g) * 1.5, 0.0, 1.0);
            break;
        }
        case 14: { // clouds / fog: a = (scale px, coverage 0-1, softness, drift px/s), b = color, c = (evolve, seed)
            float sc = max(p.a.x, 2.0);
            float2 q = (c + float2(t * p.a.w, 0.0)) / sc;
            float n = fbmg7(float3(q, t * p.c.x + p.c.y * 1.3), 5);
            float th = 1.0 - p.a.y;
            float m = smoothstep(th - p.a.z * 0.5, th + p.a.z * 0.5 + 1e-3, n);
            g = p.b.rgb * (0.75 + 0.35 * n);
            ga = m;
            break;
        }
        case 15: { // smoke: a = (scale px, rise px/s, turbulence, height 0-1), b = color, c = (seed, density)
            float sc = max(p.a.x, 2.0);
            float2 q = float2(c.x, c.y + t * p.a.y) / sc;
            float w = fbmg7(float3(q * 0.8, t * 0.3 + p.c.x), 3);
            float n = fbmg7(float3(q + p.a.z * (w - 0.5) * 2.0, t * 0.2 + p.c.x * 1.7), 4);
            float yb = 1.0 - c.y / size.y;
            float hh = max(p.a.w, 0.02);
            float fade = 1.0 - smoothstep(hh * 0.3, hh, yb);
            g = p.b.rgb * (0.8 + 0.3 * n);
            ga = clamp(smoothstep(0.3, 0.75, n) * fade * p.c.y, 0.0, 1.0);
            break;
        }
        case 16: { // fire: a = (height 0-1, scale px, speed, turbulence), b = tint, c = (seed, intensity)
            float sc = max(p.a.y, 2.0);
            float yb = (size.y - c.y) / max(p.a.x * size.y, 1.0);
            float n = fbmg7(float3(c.x / sc, c.y / sc + t * p.a.z, t * 0.5 + p.c.x * 1.9), 5);
            float f = (1.0 - yb) * (0.6 + n * 0.9) + (n - 0.5) * p.a.w;
            float heat = clamp(f * 1.4 - 0.2, 0.0, 1.0);
            float3 col = clamp(p.b.rgb * heat * 1.6 + float3(heat * heat * heat) * 0.8, 0.0, 2.0);
            g = col * p.c.y;
            ga = clamp(heat * p.c.y, 0.0, 1.0);
            break;
        }
        case 17: { // electric arcs: a = (ax, ay, bx, by), b = color, c = (amplitude px, width px, fps, glow), d.w = seed, i.z = bolts
            float2 A = p.a.xy, ab = p.a.zw - p.a.xy;
            float len = max(length(ab), 1.0);
            float2 dv = ab / len;
            float2 rel = c - A;
            float ap = dot(rel, dv);
            float t01 = clamp(ap / len, 0.0, 1.0);
            float outside = max(max(-ap, ap - len), 0.0);
            float perp = dot(rel, float2(-dv.y, dv.x));
            float frame = floor(t * max(p.c.z, 0.0));
            float w = max(p.c.y, 0.5);
            float amp = p.c.x;
            int bolts = clamp(int(p.i.z), 1, 4);
            float3 acc = float3(0.0);
            for (int k = 0; k < bolts; k++) {
                float fk = float(k);
                float fl = 0.55 + 0.45 * hg7(float2(frame * 1.31 + fk, p.d.w + 3.0));
                float off = boltg7(t01, fk, frame, p.d.w) * 2.0 * amp * sin(3.14159265 * t01);
                float dd = sqrt(sqg7(perp - off) + outside * outside);
                float core = exp(-sqg7(dd / (w * 0.45)));
                float inner = exp(-sqg7(dd / (w * 2.2))) * 0.7;
                float outer = exp(-dd / max(w * p.c.w * 1.5, 0.5)) * 0.4;
                acc += (float3(core * 1.4) + p.b.rgb * (inner + outer)) * fl;
                for (int f = 0; f < 2; f++) { // forks branching off the main bolt
                    float ff = float(f);
                    float hs = hg7(float2(fk * 3.7 + ff * 1.9 + p.d.w, frame * 0.77 + 5.0));
                    float t0 = 0.12 + 0.6 * hs;
                    float flen = 0.12 + 0.22 * hg7(float2(hs * 9.1, frame + ff));
                    float sgn = hg7(float2(hs * 4.3 + ff, frame * 1.9)) > 0.5 ? 1.0 : -1.0;
                    float sf = (t01 - t0) / flen;
                    if (sf <= 0.0 || sf >= 1.0) continue;
                    float base = boltg7(t0, fk, frame, p.d.w) * 2.0 * amp * sin(3.14159265 * t0);
                    float foff = base + sgn * sf * flen * len * 0.45 + boltg7(sf * 0.6, fk + 10.0 + ff * 3.0, frame, p.d.w) * amp * 0.9 * sf;
                    float fd = sqrt(sqg7(perp - foff) + outside * outside);
                    float tp = 1.0 - sf;
                    float fw = w * (0.35 + 0.55 * tp);
                    acc += (float3(exp(-sqg7(fd / (fw * 0.45))) * 1.1) + p.b.rgb * exp(-sqg7(fd / (fw * 2.0))) * 0.6) * tp * fl;
                }
            }
            float dA = length(c - A), dB = length(c - p.a.zw);
            acc += p.b.rgb * (exp(-dA / (w * 5.0)) + exp(-dB / (w * 5.0))) * 0.8 + float3((exp(-dA / (w * 1.2)) + exp(-dB / (w * 1.2))) * 0.6);
            g = acc;
            ga = clamp(lg7(g), 0.0, 1.0);
            break;
        }
        case 18: { // code rain: a = (cell px, fall cells/s, trail cells, glyph change rate), b = color, c = (seed, density)
            float cw = max(p.a.x, 4.0), ch = cw * 1.3;
            float col = floor(c.x / cw), row = floor(c.y / ch);
            float2 f = float2(fract(c.x / cw), fract(c.y / ch));
            float hc = hg7(float2(col, p.c.x));
            float active = step(hg7(float2(col + 0.5, p.c.x * 1.7 + 3.0)), p.c.y);
            float trail = max(p.a.z, 1.0);
            float rows = size.y / ch;
            float period = rows + trail;
            float head = fract(hc + t * p.a.y * (0.6 + 0.8 * hc) / period) * period;
            float behind = head - row;
            float inten = (behind >= 0.0 && behind < trail) ? 1.0 - behind / trail : 0.0;
            float hb = (behind >= 0.0 && behind < 1.0) ? 1.0 : 0.0;
            float2 gl = (f - float2(0.12, 0.08)) / float2(0.76, 0.84);
            float inside = step(0.0, gl.x) * step(gl.x, 1.0) * step(0.0, gl.y) * step(gl.y, 1.0);
            float2 gp = floor(clamp(gl, 0.0, 0.999) * float2(5.0, 7.0));
            float gs = floor(t * p.a.w * (0.5 + hg7(float2(col, row))) + hg7(float2(row, col)) * 10.0);
            float bit = step(0.5, hg7(float2(col * 7.0 + row * 131.0 + gp.x, gp.y * 17.0 + gs * 3.3 + p.c.x)));
            float e = inten * bit * inside * active;
            g = mix(p.b.rgb, float3(1.0), hb * 0.7) * e;
            ga = e;
            break;
        }
        case 19: { // retro grid + sun: a = (horizon 0-1, spacing px, speed, line width px), b = grid color, c = sun color, d.w = sun radius 0-1
            float hz = p.a.x * size.y;
            float dy = c.y - hz;
            float X = c.x - size.x * 0.5;
            float S = max(p.a.y, 2.0);
            float w = max(p.a.w, 0.3);
            float3 pink = float3(1.0, 0.12, 0.55);
            float3 orng = float3(1.0, 0.45, 0.12);
            float3 P = float3(0.0);
            float A = 0.0;
            float above = 1.0 - smoothstep(hz - 0.5, hz + 0.5, c.y);
            // sky: faint dusk gradient + twinkling stars, denser toward the top
            float skyT = clamp(-dy / max(hz, 1.0), 0.0, 1.0);
            P += mix(float3(0.35, 0.05, 0.35), float3(0.05, 0.02, 0.18), skyT) * 0.18 * above;
            float scl = max(mn * 0.035, 2.0);
            float2 sid = floor(c / scl);
            float sh = hg7(sid + 7.7);
            if (sh > 0.86) {
                float2 spt = (sid + 0.2 + 0.6 * float2(hg7(sid * 1.3 + 2.1), hg7(sid * 0.7 + 5.3))) * scl;
                float sd2 = length_squared(c - spt);
                float tw = 0.55 + 0.45 * sin(t * (1.5 + sh * 4.0) + sh * 40.0);
                P += float3(0.9, 0.85, 1.0) * exp(-sd2 / (0.35 + sh * 0.9)) * tw * skyT * above;
            }
            // sun: warm vertical gradient, animated slit bands through its lower half, big bloom
            float sr = max(p.d.w * size.y, 1.0);
            float2 sc = float2(size.x * 0.5, hz - sr * 0.35);
            float sd = length(c - sc);
            float v = clamp((c.y - (sc.y - sr)) / (2.0 * sr), 0.0, 1.0);
            float3 sunCol = v < 0.5 ? mix(p.c.rgb, orng, v * 2.0) : mix(orng, pink, (v - 0.5) * 2.0);
            float disk = 1.0 - smoothstep(sr - 1.0, sr + 1.0, sd);
            float yy = (c.y - sc.y) / sr;
            if (yy > -0.15) {
                float bp = fract(yy * 7.0 - t * p.a.z * 0.6);
                float gap = clamp((yy + 0.15) * 0.5, 0.0, 0.55);
                float aa = 7.0 / sr;
                disk *= smoothstep(gap - aa, gap + aa, bp);
            }
            disk *= above;
            float og = max(sd - sr, 0.0);
            float bloom = (exp(-og / (sr * 0.25 + 2.0)) * 0.55 + exp(-og / (sr * 1.1 + 4.0)) * 0.3) * (1.0 - disk);
            float3 glowCol = mix(sunCol, pink, 0.45);
            P += glowCol * bloom * mix(0.35, 1.0, above);
            P = P * (1.0 - disk) + sunCol * 1.15 * disk;
            A = max(A, disk);
            // distant mountains with a neon rim (kept off the sun in the middle)
            float mx = c.x / max(mn * 0.22, 1.0);
            float ridge = ng7(float3(mx, 1.7, 3.1)) * 0.65 + (1.0 - abs(ng7(float3(mx * 2.7, 4.2, 0.5)) * 2.0 - 1.0)) * 0.35;
            float side = smoothstep(0.08, 0.42, abs(X) / max(size.x, 1.0));
            float mh = size.y * 0.13 * ridge * side;
            float mTop = hz - mh;
            float hasM = step(0.5, mh);
            float mtn = smoothstep(mTop - 0.6, mTop + 0.6, c.y) * above * hasM;
            float3 mCol = mix(float3(0.10, 0.02, 0.18), float3(0.02, 0.0, 0.06), clamp((c.y - mTop) / max(mh, 1.0), 0.0, 1.0));
            P = P * (1.0 - mtn) + mCol * mtn;
            A = max(A, mtn * 0.95);
            float rim = exp(-abs(c.y - mTop) / 1.2) * hasM * above;
            P += mix(p.b.rgb, float3(0.3, 0.8, 1.0), 0.35) * rim * 0.9;
            // horizon haze line
            float ad = abs(dy);
            P += mix(pink, p.b.rgb, 0.5) * (exp(-ad / (size.y * 0.012 + 0.8)) * 0.9 + exp(-ad / (size.y * 0.07 + 2.0)) * 0.3);
            // perspective floor grid: bright core + colored halo, fading into the fog near the horizon
            if (dy > 0.5) {
                float k = size.y * 0.25;
                float z = k / dy;
                float xw = X * z;
                float pxd = abs(fract(xw / S + 0.5) - 0.5) * S / z;
                float zz = z * size.x * 0.5 / S + t * p.a.z;
                float dzdy = (size.x * 0.5 / S) * k / (dy * dy);
                float pzd = abs(fract(zz + 0.5) - 0.5) / max(dzdy, 1e-4);
                float dd = min(pxd, pzd);
                float core = 1.0 - smoothstep(w * 0.35, w * 0.35 + 1.0, dd);
                float halo = exp(-dd / (w * 1.6)) * 0.55 + exp(-dd / (w * 5.0)) * 0.22;
                float fog = smoothstep(0.0, size.y * 0.35 + 1.0, dy);
                float dens = clamp(1.0 / max(dzdy * 2.0, 1.0), 0.0, 1.0);
                float3 gc = mix(p.b.rgb, float3(0.3, 0.75, 1.0), 0.35 * (1.0 - fog));
                P += (gc * halo + mix(gc, float3(1.0), 0.55) * core) * mix(0.12, 1.0, fog) * mix(0.3, 1.0, dens) * 1.1;
                P += float3(0.12, 0.0, 0.16) * (1.0 - fog) * 0.6;
                P += glowCol * exp(-abs(X) / (sr * 0.5 + 2.0)) * exp(-dy / (size.y * 0.12 + 1.0)) * 0.3 * (0.6 + 0.4 * sin(dy * 0.8 - t * 4.0));
            }
            // subtle scanlines + chromatic tint toward the frame edges
            P *= 0.9 + 0.1 * sin(c.y * 3.14159);
            float ex = X / max(size.x * 0.5, 1.0);
            P *= float3(1.0 + 0.08 * ex, 1.0, 1.0 - 0.08 * ex);
            ovr7q(P, A, g, ga);
            break;
        }
        case 20: { // tunnel: a = (cx, cy, ring density, speed), b = color, c = (line width 0-1, segments, twist, depth fade)
            float2 d = c - p.a.xy;
            float r = max(length(d), 1e-3) / mn;
            float z = 0.25 / r;
            float zz = z * p.a.z + t * p.a.w;
            float w = clamp(p.c.x, 0.01, 1.0) * 0.5;
            float fr = abs(fract(zz) - 0.5);
            float ringCore = 1.0 - smoothstep(w * 0.25, w * 0.5, fr);
            float ringHalo = exp(-fr / (w * 0.6 + 0.02)) * 0.55 + exp(-fr / (w * 2.0 + 0.06)) * 0.2;
            float rid = floor(zz + 0.5);
            float ang = atan2(d.y, d.x) / 6.2831853 + p.c.z * z * 0.25 + t * 0.04 * p.a.w;
            float fa = abs(fract(ang * p.c.y) - 0.5);
            float spW = w * 0.5;
            float spoke = ((1.0 - smoothstep(spW * 0.4, spW, fa)) + exp(-fa / (spW + 0.01)) * 0.35) * step(0.5, p.c.y);
            // per-ring color drifting through a neon gradient with depth
            float3 c1 = p.b.rgb;
            float3 c2 = hrotg7(p.b.rgb, 2.3);
            float3 c3 = hrotg7(p.b.rgb, -1.6);
            float hk = 0.5 + 0.5 * sin(rid * 0.9 + z * 0.15);
            float3 rc = mix(mix(c1, c2, hk), c3, 0.3 + 0.3 * sin(rid * 0.37 - 1.0));
            // speed streaks along the walls
            float sa = ang * 80.0;
            float shh = hg7(float2(floor(sa), 3.7));
            float sz = fract(z * 0.08 + t * p.a.w * (0.4 + shh) * 0.5 + shh * 7.0);
            float streak = smoothstep(0.0, 0.04, sz) * (1.0 - smoothstep(0.04, 0.3, sz)) * step(0.7, shh)
                         * (1.0 - smoothstep(0.15, 0.45, abs(fract(sa) - 0.5)));
            // vignette into the center + distance dimming
            float fade = smoothstep(0.0, max(p.c.w, 0.01), r);
            float depthDim = exp(-z * 0.012 * p.a.z);
            float3 e = rc * (ringHalo * 1.1 + spoke * 0.55 * mix(0.4, 1.0, depthDim)) + mix(rc, float3(1.0), 0.6) * ringCore;
            e += mix(c1, float3(1.0), 0.5) * streak * 0.7;
            e *= fade * mix(0.35, 1.0, depthDim);
            e += mix(c3, c1, 0.5) * 0.12 * fade * smoothstep(0.0, 0.8, r);
            g = e;
            ga = clamp(max(e.r, max(e.g, e.b)), 0.0, 1.0);
            break;
        }
        case 21: { // equalizer: a = (bars, height 0-1, speed, gap 0-1), b = bottom color, c = top color, d.w = seed, i.z = blocks
            float n = max(floor(p.a.x), 1.0);
            float bw = size.x / n;
            float id = floor(c.x / bw);
            float fx = c.x - (id + 0.5) * bw;
            float ybase = size.y * 0.8;
            float hmax = clamp(p.a.y * size.y, 1.0, ybase * 0.96);
            float h = eqHg7(id, t * p.a.z, p.d.w) * hmax;
            float pk = h;
            for (int k = 1; k < 10; k++) { // peak caps: recent maxima falling under gravity
                float dt = float(k) * 0.07;
                pk = max(pk, eqHg7(id, (t - dt) * p.a.z, p.d.w) * hmax - 1.8 * hmax * dt * dt);
            }
            float yb = ybase - c.y;
            bool refl = yb < 0.0;
            float yy = abs(yb);
            float hw = max(bw * (1.0 - clamp(p.a.w, 0.0, 0.95)) * 0.5, 0.5);
            float segH = max(bw * 0.6, 3.0);
            float colD = sdRbg7(float2(fx, yy - h * 0.5), float2(hw, max(h * 0.5, 0.5)), min(hw, max(h * 0.5, 0.5)) * 0.9);
            float dbar = colD;
            if (p.i.z == 1u) {
                float si = floor(yy / segH);
                float shh = segH * 0.36;
                dbar = sdRbg7(float2(fx, yy - (si + 0.5) * segH), float2(hw, shh), min(hw, shh) * 0.5);
                if ((si + 0.5) * segH > h) dbar = 1e4;
            }
            float m = 1.0 - smoothstep(-0.6, 0.6, dbar);
            float glow = exp(-max(colD, 0.0) / max(bw * 0.35, 1.0)) * 0.45 * step(0.5, h);
            float capH = max(segH * 0.18, 1.0);
            float mc = 1.0 - smoothstep(-0.6, 0.6, sdRbg7(float2(fx, yy - (pk + capH * 2.5)), float2(hw, capH), min(hw, capH)));
            float v = clamp(yy / hmax, 0.0, 1.0);
            float3 col = mix(p.b.rgb, p.c.rgb, smoothstep(0.0, 1.0, v));
            col *= (0.85 + 0.35 * v) * (1.0 + 0.3 * (1.0 - clamp(abs(fx) / hw, 0.0, 1.0)));
            float3 capCol = mix(p.c.rgb, float3(1.0), 0.6);
            float solid = max(m, mc);
            float gw = glow * (1.0 - solid);
            g = (col * m + capCol * mc + col * 1.3 * gw) / max(m + mc + gw, 1e-4);
            float rk = refl ? 0.3 * exp(-yy / max(hmax * 0.3, 1.0)) : 1.0;
            ga = clamp(max(solid, glow) * rk, 0.0, 1.0);
            break;
        }
        case 22: { // halftone: a = (cell px, angle rad, speed, wave scale px), b = color, c.x = dot size, i.z = pattern
            float cl = max(p.a.x, 2.0);
            float2 q = rotg7(c - size * 0.5, p.a.y);
            float2 cid = floor(q / cl);
            float2 f = q / cl - cid - 0.5;
            float2 cc = (cid + 0.5) * cl;
            float wv = max(p.a.w, 1.0);
            float ph = p.i.z == 1u ? (cc.x + cc.y) / wv : length(cc) / wv;
            float wave = 0.5 + 0.5 * sin(ph * 6.283 - t * p.a.z * 6.283);
            float nf = fbmg7(float3(cc / (wv * 1.3), t * p.a.z * 0.6), 3);
            float sz = clamp(wave * 0.55 + smoothstep(0.25, 0.75, nf) * 0.6, 0.0, 1.1);
            float rr = p.c.x * 0.5 * (0.15 + 0.85 * sz);
            float aa = 1.0 / cl;
            float dl = length(f);
            float dotM = 1.0 - smoothstep(rr - aa, rr + aa, dl);
            float glowM = exp(-max(dl - rr, 0.0) * 7.0) * 0.3 * smoothstep(0.0, 0.1, rr);
            // flowing three-stop gradient (cool -> Color -> warm)
            float2 uvn = (c - size * 0.5) / mn;
            float gp = clamp(0.5 + 0.55 * (uvn.x * 0.8 - uvn.y * 0.6) + (nf - 0.5) * 0.6 + 0.15 * sin(t * p.a.z * 1.3), 0.0, 1.0);
            float3 cA = p.b.rgb, cB = hrotg7(p.b.rgb, 0.9) * 1.05, cC = hrotg7(p.b.rgb, -1.5) * 0.95;
            float3 col = gp < 0.5 ? mix(cC, cA, gp * 2.0) : mix(cA, cB, gp * 2.0 - 1.0);
            float shade = 1.1 - 0.35 * smoothstep(0.0, max(rr, 1e-3), length(f + float2(0.24) * rr));
            float3 P = col * dotM * shade + col * glowM * (1.0 - dotM);
            P += float3(1.0) * dotM * exp(-length_squared(f + float2(0.35) * rr) / max(rr * rr * 0.08, 1e-4)) * 0.25;
            ovr7q(P, dotM, g, ga);
            break;
        }
        case 23: { // confetti: a = (spacing, size, fall speed, spin speed), c = (seed, saturation, sway)
            for (int L = 0; L < 2; L++) {
                float fl = float(L);
                float cl = max(p.a.x, 4.0) * (1.0 + fl * 0.6);
                float2 q = c - float2(0.0, p.a.z * (0.7 + 0.3 * fl)) * t + fl * 41.0 + p.c.x * 17.0;
                float2 id = floor(q / cl);
                for (int j = -1; j <= 1; j++) {
                    for (int i = -1; i <= 1; i++) {
                        float2 cid = id + float2(float(i), float(j));
                        float ha = hg7(cid + fl * 9.1 + p.c.x), hb = hg7(cid * 1.31 + 2.7), hc = hg7(cid * 0.77 + 6.1 + p.c.x), hd = hg7(cid * 1.9 + 12.3 + fl);
                        float2 ctr = (cid + 0.5 + (float2(ha, hb) - 0.5) * 0.4) * cl;
                        ctr.x += sin(t * 2.0 + hc * 6.283) * p.c.z * cl * 0.2;
                        float ang = hd * 6.283 + t * p.a.w * (0.5 + ha);
                        float flip = abs(cos(t * p.a.w * 1.3 * (0.5 + hb) + hc * 6.283));
                        float2 lc = rotg7(q - ctr, -ang);
                        float2 hs = min(float2(p.a.y, p.a.y * 0.55 * max(flip, 0.08)) * (0.7 + 0.5 * hc) * (1.0 + fl * 0.3), float2(cl * 0.3));
                        float2 dd = abs(lc) - hs;
                        float m = 1.0 - smoothstep(-0.5, 0.5, max(dd.x, dd.y));
                        if (m > ga) { ga = m; g = hsvg7(hd, clamp(p.c.y, 0.0, 1.0), 1.0) * (0.6 + 0.4 * flip); }
                    }
                }
            }
            break;
        }
    }
    float4 base = p.d.z > 0.5 ? float4(0.0) : s;
    float bl = clamp(p.d.y, 0.0, 1.0);
    float4 o;
    if (p.i.y == 0u) {
        float3 Lg = max(g, float3(0.0)) * bl;
        o = float4(base.rgb + Lg, max(base.a, clamp(max(ga * bl, lg7(Lg)), 0.0, 1.0)));
    } else {
        float a = clamp(ga, 0.0, 1.0) * bl;
        o = float4(clamp(g, 0.0, 4.0) * a + base.rgb * (1.0 - a), a + base.a * (1.0 - a));
    }
    o = select(o, float4(0.0), isnan(o));
    dst.write(half4(o), gid);
}
