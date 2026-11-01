#include <metal_stdlib>
using namespace metal;

// Batch 2 effects. Same conventions as Effects.metal: rgba16Float premultiplied, sRGB-encoded.
struct EffectParams {
    float4 a;
    float4 b;
    float4 c;
    float4 d;
    uint4  i;
};

constexpr sampler s2Zero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler s2Edge(address::clamp_to_edge, filter::linear, coord::pixel);
constexpr sampler s2Repeat(address::repeat, filter::linear, coord::normalized);

static inline float3 unpm(float4 c) { return c.a > 1e-6 ? c.rgb / c.a : float3(0.0); }
static inline float lum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

static float h21(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float h31(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static float vn3(float3 x) {
    float3 i = floor(x), f = fract(x); float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(h31(i), h31(i + float3(1, 0, 0)), u.x), mix(h31(i + float3(0, 1, 0)), h31(i + float3(1, 1, 0)), u.x), u.y),
               mix(mix(h31(i + float3(0, 0, 1)), h31(i + float3(1, 0, 1)), u.x), mix(h31(i + float3(0, 1, 1)), h31(i + float3(1, 1, 1)), u.x), u.y), u.z);
}
static float fbm(float3 p, int oct) { float s = 0, a = 0.5, n = 0; for (int k = 0; k < oct; k++) { s += vn3(p) * a; n += a; a *= 0.5; p *= 2.03; } return s / n; }

// ---------- Warps: compute a source coordinate, then sample ----------
// i.x mode: 0 turbulent displace, 1 wave warp, 2 bulge, 3 twirl, 4 optics compensation, 5 mirror,
//           6 polar (rect->polar), 7 polar (polar->rect), 8 motion tile, 9 offset
// Pinning (AE Wave Warp): 0 none, 1 all edges, 2 top, 3 bottom, 4 left, 5 right, 6 top+bottom, 7 left+right.
// Returns how much of the warp applies here (0 on a pinned edge, rising to 1 over `soft` of the layer).
static float warpPin(float2 c, float4 rect, uint mode, float soft) {
    if (mode == 0) return 1.0;
    float2 uv = clamp((c - rect.xy) / max(rect.zw, float2(1.0)), 0.0, 1.0);
    float s = max(soft, 0.01);
    float top = smoothstep(0.0, s, uv.y), bottom = smoothstep(0.0, s, 1.0 - uv.y);
    float left = smoothstep(0.0, s, uv.x), right = smoothstep(0.0, s, 1.0 - uv.x);
    switch (mode) {
        case 1: return top * bottom * left * right;
        case 2: return top;
        case 3: return bottom;
        case 4: return left;
        case 5: return right;
        case 6: return top * bottom;
        case 7: return left * right;
        default: return 1.0;
    }
}

// Smooth 2D value noise in -1..1 (for Fractal Warp).
static float warpHash(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
static float warpNoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = warpHash(i), b = warpHash(i + float2(1, 0)), c2 = warpHash(i + float2(0, 1)), d = warpHash(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c2, d, u.x), u.y) * 2.0 - 1.0;
}

kernel void fxWarp(texture2d<half, access::sample> src [[texture(0)]],
                   texture2d<half, access::write> dst [[texture(1)]],
                   constant EffectParams& p [[buffer(0)]],
                   uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float2 q = c;
    bool edge = false;
    switch (p.i.x) {
        case 0: { // a = amount(px), size(px), complexity, evolution
            float3 np = float3(c / max(p.a.y, 1.0), p.a.w);
            int oct = int(clamp(p.a.z, 1.0, 8.0));
            float dx = fbm(np, oct) - 0.5, dy = fbm(np + float3(19.1, 7.3, 3.7), oct) - 0.5;
            q = c + float2(dx, dy) * 2.0 * p.a.x;
            edge = true;
            break;
        }
        case 1: { // wave warp: a = height(px), width(px), direction(deg), phase(rad); b = layer rect; c.x pin falloff
                  // i.y type (0 sine,1 square,2 triangle,3 sawtooth,4 circle,5 semicircle,6 smooth noise), i.z pinning
            float ang = p.a.z * M_PI_F / 180.0;
            float2 dir = float2(sin(ang), -cos(ang));
            float2 perp = float2(dir.y, -dir.x);
            float t = dot(c - p.b.xy, perp) / max(p.a.y, 1.0) * 2.0 * M_PI_F + p.a.w;
            float ph = fract(t / (2 * M_PI_F));
            float w;
            switch (p.i.y) {
                case 1: w = sin(t) >= 0 ? 1.0 : -1.0; break;
                case 2: w = 2.0 * abs(2.0 * ph - 1.0) - 1.0; break;
                case 3: w = 2.0 * ph - 1.0; break;
                case 4: { float u = ph * 2.0 - 1.0; w = (ph < 0.5 ? 1.0 : -1.0) * sqrt(max(0.0, 1.0 - pow(fract(ph * 2.0) * 2.0 - 1.0, 2.0))); (void)u; break; }
                case 5: w = sqrt(max(0.0, 1.0 - pow(ph * 2.0 - 1.0, 2.0))) * 2.0 - 1.0; break;
                case 6: { float a0 = floor(t / M_PI_F), f0 = fract(t / M_PI_F);
                          float h0 = fract(sin(a0 * 127.1) * 43758.5) * 2.0 - 1.0, h1 = fract(sin((a0 + 1.0) * 127.1) * 43758.5) * 2.0 - 1.0;
                          w = mix(h0, h1, f0 * f0 * (3.0 - 2.0 * f0)); break; }
                default: w = sin(t);
            }
            q = c + dir * w * p.a.x * warpPin(c, p.b, p.i.z, p.c.x);
            break;
        }
        case 2: { // bulge: a.xy center, a.z radius(px), a.w height (-4..4)
            float2 d = c - p.a.xy; float r = length(d) / max(p.a.z, 1.0);
            if (r < 1.0) { float k = pow(r, 1.0 + p.a.w * 0.5) / max(r, 1e-4); q = p.a.xy + d * mix(1.0, k, smoothstep(1.0, 0.0, r)); }
            break;
        }
        case 3: { // twirl: a.xy center, a.z radius, a.w angle(deg)
            float2 d = c - p.a.xy; float r = length(d) / max(p.a.z, 1.0);
            if (r < 1.0) { float an = p.a.w * M_PI_F / 180.0 * (1.0 - r) * (1.0 - r); float cs = cos(an), sn = sin(an); q = p.a.xy + float2(d.x * cs - d.y * sn, d.x * sn + d.y * cs); }
            break;
        }
        case 4: { // optics compensation: a.x FOV (0..180), i.y reverse lens distortion
            float2 ctr = size * 0.5; float2 d = (c - ctr) / (length(size) * 0.5);
            float k = tan(clamp(p.a.x, 0.0, 179.0) * M_PI_F / 360.0) * 0.6;
            float r = length(d);
            float f = p.i.y != 0 ? (1.0 / (1.0 + k * r * r)) : (1.0 + k * r * r);
            q = ctr + d * f * (length(size) * 0.5);
            break;
        }
        case 5: { // mirror: a.xy reflection center, a.z angle(deg)
            float an = p.a.z * M_PI_F / 180.0; float2 n = float2(cos(an), sin(an));
            float dd = dot(c - p.a.xy, n);
            if (dd > 0) q = c - 2.0 * dd * n;
            break;
        }
        case 6: case 7: { // polar: a.x interpolation (0..1)
            float2 ctr = size * 0.5; float2 uv = c / size;
            float2 pq;
            if (p.i.x == 6) { float2 d = uv - 0.5; float ang = atan2(d.x, -d.y) / (2 * M_PI_F) + 0.5; float rad = length(d) * 2.0; pq = float2(ang, rad) * size; }
            else { float ang = (uv.x - 0.5) * 2 * M_PI_F; float rad = uv.y * 0.5; pq = (float2(sin(ang), -cos(ang)) * rad + 0.5) * size; }
            q = mix(c, pq, p.a.x); (void)ctr;
            break;
        }
        case 8: { // motion tile: a.xy tile center (px), a.zw tile size (px); b = output center xy, half extent zw (px);
                  // c.x phase (turns), c.y horizontal phase shift; i.y mirror edges
            float2 tile = max(p.a.zw, float2(1));
            if (any(abs(c - p.b.xy) > p.b.zw)) { dst.write(half4(0), gid); return; }
            float2 r = (c - p.a.xy) / tile + 0.5;
            // Phase: every other row (or column) slides by the phase, like AE's brick offset.
            if (p.c.y > 0.5) r.y += fmod(floor(r.x), 2.0) != 0.0 ? p.c.x : 0.0;
            else r.x += fmod(floor(r.y), 2.0) != 0.0 ? p.c.x : 0.0;
            float2 f = fract(r);
            if (p.i.y != 0) { float2 cell = floor(r); f = select(f, 1.0 - f, fmod(abs(cell), 2.0) > 0.5); }
            q = p.a.xy + (f - 0.5) * tile;
            edge = true;
            break;
        }
        case 10: { // fractal warp: a = magnitude(px), frequency(1/px), parallax xy (px); b = layer rect;
                   // c = pin falloff, evolution (turns), detail (octaves), lacunarity (amplitude per octave); i.y screen space, i.z pinning
            float2 base = (p.i.y != 0 ? c : (c - p.b.xy)) + p.a.zw;
            float2 uvn = base * p.a.y;
            float evo = p.c.y * 6.2831853;
            float2 d = float2(0.0);
            float amp = 1.0, fq = 1.0, norm = 0.0;
            int oct = int(clamp(ceil(p.c.z), 1.0, 6.0));
            for (int k = 0; k < oct; k++) {
                float frac = (float(k) < p.c.z - 0.0 && float(k + 1) > p.c.z) ? fract(p.c.z) : 1.0;
                float a = amp * frac;
                d += a * float2(warpNoise(uvn * fq + float2(cos(evo), sin(evo)) * 0.6 + float2(k * 17.0, 3.1)),
                                warpNoise(uvn * fq + float2(sin(evo), cos(evo)) * 0.6 + float2(41.7, k * 9.0)));
                norm += a; amp *= p.c.w; fq *= 2.0;
            }
            d /= max(norm, 1e-4);
            q = c + d * p.a.x * warpPin(c, p.b, p.i.z, p.c.x);
            break;
        }
        case 9: { // offset: a.xy shift (px), wraps
            q = fmod(c - p.a.xy + size * 100.0, size);
            edge = true;
            break;
        }
    }
    float4 o = edge ? float4(src.sample(s2Edge, q)) : float4(src.sample(s2Zero, q));
    dst.write(half4(o), gid);
}

// ---------- Stylize ----------
// i.x: 0 posterize(a.x levels), 1 threshold(a.x level 0..1), 2 find edges(i.y invert, a.x blend),
//      3 mosaic(a.x h blocks, a.y v blocks), 4 halftone(a.x dot px, a.y angle, i.y color),
//      5 scanlines/CRT(a.x strength, a.y line px, a.z curvature), 6 impact frame(a.x threshold, a.y lines, a.zw center px),
//      7 manga (a.x screentone size, a.y ink threshold, a.z speed line amount, a.w seed)
kernel void fxStylize(texture2d<half, access::sample> src [[texture(0)]],
                      texture2d<half, access::write> dst [[texture(1)]],
                      constant EffectParams& p [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s2Zero, c));
    float a = s.a;
    float3 col = unpm(s);
    switch (p.i.x) {
        case 0: { float l = max(p.a.x, 2.0) - 1.0; col = floor(col * l + 0.5) / l; break; }
        case 1: { col = float3(lum(col) >= p.a.x ? 1.0 : 0.0); break; }
        case 2: {
            float gx = 0, gy = 0;
            for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
                float l = lum(unpm(float4(src.sample(s2Edge, c + float2(x, y)))));
                gx += l * float(x) * (y == 0 ? 2.0 : 1.0);
                gy += l * float(y) * (x == 0 ? 2.0 : 1.0);
            }
            float e = clamp(length(float2(gx, gy)), 0.0, 1.0);
            float3 ed = p.i.y != 0 ? float3(e) : float3(1.0 - e);
            col = mix(ed, col, p.a.y);
            break;
        }
        case 3: {
            float2 cell = size / float2(max(p.a.x, 1.0), max(p.a.y, 1.0));
            float2 cc = (floor(c / cell) + 0.5) * cell;
            float4 m = float4(src.sample(s2Edge, cc));
            col = unpm(m); a = m.a;
            break;
        }
        case 4: {
            float an = p.a.y * M_PI_F / 180.0; float2x2 R = float2x2(cos(an), -sin(an), sin(an), cos(an));
            float cs = max(p.a.x, 2.0);
            float2 rc = R * c; float2 cell = (floor(rc / cs) + 0.5) * cs;
            float2 sc = transpose(R) * cell;
            float3 cc = unpm(float4(src.sample(s2Edge, sc)));
            float dist = length(rc - cell) / (cs * 0.5);
            if (p.i.y != 0) {
                float3 dots = float3(dist < sqrt(cc.r) * 1.1 ? 1.0 : 0.0, dist < sqrt(cc.g) * 1.1 ? 1.0 : 0.0, dist < sqrt(cc.b) * 1.1 ? 1.0 : 0.0);
                col = dots;
            } else {
                float dark = 1.0 - lum(cc);
                col = float3(dist < sqrt(dark) * 1.15 ? 0.05 : 0.97);
            }
            break;
        }
        case 5: {
            float2 uv = c / size * 2.0 - 1.0;
            uv *= 1.0 + p.a.z * dot(uv, uv) * 0.15;
            float2 sc = (uv * 0.5 + 0.5) * size;
            float4 m = float4(src.sample(s2Zero, sc));
            col = unpm(m); a = m.a;
            float line = 0.5 + 0.5 * sin(c.y * M_PI_F * 2.0 / max(p.a.y, 1.0));
            col *= 1.0 - p.a.x * (1.0 - line) * 0.8;
            // aperture-grille subpixels
            int sub = int(c.x) % 3;
            float3 mask = sub == 0 ? float3(1, 0.7, 0.7) : (sub == 1 ? float3(0.7, 1, 0.7) : float3(0.7, 0.7, 1));
            col *= mix(float3(1), mask, p.a.x * 0.6);
            break;
        }
        case 6: {
            float l = lum(col);
            float bw = l > p.a.x ? 0.0 : 1.0;                   // classic inverted ink impact frame
            float2 d = c - p.a.zw; float ang = atan2(d.y, d.x);
            float streak = step(0.82, h21(float2(floor(ang * 60.0 / M_PI_F * max(p.a.y, 1.0) / 10.0), 1.0)));
            col = float3(max(bw, streak * smoothstep(40.0, 200.0, length(d))));
            a = 1.0;
            break;
        }
        case 7: {
            float l = lum(col);
            float ts = max(p.a.x, 2.0);
            float2 g = fract(c / ts) - 0.5;
            float tone = length(g) < (1.0 - l) * 0.62 ? 0.15 : 1.0;   // screentone dots for midtones
            float3 manga = float3(l < p.a.y ? 0.04 : (l < 0.8 ? tone : 1.0));
            // speed lines from the center
            float2 d = c - size * 0.5; float ang = atan2(d.y, d.x);
            float sl = step(1.0 - p.a.z * 0.25, h21(float2(floor((ang + M_PI_F) * 90.0), p.a.w)));
            manga = mix(manga, float3(0.02), sl * smoothstep(size.y * 0.25, size.y * 0.6, length(d)));
            col = manga;
            break;
        }
    }
    dst.write(half4(half3(clamp(col, 0.0, 64.0) * a), half(a)), gid);
}

// ---------- Glitch & VHS ----------
// i.x: 0 glitch (a.x amount, a.y block px, a.z rgb shift px, a.w seed/time), 1 VHS (a.x amount, a.y noise, a.z wobble, a.w time)
kernel void fxGlitch(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     constant EffectParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float2 size = float2(dst.get_width(), dst.get_height());
    float4 o;
    if (p.i.x == 0) {
        float bh = max(p.a.y, 2.0);
        float row = floor(c.y / bh);
        float seed = floor(p.a.w);
        float r = h21(float2(row, seed));
        float shift = r > 1.0 - p.a.x * 0.5 ? (h21(float2(row, seed + 7.0)) - 0.5) * size.x * 0.25 * p.a.x : 0.0;
        float2 q = c + float2(shift, 0);
        float rs = p.a.z * (r > 0.5 ? 1.0 : -1.0);
        float4 R = float4(src.sample(s2Zero, q + float2(rs, 0))), G = float4(src.sample(s2Zero, q)), B = float4(src.sample(s2Zero, q - float2(rs, 0)));
        o = float4(R.r, G.g, B.b, max(R.a, max(G.a, B.a)));
        // occasional color-inverted block
        if (h21(float2(row * 3.1, seed + 3.0)) > 1.0 - p.a.x * 0.08) o.rgb = o.a - o.rgb;
    } else {
        float t = p.a.w;
        float wob = sin(c.y * 0.05 + t * 9.0) * p.a.z * 3.0 + (h21(float2(floor(c.y / 3.0), floor(t * 30.0))) - 0.5) * p.a.z * 4.0;
        float2 q = c + float2(wob, 0);
        float4 base = float4(src.sample(s2Zero, q));
        float4 bleedR = float4(src.sample(s2Zero, q + float2(3.0 * p.a.x, 0)));
        float4 bleedB = float4(src.sample(s2Zero, q - float2(2.0 * p.a.x, 0)));
        o = float4(mix(base.r, bleedR.r, 0.6 * p.a.x), base.g, mix(base.b, bleedB.b, 0.6 * p.a.x), base.a);
        float n = (h21(c + floor(t * 30.0)) - 0.5) * p.a.y;
        o.rgb = clamp(o.rgb + n * o.a, 0.0, 64.0);
        float band = smoothstep(0.0, 0.02, abs(fract(c.y / size.y - t * 0.15) - 0.5) - 0.48);
        o.rgb *= mix(1.0, 1.25, (1.0 - band) * p.a.x);
    }
    dst.write(half4(o), gid);
}

// ---------- Color: curves, looks, grain ----------
// i.x: 0 curves (a = black, shadows, midtones, highlights; b.x white; i.y channel 0 RGB,1 R,2 G,3 B)
//      1 looks (a = temperature, tint, contrast, saturation; b = vibrance, highlights, shadows, fade)
//      2 grain/noise (a.x amount, a.y size, a.z color(0/1), a.w seed)
static float curve5(float x, float4 a, float w) {
    // Monotone smooth curve through (0,a.x) (0.25,a.y) (0.5,a.z) (0.75,a.w) (1,w): Catmull-Rom segments.
    float pts[5] = { a.x, a.y, a.z, a.w, w };
    float t = clamp(x, 0.0, 1.0) * 4.0; int i = min(int(t), 3); float f = t - float(i);
    float p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, 4)];
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f);
}

kernel void fxColor2(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     constant EffectParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s2Zero, c));
    if (s.a <= 0.0) { dst.write(half4(0.0h), gid); return; }
    float3 col = unpm(s);
    if (p.i.x == 0) {
        float3 o = float3(curve5(col.r, p.a, p.b.x), curve5(col.g, p.a, p.b.x), curve5(col.b, p.a, p.b.x));
        if (p.i.y == 1) col.r = o.r; else if (p.i.y == 2) col.g = o.g; else if (p.i.y == 3) col.b = o.b; else col = o;
    } else if (p.i.x == 1) {
        col *= float3(1.0 + p.a.x * 0.25, 1.0 - p.a.y * 0.1, 1.0 - p.a.x * 0.25) * float3(1, 1.0 + p.a.y * 0.15, 1);   // temperature/tint
        col = (col - 0.5) * (1.0 + p.a.z) + 0.5;                                                                    // contrast
        float l = lum(col);
        float satv = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
        col = mix(float3(l), col, 1.0 + p.a.w + p.b.x * (1.0 - satv));                                              // saturation + vibrance
        col += p.b.y * smoothstep(0.5, 1.0, l) * 0.3 + p.b.z * (1.0 - smoothstep(0.0, 0.5, l)) * 0.3;               // highlights/shadows
        col = mix(col, float3(0.5) + (col - 0.5) * 0.85 + 0.06, p.b.w);                                             // fade
    } else {
        float sz = max(p.a.y, 0.5);
        float2 g = floor(c / sz);
        float n = h21(g + p.a.w * 13.7) - 0.5;
        float3 cn = float3(h21(g + 1.3 + p.a.w), h21(g + 2.7 + p.a.w), h21(g + 4.1 + p.a.w)) - 0.5;
        col += mix(float3(n), cn, p.a.z) * p.a.x;
    }
    dst.write(half4(half3(clamp(col, 0.0, 64.0) * s.a), half(s.a)), gid);
}

// ---------- Saber-style energy beam from the layer's alpha ----------
// a.x core size, a.y glow intensity, a.z flicker, a.w time ; b.rgb glow color ; i.x core only
kernel void fxSaberCore(texture2d<half, access::sample> src [[texture(0)]],
                        texture2d<half, access::write> dst [[texture(1)]],
                        constant EffectParams& p [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 sv = float4(src.sample(s2Zero, c));
    float3 sc = unpm(sv);
    // Beam shape = the layer's coverage, limited to its bright/saturated parts so it also works on
    // footage and adjustment layers (which are opaque everywhere).
    float al = sv.a * smoothstep(0.12, 0.6, max(sc.r, max(sc.g, sc.b)));
    // Core: hot white where the layer is solid, thinned by core size.
    // Core size: how much of the shape burns white-hot (and how hot).
    float cs = clamp(p.a.x, 0.02, 1.0);
    float core = smoothstep(1.0 - cs, 1.0 - cs * 0.3, al);
    // Flicker: strong energy pulse (continuous noise so it never freezes on one value).
    float pulse = 0.5 + 0.5 * sin(p.a.w * 53.0) * cos(p.a.w * 17.0 + 1.3);
    float flick = 1.0 - p.a.z * 0.8 * pulse;
    float3 col = mix(p.b.rgb * (0.6 + cs), float3(1.0 + cs), core) * flick;
    dst.write(half4(half3(col * al), half(al)), gid);
}

// ---------- Shine-style light rays from a point ----------
// a.xy source (px), a.z length (0..1), a.w intensity ; b.rgb ray color ; i.x samples
kernel void fxShine(texture2d<half, access::sample> src [[texture(0)]],
                    texture2d<half, access::write> dst [[texture(1)]],
                    constant EffectParams& p [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 base = float4(src.sample(s2Zero, c));
    int n = int(clamp(p.i.x, 8u, 96u));
    float3 acc = float3(0);
    float decay = 1.0;
    for (int k = 0; k < n; k++) {
        float t = float(k) / float(n) * p.a.z;
        float2 q = mix(c, p.a.xy, t);
        float4 s = float4(src.sample(s2Zero, q));
        float br = smoothstep(0.45, 1.0, lum(unpm(s))) * s.a;
        acc += br * decay;
        decay *= 0.985;
    }
    acc = acc / float(n) * p.a.w * p.b.rgb * 4.0;
    float4 o = base + float4(acc, 0);
    o.a = clamp(max(base.a, lum(acc)), 0.0, 1.0);
    dst.write(half4(o), gid);
}

// ---------- Particles (stateless: each particle's life is computed from its seed) ----------
// a.xy emitter (px), a.z birth rate (/s), a.w velocity (px/s) ; b.x spread (deg), b.y direction (deg), b.z gravity, b.w life (s)
// c.x size (px), c.y time, c.z seed, c.w max particles ; d.rgb color
kernel void fxParticles(texture2d<half, access::sample> src [[texture(0)]],
                        texture2d<half, access::write> dst [[texture(1)]],
                        constant EffectParams& p [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 base = float4(src.sample(s2Zero, c));
    float life = max(p.b.w, 0.05), rate = max(p.a.z, 0.0), t = p.c.y;
    int count = int(min(rate * life, p.c.w));
    float3 acc = float3(0); float aacc = 0;
    float firstBorn = floor((t - life) * rate);
    for (int k = 0; k < count; k++) {
        float idx = firstBorn + float(k) + 1.0;
        float born = idx / max(rate, 1e-3);
        float age = t - born;
        if (age < 0.0 || age > life || born < 0.0) continue;
        float r1 = h21(float2(idx, p.c.z)), r2 = h21(float2(idx + 17.0, p.c.z)), r3 = h21(float2(idx + 31.0, p.c.z));
        float ang = (p.b.y + (r1 - 0.5) * p.b.x) * M_PI_F / 180.0;
        float spd = p.a.w * (0.6 + 0.8 * r2);
        float2 pos = p.a.xy + float2(sin(ang), -cos(ang)) * spd * age + float2(0, 0.5 * p.b.z * age * age);
        float sz = p.c.x * (0.5 + r3) * (1.0 - age / life * 0.6);
        float d = length(c - pos) / max(sz, 0.5);
        float fall = (1.0 - smoothstep(0.0, 1.0, d)) * (1.0 - age / life);
        acc += p.d.rgb * fall; aacc += fall;
    }
    aacc = clamp(aacc, 0.0, 1.0);
    float4 o = float4(base.rgb + acc, max(base.a, aacc));   // additive light particles over the layer
    dst.write(half4(o), gid);
}

// ---------- Pixel sort-style smear: bright runs stretch along a direction ----------
// a.x threshold, a.y length (px), a.z direction (deg) ; i.x samples
kernel void fxPixelSort(texture2d<half, access::sample> src [[texture(0)]],
                        texture2d<half, access::write> dst [[texture(1)]],
                        constant EffectParams& p [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float an = p.a.z * M_PI_F / 180.0; float2 dir = float2(cos(an), sin(an));
    float4 best = float4(src.sample(s2Zero, c));
    if (lum(unpm(best)) < p.a.x) { dst.write(half4(best), gid); return; }
    int n = int(clamp(p.i.x, 4u, 128u));
    float bestL = lum(unpm(best));
    // Within the bright run behind this pixel, take the brightest value: sorted-looking streaks.
    for (int k = 1; k <= n; k++) {
        float2 q = c - dir * (float(k) / float(n)) * p.a.y;
        float4 s = float4(src.sample(s2Zero, q));
        float l = lum(unpm(s));
        if (l < p.a.x) break;
        if (l > bestL) { bestL = l; best = s; }
    }
    dst.write(half4(best), gid);
}
