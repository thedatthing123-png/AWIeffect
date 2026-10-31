#include <metal_stdlib>
using namespace metal;

// Batch 15: blur, sharpen & glow 2 — hexagon bokeh, vortex, smear, inner / edge / luma-mask blur, minimax,
// bilateral smoothing, channel blur, camera-shake blur, radial / spin / linear highlight streaks, prism glow,
// dream bloom, soft glow, dark glow, hue-keyed glow, neon bloom, starglow, light wrap, diffusion (pro-mist),
// clarity, high-pass sharpen and structure.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s15Zero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler s15Edge(address::clamp_to_edge, filter::linear, coord::pixel);

static inline float3 u15(float4 c) { return c.a > 1e-6 ? c.rgb / c.a : float3(0.0); }
static inline float l15(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float2 rot15(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(cs * v.x - sn * v.y, sn * v.x + cs * v.y); }
static float3 rgb2hsv15(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-6;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
// Premultiplied highlight (light) above a luminance threshold.
static float3 hl15(float4 v, float th) {
    float3 u = clamp(u15(v), 0.0, 4.0);
    float w = smoothstep(th, th + 0.15, l15(u));
    return u * w * v.a;
}
// Adds premultiplied light over a premultiplied pixel (light also creates coverage outside the layer).
static float4 addLight15(float4 s, float3 g) {
    g = max(g, float3(0.0));
    float ga = clamp(max(g.r, max(g.g, g.b)), 0.0, 1.0);
    float a = clamp(s.a + ga * (1.0 - s.a), 0.0, 1.0);
    return float4(min(s.rgb + g, float3(a)), a);
}
static float edgeLum15(texture2d<half, access::sample> t, float2 c) {
    float4 v = float4(t.sample(s15Edge, c));
    return l15(v.rgb) * 0.8 + v.a * 0.2;
}
static float sobel15(texture2d<half, access::sample> t, float2 c, float w) {
    float tl = edgeLum15(t, c + float2(-w, -w)), tr = edgeLum15(t, c + float2(w, -w));
    float bl = edgeLum15(t, c + float2(-w, w)), br = edgeLum15(t, c + float2(w, w));
    float l = edgeLum15(t, c + float2(-w, 0)), r = edgeLum15(t, c + float2(w, 0));
    float u = edgeLum15(t, c + float2(0, -w)), d = edgeLum15(t, c + float2(0, w));
    float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl), gy = (bl + 2.0 * d + br) - (tl + 2.0 * u + tr);
    return length(float2(gx, gy));
}

kernel void fxBlur15(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     texture2d<half, access::sample> aux [[texture(2)]],
                     texture2d<half, access::sample> msk [[texture(3)]],
                     constant EffectParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s15Zero, c));
    float4 o = s;
    float t = p.d.x;
    float3 col = u15(s);
    switch (p.i.x) {
        case 0: { // hexagon bokeh: a = (radius px, highlight boost, rotation rad); 37 taps on a hex lattice
            float r = max(p.a.x, 0.0) / 3.0;
            float4 acc = float4(0.0); float ws = 0.0;
            for (int q = -3; q <= 3; q++) {
                for (int rr = -3; rr <= 3; rr++) {
                    if (abs(-q - rr) > 3) continue;
                    float2 off = rot15(float2(float(q) + float(rr) * 0.5, float(rr) * 0.8660254) * r, p.a.z);
                    float4 v = float4(src.sample(s15Zero, c + off));
                    float lv = clamp(l15(u15(v)), 0.0, 1.0);
                    float w = 1.0 + p.a.y * lv * lv * lv * lv;
                    acc += v * w; ws += w;
                }
            }
            o = acc / max(ws, 1e-4);
            break;
        }
        case 1: { // vortex blur: a = (center px, max angle rad, falloff radius px)
            float2 d = c - p.a.xy;
            float ang = p.a.z * exp(-length(d) / max(p.a.w, 1.0));
            float4 acc = float4(0.0);
            for (int k = 0; k < 32; k++) {
                float f = (float(k) / 31.0 - 0.5) * ang;
                acc += float4(src.sample(s15Zero, p.a.xy + rot15(d, f)));
            }
            o = acc / 32.0;
            break;
        }
        case 2: { // smear: a.xy = direction * length px, a.z = decay 0-1, a.w = luminance threshold
            float4 best = s;
            float bl = l15(s.rgb);
            for (int k = 1; k <= 32; k++) {
                float f = float(k) / 32.0;
                float4 v = float4(src.sample(s15Zero, c - p.a.xy * f));
                float lu = l15(u15(v));
                float fade = clamp(1.0 - f * p.a.z, 0.0, 1.0) * smoothstep(p.a.w, p.a.w + 0.1, lu);
                float4 cand = v * fade;
                float cl = l15(cand.rgb);
                if (cl > bl) { best = cand; bl = cl; }
            }
            o = best;
            break;
        }
        case 3: { // inner blur: aux = blurred input re-cut to the sharp alpha, a.x = amount
            float4 b = float4(float4(aux.sample(s15Zero, c)));
            float4 inner = float4(clamp(u15(b), 0.0, 1.0) * s.a, s.a);
            o = mix(s, inner, clamp(p.a.x, 0.0, 1.0));
            break;
        }
        case 4: { // edge mask: a = (detect width px, threshold)
            float e = sobel15(src, c, max(p.a.x, 0.5));
            float w = smoothstep(p.a.y, p.a.y + 0.15, e);
            o = float4(w);
            break;
        }
        case 5: { // masked mix: dst = mix(src, aux, mask.a * a.x)
            float w = clamp(float(msk.sample(s15Zero, c).a) * p.a.x, 0.0, 1.0);
            o = mix(s, float4(aux.sample(s15Zero, c)), w);
            break;
        }
        case 6: { // luminance mask: a = (threshold, softness), i.y = invert
            float lu = l15(col);
            float w = smoothstep(p.a.x - p.a.y, p.a.x + p.a.y + 1e-3, lu);
            if (p.i.y == 1) w = 1.0 - w;
            o = float4(w * s.a);
            break;
        }
        case 7: { // minimax pass: a.x radius px, b.xy direction, i.y 0 = maximum, 1 = minimum
            float r = max(p.a.x, 0.0);
            int n = int(clamp(ceil(r), 0.0, 16.0));
            float stepLen = n > 0 ? r / float(n) : 0.0;
            float4 m = s;
            for (int k = -n; k <= n; k++) {
                float4 v = float4(src.sample(s15Edge, c + p.b.xy * float(k) * stepLen));
                m = p.i.y == 1 ? min(m, v) : max(m, v);
            }
            o = m;
            break;
        }
        case 8: { // bilateral smooth: a = (tap spacing px, range sigma, amount); 7x7 taps
            float3 accC = float3(0.0); float accA = 0.0, ws = 0.0;
            float sr2 = 2.0 * p.a.y * p.a.y + 1e-4;
            for (int j = -3; j <= 3; j++) {
                for (int i = -3; i <= 3; i++) {
                    float4 v = float4(src.sample(s15Edge, c + float2(i, j) * p.a.x));
                    float3 vc = u15(v);
                    float dc = length(vc - col) + abs(v.a - s.a);
                    float w = exp(-float(i * i + j * j) / 4.5) * exp(-dc * dc / sr2);
                    accC += vc * w; accA += v.a * w; ws += w;
                }
            }
            ws = max(ws, 1e-5);
            float a = accA / ws;
            float4 sm = float4(clamp(accC / ws, 0.0, 1.0) * a, a);
            o = mix(s, sm, clamp(p.a.z, 0.0, 1.0));
            break;
        }
        case 9: { // channel combine 1: red from src, green from aux
            float4 g = float4(aux.sample(s15Zero, c));
            o = float4(s.r, g.g, 0.0, max(s.a, g.a));
            break;
        }
        case 10: { // channel combine 2: keep red/green, blue from aux
            float4 b = float4(aux.sample(s15Zero, c));
            o = float4(s.r, s.g, b.b, max(s.a, b.a));
            break;
        }
        case 11: { // camera shake blur: a = (amplitude px, shutter 0-1, speed Hz)
            float4 acc = float4(0.0);
            for (int k = 0; k < 24; k++) {
                float u = t * p.a.z + (float(k) / 23.0 - 0.5) * p.a.y;
                float2 off = float2(sin(u * 6.1) + 0.6 * sin(u * 13.7 + 1.3), cos(u * 5.3 + 0.7) + 0.6 * sin(u * 11.9 + 2.1));
                acc += float4(src.sample(s15Zero, c + off * p.a.x * 0.6));
            }
            o = acc / 24.0;
            break;
        }
        case 12: { // radial (zoom) streaks: a = (center px, length 0-1, threshold), b.x intensity, c = tint
            float3 acc = float3(0.0);
            for (int k = 1; k <= 32; k++) {
                float f = float(k) / 32.0;
                float4 v = float4(src.sample(s15Zero, c + (p.a.xy - c) * f * p.a.z));
                acc += hl15(v, p.a.w) * (1.0 - float(k) / 33.0);
            }
            o = addLight15(s, acc / 16.0 * p.b.x * p.c.rgb);
            break;
        }
        case 13: { // spin streaks: a = (center px, angle rad, threshold), b.x intensity, c = tint
            float3 acc = float3(0.0);
            float2 d = c - p.a.xy;
            for (int k = 1; k <= 32; k++) {
                float f = float(k) / 32.0;
                float4 v = float4(src.sample(s15Zero, p.a.xy + rot15(d, -f * p.a.z)));
                acc += hl15(v, p.a.w) * (1.0 - float(k) / 33.0);
            }
            o = addLight15(s, acc / 16.0 * p.b.x * p.c.rgb);
            break;
        }
        case 14: { // linear streaks: a.xy = direction * length px, a.z threshold, a.w intensity, c = tint
            float3 acc = float3(0.0);
            for (int k = -16; k <= 16; k++) {
                if (k == 0) continue;
                float f = float(k) / 16.0;
                float4 v = float4(src.sample(s15Zero, c + p.a.xy * f));
                acc += hl15(v, p.a.z) * (1.0 - abs(f) * 0.94);
            }
            o = addLight15(s, acc / 8.0 * p.a.w * p.c.rgb);
            break;
        }
        case 15: { // highlight extract: a = (threshold, saturation mul), i.y = 1 gates by hue (b = hue 0-1, half range, softness)
            float3 u = clamp(col, 0.0, 1.0);
            float lu = l15(u);
            float w;
            if (p.i.y == 1) {
                float3 hsv = rgb2hsv15(u);
                float dh = abs(fract(hsv.x - p.b.x + 0.5) - 0.5);
                w = (1.0 - smoothstep(p.b.y, p.b.y + p.b.z + 1e-3, dh)) * smoothstep(0.08, 0.25, hsv.y);
            } else {
                w = smoothstep(p.a.x, p.a.x + 0.15, lu);
            }
            float3 sat = max(mix(float3(lu), u, p.a.y), float3(0.0));
            o = float4(sat * w * s.a, w * s.a);
            break;
        }
        case 16: { // add glow: aux = glow, a.x = intensity, a.y = prism spread px (i.z = 1), b = tint
            float4 g = float4(aux.sample(s15Zero, c));
            if (p.i.z == 1) {
                float2 dv = c - size * 0.5;
                float L = length(dv);
                float2 dir = L > 1e-3 ? dv / L : float2(1.0, 0.0);
                g.r = float(aux.sample(s15Zero, c - dir * p.a.y).r);
                g.b = float(aux.sample(s15Zero, c + dir * p.a.y).b);
            }
            o = addLight15(s, g.rgb * p.a.x * p.b.rgb);
            break;
        }
        case 17: { // dream bloom: aux = blur, a = (amount, haze), b = tint
            float4 b = float4(aux.sample(s15Zero, c));
            float3 bc = clamp(u15(b), 0.0, 1.0) * p.b.rgb;
            float3 base = clamp(col, 0.0, 1.0);
            float3 scr = 1.0 - (1.0 - base) * (1.0 - bc);
            float3 r = mix(base, scr, p.a.x);
            r = r * (1.0 - p.a.y * 0.4) + p.a.y * 0.2 * p.b.rgb;
            float a = max(s.a, b.a * p.a.x);
            o = float4(clamp(r, 0.0, 1.0) * a, a);
            break;
        }
        case 18: { // soft glow: screen the (premultiplied) glow in aux over src, a.x = intensity
            float4 g = clamp(float4(aux.sample(s15Zero, c)) * p.a.x, 0.0, 1.0);
            o = s + g - s * g;
            o.rgb = min(o.rgb, float3(o.a));
            break;
        }
        case 19: { // dark glow: aux = blur, a = (amount, depth gamma) — shadows bloom by multiply
            float3 bc = clamp(u15(float4(aux.sample(s15Zero, c))), 0.0, 1.0);
            float3 mul = pow(bc, float3(max(p.a.y, 0.1) - 1.0 + 0.5));
            float3 r = clamp(col, 0.0, 1.0) * mix(float3(1.0), mul, clamp(p.a.x, 0.0, 1.0));
            o = float4(r * s.a, s.a);
            break;
        }
        case 20: { // starglow: a = (length px, threshold, intensity, rotation rad), b / c = alternating tints
            float3 acc = float3(0.0);
            for (int d = 0; d < 8; d++) {
                float ang = p.a.w + float(d) * 0.7853982;
                float2 dir = float2(cos(ang), sin(ang));
                float3 tint = (d & 1) == 0 ? p.b.rgb : p.c.rgb;
                float3 ray = float3(0.0);
                for (int k = 1; k <= 8; k++) {
                    float f = float(k) / 8.0;
                    float fw = 1.0 - f * 0.9;
                    ray += hl15(float4(src.sample(s15Zero, c - dir * p.a.x * f)), p.a.y) * fw * fw;
                }
                acc += ray * tint;
            }
            o = addLight15(s, acc * p.a.z * 0.35);
            break;
        }
        case 21: { // light wrap: aux = blur, a.x = intensity — brighter surroundings bleed onto darker pixels
            float3 bc = clamp(u15(float4(aux.sample(s15Zero, c))), 0.0, 1.0);
            float3 base = clamp(col, 0.0, 1.0);
            float lift = max(l15(bc) - l15(base), 0.0);
            float3 r = clamp(base + bc * lift * p.a.x * 2.0, 0.0, 1.0);
            o = float4(r * s.a, s.a);
            break;
        }
        case 22: { // diffusion / pro-mist: aux = blur, a = (strength, black lift, highlight bloom)
            float4 b = float4(aux.sample(s15Zero, c));
            float3 bc = clamp(u15(b), 0.0, 1.0);
            float3 base = clamp(col, 0.0, 1.0);
            float3 r = mix(base, bc, p.a.x * 0.4) + max(bc - 0.5, 0.0) * p.a.x * p.a.z * 1.5;
            r = r * (1.0 - p.a.y) + p.a.y;
            float a = max(s.a, b.a * p.a.x * 0.6);
            o = float4(clamp(r, 0.0, 1.0) * a, a);
            break;
        }
        case 23: { // clarity: aux = wide blur, a.x = amount -1..1 (midtone-weighted local contrast)
            float3 bc = u15(float4(aux.sample(s15Zero, c)));
            float3 base = clamp(col, 0.0, 1.0);
            float lu = l15(base);
            float mid = 0.3 + 0.7 * (1.0 - (2.0 * lu - 1.0) * (2.0 * lu - 1.0));
            float3 r = clamp(base + (base - bc) * p.a.x * 1.5 * mid, 0.0, 1.0);
            o = float4(r * s.a, s.a);
            break;
        }
        case 24: { // high pass sharpen: aux = blur, a.x = amount, i.y = show high pass
            float3 bc = u15(float4(aux.sample(s15Zero, c)));
            float3 base = clamp(col, 0.0, 1.0);
            float3 hp = base - bc;
            float3 r = p.i.y == 1 ? clamp(0.5 + hp * p.a.x, 0.0, 1.0) : clamp(base + hp * p.a.x, 0.0, 1.0);
            o = float4(r * s.a, s.a);
            break;
        }
        case 25: { // structure: aux = small blur, a.x = amount (soft-limited micro contrast + slight saturation)
            float3 bc = u15(float4(aux.sample(s15Zero, c)));
            float3 base = clamp(col, 0.0, 1.0);
            float3 d = (base - bc) * p.a.x * 3.0;
            d = d / (1.0 + abs(d) * 0.5);
            float3 r = base + d;
            float lu = l15(r);
            r = mix(float3(lu), r, 1.0 + 0.15 * p.a.x);
            o = float4(clamp(r, 0.0, 1.0) * s.a, s.a);
            break;
        }
        default: break;
    }
    float4 safe = o;
    if (any(isnan(safe)) || any(isinf(safe))) safe = s;
    dst.write(half4(safe), gid);
}
