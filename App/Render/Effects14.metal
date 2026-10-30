#include <metal_stdlib>
using namespace metal;

// Batch 14: distortion 2 & space warps — black hole lensing, droste spiral, fractal zoom, page curl, accordion fold,
// skew, keystone tilt, stretch segment, traveling wave line, twist columns, smear drag, mesh jitter, elastic bounce,
// moving magnifier, log-polar tunnel, puff/inflate, pinch waves, polar ripple, vortex spin, glass blocks,
// frosted window, water surface, mirage, earthquake chunks, zoom rings.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches). Time arrives in p.d.x.
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s14Edge(address::clamp_to_edge, filter::linear, coord::pixel);
constexpr sampler s14Zero(address::clamp_to_zero, filter::linear, coord::pixel);

static inline float4 tap14(texture2d<half, access::sample> t, float2 c) { return float4(t.sample(s14Edge, c)); }
static inline float4 tapz14(texture2d<half, access::sample> t, float2 c) { return float4(t.sample(s14Zero, c)); }
static inline float lum14(float4 c) { return dot(c.rgb, float3(0.2126, 0.7152, 0.0722)); }
static float hash14(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static inline float2 hash2_14(float2 cell, float s) { return float2(hash14(cell + s * 3.7), hash14(cell.yx + s * 5.3 + 17.0)); }
static float vnoise14(float2 x) {
    float2 i = floor(x), f = fract(x); float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash14(i), hash14(i + float2(1, 0)), u.x), mix(hash14(i + float2(0, 1)), hash14(i + float2(1, 1)), u.x), u.y);
}
static inline float2 rot14(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(v.x * cs - v.y * sn, v.x * sn + v.y * cs); }
static inline float mirror14(float x) { return 1.0 - abs(1.0 - 2.0 * fract(x * 0.5)); }
static inline float waves14(float2 q, float t) {
    return sin(dot(q, float2(1.0, 0.3)) + t * 1.3) + sin(dot(q, float2(-0.4, 1.1)) * 1.3 - t * 1.7)
         + 0.6 * sin(dot(q, float2(0.7, -0.8)) * 2.1 + t * 2.3) + 0.4 * sin(dot(q, float2(-1.2, -0.5)) * 2.9 - t * 1.1);
}

kernel void fxWarp14(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     texture2d<half, access::sample> aux [[texture(2)]],
                     constant EffectParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 o = tap14(src, c);
    float t = p.d.x;
    float hmin14 = max(min(size.x, size.y) * 0.5, 1.0);
    float twoPi = 6.2831853;
    switch (p.i.x) {
        case 0: { // black hole: a = (radius frac, lensing, glow 0-1, spin), b.xy = center
            float2 ctr = p.b.xy;
            float R = max(p.a.x * hmin14, 1.0);
            float2 d = c - ctr;
            float r = max(length(d), 1e-3);
            float2 dir = d / r;
            float rs = r - p.a.y * R * R / r;
            float ang = p.a.w * (R / r) * (R / r) + p.a.w * t * 0.5;
            float4 s = tap14(src, ctr + rot14(dir, ang) * rs);
            float hz = smoothstep(R * 0.92, R * 1.02, r);
            o = s * hz + float4(0, 0, 0, 1) * (1.0 - hz);
            float rr = (r - 1.5 * R) / (0.4 * R);
            float g = exp(-rr * rr) * p.a.z * (0.75 + 0.25 * sin(atan2(d.y, d.x) * 3.0 + t * 4.0 * p.a.w));
            o.rgb += g * float3(1.0, 0.62, 0.25);
            o.a = max(o.a, min(g, 1.0));
            break;
        }
        case 1: { // droste spiral: a = (scale ratio, twist, zoom speed, rotation rad), b.xy = center
            float2 d = c - p.b.xy;
            float r = max(length(d), 1e-3);
            float th = atan2(d.y, d.x) + p.a.w;
            float L = log(max(p.a.x, 1.05));
            float Rref = hmin14 * 0.3;
            float u = log(r / Rref) + th / twoPi * L * p.a.y - t * p.a.z * L;
            u = u - L * floor(u / L);
            float rr = Rref * exp(u);
            o = tap14(src, p.b.xy + float2(cos(th - p.a.w), sin(th - p.a.w)) * rr);
            break;
        }
        case 2: { // fractal zoom: a = (scale, speed, rotation rad/level, mix 0-1), b.xy = center
            float2 d = c - p.b.xy;
            float s = max(p.a.x, 1.1);
            float f = fract(t * p.a.y);
            float4 acc = float4(0.0); float ws = 0.0;
            for (int k = 0; k < 4; k++) {
                float e = float(k) + f;
                float zf = pow(s, e - 1.0);
                float w = sin(3.1415926 * e / 4.0);
                acc += tapz14(src, p.b.xy + rot14(d, p.a.z * e) / max(zf, 1e-3)) * w;
                ws += w;
            }
            acc /= max(ws, 1e-3);
            o = mix(o, acc, p.a.w);
            break;
        }
        case 3: { // page curl: a = (progress 0-1, angle rad, curl radius frac, shadow 0-1)
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            float d0 = min(min(0.0, dot(float2(size.x, 0), dir)), min(dot(float2(0, size.y), dir), dot(size, dir)));
            float d1 = max(max(0.0, dot(float2(size.x, 0), dir)), max(dot(float2(0, size.y), dir), dot(size, dir)));
            float ext = max(d1 - d0, 1.0);
            float x = dot(c, dir) - d0;
            float R = max(p.a.z * hmin14, 1.0);
            float F = ext * (1.0 - clamp(p.a.x, 0.0, 1.0)) - R * 0.5 * clamp(p.a.x * 4.0, 0.0, 1.0);
            float dd = x - F;
            float4 res;
            if (dd > R) {
                res = float4(0, 0, 0, p.a.w * 0.5 * exp(-(dd - R) / R));
            } else if (dd > 0.0) {
                float th = asin(clamp(dd / R, 0.0, 1.0));
                float xb = F + R * (3.1415926 - th);
                float xf = F + R * th;
                float4 b = tapz14(src, c + dir * (xb - x));
                if (xb < ext && b.a > 0.01) {
                    res = float4(mix(b.rgb, float3(0.92) * b.a, 0.55) * (0.75 + 0.25 * cos(th)), b.a);
                } else {
                    res = tapz14(src, c + dir * (xf - x));
                    res.rgb *= 1.0 - p.a.w * 0.4 * (dd / R);
                }
            } else {
                float xb = F + 3.1415926 * R + (F - x);
                float4 b = xb < ext ? tapz14(src, c + dir * (xb - x)) : float4(0.0);
                float4 fr = o;
                fr.rgb *= 1.0 - p.a.w * 0.5 * exp(dd / R);
                float4 bk = float4(mix(b.rgb, float3(0.92) * b.a, 0.55) * 0.75, b.a);
                res = bk + fr * (1.0 - bk.a);
            }
            o = res;
            break;
        }
        case 4: { // accordion fold: a = (folds, depth 0-1, angle rad, shading 0-1)
            float2 dir = float2(cos(p.a.z), sin(p.a.z));
            float2 per = float2(-dir.y, dir.x);
            float2 d = c - size * 0.5;
            float x = dot(d, dir), y = dot(d, per);
            float ext = abs(size.x * dir.x) + abs(size.y * dir.y);
            float P = max(ext / max(p.a.x, 1.0), 2.0);
            float sc = 1.0 - 0.6 * p.a.y;
            float xs = x / sc;
            float u = fract(xs / P);
            float idx = floor(xs / P);
            float even = fmod(abs(idx), 2.0);
            float tri = even < 0.5 ? u : 1.0 - u;
            float ys = y * (1.0 + p.a.y * 0.18 * (tri - 0.5));
            o = tapz14(src, size * 0.5 + dir * xs + per * ys);
            o.rgb *= 1.0 - p.a.w * 0.6 * tri;
            break;
        }
        case 5: { // skew / shear: a = (tan x, tan y, 0, 0), b.xy = anchor
            float2 d = c - p.b.xy;
            float x = d.x - p.a.x * d.y;
            float y = d.y - p.a.y * x;
            o = tapz14(src, p.b.xy + float2(x, y));
            break;
        }
        case 6: { // perspective tilt (keystone): a = (tilt x, tilt y, zoom, 0)
            float2 h = size * 0.5;
            float2 uv = (c - h) / h;
            float fy = max(1.0 + p.a.y * uv.y * 0.6, 0.1);
            float fx = max(1.0 + p.a.x * uv.x * 0.6, 0.1);
            float2 s = float2(uv.x / fy, uv.y / fx) / max(p.a.z, 0.05);
            o = tapz14(src, h + s * h);
            break;
        }
        case 7: { // stretch segment: a = (position 0-1, half width frac, stretch, angle rad)
            float2 dir = float2(cos(p.a.w), sin(p.a.w));
            float ext = abs(size.x * dir.x) + abs(size.y * dir.y);
            float2 P = size * 0.5 + dir * (p.a.x - 0.5) * ext;
            float s = dot(c - P, dir);
            float st = max(p.a.z, 0.1);
            float Hs = max(p.a.y * ext, 0.5);
            float Ho = Hs * st;
            float ssrc = abs(s) < Ho ? s / st : s - sign(s) * (Ho - Hs);
            o = tapz14(src, c + dir * (ssrc - s));
            break;
        }
        case 8: { // traveling wave line: a = (amplitude frac, wavelength frac, speed, angle rad), b.x = packet width frac
            float2 dir = float2(cos(p.a.w), sin(p.a.w));
            float2 per = float2(-dir.y, dir.x);
            float ext = abs(size.x * dir.x) + abs(size.y * dir.y);
            float s = dot(c - size * 0.5, dir) + ext * 0.5;
            float front = (fract(t * p.a.z) * 1.4 - 0.2) * ext;
            float w = max(p.b.x * ext, 1.0);
            float q = (s - front) / w;
            float env = exp(-q * q);
            float lam = max(p.a.y * hmin14, 1.0);
            float wv = sin((s - front) / lam * twoPi);
            o = tap14(src, c + per * wv * env * p.a.x * hmin14);
            o.rgb *= 1.0 + 0.15 * wv * env;
            break;
        }
        case 9: { // twist columns: a = (columns, twist rad, speed, shading 0-1)
            float cw = max(size.x / max(p.a.x, 1.0), 2.0);
            float col = floor(c.x / cw);
            float cx = (col + 0.5) * cw;
            float u = clamp((c.x - cx) / (cw * 0.5), -1.0, 1.0);
            float ph = p.a.y * (c.y / size.y - 0.5) + t * p.a.z + col * 0.37;
            float a0 = asin(u) + ph;
            float us = sin(a0);
            float sh = cos(a0);
            o = tap14(src, float2(cx + us * cw * 0.5, c.y));
            float lit = sh >= 0.0 ? (0.7 + 0.3 * sqrt(max(1.0 - u * u, 0.0))) : 0.45;
            o.rgb *= mix(1.0, lit, p.a.w);
            break;
        }
        case 10: { // smear drag: a = (length frac, angle rad, falloff, brightness bias 0-1)
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            float L = p.a.x * hmin14 * 2.0;
            float4 m = o;
            for (int k = 1; k <= 24; k++) {
                float f = float(k) / 24.0;
                float w = pow(1.0 - f, max(p.a.z, 0.05));
                float4 s = tap14(src, c - dir * L * f);
                float gate = mix(1.0, smoothstep(0.1, 0.6, lum14(s)), p.a.w);
                m = max(m, s * w * gate);
            }
            o = m;
            break;
        }
        case 11: { // mesh jitter: a = (cell frac, amount 0-1, rate /s, seed)
            float cs = max(p.a.x * hmin14, 2.0);
            float fr = floor(t * p.a.z);
            float2 g = c / cs;
            float2 i = floor(g), f = fract(g);
            float2 u = f * f * (3.0 - 2.0 * f);
            float sd = p.a.w * 1.73 + fr * 7.31;
            float2 o00 = hash2_14(i, sd) - 0.5, o10 = hash2_14(i + float2(1, 0), sd) - 0.5;
            float2 o01 = hash2_14(i + float2(0, 1), sd) - 0.5, o11 = hash2_14(i + float2(1, 1), sd) - 0.5;
            float2 off = mix(mix(o00, o10, u.x), mix(o01, o11, u.x), u.y);
            o = tap14(src, c + off * 2.0 * p.a.y * cs);
            break;
        }
        case 12: { // elastic bounce: a = (amount, frequency, damping, radius frac), b.xy = center
            float2 d = c - p.b.xy;
            float R = max(p.a.w * hmin14, 1.0);
            float fall = 1.0 - smoothstep(0.0, 1.0, length(d) / R);
            float env = exp(-p.a.z * t) * sin(twoPi * p.a.y * t + 0.6);
            float A = p.a.x * env * fall;
            float2 sc = float2(1.0 + A, 1.0 - A * 0.8);
            o = tap14(src, p.b.xy + d / max(sc, float2(0.05)));
            break;
        }
        case 13: { // moving magnifier: a = (radius frac, magnification, rim frac, speed), b = (cx, cy, orbit frac, 0)
            float R = max(p.a.x * hmin14, 2.0);
            float orb = p.b.z * hmin14;
            float ang = t * p.a.w * twoPi;
            float2 lc = p.b.xy + float2(cos(ang), sin(ang) * 0.6) * orb;
            float2 d = c - lc;
            float r = length(d) / R;
            if (r < 1.0) {
                float bar = 1.0 - 0.25 * (1.0 - r * r);
                float4 s = tap14(src, lc + d * bar / max(p.a.y, 0.1));
                float spec = pow(max(1.0 - length(d / R - float2(-0.35, -0.4)) * 1.6, 0.0), 3.0) * 0.35;
                o = s;
                o.rgb += spec * o.a;
            }
            float rim = max(p.a.z, 0.005);
            float e = abs(r - 1.0) / rim;
            if (e < 1.0) {
                float sh = 0.55 + 0.45 * dot(normalize(d + 1e-4), float2(-0.6, -0.8));
                float k = smoothstep(1.0, 0.6, e);
                o = mix(o, float4(float3(0.35 + 0.5 * sh), 1.0), k);
            }
            break;
        }
        case 14: { // tunnel warp (log-polar): a = (speed, twist, repeats, depth fade), b.xy = center
            float2 d = c - p.b.xy;
            float r = max(length(d), 1e-3);
            float th = atan2(d.y, d.x) / twoPi + 0.5;
            float lr = log(r / hmin14);
            float sx = mirror14(th * 2.0 * max(p.a.z, 0.5) + p.a.y * lr);
            float sy = mirror14(lr * max(p.a.z, 0.5) * 0.5 - t * p.a.x);
            o = tap14(src, float2(sx, sy) * size);
            o *= pow(clamp(r / hmin14, 0.0, 1.0), p.a.w);
            break;
        }
        case 15: { // puff / inflate: a = (amount, radius frac, highlight 0-1, 0)
            float R = max(p.a.y * hmin14, 1.0);
            float2 g = float2(0.0);
            for (int k = 0; k < 12; k++) {
                float an = float(k) * (twoPi / 12.0);
                float2 dv = float2(cos(an), sin(an));
                float4 s = tap14(src, c + dv * R);
                g += dv * (lum14(s) * 0.7 + s.a * 0.3);
            }
            g /= 6.0;
            o = tap14(src, c + g * p.a.x * R);
            float hl = clamp(dot(g, float2(0.6, 0.8)), 0.0, 1.0);
            o.rgb += hl * p.a.z * 0.5 * o.a;
            break;
        }
        case 16: { // pinch waves (angular lobes): a = (amount, lobes, speed, radius frac), b.xy = center
            float2 d = c - p.b.xy;
            float r = length(d);
            float R = max(p.a.w * hmin14, 1.0);
            float fall = 1.0 - smoothstep(0.0, 1.0, r / R);
            float th = atan2(d.y, d.x);
            float wv = sin(th * floor(max(p.a.y, 1.0)) + t * p.a.z * twoPi);
            float s = 1.0 + p.a.x * wv * fall * 0.6;
            o = tap14(src, p.b.xy + d * max(s, 0.05));
            break;
        }
        case 17: { // polar ripple (rotational waves): a = (angle rad, wavelength frac, speed, decay), b.xy = center
            float2 d = c - p.b.xy;
            float r = length(d);
            float lam = max(p.a.y * hmin14, 1.0);
            float ph = (r / lam - t * p.a.z) * twoPi;
            float ang = p.a.x * sin(ph) * exp(-p.a.w * 3.0 * r / hmin14);
            o = tap14(src, p.b.xy + rot14(d, ang));
            break;
        }
        case 18: { // vortex spin: a = (strength turns, radius frac, speed turns/s, power), b.xy = center
            float2 d = c - p.b.xy;
            float r = length(d);
            float R = max(p.a.y * hmin14, 1.0);
            float fall = pow(max(1.0 - r / R, 0.0), max(p.a.w, 0.1));
            float ang = (p.a.x + t * p.a.z) * twoPi * fall;
            o = tap14(src, p.b.xy + rot14(d, ang));
            break;
        }
        case 19: { // glass blocks: a = (block frac, refraction, bevel 0-0.5, highlight 0-1)
            float cs = max(p.a.x * hmin14, 3.0);
            float2 cell = floor(c / cs);
            float2 q = fract(c / cs) - 0.5;
            float2 cc = (cell + 0.5) * cs;
            float k = 1.0 - p.a.y * 1.5;
            float e = max(abs(q.x), abs(q.y));
            float bv = max(p.a.z, 0.001);
            float edge = smoothstep(0.5 - bv, 0.5, e);
            float2 nrm = abs(q.x) > abs(q.y) ? float2(sign(q.x), 0.0) : float2(0.0, sign(q.y));
            o = tap14(src, cc + q * cs * k - nrm * edge * cs * 0.25);
            float hl = edge * clamp(dot(nrm, float2(-0.7, -0.7)) + 0.3, 0.0, 1.0);
            o.rgb = o.rgb * (1.0 - edge * 0.25) + hl * p.a.w * 0.6 * max(o.a, 0.3);
            o.a = max(o.a, hl * p.a.w * 0.6);
            break;
        }
        case 20: { // frosted window: a = (roughness frac, grain frac, frost 0-1, seed), b = (cx, cy, clear radius frac, 0)
            float rough = p.a.x * hmin14;
            float gs = max(p.a.y * hmin14, 1.0);
            float2 cl = c - p.b.xy;
            float clear = smoothstep(p.b.z * hmin14 * 0.8, p.b.z * hmin14 * 1.1 + 1.0, length(cl));
            float n1 = vnoise14(c / gs + p.a.w * 3.1), n2 = vnoise14(c / gs + float2(7.3, 2.9) + p.a.w * 1.7);
            float4 acc = float4(0.0);
            for (int k = 0; k < 4; k++) {
                float2 j = hash2_14(c + float2(float(k) * 13.0, float(k) * 7.0), p.a.w) - 0.5;
                acc += tap14(src, c + (float2(n1, n2) - 0.5 + j * 0.8) * 2.0 * rough * clear);
            }
            acc *= 0.25;
            float fr = p.a.z * clear;
            acc.rgb = mix(acc.rgb, float3(0.85, 0.9, 0.95) * max(acc.a, 0.6) * 0.55 + acc.rgb * 0.45, fr);
            acc.a = max(acc.a, fr * 0.6);
            o = acc;
            break;
        }
        case 21: { // water surface: a = (strength frac, scale frac, speed, highlight 0-1)
            float sc = max(p.a.y * hmin14, 1.0);
            float2 q = c / sc;
            float tt = t * p.a.z * 2.0;
            const float e = 0.05;
            float h = waves14(q, tt);
            float2 g = float2(waves14(q + float2(e, 0), tt) - waves14(q - float2(e, 0), tt),
                              waves14(q + float2(0, e), tt) - waves14(q - float2(0, e), tt)) / (2.0 * e);
            o = tap14(src, c + g * p.a.x * hmin14 * 0.1);
            float ca = pow(clamp(h / 3.0 * 0.5 + 0.5, 0.0, 1.0), 6.0) * 3.0;
            o.rgb += ca * p.a.w * float3(0.75, 0.92, 1.0) * max(o.a, 0.2) * 0.5;
            o.a = max(o.a, min(ca * p.a.w * 0.3, 1.0));
            break;
        }
        case 22: { // mirage: a = (amount frac, band frac, speed, horizon 0-1), b.x = reflection 0-1
            float bh = max(p.a.y * hmin14, 1.0);
            float yb = c.y / bh;
            float nz = vnoise14(float2(yb * 1.7, t * p.a.z * 2.0)) - 0.5;
            float dx = (sin(yb * twoPi + t * p.a.z * 5.0) * 0.6 + nz * 1.6) * p.a.x * hmin14;
            float hy = p.a.w * size.y;
            float below = smoothstep(hy - 2.0, hy + 2.0, c.y);
            float4 a0 = tap14(src, float2(c.x + dx * (0.4 + below), c.y));
            float ry = hy - (c.y - hy) * 1.2;
            float4 rf = tap14(src, float2(c.x + dx * 1.6, ry + nz * bh));
            float fade = exp(-max(c.y - hy, 0.0) / max(size.y * 0.3, 1.0));
            o = mix(a0, max(a0, rf * float4(0.85, 0.9, 1.0, 1.0)), below * p.b.x * fade);
            break;
        }
        case 23: { // earthquake chunks: a = (intensity frac, block frac, frequency /s, seed), b.x = cracks 0-1
            float bs = max(p.a.y * hmin14, 3.0);
            float fr = floor(t * p.a.z);
            float2 shift = (hash2_14(float2(fr, 3.0), p.a.w) - 0.5) * 0.4;
            float2 g = c / bs + shift;
            float row = floor(g.y);
            g.x += hash14(float2(row, p.a.w + 11.0)) * 0.9;
            float2 cell = floor(g);
            float2 lq = fract(g);
            float2 v = (hash2_14(cell, p.a.w + fr * 3.17) - 0.5) * 2.0 * p.a.x * hmin14;
            float2 glob = (hash2_14(float2(fr, 1.0), p.a.w * 2.0) - 0.5) * p.a.x * hmin14 * 0.5;
            o = tap14(src, c + v + glob);
            float ed = min(min(lq.x, 1.0 - lq.x), min(lq.y, 1.0 - lq.y)) * bs;
            float crack = (1.0 - smoothstep(0.0, 1.5, ed)) * p.b.x;
            o.rgb *= 1.0 - crack * 0.8;
            o.a = max(o.a, crack * 0.8);
            break;
        }
        case 24: { // zoom rings: a = (ring width frac, zoom, speed, twist rad), b.xy = center
            float2 d = c - p.b.xy;
            float r = length(d);
            float w = max(p.a.x * hmin14, 2.0);
            float idx = floor(r / w - t * p.a.z);
            float alt = fmod(abs(idx), 2.0) < 0.5 ? 1.0 : -1.0;
            float s = max(1.0 + p.a.y * alt * 0.5, 0.1);
            o = tap14(src, p.b.xy + rot14(d, p.a.w * alt) / s);
            break;
        }
    }
    dst.write(half4(o), gid);
}
