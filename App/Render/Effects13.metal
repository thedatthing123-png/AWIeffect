#include <metal_stdlib>
using namespace metal;

// Batch 13: film emulation, retro media & screens — film stock looks (warm portrait, cool green, tungsten with
// red halation, punchy slide, grainy B&W), film burn, light damage, gate weave, Super 8, instant photo, JPEG
// artifacts, bit crush, LED / LCD screens, hologram scan, analog TV, teletext mosaic, thermal printer, risograph,
// screen print, neon sign, cyberpunk grade, lomo and day-for-night.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches). Only rgb changes; alpha is kept.
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s13Zero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler s13Edge(address::clamp_to_edge, filter::linear, coord::pixel);

static inline float3 u13(float4 c) { return c.a > 1e-6 ? clamp(c.rgb / c.a, 0.0, 1.0) : float3(0.0); }
static inline float l13(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float h13(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float vn13(float2 x) {
    float2 i = floor(x), f = fract(x); float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(h13(i), h13(i + float2(1, 0)), u.x), mix(h13(i + float2(0, 1)), h13(i + float2(1, 1)), u.x), u.y);
}
static float fbm13(float2 x) {
    float v = 0.0, a = 0.5;
    for (int k = 0; k < 4; k++) { v += a * vn13(x); x = x * 2.03 + float2(17.1, 5.3); a *= 0.5; }
    return v;
}
static float2 rot13(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(cs * v.x - sn * v.y, sn * v.x + cs * v.y); }
static float3 sat13(float3 c, float s) { float y = l13(c); return clamp(float3(y) + (c - y) * s, 0.0, 1.0); }
static float3 scurve13(float3 c, float k) { float3 x = clamp(c, 0.0, 1.0); float3 sc = x * x * (3.0 - 2.0 * x); return mix(x, sc, k); }
/// Animated film grain (24 fps), centered on 0.
static float grain13(float2 c, float t) {
    float f = floor(t * 24.0);
    return (h13(floor(c) + float2(f * 37.17, f * 11.73)) + h13(floor(c * 0.5) + float2(f * 5.1, 91.7 + f)) - 1.0);
}
static float vig13(float2 c, float2 size) {
    float2 q = (c / size - 0.5) * float2(size.x / max(size.y, 1.0), 1.0);
    return dot(q, q) * 2.0;
}
static float bayer13(float2 c) {
    const float m[16] = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };
    int2 b = int2(floor(c)) & 3;
    return (m[b.y * 4 + b.x] + 0.5) / 16.0;
}
static float dot13(float2 c, float a, float sz, float v) {
    float2 r = rot13(c, a) / sz;
    float2 l = fract(r) - 0.5;
    float rad = sqrt(clamp(v, 0.0, 1.0)) * 0.72;
    float aa = 1.0 / sz;
    return (1.0 - smoothstep(rad - aa, rad + aa, length(l))) * step(0.01, v);
}
static float3 smp13(texture2d<half, access::sample> t, float2 c) { return u13(float4(t.sample(s13Edge, c))); }
static float3 finishFilm13(float3 col, float3 look, float str, float gr, float2 c, float t) {
    float3 r = mix(col, look, str);
    float y = l13(r);
    float w = 0.35 + 2.6 * y * (1.0 - y);
    return clamp(r + grain13(c, t) * gr * 0.22 * w, 0.0, 1.0);
}

kernel void fxRetro13(texture2d<half, access::sample> src [[texture(0)]],
                      texture2d<half, access::write> dst [[texture(1)]],
                      texture2d<half, access::sample> aux [[texture(2)]],
                      constant EffectParams& p [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s13Zero, c));
    float t = p.d.x;
    float3 col = u13(s);
    float3 r = col;
    float alpha = s.a;
    switch (p.i.x) {
        case 0: { // warm portrait stock: a.x strength, a.y grain
            float3 x = col * float3(1.06, 1.0, 0.88) + float3(0.04, 0.025, 0.0);
            x = scurve13(x, 0.35);
            x = mix(x, x * float3(1.04, 0.98, 0.9), smoothstep(0.4, 1.0, l13(x)));
            x = sat13(x, 0.9);
            r = finishFilm13(col, x, p.a.x, p.a.y, c, t);
            break;
        }
        case 1: { // cool green stock
            float y = l13(col);
            float3 x = col * float3(0.94, 1.03, 1.0);
            x += float3(-0.02, 0.05, 0.03) * (1.0 - y) * (1.0 - y);
            x = mix(x, x * float3(1.0, 1.02, 0.96), smoothstep(0.5, 1.0, y));
            x = scurve13(x, 0.45);
            x = sat13(x, 1.08);
            r = finishFilm13(col, x, p.a.x, p.a.y, c, t);
            break;
        }
        case 2: { // tungsten stock + red halation: a.x strength, a.y grain, a.z halation radius px, a.w halation amount
            float3 x = col * float3(0.88, 0.98, 1.12) + float3(0.0, 0.01, 0.03);
            x = scurve13(x, 0.5);
            float h = 0.0;
            float rad = max(p.a.z, 0.5);
            for (int k = 0; k < 16; k++) {
                float ang = float(k) * 0.3927;
                float rr = rad * (0.5 + 0.5 * float(k & 1));
                float lv = l13(smp13(src, c + float2(cos(ang), sin(ang)) * rr));
                h += smoothstep(0.55, 0.95, lv);
            }
            h /= 16.0;
            float selfL = smoothstep(0.55, 0.95, l13(col));
            float halo = max(h - selfL * 0.6, 0.0);
            x += float3(1.0, 0.18, 0.05) * halo * p.a.w * 1.6;
            r = finishFilm13(col, clamp(x, 0.0, 1.0), p.a.x, p.a.y, c, t);
            break;
        }
        case 3: { // punchy slide stock
            float3 x = scurve13(col, 0.8);
            x = sat13(x, 1.45);
            float y = l13(x);
            x += float3(-0.03, 0.0, 0.06) * (1.0 - y);
            x = pow(max(x, float3(0.0)), float3(1.08));
            r = finishFilm13(col, clamp(x, 0.0, 1.0), p.a.x, p.a.y, c, t);
            break;
        }
        case 4: { // grainy B&W: a.x strength, a.y grain, a.z contrast
            float y = dot(col, float3(0.3, 0.6, 0.1));
            float3 x = scurve13(float3(y), clamp(p.a.z, 0.0, 1.0));
            x = (x - 0.5) * (1.0 + p.a.z * 0.5) + 0.5;
            r = finishFilm13(col, clamp(x, 0.0, 1.0), p.a.x, p.a.y * 1.6, c, t);
            break;
        }
        case 5: { // film burn: a.x intensity, a.y speed, a.z size (0-1)
            float2 uv = c / size;
            float e = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
            float tt = t * p.a.y;
            float n = fbm13(uv * 3.5 + float2(tt * 0.7, -tt * 0.45));
            float m = n * 0.9 + 0.35 * (0.5 + 0.5 * sin(tt * 2.3 + uv.x * 4.0));
            float burn = smoothstep(0.0, 1.0, (p.a.z * m * 1.4 - e) / max(p.a.z * 0.35, 0.01) + 0.5);
            burn = clamp(burn, 0.0, 1.0) + 0.15 * p.a.z * m;
            float3 hot = mix(float3(0.85, 0.12, 0.02), float3(1.0, 0.75, 0.3), clamp(burn, 0.0, 1.0));
            hot = mix(hot, float3(1.0, 0.97, 0.88), smoothstep(0.75, 1.0, burn));
            r = clamp(col + hot * burn * p.a.x * 1.3, 0.0, 1.0);
            break;
        }
        case 6: { // light damage frames: a.x amount, a.y rate (frames/s), b = leak color
            float fr = floor(t * max(p.a.y, 0.1));
            float2 uv = c / size;
            float3 acc = float3(0.0);
            for (int k = 0; k < 3; k++) {
                float2 ctr = float2(h13(float2(fr, float(k) * 7.0 + 1.0)), h13(float2(float(k) * 3.0 + 2.0, fr + 9.0)));
                float rr = 0.25 + 0.45 * h13(float2(fr * 1.7, float(k) + 4.0));
                float d = length((uv - ctr) * float2(size.x / max(size.y, 1.0), 1.0));
                float w = 1.0 - smoothstep(0.0, rr, d);
                float3 tint = mix(p.b.rgb, float3(1.0, 0.85, 0.6), h13(float2(fr, float(k) + 20.0)));
                acc += tint * w * w;
            }
            float flash = 0.3 + 0.7 * h13(float2(fr + 3.0, 55.0));
            float3 light = acc * flash + p.b.rgb * flash * 0.25;
            r = clamp(1.0 - (1.0 - col) * (1.0 - clamp(light * p.a.x, 0.0, 1.0)), 0.0, 1.0);
            break;
        }
        case 7: { // gate weave: a.x amount px, a.y speed, a.z frame line (0-1)
            float tt = t * p.a.y;
            float2 off = p.a.x * float2(0.6 + 0.4 * sin(tt * 7.1 + 1.3), 0.6 + 0.4 * cos(tt * 5.3 + 0.7)) * float2(0.5, 1.0);
            float4 ss = float4(src.sample(s13Zero, c - off));
            alpha = ss.a;
            float3 x = u13(ss);
            float lineH = p.a.z * size.y * 0.06;
            float yy = c.y - off.y * 2.0;
            float band = step(yy, lineH) + step(size.y - lineH, yy);
            x = mix(x, x * 0.08, clamp(band, 0.0, 1.0));
            r = x;
            alpha = max(alpha, clamp(band, 0.0, 1.0) * s.a);
            break;
        }
        case 8: { // Super 8: a.x vignette, a.y jitter px, a.z warmth, a.w grain
            float jt = floor(t * 18.0);
            float2 off = p.a.y * (float2(h13(float2(jt, 1.0)), h13(float2(2.0, jt))) * 0.8 + 0.2) * float2(0.6, 1.0);
            float4 ss = float4(src.sample(s13Zero, c - off));
            alpha = ss.a;
            float3 x = u13(ss);
            x = mix(x, x * float3(1.12, 1.0, 0.78) + float3(0.05, 0.03, 0.0), p.a.z);
            x = sat13(scurve13(x, 0.3), 0.85);
            float flick = 1.0 + (h13(float2(jt, 7.0)) - 0.5) * 0.08;
            x *= flick * (1.0 - clamp(vig13(c, size) * p.a.x * 1.6, 0.0, 1.0));
            r = finishFilm13(x, x, 1.0, p.a.w, c, t);
            break;
        }
        case 9: { // instant photo: a.x fade, a.y border (0-0.25 of min dim), a.z warmth, b = border color
            float3 x = mix(col, col * 0.78 + float3(0.16, 0.14, 0.12), p.a.x);
            x = mix(x, x * float3(1.05, 1.0, 0.86) + float3(0.02, 0.01, 0.0), p.a.z);
            x = sat13(x, 1.0 - 0.35 * p.a.x);
            float b = p.a.y * min(size.x, size.y);
            bool inside = c.x > b && c.x < size.x - b && c.y > b && c.y < size.y - b * 3.0;
            if (!inside) { x = p.b.rgb * (0.97 + 0.03 * h13(floor(c * 0.5))); }
            r = x;
            break;
        }
        case 10: { // JPEG artifacts: a.x quality (0-1), a.y block size px
            float bs = max(p.a.y, 2.0);
            float2 bo = floor(c / bs) * bs;
            float3 m = float3(0.0), gx = float3(0.0), gy = float3(0.0);
            for (int k = 0; k < 16; k++) {
                float2 q = float2(float(k & 3), float(k >> 2));
                float3 v = smp13(src, bo + (q + 0.5) * bs * 0.25);
                m += v;
                gx += v * (q.x - 1.5);
                gy += v * (q.y - 1.5);
            }
            m /= 16.0; gx /= 20.0; gy /= 20.0;
            float2 lp = (c - bo) / bs * 4.0 - 2.0;
            float3 approx = m + gx * lp.x + gy * lp.y;
            float qs = mix(0.6, 0.02, clamp(p.a.x, 0.0, 1.0));
            float3 det = col - approx;
            float3 qd = round(det / qs) * qs;
            float3 x = approx + qd;
            float ring = cos(lp.x * 3.1416) * cos(lp.y * 3.1416) * length(det) * (1.0 - p.a.x) * 0.5;
            x += ring;
            float y = l13(x);
            float3 chroma = m - l13(m);
            x = mix(x, float3(y) + chroma, 1.0 - p.a.x);
            r = clamp(x, 0.0, 1.0);
            break;
        }
        case 11: { // bit crush: a.x bits (1-8), a.y dither (0-1)
            float lv = exp2(floor(clamp(p.a.x, 1.0, 8.0))) - 1.0;
            float d = (bayer13(c) - 0.5) * p.a.y;
            r = clamp(floor(col * lv + 0.5 + d) / lv, 0.0, 1.0);
            break;
        }
        case 12: { // LED screen: a.x cell px, a.y dot size (0-1), a.z brightness
            float cs = max(p.a.x, 2.0);
            float2 ctr = (floor(c / cs) + 0.5) * cs;
            float4 cc = float4(src.sample(s13Edge, ctr));
            float3 v = u13(cc);
            float rad = p.a.y * 0.5 * cs;
            float dd = length(c - ctr);
            float mk = 1.0 - smoothstep(rad - 0.75, rad + 0.75, dd);
            float halo = exp(-dd * dd / max(cs * cs * 0.18, 0.1)) * 0.25;
            r = clamp(v * (mk + halo) * p.a.z + float3(0.02) * (1.0 - mk), 0.0, 1.0);
            break;
        }
        case 13: { // LCD subpixels: a.x pixel px, a.y gap (0-1), a.z brightness
            float ps = max(p.a.x, 3.0);
            float2 cell = floor(c / ps);
            float2 ctr = (cell + 0.5) * ps;
            float3 v = smp13(src, ctr);
            float2 f = (c - cell * ps) / ps;
            float sub = floor(f.x * 3.0);
            float3 mask = sub < 0.5 ? float3(1.0, 0.0, 0.0) : (sub < 1.5 ? float3(0.0, 1.0, 0.0) : float3(0.0, 0.0, 1.0));
            float fx = fract(f.x * 3.0);
            float g = p.a.y * 0.5;
            float on = step(g * 0.5, fx) * step(fx, 1.0 - g * 0.5) * step(g * 0.5, f.y) * step(f.y, 1.0 - g * 0.5);
            r = clamp(v * mask * on * p.a.z * 2.2 + v * 0.05, 0.0, 1.0);
            break;
        }
        case 14: { // hologram scan: a.x intensity, a.y line count, a.z speed, a.w flicker; b = tint
            float3 sh = float3(smp13(src, c + float2(2.0, 0.0)).r, col.g, smp13(src, c - float2(2.0, 0.0)).b);
            float y = l13(sh);
            float3 holo = p.b.rgb * (0.25 + 1.1 * y) + float3(0.0, 0.1, 0.15) * y;
            float ln = 0.5 + 0.5 * sin((c.y / size.y * p.a.y - t * p.a.z) * 6.2832);
            holo *= 0.6 + 0.6 * ln;
            float band = smoothstep(0.92, 1.0, fract(c.y / size.y - t * p.a.z * 0.15));
            holo += p.b.rgb * band * 0.6;
            holo *= 1.0 - p.a.w * (0.4 + 0.6 * h13(float2(floor(t * 30.0), 3.0)));
            r = clamp(mix(col, holo, p.a.x), 0.0, 1.0);
            break;
        }
        case 15: { // analog TV: a.x noise, a.y roll speed, a.z chroma bleed px
            float yo = fract(t * p.a.y) * size.y;
            float yy = c.y + yo;
            yy = yy - floor(yy / size.y) * size.y;
            float2 q = float2(c.x, yy);
            float3 base = smp13(src, q);
            float Y = l13(base);
            float3 ch = float3(0.0);
            for (int k = 0; k < 6; k++) ch += smp13(src, q - float2(p.a.z * float(k) / 5.0, 0.0));
            ch /= 6.0;
            float3 x = clamp(float3(Y) + (ch - l13(ch)) * 1.2, 0.0, 1.0);
            float bar = smoothstep(0.0, 0.08, abs(fract(yy / size.y + 0.5) - 0.5) - 0.02);
            x *= 0.75 + 0.25 * bar;
            float fr = floor(t * 30.0);
            float n = h13(floor(c) + float2(fr * 13.7, fr * 3.1));
            x = mix(x, float3(n), p.a.x * 0.6);
            x *= 0.92 + 0.08 * sin(c.y * 3.1416);
            r = clamp(x, 0.0, 1.0);
            break;
        }
        case 16: { // teletext mosaic: a.x cell width px, a.y threshold (0-1)
            float cw = max(p.a.x, 2.0);
            float2 cs = float2(cw, cw * 1.5);
            float2 cell = floor(c / cs);
            float2 f = (c - cell * cs) / cs;
            float2 sub = floor(f * float2(2.0, 3.0));
            float2 ctr = cell * cs + (sub + 0.5) * cs / float2(2.0, 3.0);
            float3 v = smp13(src, ctr);
            float3 x = step(float3(p.a.y), v);
            float2 sf = fract(f * float2(2.0, 3.0));
            float gap = step(0.08, sf.x) * step(sf.x, 0.92) * step(0.08, sf.y) * step(sf.y, 0.92);
            r = x * gap;
            break;
        }
        case 17: { // thermal printer: a.x dot px, a.y darkness, a.z fade streaks; b = paper, c = ink
            float ds = max(p.a.x, 1.0);
            float2 cc = (floor(c / ds) + 0.5) * ds;
            float y = l13(smp13(src, cc));
            y = clamp((y - 0.5) * (1.0 + p.a.y) + 0.5 - p.a.y * 0.15, 0.0, 1.0);
            float ink = step(y, bayer13(c / ds));
            float row = floor(c.y / ds);
            float fade = 1.0 - p.a.z * (0.25 + 0.75 * vn13(float2(row * 0.15, 2.0))) * 0.8;
            float3 paper = p.b.rgb * (0.96 + 0.04 * h13(floor(c * 0.5)));
            r = mix(paper, p.c.rgb, ink * fade);
            break;
        }
        case 18: { // risograph: a.x dot px, a.y misregistration px, a.z grain; b = ink 1, c = ink 2
            float ds = max(p.a.x, 2.0);
            float2 o1 = float2(p.a.y, p.a.y * 0.4);
            float3 v1 = smp13(src, c - o1);
            float3 v2 = smp13(src, c + o1);
            float d1 = clamp(1.0 - v1.g * 1.15, 0.0, 1.0) * 0.95;
            float d2 = clamp(1.0 - (v2.r * 0.6 + v2.g * 0.4) * 1.1, 0.0, 1.0) * 0.95;
            float g = (h13(floor(c)) - 0.5) * p.a.z;
            float m1 = dot13(c, 0.26, ds, d1 + g * 0.3);
            float m2 = dot13(c, 1.31, ds, d2 - g * 0.3);
            float3 paper = float3(0.96, 0.94, 0.9) - g * 0.06;
            float3 x = paper * (1.0 - m1 * (1.0 - p.b.rgb)) * (1.0 - m2 * (1.0 - p.c.rgb));
            r = clamp(x, 0.0, 1.0);
            break;
        }
        case 19: { // screen print: a.x balance (-0.5..0.5), a.y texture, a.z offset px; b,c,d.yzw = inks
            float yA = l13(smp13(src, c - float2(p.a.z, p.a.z * 0.5)));
            float yB = l13(col);
            float t1 = 0.3 + p.a.x * 0.5, t2 = 0.62 + p.a.x * 0.5;
            float3 x = float3(p.d.y, p.d.z, p.d.w);
            if (yB < t2) x = p.c.rgb;
            float tex = vn13(c * 0.35) * 0.6 + h13(floor(c)) * 0.4;
            bool drop = tex < p.a.y * 0.45;
            if (yA < t1 && !drop) x = p.b.rgb;
            if (drop && yB < t2) x = mix(x, float3(p.d.y, p.d.z, p.d.w), 0.6);
            r = x;
            break;
        }
        case 20: { // neon sign: a.x threshold, a.y glow radius px, a.z flicker, a.w desaturate; b = glow color
            float y = l13(col);
            float glow = 0.0;
            float rad = max(p.a.y, 0.5);
            for (int k = 0; k < 16; k++) {
                float ang = float(k) * 0.3927 + 0.2;
                float rr = rad * (0.35 + 0.65 * float((k % 3) + 1) / 3.0);
                glow += smoothstep(p.a.x, p.a.x + 0.15, l13(smp13(src, c + float2(cos(ang), sin(ang)) * rr)));
            }
            glow /= 16.0;
            float fk = 1.0 - p.a.z * (0.3 + 0.7 * h13(float2(floor(t * 15.0), 9.0)));
            float3 base = sat13(col, 1.0 - p.a.w) * (1.0 - 0.5 * p.a.w);
            float tube = smoothstep(p.a.x, p.a.x + 0.15, y);
            float3 x = mix(base, mix(p.b.rgb, float3(1.0), 0.45) * fk, tube * fk);
            x += p.b.rgb * glow * 1.4 * fk;
            r = clamp(x, 0.0, 1.0);
            break;
        }
        case 21: { // cyberpunk grade: a.x strength, a.y pivot, a.z saturation
            float y = l13(col);
            float w = smoothstep(p.a.y - 0.3, p.a.y + 0.3, y);
            float3 tealC = float3(0.0, 0.55, 0.65), magC = float3(1.0, 0.2, 0.75);
            float3 x = mix(col * (0.6 + tealC * 0.9), col * (0.6 + magC * 0.7) + magC * 0.08, w);
            x = sat13(scurve13(x, 0.4), p.a.z);
            r = clamp(mix(col, x, p.a.x), 0.0, 1.0);
            break;
        }
        case 22: { // lomo: a.x strength, a.y vignette, a.z saturation
            float3 x = float3(scurve13(float3(col.r), 0.9).r, scurve13(float3(col.g), 0.7).r, col.b * 0.7 + 0.12);
            x = sat13(x, p.a.z);
            float v = clamp(vig13(c, size) * p.a.y * 1.8, 0.0, 1.0);
            x = sat13(x * (1.0 - v), 1.0 + v * 0.5);
            r = clamp(mix(col, x, p.a.x), 0.0, 1.0);
            break;
        }
        case 23: { // day for night: a.x darkness, a.y blue tint, a.z desaturate; b = moon color
            float y = l13(col);
            float3 x = sat13(col, 1.0 - p.a.z);
            x *= 1.0 - p.a.x * 0.8;
            x = mix(x, x * float3(0.55, 0.75, 1.35) + float3(0.0, 0.01, 0.04), p.a.y);
            x += p.b.rgb * smoothstep(0.7, 1.0, y) * 0.25 * p.a.x;
            r = clamp(x, 0.0, 1.0);
            break;
        }
        default: break;
    }
    float4 o = float4(clamp(r, 0.0, 1.0) * alpha, alpha);
    dst.write(half4(o), gid);
}
