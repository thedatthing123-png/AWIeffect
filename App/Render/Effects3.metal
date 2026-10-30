#include <metal_stdlib>
using namespace metal;

// Batch 3 effects. rgba16Float premultiplied, sRGB-encoded (same as batches 1-2).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s3Zero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler s3Edge(address::clamp_to_edge, filter::linear, coord::pixel);

static inline float3 um(float4 c) { return c.a > 1e-6 ? c.rgb / c.a : float3(0.0); }
static inline float lm(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float hh(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float hh3(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static float vnz(float3 x) {
    float3 i = floor(x), f = fract(x); float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hh3(i), hh3(i + float3(1, 0, 0)), u.x), mix(hh3(i + float3(0, 1, 0)), hh3(i + float3(1, 1, 0)), u.x), u.y),
               mix(mix(hh3(i + float3(0, 0, 1)), hh3(i + float3(1, 0, 1)), u.x), mix(hh3(i + float3(0, 1, 1)), hh3(i + float3(1, 1, 1)), u.x), u.y), u.z);
}
static float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

// ---------- Generators (draw over the layer; d.w = blend with original 0..1) ----------
// i.x: 0 gradient ramp (a.xy start, a.zw end, b start color, c end color, i.y radial)
//      1 4-color gradient (a.xy p1, a.zw p2, b.xy p3, b.zw p4; c = colors packed as 4 x rgb via d + i… see Swift)
//      2 checkerboard (a.xy anchor, a.z size, b color, c.x opacity)
//      3 grid (a.xy anchor, a.z cell size, a.w line width, b color)
//      4 cell pattern (a.x size, a.y evolution, a.z contrast)
//      5 lightning (a.xy start, a.zw end, b.x seed/time, b.y branching, b.z width, c color)
//      6 lens flare (a.xy center, a.z brightness)
kernel void fxGenerate(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float2 size = float2(dst.get_width(), dst.get_height());
    float4 s = float4(src.sample(s3Zero, c));
    float4 g = float4(0);
    bool additive = false;
    switch (p.i.x) {
        case 0: {
            float t;
            if (p.i.y != 0) t = length(c - p.a.xy) / max(length(p.a.zw - p.a.xy), 1.0);
            else { float2 d = p.a.zw - p.a.xy; t = dot(c - p.a.xy, d) / max(dot(d, d), 1.0); }
            t = clamp(t, 0.0, 1.0);
            g = float4(mix(p.b.rgb, p.c.rgb, t), 1);
            break;
        }
        case 1: {
            // Inverse-distance blend of four colored points.
            float2 pts[4] = { p.a.xy, p.a.zw, p.b.xy, p.b.zw };
            float3 cols[4] = { p.c.rgb, float3(p.c.w, p.d.x, p.d.y), float3(p.d.z, float(p.i.y) / 255.0, float(p.i.z) / 255.0),
                               float3(float(p.i.w & 0xFF) / 255.0, float((p.i.w >> 8) & 0xFF) / 255.0, float((p.i.w >> 16) & 0xFF) / 255.0) };
            float3 acc = 0; float ws = 0;
            for (int k = 0; k < 4; k++) { float w = 1.0 / pow(max(length(c - pts[k]), 1.0), 2.0); acc += cols[k] * w; ws += w; }
            g = float4(acc / ws, 1);
            break;
        }
        case 2: {
            float2 q = floor((c - p.a.xy) / max(p.a.z, 1.0));
            float on = fmod(abs(q.x + q.y), 2.0) < 1.0 ? 1.0 : 0.0;
            g = float4(p.b.rgb, on * p.c.x);
            break;
        }
        case 3: {
            float2 q = fmod(abs(c - p.a.xy), max(p.a.z, 2.0));
            float line = (q.x < p.a.w || q.y < p.a.w) ? 1.0 : 0.0;
            g = float4(p.b.rgb, line);
            break;
        }
        case 4: {
            float2 q = c / max(p.a.x, 2.0);
            float2 i0 = floor(q); float md = 9.0;
            for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
                float2 cell = i0 + float2(x, y);
                float2 o = float2(hh(cell + 0.37), hh(cell + 9.1));
                o = 0.5 + 0.45 * sin(p.a.y * 6.2831 + 6.2831 * o);
                md = min(md, length(cell + o - q));
            }
            float v = clamp((md - 0.5) * p.a.z + 0.5, 0.0, 1.0);
            g = float4(float3(v), 1);
            break;
        }
        case 5: {
            // Jagged bolt: distance to a noisy polyline between start and end.
            float2 a = p.a.xy, b = p.a.zw; float2 d = b - a; float L = max(length(d), 1.0); float2 n = float2(-d.y, d.x) / L;
            float t = clamp(dot(c - a, d) / (L * L), 0.0, 1.0);
            float off = 0; float amp = L * 0.12; float fr = 4.0;
            for (int k = 0; k < 5; k++) { off += (vnz(float3(t * fr, p.b.x, float(k))) - 0.5) * amp; amp *= 0.5; fr *= 2.1; }
            off *= sin(t * M_PI_F);
            float2 q = a + d * t + n * off;
            float dist = length(c - q);
            float core = exp(-dist / max(p.b.z, 0.5));
            float glow = exp(-dist / max(p.b.z * 8.0, 1.0)) * 0.6;
            g = float4(mix(p.c.rgb, float3(1), core) * (core + glow), clamp(core + glow, 0.0, 1.0));
            additive = true;
            break;
        }
        case 6: {
            float2 d = c - p.a.xy; float r = length(d) / length(size);
            float3 col = float3(1.0, 0.85, 0.6) * exp(-r * 18.0) * 1.6;
            col += float3(0.4, 0.6, 1.0) * smoothstep(0.012, 0.0, abs(r - 0.12)) * 0.5;      // ring
            float2 ctr = size * 0.5; float2 axis = ctr - p.a.xy;
            for (int k = 1; k <= 4; k++) {                                                   // ghosts
                float2 gp = p.a.xy + axis * (0.5 * float(k));
                float gd = length(c - gp) / length(size);
                col += float3(0.3 + 0.1 * k, 0.4, 0.9 - 0.15 * k) * smoothstep(0.03 * k, 0.0, gd) * 0.35;
            }
            float streak = exp(-abs(d.y) / 2.5) * exp(-abs(d.x) / (size.x * 0.35)) * 0.8;
            col += float3(1.0, 0.9, 0.8) * streak;
            col *= p.a.z / 100.0;
            g = float4(col, clamp(lm(col), 0.0, 1.0));
            additive = true;
            break;
        }
    }
    float4 o;
    if (additive) { o = s + float4(g.rgb * g.a, 0); o.a = max(s.a, g.a); }
    else {
        float4 gp = float4(g.rgb * g.a, g.a);
        o = gp + s * (1.0 - gp.a);                 // generator over the layer
        o = mix(o, s, p.d.w);                      // blend with original
    }
    dst.write(half4(o), gid);
}

// ---------- Stylize 2 ----------
// i.x: 0 emboss (a.x direction deg, a.y relief, a.z blend), 1 roughen edges (a.x border px, a.y scale px, a.z evolution),
//      2 scatter (a.x amount px), 3 strobe (a.x on 0/1, b color, a.y blend), 4 kaleida (a.xy center, a.z size px, a.w rotation deg, i.y mirrors),
//      5 sharpen (a.x amount), 6 unsharp (needs blurred input in texture 2; a.x amount, a.y threshold)
kernel void fxStylize2(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       texture2d<half, access::sample> aux [[texture(2)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s3Zero, c));
    float4 o = s;
    switch (p.i.x) {
        case 0: {
            float an = p.a.x * M_PI_F / 180.0; float2 d = float2(cos(an), -sin(an)) * max(p.a.y, 0.5);
            float a1 = lm(um(float4(src.sample(s3Edge, c + d)))), a2 = lm(um(float4(src.sample(s3Edge, c - d))));
            float3 e = float3(clamp(0.5 + (a1 - a2) * 2.0, 0.0, 1.0));
            o = float4(mix(e, um(s), p.a.z) * s.a, s.a);
            break;
        }
        case 1: {
            float n = vnz(float3(c / max(p.a.y, 1.0), p.a.z)) * 2.0 - 1.0;
            float2 off = float2(n, vnz(float3(c / max(p.a.y, 1.0) + 7.3, p.a.z)) * 2.0 - 1.0) * p.a.x;
            float a = float(src.sample(s3Zero, c + off).a);
            o = float4(um(s) * a, a);
            break;
        }
        case 2: {
            float2 off = (float2(hh(c), hh(c + 3.7)) - 0.5) * 2.0 * p.a.x;
            o = float4(src.sample(s3Zero, c + off));
            break;
        }
        case 3: {
            if (p.a.x > 0.5) o = float4(mix(um(s), p.b.rgb, p.a.y) * s.a, s.a);
            break;
        }
        case 4: {
            float2 d = c - p.a.xy;
            float n = float(max(p.i.y, 2u));
            float an = atan2(d.y, d.x) - p.a.w * M_PI_F / 180.0;
            float seg = 2.0 * M_PI_F / n;
            an = fmod(an + 100.0 * seg, seg); if (an > seg * 0.5) an = seg - an;     // mirror within each wedge
            float r = fmod(length(d), max(p.a.z, 1.0) * 2.0);
            if (r > p.a.z) r = 2.0 * p.a.z - r;
            o = float4(src.sample(s3Edge, p.a.xy + float2(cos(an), sin(an)) * r));
            break;
        }
        case 5: {
            float4 n = float4(src.sample(s3Edge, c + float2(1, 0))) + float4(src.sample(s3Edge, c - float2(1, 0)))
                     + float4(src.sample(s3Edge, c + float2(0, 1))) + float4(src.sample(s3Edge, c - float2(0, 1)));
            o = s + (s * 4.0 - n) * p.a.x;
            o = float4(clamp(o.rgb, 0.0, 64.0), s.a);
            break;
        }
        case 6: {
            float4 b = float4(aux.sample(s3Zero, c));
            float3 diff = s.rgb - b.rgb;
            float3 mask = step(float3(p.a.y), abs(diff));
            o = float4(clamp(s.rgb + diff * p.a.x * mask, 0.0, 64.0), s.a);
            break;
        }
    }
    dst.write(half4(o), gid);
}

// ---------- Distort 2 ----------
// i.x: 0 ripple (a.xy center, a.z radius, a.w wave width ; b.x height, b.y phase), 1 spherize (a.xy center, a.z radius, a.w amount),
//      2 magnify (a.xy center, a.z magnification, a.w size), 3 corner pin (homography rows in a/b/c: target px -> source px),
//      4 CC lens (a.xy center, a.z size, a.w convergence)
kernel void fxDistort2(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float2 q = c;
    switch (p.i.x) {
        case 0: {
            float2 d = c - p.a.xy; float r = length(d);
            if (r < p.a.z && r > 1e-3) {
                float w = sin(r / max(p.a.w, 1.0) * 2.0 * M_PI_F - p.b.y) * p.b.x * (1.0 - r / p.a.z);
                q = c + d / r * w;
            }
            break;
        }
        case 1: {
            float2 d = c - p.a.xy; float r = length(d) / max(p.a.z, 1.0);
            if (r < 1.0) { float k = mix(1.0, sin(r * M_PI_F * 0.5) / max(r, 1e-4) * (2.0 / M_PI_F), p.a.w); q = p.a.xy + d * k; }
            break;
        }
        case 2: {
            float2 d = c - p.a.xy;
            if (length(d) < p.a.w) q = p.a.xy + d / max(p.a.z, 0.01);
            break;
        }
        case 3: {
            float3 h = float3(c, 1.0);
            float w = dot(p.c.xyz, h);
            if (abs(w) < 1e-6) { dst.write(half4(0.0h), gid); return; }
            q = float2(dot(p.a.xyz, h), dot(p.b.xyz, h)) / w;
            break;
        }
        case 4: {
            float2 d = (c - p.a.xy) / max(p.a.z, 1.0); float r = length(d);
            if (r < 1.0) { float k = pow(r, 1.0 + p.a.w) / max(r, 1e-4); q = p.a.xy + d * k * p.a.z; }
            else { dst.write(half4(0.0h), gid); return; }
            break;
        }
    }
    dst.write(half4(src.sample(s3Zero, q)), gid);
}

// ---------- Transitions (a.x completion 0..1, a.y feather px) ----------
// i.x: 0 linear wipe (a.z angle), 1 radial wipe (a.z start angle, b.xy center, i.y direction 0 cw / 1 ccw), 2 iris (b.xy center, a.z max radius),
//      3 block dissolve (a.z block px), 4 venetian blinds (a.z direction deg, a.w width px), 5 gradient wipe (layer luma, a.y softness 0..1)
kernel void fxTransition(texture2d<half, access::sample> src [[texture(0)]],
                         texture2d<half, access::write> dst [[texture(1)]],
                         constant EffectParams& p [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float2 size = float2(dst.get_width(), dst.get_height());
    float4 s = float4(src.sample(s3Zero, c));
    float t = clamp(p.a.x, 0.0, 1.0), f = max(p.a.y, 0.5);
    float keep = 1.0;
    switch (p.i.x) {
        case 0: {
            float an = p.a.z * M_PI_F / 180.0; float2 dir = float2(sin(an), -cos(an));
            float ext = abs(dir.x) * size.x + abs(dir.y) * size.y;
            float x = dot(c - size * 0.5, dir) + ext * 0.5;           // 0..ext along the wipe
            float edge = mix(-f, ext + f, t);
            keep = smoothstep(edge - f, edge + f, x);
            break;
        }
        case 1: {
            float2 d = c - p.b.xy;
            float an = atan2(d.x, -d.y) - p.a.z * M_PI_F / 180.0;
            an = fmod(an + 4.0 * M_PI_F, 2.0 * M_PI_F) / (2.0 * M_PI_F);
            if (p.i.y != 0) an = 1.0 - an;
            float fe = f / max(length(d), 1.0) / (2.0 * M_PI_F);
            keep = smoothstep(t - fe, t + fe, an);
            break;
        }
        case 2: {
            float r = length(c - p.b.xy), R = p.a.z * (1.0 - t);
            keep = 1.0 - smoothstep(R - f, R + f, r);
            break;
        }
        case 3: {
            float2 cell = floor(c / max(p.a.z, 1.0));
            float fw = f / 500.0;    // feather softens which blocks are mid-dissolve
            keep = smoothstep(t - fw, t + fw, hh(cell * 1.37 + 0.5));
            break;
        }
        case 4: {
            float an = p.a.z * M_PI_F / 180.0; float2 dir = float2(cos(an), sin(an));
            float x = fmod(abs(dot(c, dir)), max(p.a.w, 1.0)) / max(p.a.w, 1.0);
            keep = smoothstep(t - f / p.a.w, t + f / p.a.w, x);
            break;
        }
        case 5: {
            float l = lm(um(s));
            float soft = max(max(p.a.z, f / 300.0), 0.001);
            keep = smoothstep(t * (1.0 + soft) - soft, t * (1.0 + soft), l);
            break;
        }
    }
    dst.write(half4(s * keep), gid);
}

// ---------- Color 3 ----------
// i.x: 0 color balance (a = shadows rgb, b = mids rgb, c = highs rgb ; all -1..1), 1 vibrance (a.x vibrance, a.y saturation),
//      2 black & white (a = reds/yellows/greens/cyans mix, b.x blues, b.y magentas ; b.z tint amount, c tint color)
//      3 photo filter (b color, a.x density, i.y preserve luminosity), 4 tritone (b highlights, c midtones, d shadows, a.x blend)
//      5 leave color (b color to leave, a.x amount to decolor, a.y tolerance), 6 change to color (b from, c to, a.x tolerance, a.y softness)
kernel void fxColor3(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     constant EffectParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s3Zero, c));
    if (s.a <= 0.0) { dst.write(half4(0.0h), gid); return; }
    float3 col = um(s);
    float l = lm(col);
    switch (p.i.x) {
        case 0: {
            float ws = 1.0 - smoothstep(0.0, 0.5, l), wh = smoothstep(0.5, 1.0, l), wm = 1.0 - ws - wh;
            col += (p.a.rgb * ws + p.b.rgb * wm + p.c.rgb * wh) * 0.4;
            break;
        }
        case 1: {
            float mx = max(col.r, max(col.g, col.b)), mn = min(col.r, min(col.g, col.b));
            float sat = mx - mn;
            col = mix(float3(l), col, 1.0 + p.a.x * (1.0 - sat) * 1.5 + p.a.y);
            break;
        }
        case 2: {
            float3 hsv = rgb2hsv(clamp(col, 0.0, 1.0));
            float hues[6] = { p.a.x, p.a.y, p.a.z, p.a.w, p.b.x, p.b.y };
            float h6 = hsv.x * 6.0; int i0 = int(floor(h6)) % 6; int i1 = (i0 + 1) % 6; float fr = fract(h6);
            float w = mix(hues[i0], hues[i1], fr);
            float g = clamp(l + (w - 0.5) * hsv.y * 0.8, 0.0, 1.0);
            col = mix(float3(g), float3(g) * p.c.rgb * 1.2, p.b.z);
            break;
        }
        case 3: {
            float3 f = mix(col, col * p.b.rgb * 1.5, p.a.x);
            if (p.i.y != 0) f *= l / max(lm(f), 1e-4);
            col = f;
            break;
        }
        case 4: {
            float3 tri = l < 0.5 ? mix(p.d.rgb, p.c.rgb, l * 2.0) : mix(p.c.rgb, p.b.rgb, (l - 0.5) * 2.0);
            col = mix(tri, col, p.a.w);
            break;
        }
        case 5: {
            float3 h1 = rgb2hsv(clamp(col, 0.0, 1.0)), h2 = rgb2hsv(clamp(p.b.rgb, 0.0, 1.0));
            float dh = abs(h1.x - h2.x); dh = min(dh, 1.0 - dh);
            float keepc = 1.0 - smoothstep(p.a.y, p.a.y + 0.08, dh);
            col = mix(mix(col, float3(l), p.a.x), col, keepc);
            break;
        }
        case 6: {
            float3 h1 = rgb2hsv(clamp(col, 0.0, 1.0)), hf = rgb2hsv(clamp(p.b.rgb, 0.0, 1.0)), ht = rgb2hsv(clamp(p.c.rgb, 0.0, 1.0));
            float dh = abs(h1.x - hf.x); dh = min(dh, 1.0 - dh);
            float m = 1.0 - smoothstep(p.a.x, p.a.x + max(p.a.y, 0.01), dh);
            float3 shifted = col;
            float hueShift = ht.x - hf.x;
            float3 hs = h1; hs.x = fract(hs.x + hueShift);
            // hsv -> rgb
            float3 k = float3(1.0, 2.0 / 3.0, 1.0 / 3.0);
            float3 pp = abs(fract(hs.xxx + k) * 6.0 - 3.0);
            shifted = hs.z * mix(float3(1.0), clamp(pp - 1.0, 0.0, 1.0), hs.y);
            col = mix(col, shifted, m);
            break;
        }
    }
    dst.write(half4(half3(clamp(col, 0.0, 64.0) * s.a), half(s.a)), gid);
}

// ---------- Matte & keys ----------
// i.x: 0 luma key (a.x threshold, a.y tolerance, a.z feather, i.y key out darker 0 / brighter 1)
//      1 choker apply (texture 2 = blurred alpha source; a.x choke -1..1)
//      2 shadow prep (a.xy offset px, b color, a.z opacity) -> tinted shifted alpha
//      3 under (texture 2 = layer on top of texture 0)
kernel void fxMatte(texture2d<half, access::sample> src [[texture(0)]],
                    texture2d<half, access::write> dst [[texture(1)]],
                    texture2d<half, access::sample> aux [[texture(2)]],
                    constant EffectParams& p [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s3Zero, c));
    float4 o = s;
    switch (p.i.x) {
        case 0: {
            float l = lm(um(s));
            float d = p.i.y != 0 ? (l - p.a.x) : (p.a.x - l);
            float keyed = smoothstep(-p.a.y - p.a.z, -p.a.y, -d);
            o = s * (1.0 - keyed);
            break;
        }
        case 1: {
            float ba = float(aux.sample(s3Zero, c).a);
            float a = clamp((ba - 0.5 + p.a.x * 0.5) * 4.0 + 0.5, 0.0, 1.0);
            o = float4(um(s) * a * step(1e-4, max(s.a, ba)), a * step(1e-4, max(s.a, ba)));
            break;
        }
        case 2: {
            float a = float(src.sample(s3Zero, c - p.a.xy).a) * p.a.z;
            o = float4(p.b.rgb * a, a);
            break;
        }
        case 3: {
            float4 top = float4(aux.sample(s3Zero, c));
            o = top + s * (1.0 - top.a);
            break;
        }
    }
    dst.write(half4(o), gid);
}
