#include <metal_stdlib>
using namespace metal;

// Batch 19: the glitch pack (designed bursts: calm gaps, big hits, small jitter, rare spikes, held pieces that
// snap), plus the color-keeping Deep Glow combine and the chroma-key invert.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler sm19(address::clamp_to_zero, filter::linear, coord::pixel);

static inline float h19(float x) { return fract(sin(x * 127.1 + 311.7) * 43758.5453); }
static inline float h192(float2 p) { return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
static inline float lum19(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static inline float4 S(texture2d<half, access::sample> t, float2 p) { return float4(t.sample(sm19, p)); }

/// Burst envelope: hits fire on every other slot plus random extras; each hit attacks instantly and decays
/// (`len` = how long it rings, 0-1 of a slot), with its own random strength.
static inline float burst19(float t, float rate, float len, float seed) {
    float r = max(rate, 0.01);
    float s = floor(t * r), ph = fract(t * r);
    bool fire = fmod(s, 2.0) >= 1.0 || h19(s * 1.37 + seed) < 0.45;
    if (!fire) return 0.0;
    return exp(-ph / max(len, 0.02) * 2.5) * (0.6 + 0.4 * h19(s * 3.1 + seed));
}

/// Layered glitch timing: always-on base + main bursts + fast small jitter + rare big spikes.
/// b = (base 0-1, bursts per second, burst length 0-1, seed)
static inline float glitchK(float t, float4 b) {
    float main = burst19(t, b.y, b.z, b.w);
    float jitter = burst19(t, b.y * 3.7, b.z * 0.5, b.w + 17.0) * 0.35;
    float spike = burst19(t, b.y * 0.37, 0.15, b.w + 41.0) * (h19(floor(t * b.y * 0.37) + b.w) > 0.7 ? 0.8 : 0.0);
    return b.x + main + jitter + spike;
}

/// Pieces hold for a couple of frames, then snap to new places (12 steps per second).
static inline float held19(float t) { return floor(t * 12.0); }

kernel void fx19(texture2d<half, access::sample> src [[texture(0)]],
                 texture2d<half, access::write> dst [[texture(1)]],
                 texture2d<half, access::sample> aux [[texture(2)]],
                 constant EffectParams& p [[buffer(0)]],
                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float t = p.d.x;
    float k = glitchK(t, p.b);
    float fr = held19(t) + p.b.w * 7.0;
    float4 o;
    switch (p.i.x) {
    case 0: {
        // Slice Glitch: a = (offset px, slices, rgb px, -)
        float rows = max(p.a.y, 1.0);
        float band = floor(c.y / (size.y / rows));
        float on = step(0.45, h192(float2(band * 1.7, fr)));
        float off = (h192(float2(band, fr)) - 0.5) * 2.0 * p.a.x * k * on;
        float2 q = c + float2(off, 0.0);
        float sp = p.a.z * k * on;
        float4 g = S(src, q);
        float4 r = S(src, q + float2(sp, 0.0)), bl = S(src, q - float2(sp, 0.0));
        o = float4(r.r, g.g, bl.b, max(g.a, max(r.a, bl.a)));
        break; }
    case 1: {
        // Datamosh: a = (smear px, block px, stuck 0-1, -) — blocks drag their pixels along a motion field.
        float bs = max(p.a.y, 2.0);
        float2 blk = floor(c / bs);
        float2 dir = float2(h192(blk + fr * 0.13) - 0.5, h192(blk * 1.3 + 7.0 + fr * 0.07) - 0.5) * 2.0;
        float moving = step(0.35, h192(blk * 2.1 + floor(fr / 3.0)));
        float2 v = dir * p.a.x * k * moving;
        float4 acc = float4(0.0);
        for (int s = 0; s < 8; s++) acc += S(src, c - v * (float(s) / 7.0));
        o = acc / 8.0;
        // Stuck blocks keep one corner's color (frozen compression block).
        float stuck = step(1.0 - p.a.z * min(k, 1.0) * 0.6, h192(blk * 3.7 + floor(fr / 2.0)));
        o = mix(o, S(src, (blk + 0.5) * bs + v), stuck);
        break; }
    case 2: {
        // Pixel Sort: a = (length px, threshold 0-1, angle rad, -) — bright runs streak along the direction.
        float2 d = float2(cos(p.a.z), sin(p.a.z));
        float L = p.a.x * min(k, 1.5);
        o = S(src, c);
        float best = lum19(o.rgb);
        for (int s = 1; s <= 24; s++) {
            float4 q = S(src, c - d * (L * float(s) / 24.0));
            float l = lum19(q.rgb);
            if (l > p.a.y && l > best) { best = l; o = mix(o, q, 1.0 - float(s) / 30.0); }
        }
        break; }
    case 3: {
        // JPEG Corruption: a = (damage 0-1, block px, color bleed px, -)
        float bs = max(p.a.y, 2.0);
        float2 blk = floor(c / bs);
        float4 avg = (S(src, (blk + 0.25) * bs) + S(src, (blk + 0.75) * bs) + S(src, (blk + float2(0.25, 0.75)) * bs) + S(src, (blk + float2(0.75, 0.25)) * bs)) / 4.0;
        float4 px = S(src, c);
        float dmg = clamp(p.a.x * k, 0.0, 1.0);
        // Quantize toward the block average (blocky), with ringing near edges.
        float levels = mix(32.0, 4.0, dmg);
        float3 q = floor(mix(px.rgb, avg.rgb, dmg * 0.8) * levels + 0.5) / levels;
        float ring = sin((c.x - blk.x * bs) * 3.14159 * 2.0 / bs) * sin((c.y - blk.y * bs) * 3.14159 * 2.0 / bs) * 0.06 * dmg;
        q += ring * px.a;
        // Chroma bleed: color sampled off to the side (subsampled chroma).
        float3 side = S(src, c + float2(p.a.z * k, 0.0)).rgb;
        float Y = lum19(q);
        float3 chroma = side - lum19(side);
        q = Y + chroma;
        // A few blocks shift hue completely.
        float bad = step(1.0 - dmg * 0.25, h192(blk + floor(fr / 2.0)));
        q = mix(q, q.gbr, bad);
        o = float4(clamp(q, 0.0, px.a), px.a);
        break; }
    case 4: {
        // VHS Tracking: a = (tracking px, band 0-1, roll speed, noise 0-1), c.x = color bleed px
        float bandY = fract(t * p.a.z * 0.25 + p.b.w * 0.1) * (size.y * 1.4) - size.y * 0.2;
        float bh = max(p.a.y * size.y * 0.5, 2.0);
        float inBand = exp(-pow((c.y - bandY) / bh, 2.0));
        float wob = sin(c.y * 0.05 + t * 9.0) * 0.3 + (h19(floor(c.y / 2.0) + fr) - 0.5);
        float off = (inBand * 1.5 + 0.15) * wob * p.a.x * min(k, 1.5);
        float2 q = c + float2(off, 0.0);
        float bleed = p.c.x * (0.5 + 0.5 * min(k, 1.0));
        float4 g = S(src, q);
        float4 r = S(src, q + float2(bleed, 0.0)), b = S(src, q - float2(bleed * 0.6, 0.0));
        o = float4(r.r, g.g, b.b, max(g.a, max(r.a, b.a)));
        float n = (h192(float2(floor(c.x / 2.0), floor(c.y) + fr * 3.0)) - 0.5) * p.a.w * (0.25 + inBand);
        o.rgb = clamp(o.rgb + n * o.a, 0.0, o.a);
        // Bright tape line in the band.
        o.rgb = min(o.rgb + inBand * step(0.92, h19(floor(c.y) + fr)) * 0.5 * o.a, float3(o.a));
        break; }
    case 5: {
        // Signal Loss: a = (static 0-1, bars 0-1, drop strength 0-1, -)
        float drop = clamp(k * p.a.z, 0.0, 1.0);
        float4 px = S(src, c + float2((h19(floor(c.y / 6.0) + fr) - 0.5) * 40.0 * drop, 0.0));
        float st = h192(floor(c / 2.0) + fr * 11.0);
        float3 bars = float3(step(0.5, fract(c.x / size.x * 7.0)), step(0.5, fract(c.x / size.x * 3.5)), step(0.5, fract(c.x / size.x * 14.0)));
        float3 junk = mix(float3(st), bars, p.a.y);
        float a = max(px.a, drop);
        o = float4(mix(px.rgb, junk * a, drop * max(p.a.x, p.a.y)), a);
        break; }
    case 6: {
        // Interlace / Bad TV: a = (split px, wobble px, scanlines 0-1, -)
        float odd = fmod(floor(c.y), 2.0) < 1.0 ? 1.0 : -1.0;
        float wob = sin(c.y * 0.02 + t * 6.0) * p.a.y * min(k, 1.5);
        float2 q = c + float2(odd * p.a.x * k + wob, 0.0);
        o = S(src, q);
        o.rgb *= 1.0 - p.a.z * 0.5 * step(0.0, odd);
        break; }
    case 7: {
        // Block Corruption: a = (amount 0-1, block px, color shift 0-1, -)
        float bs = max(p.a.y, 2.0);
        float2 blk = floor(c / bs);
        float hit = step(1.0 - clamp(p.a.x * k, 0.0, 1.0) * 0.5, h192(blk * 1.9 + floor(fr / 2.0)));
        float4 px = S(src, c);
        float4 frozen = S(src, (blk + float2(h192(blk), h192(blk + 3.0))) * bs);
        float3 wrong = mix(frozen.rgb, frozen.brg, p.a.z);
        o = mix(px, float4(wrong, frozen.a), hit);
        break; }
    case 8: {
        // Stutter Jump: a = (jump px, ghost 0-1, zoom 0-1, -) — the picture jumps between held spots.
        float j = floor(fr / 2.0);
        float2 off = float2(h19(j) - 0.5, h19(j + 9.0) - 0.5) * 2.0 * p.a.x * k;
        float z = 1.0 + (h19(j + 4.0) - 0.5) * p.a.z * 0.3 * min(k, 1.5);
        float2 q = (c - size * 0.5) / z + size * 0.5 + off;
        float2 prevOff = float2(h19(j - 1.0) - 0.5, h19(j + 8.0) - 0.5) * 2.0 * p.a.x * k;
        o = mix(S(src, q), S(src, c + prevOff), p.a.y * 0.5);
        break; }
    case 9: {
        // Mirror Tile Glitch: a = (tiles, flip amount 0-1, offset px, -)
        float n = max(p.a.x, 1.0);
        float2 tile = size / n;
        float2 id = floor(c / tile);
        float2 local = c - id * tile;
        float r = h192(id + floor(fr / 3.0));
        float f = clamp(p.a.y * k, 0.0, 1.0);
        if (r < f * 0.5) local.x = tile.x - local.x;
        else if (r < f) local.y = tile.y - local.y;
        float2 sh = (float2(h192(id * 2.0 + fr), h192(id * 3.0 + fr)) - 0.5) * p.a.z * k * step(0.6, r);
        o = S(src, id * tile + local + sh);
        break; }
    case 10: {
        // Slit Scan: a = (stretch px, frequency, speed, angle rad) — rows slide by a traveling wave.
        float2 d = float2(cos(p.a.w), sin(p.a.w));
        float2 nrm = float2(-d.y, d.x);
        float along = dot(c, nrm);
        float w = sin(along * p.a.y * 0.01 + t * p.a.z) + 0.5 * sin(along * p.a.y * 0.023 - t * p.a.z * 1.7);
        o = S(src, c + d * w * p.a.x * min(k, 1.5));
        break; }
    case 11: {
        // Chroma Shatter: a = (shards, push px, rgb px, -) — Voronoi shards each shift with a color split.
        float n = max(p.a.x, 2.0);
        float2 g = c / size * n;
        float2 cell = floor(g);
        float best = 1e9; float2 id = cell;
        for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
            float2 cc = cell + float2(x, y);
            float2 pt = cc + float2(h192(cc), h192(cc + 5.3));
            float dd = distance(g, pt);
            if (dd < best) { best = dd; id = cc; }
        }
        float r = h192(id + floor(fr / 3.0));
        float2 push = (float2(h192(id * 1.7 + fr), h192(id * 2.9 + fr)) - 0.5) * 2.0 * p.a.y * k * step(0.4, r);
        float sp = p.a.z * k * step(0.4, r);
        float4 gg = S(src, c + push);
        float4 rr = S(src, c + push + float2(sp, 0.0)), bb = S(src, c + push - float2(sp, 0.0));
        o = float4(rr.r, gg.g, bb.b, max(gg.a, max(rr.a, bb.a)));
        break; }
    case 12: {
        // Glitch Flash: a = (invert 0-1, shift px, flash 0-1, -)
        float hit = clamp(k, 0.0, 1.0);
        float sp = p.a.y * hit;
        float4 g = S(src, c);
        float4 r = S(src, c + float2(sp, -sp * 0.3));
        o = float4(r.r, g.g, g.b, max(g.a, r.a));
        float3 inv = o.a - o.rgb;
        o.rgb = mix(o.rgb, inv, p.a.x * hit);
        o.rgb = min(o.rgb + p.a.z * hit * hit * o.a, float3(o.a));
        break; }
    default: {
        // Displacement Glitch: a = (amount px, block px, steps/s, vertical 0-1)
        float bs = max(p.a.y, 2.0);
        float st = floor(t * max(p.a.z, 1.0)) + p.b.w * 3.0;
        float2 blk = floor(c / float2(bs * 4.0, bs));
        float nx = h192(blk + st) - 0.5, ny = h192(blk * 1.3 + st + 2.0) - 0.5;
        float on = step(0.5, h192(blk * 0.7 + st * 0.31));
        o = S(src, c + float2(nx, ny * p.a.w) * 2.0 * p.a.x * k * on);
        break; }
    }
    dst.write(half4(o), gid);
}

/// Deep Glow combine that keeps the subject's colors: the glow adds light in the subject's own hue, and when a
/// pixel would pass full brightness it is scaled down as a whole (never pushed toward white).
/// textures: 0 src, 1 dst, 2 glow.  a = (strength, saturation boost, -, -), b = tint (white = none)
kernel void fx19GlowKeep(texture2d<half, access::sample> src [[texture(0)]],
                         texture2d<half, access::write> dst [[texture(1)]],
                         texture2d<half, access::sample> glow [[texture(2)]],
                         constant EffectParams& p [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 s = S(src, c);
    float4 g = S(glow, c * float2(glow.get_width(), glow.get_height()) / float2(dst.get_width(), dst.get_height()));
    g.rgb *= p.b.rgb;
    // Saturation boost on the glow (straight color), so halos look rich instead of milky.
    if (g.a > 1e-4) {
        float3 gs = g.rgb / g.a;
        float l = lum19(gs);
        gs = max(mix(float3(l), gs, 1.0 + p.a.y), 0.0);
        g.rgb = gs * g.a;
    }
    float k = p.a.x;
    float3 rgb = s.rgb + g.rgb * k;
    float a = clamp(s.a + g.a * k * (1.0 - s.a), 0.0, 1.0);
    // Hue-keeping limit: scale the whole color down instead of clipping channels to white.
    float m = max(rgb.r, max(rgb.g, rgb.b));
    if (m > a && m > 1e-5) rgb *= a / m;
    dst.write(half4(float4(rgb, a)), gid);
}

/// Chroma key invert: keep what the key removed. textures: 0 original, 1 dst, 2 keyed.
kernel void fx19KeyInvert(texture2d<half, access::sample> src [[texture(0)]],
                          texture2d<half, access::write> dst [[texture(1)]],
                          texture2d<half, access::sample> keyed [[texture(2)]],
                          constant EffectParams& p [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 s = S(src, c), k = S(keyed, c);
    float keep = s.a > 1e-4 ? clamp(1.0 - k.a / s.a, 0.0, 1.0) : 0.0;
    dst.write(half4(s * keep), gid);
}
