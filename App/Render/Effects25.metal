#include <metal_stdlib>
using namespace metal;

// Batch 25: the shared photographic light engine for the Glow & Light remakes.
//   fxLightPrep25  — light extraction: soft-knee threshold so only bright parts emit (color, alpha, hue-keyed, solid).
//   fxLightSum25   — weighted sum of up to four blur levels (tight core + wide halo pyramid).
//   fxLightComp25  — adds light with a hue-keeping soft shoulder instead of clipping channels to a white sheet.
//   fxStreak25     — star / linear / zoom / god-ray streaks with exponential falloff along the ray.
//   fxLightGen25   — generated light: light sweep, lens flare, light leak.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s25Zero(address::clamp_to_zero, filter::linear, coord::pixel);

static inline float3 un25(float4 c) { return c.a > 1e-5 ? c.rgb / c.a : float3(0.0); }
static inline float lum25(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static inline float maxc25(float3 c) { return max(c.r, max(c.g, c.b)); }
static inline float4 tap25(texture2d<half, access::sample> t, float2 c) { return float4(t.sample(s25Zero, c)); }

static float hash25(float2 q) {
    q = fract(q * float2(123.34, 456.21));
    q += dot(q, q + 45.32);
    return fract(q.x * q.y);
}
static float noise25(float2 q) {
    float2 i = floor(q), f = fract(q);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash25(i), b = hash25(i + float2(1.0, 0.0));
    float c = hash25(i + float2(0.0, 1.0)), d = hash25(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
static float fbm25(float2 q) {
    float s = 0.0, w = 0.5;
    for (int k = 0; k < 4; k++) { s += noise25(q) * w; q = q * 2.03 + float2(7.1, 3.7); w *= 0.5; }
    return s / 0.9375;
}
// Hue rotation around the gray axis (keeps luminance roughly).
static float3 hueRot25(float3 c, float a) {
    float3 k = float3(0.57735);
    float cs = cos(a), sn = sin(a);
    return c * cs + cross(k, c) * sn + k * dot(k, c) * (1.0 - cs);
}
// Smooth spectrum 0..1 -> red..violet (for rainbow glints / chromatic ghosts).
static float3 spectrum25(float x) {
    x = fract(x);
    float3 c = 0.5 + 0.5 * cos(6.2831853 * (x + float3(0.0, 0.33, 0.67)));
    return c * c;
}

// Adds premultiplied light `g` onto premultiplied `s`.
// Coverage comes from the emitted light (dark light never makes a muddy silhouette). Over-range color is
// compressed by a soft shoulder that scales all channels together (hue kept); only real overexposure
// drifts toward white, by `burn` — like film, never a flat white sheet.
static float4 addLight25(float4 s, float3 g, float burn) {
    g = max(g, float3(0.0));
    float gm = maxc25(g);
    float a = clamp(s.a + clamp(gm, 0.0, 1.0) * (1.0 - s.a), 0.0, 1.0);
    float3 rgb = max(s.rgb, float3(0.0)) + g;
    float m = maxc25(rgb);
    if (a > 1e-5 && m > 1e-6) {
        float x = m / a;
        float mb = s.a > 1e-5 ? maxc25(s.rgb) / s.a : 0.0;
        float k = clamp(mb, 0.7, 0.98);
        float y = x <= k ? x : k + (1.0 - k) * tanh(min((x - k) / (1.0 - k), 8.0));
        rgb *= y / x;
        float over = max(x - 1.0, 0.0);
        float w = clamp(burn, 0.0, 1.0) * (1.0 - exp(-over * 0.7));
        float3 white = float3(maxc25(rgb));
        rgb = mix(rgb, white, w);
    }
    return float4(min(rgb, float3(a)), a);
}

// ---------------------------------------------------------------------------------------------
// Light extraction. textures: 0 src, 1 dst.
// a = (threshold, knee, saturation, gain), b = tint rgb (b.w = tint amount 0..1),
// c = hue key (hue 0..1, half range 0..0.5, softness), i.y source: 0 color, 1 alpha, 2 hue key, 3 solid tint × alpha.
kernel void fxLightPrep25(texture2d<half, access::sample> src [[texture(0)]],
                          texture2d<half, access::write> dst [[texture(1)]],
                          constant EffectParams& p [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 s = tap25(src, c);
    float3 u = clamp(un25(s), 0.0, 1.0);
    float thr = clamp(p.a.x, 0.0, 0.99);
    float knee = max(p.a.y, 1e-3);
    float3 light = float3(0.0);
    if (p.i.y == 1u || p.i.y == 3u) {
        // Alpha / solid source: the layer's shape emits the tint (alpha threshold keeps soft edges soft).
        float w = smoothstep(thr - knee * 0.5, thr + knee * 0.5, s.a);
        float3 col = p.i.y == 3u ? p.b.rgb : mix(u, p.b.rgb, clamp(p.b.w, 0.0, 1.0));
        light = col * w * (p.i.y == 3u ? 1.0 : s.a);
    } else {
        // Brightness mixes luma and the max channel so saturated neon (pure red / blue) still emits.
        float br = mix(lum25(u), maxc25(u), 0.5);
        float w;
        if (p.i.y == 2u) {
            float mx = maxc25(u), mn = min(u.r, min(u.g, u.b));
            float d = mx - mn;
            float h = 0.0;
            if (d > 1e-5) {
                if (mx == u.r) h = (u.g - u.b) / d;
                else if (mx == u.g) h = (u.b - u.r) / d + 2.0;
                else h = (u.r - u.g) / d + 4.0;
                h = fract(h / 6.0);
            }
            float sat = mx > 1e-5 ? d / mx : 0.0;
            float dh = abs(fract(h - p.c.x + 0.5) - 0.5);
            w = (1.0 - smoothstep(p.c.y, p.c.y + max(p.c.z, 1e-3), dh)) * smoothstep(0.1, 0.3, sat) * smoothstep(0.05, 0.3, mx);
            w *= 0.4 + 0.6 * mx;
        } else {
            // Soft-knee threshold (photographic bloom): emission grows with how far a pixel is above the threshold.
            float soft = clamp(br - thr + knee, 0.0, 2.0 * knee);
            soft = soft * soft / (4.0 * knee + 1e-4);
            float contrib = max(soft, br - thr) / max(1.0 - thr, 0.05);
            w = clamp(contrib, 0.0, 1.5);
        }
        float3 col = u;
        float l = lum25(col);
        col = max(mix(float3(l), col, p.a.z), float3(0.0));
        col = mix(col, p.b.rgb * max(maxc25(col), l), clamp(p.b.w, 0.0, 1.0));
        light = col * w * s.a;
    }
    light *= p.a.w;
    dst.write(half4(float4(light, clamp(maxc25(light), 0.0, 1.0))), gid);
}

// Weighted sum of blur levels. textures: 0..3 levels, 4 dst. a = weights (negative weights subtract, result >= 0).
kernel void fxLightSum25(texture2d<half, access::sample> t0 [[texture(0)]],
                         texture2d<half, access::sample> t1 [[texture(1)]],
                         texture2d<half, access::sample> t2 [[texture(2)]],
                         texture2d<half, access::sample> t3 [[texture(3)]],
                         texture2d<half, access::write> dst [[texture(4)]],
                         constant EffectParams& p [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float3 g = tap25(t0, c).rgb * p.a.x + tap25(t1, c).rgb * p.a.y + tap25(t2, c).rgb * p.a.z + tap25(t3, c).rgb * p.a.w;
    g = max(g, float3(0.0));
    dst.write(half4(float4(g, clamp(maxc25(g), 0.0, 1.0))), gid);
}

// Composite light over the layer. textures: 0 src, 1 dst, 2 glow, 3 mask (layer shape for inside/outside).
// a = (intensity, saturation, burn, prism spread px), b = tint rgb, c = color A, d = color B,
// i.x op (0 add, 1 screen), i.y composite (0 glow over, 1 original on top, 2 glow only),
// i.z colors (0 original, 1 A&B by glow brightness), i.w mask (0 none, 1 outside the shape only, 2 inside only).
kernel void fxLightComp25(texture2d<half, access::sample> src [[texture(0)]],
                          texture2d<half, access::write> dst [[texture(1)]],
                          texture2d<half, access::sample> glow [[texture(2)]],
                          texture2d<half, access::sample> msk [[texture(3)]],
                          constant EffectParams& p [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float2 gs = float2(glow.get_width(), glow.get_height()) / size;
    float4 s = tap25(src, c);
    float3 g = tap25(glow, c * gs).rgb;
    if (p.a.w > 0.01) {
        // Prism dispersion: red and blue parts of the halo fan apart radially from the frame center.
        float2 dv = c - size * 0.5;
        float L = length(dv);
        float2 dir = L > 1e-3 ? dv / L : float2(1.0, 0.0);
        float rr = tap25(glow, (c - dir * p.a.w) * gs).r;
        float bb = tap25(glow, (c + dir * p.a.w) * gs).b;
        float gg = (tap25(glow, (c - dir * p.a.w * 0.5) * gs).g + g.g) * 0.5;
        g = float3(rr, gg, bb);
    }
    if (p.i.z == 1u) {
        float l = maxc25(g);
        float k = clamp(l, 0.0, 1.0);
        g = mix(p.d.rgb, p.c.rgb, k * k) * l;
    }
    float gl = lum25(g);
    g = max(mix(float3(gl), g, p.a.y), float3(0.0));
    g *= p.b.rgb * p.a.x;
    if (p.i.w == 1u) g *= 1.0 - clamp(tap25(msk, c).a, 0.0, 1.0);
    else if (p.i.w == 2u) g *= clamp(tap25(msk, c).a, 0.0, 1.0);
    float4 o;
    if (p.i.y == 2u) {
        o = addLight25(float4(0.0), g, p.a.z);
    } else {
        float3 gg = g;
        if (p.i.x == 1u) gg = g * (1.0 - clamp(s.rgb, 0.0, 1.0)); // screen: light fades on already-bright pixels
        if (p.i.y == 1u) {
            float4 under = addLight25(float4(0.0), gg, p.a.z);
            o = s + under * (1.0 - s.a);                            // original stays on top of its own glow
        } else {
            o = addLight25(s, gg, p.a.z);
        }
    }
    dst.write(half4(o), gid);
}

// Streaks. textures: 0 light (premultiplied emission, already thresholded), 1 dst.
// i.x mode: 0 star (i.y rays), 1 linear two-sided, 2 zoom from highlights toward/away a center, 3 god rays toward a source.
// a = (center x px, center y px, length px (modes 0/1) or length 0..1 (modes 2/3), rotation rad),
// b = (decay, intensity, rays alternate 0/1, time), c = tint A, d = tint B, i.z rainbow.
kernel void fxStreak25(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float decay = max(p.b.x, 0.1);
    float jitter = hash25(c + fract(p.b.w * 7.13));
    float3 acc = float3(0.0);
    if (p.i.x == 0u || p.i.x == 1u) {
        int rays = p.i.x == 1u ? 2 : clamp(int(p.i.y), 2, 16);
        const int N = 24;
        for (int r = 0; r < 16; r++) {
            if (r >= rays) break;
            float ang = p.a.w + 6.2831853 * float(r) / float(rays);
            float2 dir = float2(cos(ang), sin(ang));
            bool alt = p.b.z > 0.5 && (r & 1) == 1;
            float3 tint = alt ? p.d.rgb : p.c.rgb;
            float rayLen = p.a.z * (alt ? 0.6 : 1.0);
            float3 ray = float3(0.0);
            for (int k = 0; k < N; k++) {
                float f = (float(k) + 0.5 + (jitter - 0.5) * 0.8) / float(N);
                float ff = f * f;                       // denser near the core: tight core, long faint tail
                float w = exp(-decay * f * 3.0) * (1.0 - f) * (1.0 + 2.0 * f) / float(N);
                float3 q = tap25(src, c - dir * rayLen * ff).rgb;
                float3 tt = p.i.z == 1u ? mix(float3(1.0), spectrum25(f * 0.85 + float(r) * 0.11 + p.b.w * 0.15), smoothstep(0.05, 0.4, f)) : float3(1.0);
                ray += q * w * tt * (2.0 * f);          // ff spacing: weight by spacing so energy stays even
            }
            acc += ray * tint;
        }
        acc *= 6.0 / float(rays);
    } else {
        const int N = 40;
        float2 toC = p.a.xy - c;
        float span = clamp(p.a.z, 0.0, 1.0);
        float wsum = 0.0;
        for (int k = 0; k < N; k++) {
            float f = (float(k) + jitter) / float(N);
            float w = exp(-decay * f * 2.5);
            acc += tap25(src, c + toC * f * span).rgb * w;
            wsum += w;
        }
        acc = acc / max(wsum, 1e-3) * (p.i.x == 3u ? 2.2 : 1.6);
        acc *= p.c.rgb;
    }
    acc *= p.b.y;
    dst.write(half4(float4(acc, clamp(maxc25(acc), 0.0, 1.0))), gid);
}

// Generated light. textures: 0 src, 1 dst.
// i.x mode:
//  0 light sweep: a = (dirx, diry, width px, intensity), b = color, c = (speed, offset, softness, bend px),
//    d = (time, irregularity px, contour scale px, evolution rad), i.y = 1 organic contour.
//  1 lens flare: a = (cx, cy, brightness 0..3, scale), b = color, c = (ghosts, streak, rays, halo), d.x = time.
//  2 light leak: a = (intensity, speed, size px, hue rad), c.x = seed, d.x = time.
kernel void fxLightGen25(texture2d<half, access::sample> src [[texture(0)]],
                         texture2d<half, access::write> dst [[texture(1)]],
                         constant EffectParams& p [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = tap25(src, c);
    float t = p.d.x;
    float4 o = s;
    if (p.i.x == 0u) {
        float2 dir = p.a.xy;
        float w = max(p.a.z, 0.5);
        float half_ = 0.5 * (abs(dir.x) * size.x + abs(dir.y) * size.y);
        float proj = dot(c - size * 0.5, dir);
        // Eased travel: the band accelerates in and out of each pass like a hand-keyed sweep.
        float ph = fract(t * p.c.x + p.c.y);
        float eased = ph * ph * (3.0 - 2.0 * ph);
        float center = mix(-half_ - w * 1.5, half_ + w * 1.5, mix(ph, eased, 0.6));
        if (p.i.y == 1u) {
            float tangent = dot(c - size * 0.5, float2(-dir.y, dir.x)) / max(p.d.z, 0.1);
            proj += p.c.w * sin(tangent + p.d.w)
                  + p.d.y * (0.65 * sin(tangent * 2.17 + p.d.w * 1.31) + 0.35 * sin(tangent * 4.73 - p.d.w * 0.73));
        }
        float d = (proj - center) / (w * 0.5);
        float soft = clamp(p.c.z, 0.0, 1.0);
        // Gaussian sheen + a tight hot core; softness widens the sheen and dims the core.
        float sheen = exp(-d * d * mix(4.0, 1.2, soft));
        float core = exp(-d * d * mix(60.0, 14.0, soft)) * (1.0 - soft * 0.6);
        float3 u = clamp(un25(s), 0.0, 1.0);
        float surf = 0.35 + 0.65 * smoothstep(0.0, 0.9, lum25(u));   // shine catches the bright parts more
        float3 light = p.b.rgb * (sheen * 0.55 + core) * surf * p.a.w;
        // A little of the surface color tints the sheen, like a real reflection.
        light = mix(light, light * (0.4 + u), 0.25);
        o = addLight25(s, light * s.a, 0.35);
        o.a = s.a;
        o.rgb = min(o.rgb, float3(o.a));
    } else if (p.i.x == 1u) {
        float diag = length(size);
        float sc = max(p.a.w, 0.05);
        float2 v = (c - p.a.xy) / (diag * sc);
        float r = length(v);
        float ang = atan2(v.y, v.x);
        float3 tint = p.b.rgb;
        float3 col = float3(0.0);
        // Hot core + soft bloom: warm, white-hot only in the very center.
        col += mix(tint, float3(1.0), 0.7) * exp(-r * 70.0) * 1.6;
        col += tint * exp(-r * 14.0) * 0.55;
        col += tint * float3(1.0, 0.8, 0.6) * exp(-r * 4.0) * 0.12;
        // Starburst rays: irregular widths and lengths, shimmering slowly.
        float rays = 0.0;
        for (int k = 0; k < 3; k++) {
            float fq = float(6 + k * 5);
            float n = noise25(float2(ang * fq * 0.5 + float(k) * 13.0, t * 0.6));
            float ray = pow(clamp(0.5 + 0.5 * cos(ang * fq + float(k) * 1.7 + n * 2.0), 0.0, 1.0), 40.0 + float(k) * 30.0);
            rays += ray * (0.6 + 0.6 * n) / (1.0 + float(k));
        }
        col += tint * rays * exp(-r * mix(9.0, 5.0, 0.5)) * 0.9 * p.c.z;
        // Anamorphic streak through the source.
        float2 dv = (c - p.a.xy) / diag;
        float streak = exp(-abs(dv.y) / (0.0022 * sc)) * exp(-abs(dv.x) / (0.38 * sc));
        col += float3(0.55, 0.75, 1.0) * streak * 0.9 * p.c.y;
        // Halo ring with a chromatic rim (red outside, blue inside).
        float3 Rr = float3(0.205, 0.198, 0.19);
        float3 re = (float3(r) - Rr) / 0.011;
        float3 ring = exp(-re * re);
        col += ring * float3(1.0, 0.85, 0.9) * 0.22 * p.c.w;
        // Ghosts along the line from the source through the frame center.
        float2 axis = size * 0.5 - p.a.xy;
        float ghostPos[6] = {0.35, 0.62, 1.15, 1.45, 1.8, 2.25};
        float ghostSize[6] = {0.018, 0.045, 0.03, 0.08, 0.022, 0.12};
        for (int k = 0; k < 6; k++) {
            float2 gp = p.a.xy + axis * ghostPos[k];
            float gd = length(c - gp) / (diag * sc);
            float gsz = ghostSize[k];
            float3 gcol = spectrum25(float(k) * 0.17 + 0.05) * 0.6 + tint * 0.4;
            // Chromatic edge: each channel's disc is a slightly different size.
            float3 disc = float3(1.0) - smoothstep(float3(gsz * 0.82, gsz * 0.9, gsz * 0.98), float3(gsz * 0.98, gsz * 1.04, gsz * 1.1), float3(gd));
            float rim = 0.55 + 0.45 * smoothstep(gsz * 0.3, gsz, gd);
            col += disc * rim * gcol * (k == 5 ? 0.05 : 0.11) * p.c.x;
        }
        col *= p.a.z;
        o = addLight25(s, col, 0.45);
    } else {
        float sc = max(p.a.z, 1.0);
        float seed = p.c.x;
        float tt = t * p.a.y;
        float3 base = float3(1.0, 0.42, 0.1);
        float3 acc = float3(0.0);
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            // Blobs drift in from the frame edges and breathe, never sitting still.
            float side = (k == 1) ? 1.0 : 0.0;
            float2 ctr;
            ctr.x = mix(-0.1, 0.32, noise25(float2(tt * 0.11 + fk * 3.1, seed)));
            ctr.x = side > 0.5 ? size.x - ctr.x * size.x : ctr.x * size.x;
            ctr.y = mix(-0.1, 1.1, noise25(float2(tt * 0.07 + fk * 5.7, seed * 1.7 + 4.0))) * size.y;
            float rad = sc * (0.8 + 0.7 * noise25(float2(tt * 0.13 + fk * 9.1, seed + 2.0)));
            float2 q = (c - ctr) / rad;
            float warp = fbm25(c / (sc * 0.7) + float2(tt * 0.05 + fk * 11.0, seed));
            float dd = length(q) * (0.75 + 0.5 * warp);
            float field = exp(-dd * dd * 1.6);
            float breathe = 0.65 + 0.35 * sin(tt * (0.7 + fk * 0.3) + fk * 2.0 + seed);
            float3 col = hueRot25(base, p.a.w + (fk - 1.0) * 0.35);
            col = max(col, float3(0.0));
            col = mix(col, float3(1.0, 0.93, 0.78), field * field * 0.45);  // hot center of the leak
            acc += col * field * breathe;
        }
        // Gentle overall flash lift where the leak is strongest.
        float3 leak = acc * p.a.x;
        leak += float3(1.0, 0.8, 0.6) * maxc25(acc) * 0.05 * p.a.x;
        o = addLight25(s, leak * (1.0 - clamp(s.rgb, 0.0, 1.0) * 0.5), 0.3);
    }
    dst.write(half4(o), gid);
}
