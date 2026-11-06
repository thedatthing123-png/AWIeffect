#include <metal_stdlib>
using namespace metal;

// Batch 24: the glitch engine that the remade glitch / pixel / block effects share.
// Real digital damage is coherent: codec blocks of mixed sizes, rows that tear and smear, color channels that slip,
// blocks that freeze on a stale row. It reuses the picture's own colors; it never sprinkles random rainbow pixels.
// rgba16Float premultiplied, sRGB-encoded.
//   a, b = mode settings, c = burst timing (base, bursts/s, length, seed) when i.y == 1,
//   d = (time s, held frame index, seed, -), i.x = mode, i.z = mode option.
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler gxs(address::clamp_to_edge, filter::linear, coord::pixel);

static inline uint gxPcg(uint v) {
    uint s = v * 747796405u + 2891336453u;
    uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
    return (w >> 22u) ^ w;
}
/// Stable hash of an integer cell and a salt (no sin(): stays random at large coordinates).
static inline float gxH(float2 cell, float salt) {
    int2 q = int2(floor(cell));
    uint h = gxPcg(uint(q.x) + gxPcg(uint(q.y) + gxPcg(uint(int(floor(salt * 7.0)) + 1013904223))));
    return float(h) * (1.0 / 4294967295.0);
}
static inline float gxH1(float x, float salt) { return gxH(float2(x, 0.0), salt); }
static inline float gxLum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static inline float4 gxS(texture2d<half, access::sample> t, float2 p) { return float4(t.sample(gxs, p)); }

/// Burst envelope (same feel as the glitch pack): hits attack instantly and ring out.
static inline float gxBurst(float t, float rate, float len, float seed) {
    float r = max(rate, 0.01);
    float s = floor(t * r), ph = fract(t * r);
    bool fire = fmod(s, 2.0) >= 1.0 || gxH1(s * 1.37, seed) < 0.45;
    if (!fire) return 0.0;
    return exp(-ph / max(len, 0.02) * 2.5) * (0.6 + 0.4 * gxH1(s * 3.1, seed + 1.0));
}
static inline float gxK(float t, float4 b) {
    return b.x + gxBurst(t, b.y, b.z, b.w) + gxBurst(t, b.y * 3.7, b.z * 0.5, b.w + 17.0) * 0.35;
}

/// Codec-style block layout: a big block splits into quarters (randomly, per block) down to `minSize`, so blocks
/// of several sizes sit side by side like a broken video stream. Returns (origin, size).
static inline float4 gxBlock(float2 c, float2 big, float minSize, float salt, float split) {
    float2 s = max(big, float2(1.0));
    float2 o = floor(c / s) * s;
    for (int l = 0; l < 4; l++) {
        if (min(s.x, s.y) * 0.5 < minSize) break;
        if (gxH(o / max(minSize, 1.0), salt + float(l) * 31.0) > split) break;
        s *= 0.5;
        o += step(o + s, c) * s;
    }
    return float4(o, s);
}

/// RGB split around q with premultiplied-safe alpha.
static inline float4 gxSplit(texture2d<half, access::sample> t, float2 q, float2 d) {
    float4 g = gxS(t, q);
    if (dot(d, d) < 1e-4) return g;
    float4 r = gxS(t, q + d), b = gxS(t, q - d);
    float a = max(g.a, max(r.a, b.a));
    return float4(min(float3(r.r, g.g, b.b), float3(a)), a);
}

struct GXHit { float p; float shift; float vshift; float rgb; float swap; float inv; float smear; float pix; };

/// Damages one block: it slides, splits its channels, and may freeze on its first row (smear), drop to big
/// pixels, swap channels or invert. Everything is sampled from the picture itself.
static inline float4 gxCorrupt(texture2d<half, access::sample> t, float2 c, float4 blk, float salt, GXHit g, float baseRgb) {
    float2 id = blk.xy / max(blk.zw, float2(1.0));
    float r0 = gxH(id, salt), r1 = gxH(id, salt + 1.0), r2 = gxH(id, salt + 2.0), r3 = gxH(id, salt + 3.0);
    float r4 = gxH(id, salt + 4.0), r5 = gxH(id, salt + 5.0);
    if (r0 >= g.p) return gxSplit(t, c, float2(baseRgb, 0.0));
    float2 q = c + float2((r1 - 0.5) * 2.0 * g.shift, (r2 - 0.5) * 2.0 * g.vshift);
    float sel = r4;
    if (sel < g.smear) {
        // Frozen block: one row (or column) repeats across it, the classic stuck-macroblock streak.
        if (r5 < 0.6) q.y = blk.y + 0.5 + floor(r3 * 3.0); else q.x = blk.x + 0.5 + floor(r3 * 3.0);
    } else if (sel < g.smear + g.pix) {
        float cell = max(floor(min(blk.z, blk.w) / 4.0), 2.0);
        q = floor(q / cell) * cell + cell * 0.5;
    }
    float4 o = gxSplit(t, q, float2(g.rgb * (0.5 + r3), 0.0));
    if (r5 < g.swap) o.rgb = (r1 < 0.5) ? o.gbr : o.brg;
    else if (r5 < g.swap + g.inv) o.rgb = o.a - o.rgb;
    return o;
}

kernel void fxGX(texture2d<half, access::sample> src [[texture(0)]],
                 texture2d<half, access::write> dst [[texture(1)]],
                 constant EffectParams& p [[buffer(0)]],
                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float t = p.d.x, fr = p.d.y, seed = p.d.z;
    float k = p.i.y == 1 ? gxK(t, p.c) : 1.0;
    float salt = fr * 3.0 + seed * 101.0;
    float4 o;
    switch (p.i.x) {
    case 0: {
        // AWI Glitch: a = (amount 0-1, block height px, rgb px, -). Wide blocks of mixed sizes.
        float amt = clamp(p.a.x * k, 0.0, 1.5);
        float bh = max(p.a.y, 2.0);
        float4 blk = gxBlock(c, float2(bh * 8.0, bh * 2.0), bh * 0.5, salt, 0.55);
        GXHit g = { amt * 0.55, amt * size.x * 0.12, 0.0, p.a.z * (0.5 + amt), 0.22, 0.12, 0.18, 0.1 };
        o = gxCorrupt(src, c, blk, salt, g, p.a.z * amt * 0.25);
        break; }
    case 1: {
        // Glitch Blocks: a = (displacement px, block px, amount 0-1, rgb px)
        float bs = max(p.a.y, 3.0);
        float4 blk = gxBlock(c, float2(bs * 4.0, bs * 2.0), bs * 0.5, salt, 0.6);
        GXHit g = { p.a.z * k, p.a.x * k, p.a.x * 0.15 * k, p.a.w * k, 0.15, 0.05, 0.2, 0.1 };
        o = gxCorrupt(src, c, blk, salt, g, 0.0);
        break; }
    case 2: {
        // Glitch Lines: a = (tear px, line height px, density 0-1, color shift px). Thin full-or-partial rows.
        float h = max(p.a.y, 1.0);
        float rowsTall = 1.0 + floor(gxH1(floor(c.y / (h * 4.0)), salt + 9.0) * 4.0);
        float bandH = h * rowsTall;
        float band = floor(c.y / bandH);
        float segW = size.x * (gxH1(band, salt + 3.0) < 0.5 ? 1.0 : 0.5);
        float4 blk = float4(floor(c.x / segW) * segW, band * bandH, segW, bandH);
        GXHit g = { p.a.z * 0.7 * k, p.a.x * k, 0.0, p.a.w * k, 0.08, 0.04, 0.3, 0.0 };
        o = gxCorrupt(src, c, blk, salt, g, 0.0);
        break; }
    case 3: {
        // Digital Noise: a = (intensity 0-1, pixel px). Damaged zones turn into coarse posterized pixels with
        // swapped channels and a few bright stuck pixels taken from the picture's own highlights.
        float px = max(p.a.y, 1.0);
        float amt = clamp(p.a.x * k, 0.0, 1.0);
        float4 blk = gxBlock(c, float2(px * 16.0, px * 8.0), px * 2.0, salt, 0.55);
        float2 id = blk.xy / blk.zw;
        if (gxH(id, salt) < amt * 0.7) {
            float2 q = floor(c / px) * px + px * 0.5;
            o = gxS(src, q);
            float lv = mix(6.0, 2.0, amt);
            if (o.a > 1e-4) o.rgb = floor(o.rgb / o.a * lv + 0.5) / lv * o.a;
            float r = gxH(id, salt + 7.0);
            if (r < 0.45) o.rgb = o.brg; else if (r < 0.6) o.rgb = o.a - o.rgb;
            float spark = gxH(floor(c / px), salt + 11.0);
            if (spark < 0.06 * amt) { float m = max(o.r, max(o.g, o.b)); o.rgb = min(o.rgb + m * 0.8 + 0.2 * o.a, float3(o.a)); }
            float2 sh = float2((gxH(id, salt + 2.0) - 0.5) * px * 6.0 * amt, 0.0);
            o = mix(o, gxS(src, q + sh), 0.25);
        } else {
            o = gxSplit(src, c, float2(px * 0.3 * amt, 0.0));
        }
        break; }
    case 4: {
        // Datamosh: a = (smear px, block px, chaos 0-1, angle rad), b.x = frozen blocks 0-1, i.z = 1 random
        // directions. Blocks move along their own motion vectors and drag the pixels behind them.
        float bs = max(p.a.y, 2.0);
        float slow = floor(fr / 3.0);
        float4 blk = gxBlock(c, float2(bs * 4.0), bs, slow + seed * 13.0, 0.6);
        float2 id = blk.xy / blk.zw;
        float ang = p.i.z == 1 ? gxH(id, slow + 5.0) * 6.2832 : p.a.w + (gxH(id, slow + 5.0) - 0.5) * 3.1416 * p.a.z;
        float2 dir = float2(cos(ang), sin(ang));
        float moving = step(gxH(id, slow + 9.0), 0.35 + 0.55 * p.a.z);
        float2 v = dir * p.a.x * k * moving * (0.4 + 0.6 * gxH(id, slow + 2.0));
        float4 acc = float4(0.0);
        for (int s = 0; s < 10; s++) acc += gxS(src, c - v * (float(s) / 9.0));
        o = acc / 10.0;
        // Frozen blocks repeat their leading row: the stale macroblock look.
        float frozen = step(gxH(id, slow + 21.0), p.b.x * min(k, 1.0) * 0.6);
        if (frozen > 0.5) {
            float2 q = abs(dir.x) > abs(dir.y) ? float2(blk.x + 0.5, c.y) : float2(c.x, blk.y + 0.5);
            o = gxS(src, q - v);
        }
        // Compression drift: color lags a little behind brightness in moving blocks.
        float4 side = gxS(src, c - v * 1.3);
        float y = gxLum(o.rgb);
        float3 chroma = side.rgb - gxLum(side.rgb);
        o.rgb = clamp(mix(o.rgb, y + chroma, 0.5 * moving), 0.0, o.a);
        break; }
    case 5: {
        // JPEG: a = (damage 0-1, block px, color bleed px, corrupt 0/1). Each block keeps its smooth average shape
        // (a 2x2 fit), detail is quantized hard with ringing, and color is stored at a quarter resolution.
        float bs = max(p.a.y, 2.0);
        float dmg = clamp(p.a.x * k, 0.0, 1.0);
        float2 blk = floor(c / bs) * bs;
        float2 lp = (c - blk) / bs;
        float4 q00 = gxS(src, blk + bs * float2(0.25, 0.25)), q10 = gxS(src, blk + bs * float2(0.75, 0.25));
        float4 q01 = gxS(src, blk + bs * float2(0.25, 0.75)), q11 = gxS(src, blk + bs * float2(0.75, 0.75));
        float2 w = clamp((lp - 0.25) * 2.0, 0.0, 1.0);
        float4 low = mix(mix(q00, q10, w.x), mix(q01, q11, w.x), w.y);
        float4 px = gxS(src, c);
        float a = px.a;
        float3 detail = px.rgb - low.rgb;
        float stepQ = mix(0.02, 0.4, dmg);
        float3 qd = round(detail / stepQ) * stepQ;
        // Ringing: quantization error shows up as a faint ripple at the block's own frequency.
        float ring = cos(lp.x * 6.2832 * 2.0) * cos(lp.y * 6.2832 * 2.0) * length(detail) * dmg * 0.6;
        float lv = mix(48.0, 10.0, dmg);
        float3 rgb = round(low.rgb * lv) / lv + qd * (1.0 - dmg * 0.6) + ring;
        // 4:2:0 chroma: color comes from a block twice the size, slid sideways by the bleed.
        float2 cb2 = floor((c + float2(p.a.z, 0.0)) / (bs * 2.0)) * bs * 2.0 + bs;
        float4 cc = gxS(src, cb2);
        float3 chroma = cc.rgb - gxLum(cc.rgb);
        float Y = gxLum(rgb);
        rgb = mix(rgb, Y + chroma, clamp(dmg * 1.4, 0.0, 1.0));
        o = float4(clamp(rgb, 0.0, a), a);
        if (p.a.w > 0.5) {
            float4 big = gxBlock(c, float2(bs * 4.0), bs, salt, 0.5);
            GXHit g = { dmg * 0.3, bs * 3.0, bs * 0.5, 0.0, 0.35, 0.0, 0.45, 0.0 };
            float2 id = big.xy / big.zw;
            if (gxH(id, salt) < g.p) o = gxCorrupt(src, c, big, salt, g, 0.0);
        }
        break; }
    case 6: {
        // Teletext: a = (cell width px, threshold 0-1). 2x3 block graphics in the 8 broadcast colors on black.
        float cw = max(p.a.x, 2.0);
        float2 cell = float2(cw, cw * 1.5);
        float2 o0 = floor(c / cell) * cell;
        float2 sub = floor((c - o0) / (cell / float2(2.0, 3.0)));
        float2 subSize = cell / float2(2.0, 3.0);
        float4 avg = float4(0.0);
        for (int y = 0; y < 3; y++) for (int x = 0; x < 2; x++) avg += gxS(src, o0 + (float2(x, y) + 0.5) * subSize);
        avg /= 6.0;
        float4 me = gxS(src, o0 + (sub + 0.5) * subSize);
        float3 col = avg.a > 1e-4 ? avg.rgb / avg.a : float3(0.0);
        float m = max(col.r, max(col.g, col.b));
        float3 pal = m > 0.08 ? step(float3(m * 0.6), col) : float3(0.0);
        if (dot(pal, pal) < 0.5) pal = float3(1.0);
        bool on = me.a > 0.01 && gxLum(me.rgb / max(me.a, 1e-4)) > p.a.y * 0.8;
        float a = gxS(src, c).a;
        o = float4((on ? pal : float3(0.0)) * a, a);
        break; }
    case 7: {
        // Color Bands: a = (band px, amount 0-1, shift px, -). Bands of uneven height slide and swap channels.
        float bh = max(p.a.x, 2.0);
        float band = floor(c.y / bh);
        float group = floor(band / (1.0 + floor(gxH1(floor(band / 4.0), salt) * 4.0)));
        float r = gxH1(group, salt + 1.0);
        if (r < p.a.y * 0.8) {
            float sh = (gxH1(group, salt + 2.0) - 0.5) * 2.0 * p.a.z;
            float2 q = c + float2(sh, 0.0);
            float sel = gxH1(group, salt + 3.0);
            if (sel < 0.25) q.x = floor(q.x / (bh * 6.0)) * bh * 6.0 + 0.5;
            o = gxSplit(src, q, float2(p.a.z * 0.2, 0.0));
            float sw = gxH1(group, salt + 4.0);
            if (sw < 0.4) o.rgb = o.gbr; else if (sw < 0.7) o.rgb = o.brg; else if (sw < 0.8) o.rgb = o.a - o.rgb;
            if (sel > 0.75 && o.a > 1e-4) o.rgb = floor(o.rgb / o.a * 3.0 + 0.5) / 3.0 * o.a;
        } else {
            o = gxS(src, c);
        }
        break; }
    case 8: {
        // Block Shuffle: a = (block px, amount 0-1). Blocks show a different part of the picture, never a hole.
        float bs = max(p.a.x, 4.0);
        float4 blk = gxBlock(c, float2(bs * 2.0), bs, salt, 0.5);
        float2 id = blk.xy / blk.zw;
        if (gxH(id, salt) < p.a.y * k) {
            float2 n = floor(size / blk.zw);
            float2 from = floor(float2(gxH(id, salt + 1.0), gxH(id, salt + 2.0)) * n) * blk.zw;
            o = gxSplit(src, from + (c - blk.xy), float2(bs * 0.04, 0.0));
        } else {
            o = gxS(src, c);
        }
        break; }
    case 9: {
        // Signal Loss: a = (static 0-1, sync bars 0-1, drop 0-1). The signal slips: rows lose sync, the picture
        // rolls, contrast collapses and gray (never colored) static takes over.
        float drop = clamp(p.a.z * k, 0.0, 1.0);
        float roll = drop > 0.05 ? fract(t * 0.9 + gxH1(fr, seed)) * size.y * drop * 0.4 : 0.0;
        float rowG = floor(c.y / 3.0);
        float sync = (gxH1(rowG, salt) - 0.5) * 60.0 * drop * drop;
        float saw = fract(c.y / size.y * 3.0 + t) * 30.0 * drop;
        float2 q = float2(c.x + sync + saw, fmod(c.y + roll, size.y));
        float4 px = gxS(src, q);
        float a = max(px.a, drop * p.a.x);
        float y = gxLum(px.rgb);
        float3 pic = mix(px.rgb, float3(y), drop * 0.7);
        pic = mix(pic, float3(0.5 * px.a), drop * 0.35);
        float st = gxH(floor(c / float2(2.0, 1.0)), fr * 11.0 + seed);
        float3 stat = float3(st * st) * a;
        o = float4(mix(pic, stat, drop * p.a.x), a);
        float bar = smoothstep(0.0, 0.12, abs(fract(c.y / size.y - t * 0.35) - 0.5) - 0.32);
        o.rgb *= mix(1.0, 0.25 + 0.75 * bar, p.a.y * drop);
        break; }
    case 10: {
        // Block Corruption: a = (amount 0-1, block px, color shift 0-1)
        float bs = max(p.a.y, 2.0);
        float4 blk = gxBlock(c, float2(bs * 4.0), bs, floor(fr / 2.0) * 3.0 + seed * 101.0, 0.6);
        GXHit g = { clamp(p.a.x * k, 0.0, 1.0) * 0.5, bs * 1.5, bs * 0.4, bs * 0.25, p.a.z * 0.6, p.a.z * 0.1, 0.45, 0.15 };
        o = gxCorrupt(src, c, blk, floor(fr / 2.0) * 3.0 + seed * 101.0, g, 0.0);
        break; }
    case 11: {
        // Pixel Sort: a = (threshold 0-1, length px, angle rad, -). Inside each bright run, pixels are replaced by
        // a smooth ramp from the run's darkest to its brightest color, which is what sorting a run looks like.
        float2 d = float2(cos(p.a.z), sin(p.a.z));
        float L = max(p.a.y * min(k, 1.5), 1.0);
        float4 me = gxS(src, c);
        float lm = me.a > 1e-4 ? gxLum(me.rgb / me.a) : 0.0;
        if (lm < p.a.x || me.a < 0.01) { o = me; break; }
        const int N = 40;
        float stepL = L / float(N);
        float back = 0.0, fwd = 0.0;
        float4 dark = me, bright = me; float ld = lm, lb = lm;
        for (int s = 1; s <= N; s++) {
            float4 q = gxS(src, c - d * stepL * float(s));
            float l = q.a > 1e-4 ? gxLum(q.rgb / q.a) : 0.0;
            if (l < p.a.x || q.a < 0.01) break;
            back = float(s);
            if (l < ld) { ld = l; dark = q; } if (l > lb) { lb = l; bright = q; }
        }
        for (int s = 1; s <= N; s++) {
            float4 q = gxS(src, c + d * stepL * float(s));
            float l = q.a > 1e-4 ? gxLum(q.rgb / q.a) : 0.0;
            if (l < p.a.x || q.a < 0.01) break;
            fwd = float(s);
            if (l < ld) { ld = l; dark = q; } if (l > lb) { lb = l; bright = q; }
        }
        float u = (back + fwd) > 0.0 ? back / (back + fwd) : 0.5;
        o = mix(dark, bright, smoothstep(0.0, 1.0, u));
        break; }
    case 12: {
        // VHS: a = (bleed 0-1, noise 0-1, wobble 0-1). Soft luma, low-resolution color smeared to the right,
        // wobbling lines, a torn head-switching strip at the bottom and white dropout streaks.
        float bleed = p.a.x, nz = p.a.y, wob = p.a.z;
        float row = floor(c.y);
        float lineWob = sin(c.y * 0.035 + t * 2.3) * 1.5 + (gxH1(row, floor(t * 30.0)) - 0.5) * 1.2;
        float2 q = c + float2(lineWob * wob * 2.0, 0.0);
        float head = smoothstep(size.y * 0.955, size.y * 0.975, c.y);
        q.x += head * (20.0 + gxH1(floor(c.y / 2.0), floor(t * 30.0)) * 25.0);
        float4 lumaS = (gxS(src, q - float2(1.0, 0.0)) + gxS(src, q) * 2.0 + gxS(src, q + float2(1.0, 0.0))) * 0.25;
        float4 chromaS = float4(0.0);
        float spread = 2.0 + bleed * 10.0;
        for (int s = 0; s < 8; s++) chromaS += gxS(src, q - float2(spread * (float(s) / 7.0) + bleed * 4.0, 0.0));
        chromaS /= 8.0;
        float Y = gxLum(lumaS.rgb);
        float3 rgb = Y + (chromaS.rgb - gxLum(chromaS.rgb)) * (1.0 - 0.25 * bleed);
        float a = lumaS.a;
        rgb = mix(rgb, rgb * 0.92 + 0.04 * a, 0.6);
        float g = (gxH(floor(c / float2(2.0, 1.0)), floor(t * 30.0)) - 0.5) * nz * 0.18;
        rgb += g * a;
        // Dropouts: short bright streaks on random lines.
        float dl = gxH1(row, floor(t * 30.0) + 3.0);
        if (dl < nz * 0.012) {
            float x0 = gxH1(row, floor(t * 30.0) + 4.0) * size.x;
            float len = 20.0 + gxH1(row, floor(t * 30.0) + 5.0) * 90.0;
            if (c.x > x0 && c.x < x0 + len) rgb = mix(rgb, float3(a), 0.85);
        }
        rgb = mix(rgb, float3(gxH(floor(c / 2.0), floor(t * 30.0)) * a), head * 0.5);
        o = float4(clamp(rgb, 0.0, a), a);
        break; }
    default: {
        // Signal Interference: a = (strength px, bands, speed, color shift px), b.x = line noise 0-1.
        float ph = c.y / size.y * p.a.y - t * p.a.z;
        float env = smoothstep(0.55, 1.0, sin(ph * 6.2832) * 0.5 + 0.5);
        float jag = sin(c.y * 0.35 + t * 37.0) * 0.6 + (gxH1(floor(c.y / 2.0), floor(t * 24.0) + p.d.z) - 0.5);
        float noisy = step(gxH1(floor(c.y / 2.0), floor(t * 24.0) + 7.0 + p.d.z), p.b.x * 0.08);
        float shift = p.a.x * (env * jag * 1.5 + noisy * (gxH1(floor(c.y), floor(t * 24.0)) - 0.5) * 3.0);
        float2 q = c + float2(shift, 0.0);
        o = gxSplit(src, q, float2(p.a.w * (0.3 + env), 0.0));
        o.rgb = min(o.rgb * (1.0 + env * 0.18) + noisy * 0.12 * o.a, float3(o.a));
        break; }
    }
    dst.write(half4(o), gid);
}
