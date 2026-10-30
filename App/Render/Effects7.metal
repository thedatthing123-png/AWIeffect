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
            float cl = max(p.a.x, 4.0);
            float2 q = c + p.c.x * 23.0;
            float2 id = floor(q / cl);
            float acc = 0.0;
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 cid = id + float2(float(i), float(j));
                    float ha = hg7(cid + p.c.x * 3.3), hb = hg7(cid * 1.7 + 4.1), hc = hg7(cid * 0.6 + 9.7 + p.c.x);
                    if (hc > 0.75) continue;
                    float2 ctr = (cid + 0.25 + 0.5 * float2(ha, hb)) * cl;
                    float r = max(p.a.y * (0.5 + hc), 0.3);
                    float2 dv = q - ctr;
                    float d2 = dot(dv, dv);
                    float tw = 0.5 + 0.5 * sin(t * p.a.z * (0.5 + ha) * 6.283 + hb * 6.283);
                    float core = exp(-d2 / (r * r));
                    float flare = exp(-abs(dv.x) * abs(dv.y) / (r * r * 0.25)) * exp(-sqrt(d2) / (r * 3.0)) * 0.8;
                    acc += (core + flare) * mix(0.25, 1.0, tw) * p.a.w;
                }
            }
            ga = clamp(acc, 0.0, 1.0);
            g = p.b.rgb * acc;
            break;
        }
        case 2: { // snow: a = (spacing, size, fall speed, wind), b = color, c = (seed, wobble)
            float hue;
            float acc = partg7(c, p.a.x, p.a.y, float2(p.a.w, p.a.z), p.c.y, t, p.c.x, 3, 0.5, 0.0, 0.0, hue);
            g = p.b.rgb;
            ga = clamp(acc * 0.9, 0.0, 1.0);
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
            float hue;
            float acc = partg7(c, p.a.x, p.a.y, float2(p.a.w * 20.0, -p.a.z), p.a.w * 0.5, t, p.c.x, 2, 0.85, p.c.y, 0.7, hue);
            float k = mix(0.35, 1.0, c.y / size.y);
            float3 col = mix(p.b.rgb, float3(1.0, 0.9, 0.55), hue * 0.6);
            float e = acc * k * 1.4;
            g = col * e;
            ga = clamp(e, 0.0, 1.0);
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
            float hue;
            float acc = partg7(c, p.a.x, p.a.y, float2(p.a.z, -p.a.z * 0.35), 1.0, t, p.c.x, 3, 0.8, 1.5, 0.4, hue);
            float e = acc * p.a.w;
            g = p.b.rgb * e;
            ga = clamp(e, 0.0, 1.0);
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
            float x = (L - rad) / max(p.c.x, 0.5);
            float gk = exp(-x * x);
            s = float4(src.sample(sg7Zero, c - dir * p.c.y * x * gk * (1.0 - prog)));
            float e = gk * p.c.z * (1.0 - prog);
            g = p.b.rgb * e;
            ga = clamp(e, 0.0, 1.0);
            break;
        }
        case 11: { // energy beam: a = (ax, ay, bx, by), b = color, c = (width px, glow, wiggle px, speed)
            float2 A = p.a.xy, ab = p.a.zw - p.a.xy;
            float len = max(length(ab), 1.0);
            float2 dv = ab / len;
            float2 rel = c - A;
            float ap = dot(rel, dv);
            float al = clamp(ap, 0.0, len);
            float perp = dot(rel, float2(-dv.y, dv.x));
            float wig = (ng7(float3(al / 40.0, t * p.c.w, 0.0)) - 0.5) * 2.0 * p.c.z * sin(3.14159265 * al / len);
            float dd = length(float2(ap - al, perp - wig));
            float w = max(p.c.x, 0.5);
            float core = 1.0 - smoothstep(w * 0.25, w * 0.5 + 0.5, dd);
            float gl = exp(-dd / max(w * p.c.y, 0.5));
            float fl = 0.85 + 0.15 * sin(t * (p.c.w + 1.0) * 30.0);
            g = (p.b.rgb * gl + float3(core)) * fl;
            ga = clamp(max(core, gl), 0.0, 1.0);
            break;
        }
        case 12: { // plasma: a = (scale px, speed, hue shift 0-1, saturation)
            float sc = max(p.a.x, 1.0);
            float2 q = c / sc;
            float sp = t * p.a.y;
            float v = sin(q.x + sp) + sin(q.y + sp * 0.7) + sin((q.x + q.y) * 0.7 + sp * 1.3) + sin(length(c - size * 0.5) / sc - sp * 1.5);
            g = hsvg7(v / 8.0 + p.a.z + 0.5, clamp(p.a.w, 0.0, 1.0), 1.0);
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
            int bolts = clamp(int(p.i.z), 1, 4);
            float3 acc = float3(0.0); float cov = 0.0;
            for (int k = 0; k < bolts; k++) {
                float n = 0.0, amp = 1.0, fq = 1.0;
                for (int o = 0; o < 4; o++) {
                    n += (ng7(float3(t01 * fq * 6.0, float(k) * 7.1 + p.d.w, frame * 0.37 + float(o) * 3.1)) - 0.5) * amp;
                    fq *= 2.1; amp *= 0.5;
                }
                float off = n * 2.0 * p.c.x * sin(3.14159265 * t01);
                float dd = sqrt((perp - off) * (perp - off) + outside * outside);
                float core = 1.0 - smoothstep(w * 0.3, w * 0.5 + 0.5, dd);
                float gl = exp(-dd / max(w * p.c.w, 0.5)) * 0.6;
                acc += p.b.rgb * gl + float3(core);
                cov = max(cov, max(core, gl));
            }
            g = acc;
            ga = clamp(cov, 0.0, 1.0);
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
            float S = max(p.a.y, 2.0);
            float w = max(p.a.w, 0.3);
            float lineM = 0.0;
            if (dy > 0.5) {
                float k = size.y * 0.25;
                float z = k / dy;
                float xw = (c.x - size.x * 0.5) * z;
                float px = abs(fract(xw / S + 0.5) - 0.5) * S / z;
                float zz = z * size.x * 0.5 / S + t * p.a.z;
                float dzdy = (size.x * 0.5 / S) * k / (dy * dy);
                float pz = abs(fract(zz + 0.5) - 0.5) / max(dzdy, 1e-4);
                float m = max(1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, px), 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, pz));
                m += (exp(-px / (w * 3.0)) + exp(-pz / (w * 3.0))) * 0.25;
                lineM = clamp(m, 0.0, 1.0) * smoothstep(0.0, size.y * 0.1 + 1.0, dy);
            }
            float sr = max(p.d.w * size.y, 1.0);
            float2 sc = float2(size.x * 0.5, hz - sr * 0.35);
            float sd = length(c - sc);
            float sunM = (1.0 - smoothstep(sr - 1.0, sr + 1.0, sd)) * step(c.y, hz);
            float yy = (c.y - sc.y) / sr;
            if (yy > 0.0) sunM *= step(yy * 0.6, fract(yy * 7.0 - t * p.a.z * 0.5));
            float3 sunCol = mix(p.c.rgb, float3(1.0, 0.2, 0.6), clamp((c.y - (sc.y - sr)) / (2.0 * sr), 0.0, 1.0));
            g = mix(p.b.rgb, sunCol, sunM / (sunM + lineM + 1e-4));
            ga = max(sunM, lineM);
            break;
        }
        case 20: { // tunnel: a = (cx, cy, ring density, speed), b = color, c = (line width 0-1, segments, twist, depth fade)
            float2 d = c - p.a.xy;
            float r = max(length(d), 1e-3) / mn;
            float z = 0.25 / r;
            float zz = z * p.a.z + t * p.a.w;
            float w = clamp(p.c.x, 0.01, 1.0) * 0.5;
            float ringM = 1.0 - smoothstep(w * 0.6, w, abs(fract(zz) - 0.5));
            float ang = atan2(d.y, d.x) / 6.2831853 + p.c.z * z;
            float segM = 1.0 - smoothstep(w * 0.6, w, abs(fract(ang * p.c.y) - 0.5));
            float fade = smoothstep(0.0, max(p.c.w, 0.01), r);
            float e = max(ringM, segM * 0.7) * fade;
            g = p.b.rgb * e;
            ga = clamp(e, 0.0, 1.0);
            break;
        }
        case 21: { // equalizer: a = (bars, height 0-1, speed, gap 0-1), b = bottom color, c = top color, d.w = seed, i.z = blocks
            float n = max(floor(p.a.x), 1.0);
            float bw = size.x / n;
            float id = floor(c.x / bw), fx = fract(c.x / bw);
            float hv = ng7(float3(id * 0.37 + p.d.w * 5.0, t * p.a.z, 0.0)) * 0.7 + 0.3 * ng7(float3(id * 1.7, t * p.a.z * 2.3, p.d.w));
            float hmax = max(p.a.y * size.y, 1.0);
            float h = pow(clamp(hv, 0.0, 1.0), 1.2) * hmax;
            float yb = size.y - c.y;
            float gp = clamp(p.a.w, 0.0, 0.95) * 0.5;
            float m = step(gp, fx) * step(fx, 1.0 - gp) * step(yb, h);
            if (p.i.z == 1u) m *= step(0.25, fract(yb / max(bw * 0.6, 1.0)));
            g = mix(p.b.rgb, p.c.rgb, clamp(yb / hmax, 0.0, 1.0));
            ga = m;
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
            float rr = p.c.x * 0.5 * (0.55 + 0.45 * sin(ph * 6.283 - t * p.a.z * 6.283));
            float aa = 1.0 / cl;
            ga = 1.0 - smoothstep(rr - aa, rr + aa, length(f));
            g = p.b.rgb;
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
