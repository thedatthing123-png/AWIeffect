#include <metal_stdlib>
using namespace metal;

// Batch 18: edit essentials — Twitch-style glitch bursts and a manga negative / mono flash.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler sm18(address::clamp_to_zero, filter::linear, coord::pixel);

static inline float h18(float x) { return fract(sin(x * 127.1 + 311.7) * 43758.5453); }
static inline float h182(float2 p) { return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
static inline float lum18(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

kernel void fx18(texture2d<half, access::sample> src [[texture(0)]],
                 texture2d<half, access::write> dst [[texture(1)]],
                 texture2d<half, access::sample> aux [[texture(2)]],
                 constant EffectParams& p [[buffer(0)]],
                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float t = p.d.x;
    float4 o;
    if (p.i.x == 0) {
        // Twitch: a = (intensity 0-1, bursts per second, burst length 0-1, seed)
        //         b = (rgb split px, slice px, flash 0-1, blur px)
        float slot = floor(t * max(p.a.y, 0.01));
        float phase = fract(t * max(p.a.y, 0.01));
        // Every other burst always fires (plus random extras), so the rhythm stays readable.
        bool fire = slot < 0.5 || fmod(slot, 2.0) >= 1.0 || h18(slot + p.a.w * 13.0) < 0.5;
        float on = (fire && phase < max(p.a.z, 0.02)) ? 1.0 : 0.0;
        float k = on * p.a.x * (0.5 + 0.5 * h18(slot * 3.1 + p.a.w));
        float fr = floor(t * 30.0);
        // Horizontal slice offsets.
        float band = floor(c.y / max(size.y / 18.0, 2.0));
        float sl = (h182(float2(band, fr + p.a.w)) - 0.5) * 2.0 * p.b.y * k * step(0.55, h182(float2(band * 1.7, fr)));
        float2 q = c + float2(sl, 0.0);
        // Directional jitter blur.
        float bl = p.b.w * k;
        float4 acc = float4(0.0);
        for (int s = -2; s <= 2; s++) acc += float4(src.sample(sm18, q + float2(float(s) * bl * 0.5, 0.0)));
        float4 base = acc / 5.0;
        float split = p.b.x * k;
        float r = float(src.sample(sm18, q + float2(split, 0.0)).r);
        float b = float(src.sample(sm18, q - float2(split, 0.0)).b);
        o = float4(r, base.g, b, base.a);
        o.a = max(o.a, max(float(src.sample(sm18, q + float2(split, 0.0)).a), float(src.sample(sm18, q - float2(split, 0.0)).a)));
        o.rgb = min(o.rgb + p.b.z * k * o.a, float3(o.a));
    } else if (p.i.x == 2) {
        // Warp Chroma: a = (amount px, channel spread 0-1, angle rad, -)
        float2 e = float2(1.5, 0.0);
        float lx = lum18(float3(src.sample(sm18, c + e.xy).rgb)) - lum18(float3(src.sample(sm18, c - e.xy).rgb));
        float ly = lum18(float3(src.sample(sm18, c + e.yx).rgb)) - lum18(float3(src.sample(sm18, c - e.yx).rgb));
        float2 g = float2(lx, ly);
        float cs = cos(p.a.z), sn = sin(p.a.z);
        g = float2(g.x * cs - g.y * sn, g.x * sn + g.y * cs) * p.a.x * 4.0;
        float4 cr = float4(src.sample(sm18, c + g * (1.0 + p.a.y)));
        float4 cg = float4(src.sample(sm18, c + g));
        float4 cb = float4(src.sample(sm18, c + g * (1.0 - p.a.y)));
        o = float4(cr.r, cg.g, cb.b, max(cg.a, max(cr.a, cb.a)));
    } else if (p.i.x == 3) {
        // Scanline Tear: a = (amount px, band height 0-1, speed, jagged px)
        float center = fract(t * p.a.z * 0.3 + 0.37) * size.y;
        float half_ = max(p.a.y * size.y * 0.5, 1.0);
        float inBand = 1.0 - smoothstep(half_ * 0.8, half_, abs(c.y - center));
        float row = floor(c.y / max(p.a.w, 1.0));
        float sh = (h182(float2(row, floor(t * 24.0))) - 0.5) * 2.0 * p.a.x * inBand;
        o = float4(src.sample(sm18, c + float2(sh, 0.0)));
    } else if (p.i.x == 4) {
        // Wave Glitch: a = (amount px, waves, speed, steps/s)
        float tq = floor(t * max(p.a.w, 0.5)) / max(p.a.w, 0.5);
        float sh = p.a.x * sin(c.y / size.y * p.a.y * 6.2831853 + tq * p.a.z * 6.2831853);
        o = float4(src.sample(sm18, c + float2(sh, 0.0)));
    } else if (p.i.x == 5) {
        // Block Shuffle: a = (block px, chance 0-1, rate fps, seed)
        float bs = max(p.a.x, 2.0);
        float2 blk = floor(c / bs);
        float fr = floor(t * max(p.a.z, 0.5));
        float2 q = c;
        if (h182(blk + float2(fr * 1.37, p.a.w)) < p.a.y) {
            float2 other = floor(float2(h182(blk + fr + 3.1), h182(blk.yx + fr + 7.7)) * size / bs);
            q = other * bs + fmod(c, bs);
        }
        o = float4(src.sample(sm18, q));
    } else if (p.i.x == 6) {
        // Channel Smear: a = (length px, angle rad, spread 0-1, -)
        float2 dir = float2(cos(p.a.y), sin(p.a.y));
        float3 len = float3(1.0, 1.0 - p.a.z * 0.5, 1.0 - p.a.z) * p.a.x;
        float4 acc = float4(0.0);
        for (int k = 0; k < 10; k++) {
            float f = float(k) / 9.0;
            acc.r += float(src.sample(sm18, c - dir * len.r * f).r);
            acc.g += float(src.sample(sm18, c - dir * len.g * f).g);
            acc.b += float(src.sample(sm18, c - dir * len.b * f).b);
            acc.a += float(src.sample(sm18, c - dir * len.r * f).a);
        }
        o = acc / 10.0;
        o.rgb = min(o.rgb, float3(max(o.a, 1e-4)));
    } else {
        // Negative / mono flash: a = (flashes per second, mix 0-1, mode 0 negative 1 mono threshold 2 both, threshold)
        float4 s = float4(src.sample(sm18, c));
        float fr = floor(t * max(p.a.x, 0.01));
        float on = fmod(fr, 2.0) >= 1.0 ? 1.0 : 0.0;
        float3 col = s.a > 0.0 ? s.rgb / s.a : float3(0.0);
        float3 neg = 1.0 - col;
        float3 mono = float3(step(p.a.w, lum18(col)));
        float3 fx = p.a.z < 0.5 ? neg : (p.a.z < 1.5 ? mono : (fmod(fr, 4.0) < 2.0 ? neg : 1.0 - mono));
        col = mix(col, fx, on * p.a.y);
        o = float4(col * s.a, s.a);
    }
    dst.write(half4(o), gid);
}

// Puppet Pins: rigid moving-least-squares warp (Schaefer et al.), solved backwards (deformed pins -> rest pins)
// so each output pixel finds where to read the source. pins[k] = (restX, restY, deformedX, deformedY), layer px.
// a = (stiffness exponent, unit = texture px per layer px, -, -), i.y = pin count.
kernel void fxPuppet(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     constant EffectParams& p [[buffer(0)]],
                     constant float4* pins [[buffer(1)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float unit = max(p.a.y, 1e-4);
    float2 v = (c - size * 0.5) / unit;
    uint n = min(p.i.y, 32u);
    if (n == 0) { dst.write(src.sample(sm18, c), gid); return; }
    float wsum = 0.0; float2 qs = 0.0, ps = 0.0;
    for (uint k = 0; k < n; k++) {
        float2 q = pins[k].zw, r = pins[k].xy;
        float w = 1.0 / pow(max(dot(q - v, q - v), 1.0), p.a.x);
        if ((p.i.z >> k) & 1u) w *= 8.0;
        wsum += w; qs += w * q; ps += w * r;
    }
    qs /= wsum; ps /= wsum;
    float2 f;
    if (n == 1) {
        f = v + (ps - qs);
    } else {
        // Complex-number form: T = sum w conj(qh) ph, rotation of d = v - q* by T, length kept (rigid).
        float2 T = 0.0;
        float2 d = v - qs;
        for (uint k = 0; k < n; k++) {
            float2 q = pins[k].zw - qs, r = pins[k].xy - ps;
            float w = 1.0 / pow(max(dot(pins[k].zw - v, pins[k].zw - v), 1.0), p.a.x);
            if ((p.i.z >> k) & 1u) w *= 8.0;
            T += w * float2(q.x * r.x + q.y * r.y, q.x * r.y - q.y * r.x);
        }
        float tl = length(T);
        float2 rot = tl > 1e-8 ? T / tl : float2(1.0, 0.0);
        f = ps + float2(d.x * rot.x - d.y * rot.y, d.x * rot.y + d.y * rot.x);
    }
    dst.write(src.sample(sm18, size * 0.5 + f * unit), gid);
}

// CC Studio Grade. a = (exposure EV, contrast, highlights, shadows), b = (temp, tint, vibrance, saturation),
// c = (hsl hue 0-1, hsl range 0-1, hsl shift 0-1, split 0-1), d = (hsl sat, hsl light, lut strength, -), i.x = lut on.
// wheels[0..2] = lift / gamma / gain rgb (-1..1). curve: 256x1 (r,g,b). lut: 3D.
static float3 hsv18(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
static float3 rgb18(float3 c) {
    float3 p = abs(fract(c.xxx + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(float3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
kernel void fxGrade(texture2d<half, access::sample> src [[texture(0)]],
                    texture2d<half, access::write> dst [[texture(1)]],
                    texture2d<half, access::sample> curve [[texture(2)]],
                    texture3d<half, access::sample> lut [[texture(3)]],
                    constant EffectParams& p [[buffer(0)]],
                    constant float4* wheels [[buffer(1)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 s = float4(src.read(gid));
    if (p.c.w > 0.0 && float(gid.x) < p.c.w * float(dst.get_width())) { dst.write(half4(s), gid); return; }
    if (s.a <= 0.0) { dst.write(half4(s), gid); return; }
    float3 c = s.rgb / s.a;
    // Exposure in (approximately) linear light.
    c = pow(max(c, 0.0), 2.2) * exp2(p.a.x); c = pow(max(c, 0.0), 1.0 / 2.2);
    // White balance.
    c += float3(p.b.x * 0.12, p.b.y * 0.12, -p.b.x * 0.12);
    // Contrast around mid grey.
    c = (c - 0.5) * (1.0 + p.a.y) + 0.5;
    // Highlights / shadows.
    float l = dot(clamp(c, 0.0, 1.0), float3(0.2126, 0.7152, 0.0722));
    c += p.a.z * 0.3 * smoothstep(0.45, 1.0, l) + p.a.w * 0.3 * (1.0 - smoothstep(0.0, 0.55, l));
    // Lift / gamma / gain.
    float3 lift = wheels[0].rgb * 0.25, gam = wheels[1].rgb, gain = 1.0 + wheels[2].rgb * 0.5;
    c = clamp(c * gain + lift * (1.0 - c), 0.0, 1.0);
    c = pow(c, exp2(-gam));
    // Curves (master then channel), from the lookup.
    constexpr sampler cs(address::clamp_to_edge, filter::linear, coord::normalized);
    c = float3(float(curve.sample(cs, float2(c.r, 0.5)).r), float(curve.sample(cs, float2(c.g, 0.5)).g), float(curve.sample(cs, float2(c.b, 0.5)).b));
    // Saturation + vibrance (vibrance boosts dull colors more).
    l = dot(c, float3(0.2126, 0.7152, 0.0722));
    float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    c = l + (c - l) * (1.0 + p.b.w + p.b.z * (1.0 - sat));
    // HSL secondary: only hues near the target change.
    float3 h = hsv18(clamp(c, 0.0, 1.0));
    float dh = abs(fract(h.x - p.c.x + 0.5) - 0.5);
    float w = 1.0 - smoothstep(p.c.y * 0.5, p.c.y, dh);
    if (w > 0.0) {
        h.x = fract(h.x + p.c.z * w);
        h.y = clamp(h.y * (1.0 + p.d.x * w), 0.0, 1.0);
        h.z = clamp(h.z + p.d.y * 0.5 * w, 0.0, 1.0);
        c = rgb18(h);
    }
    // LUT.
    if (p.i.x == 1) {
        float n = float(lut.get_width());
        float3 uvw = clamp(c, 0.0, 1.0) * ((n - 1.0) / n) + 0.5 / n;
        constexpr sampler ls(address::clamp_to_edge, filter::linear, coord::normalized);
        c = mix(c, float3(lut.sample(ls, uvw).rgb), p.d.z);
    }
    c = clamp(c, 0.0, 1.0);
    dst.write(half4(half3(c * s.a), half(s.a)), gid);
}

// Layer-referencing effects. aux = the chosen layer, already aligned to this layer's buffer.
// i.x 0 = displacement map: a = (max horizontal px, max vertical px, source mode 0 luma / 1 red-green, -)
// i.x 1 = set matte: a = (mode 0 alpha / 1 luma, invert, -, -)
kernel void fxLayerRef(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       texture2d<half, access::sample> aux [[texture(2)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 m = float4(aux.sample(sm18, c));
    float3 mc = m.a > 0.0 ? m.rgb / m.a : float3(0.0);
    if (p.i.x == 0) {
        float hx = p.a.z < 0.5 ? lum18(mc) : mc.r;
        float hy = p.a.z < 0.5 ? lum18(mc) : mc.g;
        // Mid grey = no move (AE): darker pushes one way, brighter the other; transparent map areas don't move.
        float2 d = float2((hx - 0.5) * 2.0 * p.a.x, (hy - 0.5) * 2.0 * p.a.y) * m.a;
        dst.write(src.sample(sm18, c + d), gid);
    } else {
        float4 s = float4(src.sample(sm18, c));
        float k = p.a.x < 0.5 ? m.a : lum18(mc) * m.a;
        if (p.a.y > 0.5) k = 1.0 - k;
        dst.write(half4(s * k), gid);
    }
}
