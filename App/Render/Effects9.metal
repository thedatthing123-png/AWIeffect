#include <metal_stdlib>
using namespace metal;

// Batch 9: transitions & wipes. Every mode reads Completion (0-1) in p.a.x:
// 0 = layer fully visible, 1 = layer fully hidden. Time in p.d.x.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s9Zero(address::clamp_to_zero, filter::linear, coord::pixel);

static inline float3 u9(float4 c) { return c.a > 1e-6 ? c.rgb / c.a : float3(0.0); }
static inline float l9(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static inline float fmod9(float x, float y) { return x - y * floor(x / y); }
static float h9(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float h93(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static float n9(float3 x) {
    float3 i = floor(x), f = fract(x); float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(h93(i), h93(i + float3(1, 0, 0)), u.x), mix(h93(i + float3(0, 1, 0)), h93(i + float3(1, 1, 0)), u.x), u.y),
               mix(mix(h93(i + float3(0, 0, 1)), h93(i + float3(1, 0, 1)), u.x), mix(h93(i + float3(0, 1, 1)), h93(i + float3(1, 1, 1)), u.x), u.y), u.z);
}
static float fbm9(float2 x, float z) {
    float s = 0.0, a = 0.5;
    float3 q = float3(x, z);
    for (int k = 0; k < 4; k++) { s += n9(q) * a; q = q * 2.03 + float3(1.7, 9.2, 0.0); a *= 0.5; }
    return s / 0.9375;
}
// Visibility of a normalized coordinate x (0..1): hidden where x is below the moving threshold.
static inline float prog9(float x, float comp, float fe) {
    fe = max(fe, 1e-4);
    float thr = mix(-fe, 1.0 + fe, comp);
    return smoothstep(thr - fe, thr + fe, x);
}
static inline float2 rot9(float2 v, float a) { float c = cos(a), s = sin(a); return float2(v.x * c - v.y * s, v.x * s + v.y * c); }
// Largest distance from the center to a frame corner.
static inline float rmax9(float2 ctr, float2 size) {
    return max(max(length(ctr), length(ctr - float2(size.x, 0.0))), max(length(ctr - float2(0.0, size.y)), length(ctr - size)));
}
static float sdHeart9(float2 p) {
    p.x = abs(p.x);
    if (p.y + p.x > 1.0) { float2 d = p - float2(0.25, 0.75); return sqrt(dot(d, d)) - 0.35355339; }
    float2 a = p - float2(0.0, 1.0);
    float2 b = p - 0.5 * max(p.x + p.y, 0.0);
    return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
}
static float sdStar9(float2 p, float r, int n, float m) {
    float an = 3.14159265 / float(n);
    float en = 3.14159265 / m;
    float2 acs = float2(cos(an), sin(an));
    float2 ecs = float2(cos(en), sin(en));
    float bn = fmod9(atan2(p.x, p.y), 2.0 * an) - an;
    p = length(p) * float2(cos(bn), abs(sin(bn)));
    p -= r * acs;
    p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
    return length(p) * sign(p.x);
}
static inline float gauge9(float2 q, int shape) {
    float2 a = abs(q);
    if (shape == 1) return max(a.x, a.y);
    if (shape == 2) return max(a.x * 0.8660254 + a.y * 0.5, a.y);
    if (shape == 3) return a.x + a.y;
    return length(q);
}

kernel void fxTrans9(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     texture2d<half, access::sample> aux [[texture(2)]],
                     constant EffectParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s9Zero, c));
    float4 o = s;
    float t = p.d.x;
    float comp = clamp(p.a.x, 0.0, 1.0);
    float2 ctr = p.c.zw;
    switch (p.i.x) {
        case 0: { // clock wipe: a = (comp, feather px, start rad, direction ±1), c.zw = center
            float2 q = c - ctr;
            float r = max(length(q), 1.0);
            float fr = fract((atan2(q.x, -q.y) - p.a.z) * p.a.w / 6.2831853);
            o = s * prog9(fr, comp, max(p.a.y, 0.5) / (r * 6.2831853));
            break;
        }
        case 1: { // barn doors (opening from the middle): a = (comp, feather px, vertical)
            float half_ = p.a.z > 0.5 ? size.y * 0.5 : size.x * 0.5;
            float x = (p.a.z > 0.5 ? abs(c.y - size.y * 0.5) : abs(c.x - size.x * 0.5)) / max(half_, 1.0);
            o = s * prog9(x, comp, max(p.a.y, 0.5) / max(half_, 1.0));
            break;
        }
        case 2: { // diagonal wipe: a = (comp, feather px, angle rad)
            float2 dir = float2(cos(p.a.z), sin(p.a.z));
            float ext = max(0.5 * (abs(dir.x) * size.x + abs(dir.y) * size.y), 1.0);
            float x = (dot(c - size * 0.5, dir) + ext) / (2.0 * ext);
            o = s * prog9(x, comp, max(p.a.y, 0.5) / (2.0 * ext));
            break;
        }
        case 3: { // diamond wipe (hole grows from center): a = (comp, feather px), c.zw = center
            float2 q = c - ctr;
            float lmax = 1.0;
            lmax = max(lmax, abs(ctr.x) + abs(ctr.y));
            lmax = max(lmax, abs(size.x - ctr.x) + abs(ctr.y));
            lmax = max(lmax, abs(ctr.x) + abs(size.y - ctr.y));
            lmax = max(lmax, abs(size.x - ctr.x) + abs(size.y - ctr.y));
            o = s * prog9((abs(q.x) + abs(q.y)) / lmax, comp, max(p.a.y, 0.5) / lmax);
            break;
        }
        case 4:   // heart wipe (heart iris closes): a = (comp, feather px, rotation rad), c.zw = center
        case 5: { // star wipe: a = (comp, feather px, rotation rad, points), b.x = inner sharpness
            float f = max(p.a.y, 0.5);
            float R = rmax9(ctr, size);
            float2 q = rot9(c - ctr, -p.a.z);
            q.y = -q.y;
            float S, sd;
            if (p.i.x == 4u) {
                S = max((1.0 - comp) * 3.2 * (R + f), 1e-3);
                sd = sdHeart9(q / S + float2(0.0, 0.45));
            } else {
                int n = clamp(int(round(p.a.w)), 3, 24);
                float m = clamp(p.b.x, 2.0, float(n));
                S = max((1.0 - comp) * 3.0 * (R + f), 1e-3);
                sd = sdStar9(q / S, 1.0, n, m);
            }
            float vis = smoothstep(-f, f, -sd * S) * (1.0 - step(0.9995, comp));
            o = s * vis;
            break;
        }
        case 6: { // shape iris (closes): a = (comp, feather px, rotation rad, shape), c.zw = center
            int shape = int(p.a.w + 0.5);
            float dmax = 1.0;
            float2 corners[4] = { float2(0.0), float2(size.x, 0.0), float2(0.0, size.y), size };
            for (int k = 0; k < 4; k++) dmax = max(dmax, gauge9(rot9(corners[k] - ctr, -p.a.z), shape));
            float g = gauge9(rot9(c - ctr, -p.a.z), shape);
            o = s * prog9(1.0 - g / dmax, comp, max(p.a.y, 0.5) / dmax);
            break;
        }
        case 7: { // pixel dissolve: a = (comp, block px, seed)
            float2 cell = floor(c / max(p.a.y, 1.0));
            float h = h9(cell + float2(p.a.z * 17.13, p.a.z * 3.71));
            o = (comp < 1.0 && h >= comp) ? s : float4(0.0);
            break;
        }
        case 8:   // noise dissolve: a = (comp, scale px, edge width, glow), b = edge color
        case 9: { // burn away: a = (comp, scale px, burn width, ember), b = ember color, c.x = upward spread
            float nn = saturate((fbm9(c / max(p.a.y, 1.0), 3.7) - 0.2) / 0.6);
            float w = max(p.a.z, 1e-3);
            if (p.i.x == 8u) {
                float e = nn - mix(-w, 1.0, comp);
                float vis = smoothstep(0.0, 0.01, e);
                float glow = (1.0 - smoothstep(0.0, w, e)) * vis;
                o = float4((s.rgb + p.b.rgb * glow * p.a.w * s.a) * vis, s.a * vis);
            } else {
                float field = mix(nn, 1.0 - c.y / size.y, clamp(p.c.x, 0.0, 1.0));
                float e = field - mix(-2.0 * w, 1.0, comp);
                float vis = smoothstep(0.0, 0.008, e);
                float ember = 1.0 - smoothstep(0.0, w * 0.6, e);
                float charr = 1.0 - smoothstep(w * 0.6, 2.0 * w, e);
                float flick = 0.75 + 0.25 * n9(float3(c * 0.08, t * 6.0));
                float3 rgb = s.rgb * mix(1.0, 0.15, charr * 0.85) + p.b.rgb * ember * p.a.w * flick * s.a;
                o = float4(rgb * vis, s.a * vis);
            }
            break;
        }
        case 10: { // ink bleed: a = (comp, roughness, scale px, feather px), b = ink color, c.zw = center
            float R = rmax9(ctr, size);
            float rough = max(p.a.y, 0.0);
            float nz = fbm9(c / max(p.a.z, 1.0), 1.3) - 0.5;
            float field = length(c - ctr) / R + nz * rough;
            float x = (field + rough * 0.5) / (1.0 + rough);
            float m = prog9(x, comp, max(p.a.w, 0.5) / (R * (1.0 + rough)));
            float band = clamp(4.0 * m * (1.0 - m), 0.0, 1.0);
            o = float4(mix(s.rgb, p.b.rgb * s.a, band) * m, s.a * m);
            break;
        }
        case 11: { // slide push: a = (comp, angle rad, motion blur px)
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            float ext = abs(dir.x) * size.x + abs(dir.y) * size.y;
            float2 off = dir * comp * ext;
            float bl = p.a.z * sin(3.14159265 * comp);
            float4 acc = float4(0.0);
            const int N = 16;
            for (int k = 0; k < N; k++) {
                float fk = float(k) / float(N - 1) - 0.5;
                acc += float4(src.sample(s9Zero, c - off - dir * bl * fk));
            }
            o = acc / float(N);
            break;
        }
        case 12: { // zoom through: a = (comp, zoom amount, fade start, blur), c.zw = center
            float sc = 1.0 + comp * comp * max(p.a.y, 0.0);
            float4 acc = float4(0.0);
            const int N = 12;
            for (int k = 0; k < N; k++) {
                float fk = float(k) / float(N - 1);
                float sk = sc * (1.0 + p.a.w * comp * 0.5 * fk);
                acc += float4(src.sample(s9Zero, ctr + (c - ctr) / sk));
            }
            float fs = clamp(p.a.z, 0.0, 0.95);
            o = acc / float(N) * (1.0 - smoothstep(fs, 1.0, comp));
            break;
        }
        case 13: { // spin twist: a = (comp, twist rad, feather px), c.zw = center
            float R = rmax9(ctr, size);
            float2 q = c - ctr;
            float r = length(q);
            float fall = 1.0 - saturate(r / R);
            float ang = comp * p.a.y * fall * fall;
            float4 tw = float4(src.sample(s9Zero, ctr + rot9(q, ang)));
            o = tw * prog9(r / R, comp, max(p.a.z, 0.5) / R);
            break;
        }
        case 14: { // glitch reveal: a = (comp, band px, displacement px, rgb split px), c.x = seed
            float frame = floor(t * 12.0);
            float band = floor(c.y / max(p.a.y, 1.0));
            float hb = h9(float2(band, p.c.x * 7.7 + 1.0));
            float vis = (comp < 1.0 && hb >= comp) ? 1.0 : 0.0;
            float k = sin(3.14159265 * comp);
            float jit = (h9(float2(band * 1.37, frame + p.c.x * 3.1)) - 0.5) * 2.0 * p.a.z * k;
            float sp = p.a.w * k;
            float4 cg = float4(src.sample(s9Zero, c + float2(jit, 0.0)));
            float4 cr = float4(src.sample(s9Zero, c + float2(jit + sp, 0.0)));
            float4 cb = float4(src.sample(s9Zero, c + float2(jit - sp, 0.0)));
            o = float4(cr.r, cg.g, cb.b, max(cg.a, max(cr.a, cb.a))) * vis;
            break;
        }
        case 15: { // stripes wipe: a = (comp, count, feather 0-0.5, stagger), b.x = angle rad
            float2 dir = float2(cos(p.b.x), sin(p.b.x));
            float2 perp = float2(-dir.y, dir.x);
            float2 q = c - size * 0.5;
            float extD = max(0.5 * (abs(dir.x) * size.x + abs(dir.y) * size.y), 1.0);
            float extP = max(0.5 * (abs(perp.x) * size.x + abs(perp.y) * size.y), 1.0);
            float u = (dot(q, dir) + extD) / (2.0 * extD);
            float v = saturate((dot(q, perp) + extP) / (2.0 * extP));
            float local = fract(u * floor(max(p.a.y, 1.0)));
            float stg = max(p.a.w, 0.0);
            float cc = clamp(comp * (1.0 + stg) - stg * v, 0.0, 1.0);
            o = s * prog9(local, cc, p.a.z);
            break;
        }
        case 16: { // checker wipe: a = (comp, cell px, feather 0-0.5)
            float cs = max(p.a.y, 2.0);
            float2 cell = floor(c / cs);
            float par = fmod9(cell.x + cell.y, 2.0);
            float cc = clamp(par < 0.5 ? comp * 1.6 : comp * 1.6 - 0.6, 0.0, 1.0);
            o = s * prog9(fract(c.x / cs), cc, p.a.z);
            break;
        }
        case 17: { // radial blinds: a = (comp, count, feather 0-0.5, rotation rad), c.zw = center
            float2 q = c - ctr;
            float a01 = fract((atan2(q.y, q.x) - p.a.w) / 6.2831853);
            o = s * prog9(fract(a01 * floor(max(p.a.y, 1.0))), comp, p.a.z);
            break;
        }
        case 18: { // blocks flip: a = (comp, block px, stagger 0-0.9, order)
            float bs = max(p.a.y, 2.0);
            float2 cell = floor(c / bs);
            float2 cc = (cell + 0.5) * bs;
            int order = int(p.a.w + 0.5);
            float delay = order == 1 ? saturate((cc.x / size.x + cc.y / size.y) * 0.5)
                        : order == 2 ? saturate(length(cc - size * 0.5) / max(length(size) * 0.5, 1.0))
                        : h9(cell + 3.7);
            float stg = clamp(p.a.z, 0.0, 0.9);
            float pb = saturate((comp - delay * stg) / max(1.0 - stg, 0.05));
            float sx = cos(pb * 1.5707963);
            float sy = 1.0 - pb * 0.25;
            float2 lc = c - cc;
            if (pb >= 0.999 || abs(lc.x) > sx * bs * 0.5 || abs(lc.y) > sy * bs * 0.5) { o = float4(0.0); break; }
            float4 q = float4(src.sample(s9Zero, cc + lc / float2(max(sx, 1e-3), sy)));
            o = float4(q.rgb * mix(0.55, 1.0, sx), q.a);
            break;
        }
        case 19: { // ripple dissolve: a = (comp, wavelength px, amplitude px, feather px), c.zw = center
            float R = rmax9(ctr, size);
            float2 q = c - ctr;
            float r = length(q);
            float wv = max(p.a.y, 1.0), amp = max(p.a.z, 0.0), f = max(p.a.w, 0.5);
            float wave = sin(r / wv * 6.2831853 - t * 6.0);
            float d = r + wave * amp * 0.5 - mix(-f - amp, R + f + amp, comp);
            float2 rd = r > 1e-3 ? q / r : float2(0.0);
            float2 disp = rd * wave * amp * 0.3 * (1.0 - saturate(abs(d) / (4.0 * wv)));
            o = float4(src.sample(s9Zero, c + disp)) * smoothstep(-f, f, d);
            break;
        }
        case 20: { // directional blur wipe: a = (comp, angle rad, blur px, edge width px)
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            float ext = 0.5 * (abs(dir.x) * size.x + abs(dir.y) * size.y);
            float ew = max(p.a.w, 1.0);
            float d = dot(c - size * 0.5, dir) - mix(-ext - ew, ext + ew, comp);
            float bl = p.a.z * exp(-(d / ew) * (d / ew));
            float4 acc = float4(0.0);
            const int N = 16;
            for (int k = 0; k < N; k++) {
                float fk = float(k) / float(N - 1) - 0.5;
                acc += float4(src.sample(s9Zero, c + dir * bl * fk));
            }
            o = acc / float(N) * smoothstep(-ew * 0.5, ew * 0.5, d);
            break;
        }
        case 21: { // luma fade: a = (comp, softness, bright first)
            float lum = saturate(l9(u9(s)));
            float x = p.a.z > 0.5 ? 1.0 - lum : lum;
            o = s * prog9(x, comp, p.a.y);
            break;
        }
        case 22: { // gradient sweep wipe: a = (comp, angle rad, light width px, intensity), b = color, c.x = softness px
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            float ext = 0.5 * (abs(dir.x) * size.x + abs(dir.y) * size.y);
            float sf = max(p.c.x, 0.5), w = max(p.a.z, 0.5);
            float d = dot(c - size * 0.5, dir) - mix(-ext - sf - w, ext + sf + w, comp);
            float m = smoothstep(-sf, sf, d);
            float glow = exp(-(d / w) * (d / w)) * p.a.w;
            o = float4(s.rgb * m + p.b.rgb * glow * s.a, s.a * m);
            break;
        }
        case 23: { // split reveal: a = (comp, angle rad, edge glow px), b = glow color
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            float ext = 0.5 * (abs(dir.x) * size.x + abs(dir.y) * size.y);
            float pos = dot(c - size * 0.5, dir);
            float sd = pos >= 0.0 ? 1.0 : -1.0;
            float off = comp * (ext + 1.0);
            float spos = pos - sd * off;
            if (spos * sd < 0.0) { o = float4(0.0); break; }
            float4 q = float4(src.sample(s9Zero, c - dir * sd * off));
            float glow = exp(-abs(spos) / max(p.a.z, 0.5)) * sin(3.14159265 * comp);
            o = float4(q.rgb + p.b.rgb * glow * q.a, q.a);
            break;
        }
        case 24: { // liquid wipe: a = (comp, angle rad, amplitude px, wavelength px), b = (speed, feather px)
            float2 dir = float2(cos(p.a.y), sin(p.a.y));
            float2 perp = float2(-dir.y, dir.x);
            float2 q = c - size * 0.5;
            float ext = 0.5 * (abs(dir.x) * size.x + abs(dir.y) * size.y);
            float amp = max(p.a.z, 0.0), wv = max(p.a.w, 1.0), f = max(p.b.y, 0.5);
            float v = dot(q, perp);
            float wave = sin(v / wv * 6.2831853 + t * p.b.x) * amp + 0.5 * amp * sin(v / wv * 2.7 - t * p.b.x * 1.3);
            float d = dot(q, dir) + wave - mix(-ext - 1.5 * amp - f, ext + 1.5 * amp + f, comp);
            o = s * smoothstep(-f, f, d);
            break;
        }
        default: break;
    }
    dst.write(half4(clamp(o, float4(0.0), float4(64.0))), gid);
}
