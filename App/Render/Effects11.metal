#include <metal_stdlib>
using namespace metal;

// Batch 11: repeaters (grid, line, radial, scatter, mirror tile, zoom tunnel, echo offset), opacity tools
// (blink, pulse, dissolve, feather, vignette alpha, linear fade, flicker) and matte/key tools
// (advanced chroma key, spill cleaner, choker, unmultiply, color range, luma matte, alpha levels, edge refine,
// remove color matting). rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s11Zero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler s11Edge(address::clamp_to_edge, filter::linear, coord::pixel);

static inline float3 u11(float4 c) { return c.a > 1e-6 ? c.rgb / c.a : float3(0.0); }
static inline float l11(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float h11(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static inline float2 rot11(float2 v, float a) { float c = cos(a), s = sin(a); return float2(v.x * c - v.y * s, v.x * s + v.y * c); }
static inline float4 over11(float4 top, float4 bottom) { return top + bottom * (1.0 - top.a); }
static inline float3 ycc11(float3 c) {
    float y = l11(c);
    return float3(y, (c.b - y) * 0.5389, (c.r - y) * 0.635);
}
static inline float3 rgb11(float3 q) {
    float r = q.x + q.z / 0.635;
    float b = q.x + q.y / 0.5389;
    float g = (q.x - 0.2126 * r - 0.0722 * b) / 0.7152;
    return float3(r, g, b);
}
static float3 hsv11(float3 c) {
    float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
    float d = mx - mn;
    float h = 0.0;
    if (d > 1e-5) {
        if (mx == c.r) h = (c.g - c.b) / d;
        else if (mx == c.g) h = 2.0 + (c.b - c.r) / d;
        else h = 4.0 + (c.r - c.g) / d;
        h *= 60.0;
        if (h < 0.0) h += 360.0;
    }
    return float3(h, mx > 1e-5 ? d / mx : 0.0, mx);
}

kernel void fxRepeat11(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       texture2d<half, access::sample> aux [[texture(2)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float2 ctr = size * 0.5;
    float4 s = float4(src.sample(s11Zero, c));
    float4 o = s;
    float t = p.d.x;
    switch (p.i.x) {
        case 0: { // repeat grid: a = (cols, rows, spacing 0-0.9, row offset 0-1)
            float2 g = float2(max(floor(p.a.x), 1.0), max(floor(p.a.y), 1.0));
            float2 u = c / size * g;
            float row = floor(u.y);
            u.x += p.a.w * (row - 2.0 * floor(row * 0.5));
            float2 f = fract(u);
            f = (f - 0.5) / max(1.0 - p.a.z, 0.05) + 0.5;
            if (f.x < 0.0 || f.y < 0.0 || f.x > 1.0 || f.y > 1.0) o = float4(0.0);
            else o = float4(src.sample(s11Zero, f * size));
            break;
        }
        case 1: { // repeat line: a = (count, spacing px, scale falloff, opacity falloff), b = (dir x, dir y, rot per copy, 0)
            int n = clamp(int(p.a.x), 1, 12);
            float4 acc = float4(0.0);
            for (int k = 0; k < 12; k++) {
                if (k >= n) break;
                float fk = float(k);
                float sc = max(pow(max(1.0 - p.a.z, 0.01), fk), 1e-3);
                float2 q = ctr + rot11(c - ctr - p.b.xy * p.a.y * fk, -p.b.z * fk) / sc;
                float4 col = float4(src.sample(s11Zero, q)) * pow(max(1.0 - p.a.w, 0.0), fk);
                acc = over11(col, acc);
            }
            o = acc;
            break;
        }
        case 2: { // repeat radial: a = (count, radius px, copy scale, phase rad), b.x = rotate copies
            int n = clamp(int(p.a.x), 1, 24);
            float sc = max(p.a.z, 0.02);
            float4 acc = s;
            for (int k = 0; k < 24; k++) {
                if (k >= n) break;
                float ang = p.a.w + 6.2831853 * float(k) / float(n);
                float2 local = c - (ctr + float2(cos(ang), sin(ang)) * p.a.y);
                if (p.b.x > 0.5) local = rot11(local, -ang);
                float4 col = float4(src.sample(s11Zero, ctr + local / sc));
                acc = over11(col, acc);
            }
            o = acc;
            break;
        }
        case 3: { // scatter field: a = (count, spread px, scale, seed), b.x = rotation randomness rad
            int n = clamp(int(p.a.x), 1, 48);
            float4 acc = s;
            for (int k = 0; k < 48; k++) {
                if (k >= n) break;
                float fk = float(k);
                float2 r = float2(h11(float2(fk * 1.37, p.a.w * 3.1 + 0.5)), h11(float2(fk * 2.11 + 7.0, p.a.w * 1.7 + 2.0)));
                float rs = h11(float2(fk + 11.0, p.a.w + 5.3));
                float ra = h11(float2(fk * 0.73 + 3.0, p.a.w * 2.9 + 9.1));
                float2 pos = ctr + (r * 2.0 - 1.0) * p.a.y;
                float sc = max(p.a.z * (0.6 + 0.8 * rs), 0.02);
                float2 local = rot11(c - pos, -(ra - 0.5) * 2.0 * p.b.x);
                float4 col = float4(src.sample(s11Zero, ctr + local / sc));
                acc = over11(col, acc);
            }
            o = acc;
            break;
        }
        case 4: { // mirror tile 4-way: a = (tiles, offset x, offset y, 0) offsets in tiles
            float n = max(floor(p.a.x), 1.0);
            float2 u = c / size * n + p.a.yz;
            float2 m = u - 2.0 * floor(u * 0.5);
            m = 1.0 - abs(m - 1.0);
            o = float4(src.sample(s11Edge, clamp(m, 0.0, 1.0) * size));
            break;
        }
        case 5: { // infinite zoom tunnel: a = (copies, scale step, speed, 0)
            int n = clamp(int(p.a.x), 1, 16);
            float st = clamp(p.a.y, 0.05, 0.98);
            float ph = fract(t * p.a.z);
            float4 acc = float4(0.0);
            for (int k = 0; k < 16; k++) {
                if (k >= n) break;
                float sc = max(pow(st, float(k) - ph), 1e-3);
                float4 col = float4(src.sample(s11Zero, ctr + (c - ctr) / sc));
                acc = over11(col, acc);
            }
            o = acc;
            break;
        }
        case 6: { // echo offset: a = (copies, distance px, fade, 0), b.xy = direction
            int n = clamp(int(p.a.x), 1, 16);
            float4 acc = s;
            for (int j = 0; j < 16; j++) {
                if (j >= n) break;
                float k = float(n - j);
                float4 col = float4(src.sample(s11Zero, c - p.b.xy * p.a.y * k)) * 0.7 * pow(max(1.0 - p.a.z, 0.0), k - 1.0);
                acc = over11(col, acc);
            }
            o = acc;
            break;
        }
        case 7: { // blink: a = (rate Hz, duty, min opacity, 0)
            float ph = fract(t * max(p.a.x, 0.0));
            float op = ph < p.a.y ? 1.0 : p.a.z;
            o = s * op;
            break;
        }
        case 8: { // pulse opacity: a = (speed Hz, min, max, phase rad)
            float w = 0.5 + 0.5 * cos(6.2831853 * t * p.a.x + p.a.w);
            o = s * clamp(mix(p.a.y, p.a.z, w), 0.0, 1.0);
            break;
        }
        case 9: { // random dissolve: a = (amount, grain px, seed, animate)
            float2 cell = floor(c / max(p.a.y, 1.0));
            float fr = p.a.w > 0.5 ? floor(t * 24.0) : 0.0;
            float r = h11(cell + float2(p.a.z * 17.3 + fr * 7.1, p.a.z * 5.9 - fr * 3.3));
            o = r >= p.a.x ? s : float4(0.0);
            break;
        }
        case 10: { // feather combine: aux = blurred input
            float b = float4(aux.sample(s11Zero, c)).a;
            o = s * clamp(2.0 * b - 1.0, 0.0, 1.0);
            break;
        }
        case 11: { // vignette alpha: a = (cx, cy, radius, softness)
            float d = length(c - p.a.xy) / max(0.5 * length(size), 1.0);
            float m = 1.0 - smoothstep(p.a.z - max(p.a.w, 1e-3), p.a.z, d);
            o = s * m;
            break;
        }
        case 12: { // advanced chroma key: b = key, a = (tolerance, softness, spill, 0)
            float3 un = u11(s);
            float3 kc = ycc11(p.b.rgb), pc = ycc11(un);
            float d = length(pc.yz - kc.yz);
            float m = smoothstep(p.a.x, p.a.x + max(p.a.y, 1e-3), d);
            float kl = length(kc.yz);
            if (kl > 1e-4) {
                float2 kd = kc.yz / kl;
                float amt = max(dot(pc.yz, kd), 0.0);
                pc.yz -= kd * amt * p.a.z;
            }
            float3 col = clamp(rgb11(pc), 0.0, 1.0);
            float na = s.a * m;
            o = float4(col * na, na);
            break;
        }
        case 13: { // spill cleaner: b = key, a = (amount, luma compensation, 0, 0)
            float3 un = u11(s);
            float3 kc = ycc11(p.b.rgb), pc = ycc11(un);
            float kl = length(kc.yz);
            if (kl > 1e-4) {
                float2 kd = kc.yz / kl;
                float amt = max(dot(pc.yz, kd), 0.0) * p.a.x;
                pc.yz -= kd * amt;
                pc.x += amt * p.a.y * 0.5;
            }
            o = float4(clamp(rgb11(pc), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 14: { // matte choker morph: a.x = radius px (+ shrink, - grow)
            float r = abs(p.a.x);
            if (r < 0.01) break;
            float best = s.a;
            float4 bq = s;
            for (int ring = 1; ring <= 4; ring++) {
                float rr = r * float(ring) / 4.0;
                for (int k = 0; k < 8; k++) {
                    float ang = (float(k) + 0.5 * float(ring & 1)) * 0.7853982;
                    float4 q = float4(src.sample(s11Zero, c + float2(cos(ang), sin(ang)) * rr));
                    if (p.a.x > 0.0) { if (q.a < best) { best = q.a; } }
                    else if (q.a > best) { best = q.a; bq = q; }
                }
            }
            float3 col = (p.a.x > 0.0 || s.a > 0.5) ? u11(s) : u11(bq);
            o = float4(col * best, best);
            break;
        }
        case 15: { // unmultiply: a = (amount, gamma)
            float3 un = u11(s);
            float mx = max(un.r, max(un.g, un.b));
            float na = pow(clamp(mx, 0.0, 1.0), 1.0 / max(p.a.y, 0.05));
            float3 col = clamp(un / max(na, 1e-4), 0.0, 1.0);
            float a2 = na * s.a;
            o = mix(s, float4(col * a2, a2), clamp(p.a.x, 0.0, 1.0));
            break;
        }
        case 16: { // color range key: a = (hue deg, width deg, sat min, val min), i.y = invert
            float3 h = hsv11(u11(s));
            float dh = abs(fmod(h.x - p.a.x + 720.0, 360.0) - 180.0);
            dh = 180.0 - dh;
            float hw = 1.0 - smoothstep(p.a.y * 0.5, p.a.y * 0.5 + 10.0, dh);
            float k = hw * smoothstep(0.0, 0.4, h.y - p.a.z) * smoothstep(0.0, 0.4, h.z - p.a.w);
            if (p.i.y != 0) k = 1.0 - k;
            o = s * (1.0 - k);
            break;
        }
        case 17: { // luma matte soft: a = (in, out, 0, 0), i.y = invert
            float l = l11(u11(s));
            float m = clamp((l - p.a.x) / max(p.a.y - p.a.x, 1e-3), 0.0, 1.0);
            m = m * m * (3.0 - 2.0 * m);
            if (p.i.y != 0) m = 1.0 - m;
            o = s * m;
            break;
        }
        case 18: { // alpha levels: a = (in black, in white, gamma, out black), b.x = out white
            float na = clamp((s.a - p.a.x) / max(p.a.y - p.a.x, 1e-3), 0.0, 1.0);
            na = pow(na, 1.0 / max(p.a.z, 0.01));
            na = clamp(mix(p.a.w, p.b.x, na), 0.0, 1.0);
            o = float4(u11(s) * na, na);
            break;
        }
        case 19: { // edge refine combine: aux = blurred, a = (contrast, shift, 0, 0)
            float4 bl = float4(aux.sample(s11Zero, c));
            float3 col = s.a > 1e-3 ? u11(s) : u11(bl);
            float na = clamp((bl.a - 0.5 - p.a.y * 0.5) * (1.0 + p.a.x * 8.0) + 0.5, 0.0, 1.0);
            o = float4(col * na, na);
            break;
        }
        case 20: { // remove color matting (color to alpha): b = matte color, a.x = amount
            float3 un = u11(s);
            float3 m = clamp(p.b.rgb, 0.0, 1.0);
            float3 dv;
            for (int k = 0; k < 3; k++) {
                float x = un[k], mk = m[k];
                dv[k] = x > mk ? (x - mk) / max(1.0 - mk, 1e-4) : (mk - x) / max(mk, 1e-4);
            }
            float na = clamp(max(dv.r, max(dv.g, dv.b)), 0.0, 1.0);
            float3 col = clamp(m + (un - m) / max(na, 1e-4), 0.0, 1.0);
            float a2 = na * s.a;
            o = mix(s, float4(col * a2, a2), clamp(p.a.x, 0.0, 1.0));
            break;
        }
        case 21: { // linear alpha fade: a = (dir x, dir y, start, length)
            float2 dir = p.a.xy;
            float nrm = max(abs(dir.x) + abs(dir.y), 1e-3);
            float pr = dot(c / size - 0.5, dir) / nrm + 0.5;
            o = s * clamp((pr - p.a.z) / max(p.a.w, 1e-3), 0.0, 1.0);
            break;
        }
        case 22: { // opacity flicker: a = (speed Hz, amount, seed, 0)
            float fr = floor(t * max(p.a.x, 0.0));
            float r = h11(float2(fr * 1.13 + 0.7, p.a.z * 3.7 + 1.9));
            o = s * clamp(1.0 - p.a.y * (0.3 + 0.7 * r), 0.0, 1.0);
            break;
        }
        default: break;
    }
    dst.write(half4(o), gid);
}
