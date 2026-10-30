#include <metal_stdlib>
using namespace metal;

// Batch 10: lighting, material & 3D look — bevels, bump / normal-map lighting, chrome, gold, glass, light sweep,
// star glints, spotlight, point light, two-tone, edge AO, inner shadow, emboss color, fresnel, holo foil, neon tubes,
// specular, volumetric beam, film bloom, lens dirt, pseudo 3D card tilt.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s10Zero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler s10Edge(address::clamp_to_edge, filter::linear, coord::pixel);

static inline float3 u10(float4 c) { return c.a > 1e-6 ? c.rgb / c.a : float3(0.0); }
static inline float l10(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float h10(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float h103(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static float n10(float3 x) {
    float3 i = floor(x), f = fract(x); float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(h103(i), h103(i + float3(1, 0, 0)), u.x), mix(h103(i + float3(0, 1, 0)), h103(i + float3(1, 1, 0)), u.x), u.y),
               mix(mix(h103(i + float3(0, 0, 1)), h103(i + float3(1, 0, 1)), u.x), mix(h103(i + float3(0, 1, 1)), h103(i + float3(1, 1, 1)), u.x), u.y), u.z);
}
static inline float3 rainbow10(float x) { return 0.5 + 0.5 * cos(6.2831853 * (x + float3(0.0, 0.33, 0.67))); }
/// Surface normal (+z toward viewer) from a height texture's red channel.
static float3 nrm10(texture2d<half, access::sample> h, float2 c, float depth) {
    float dx = float(h.sample(s10Edge, c + float2(1, 0)).r) - float(h.sample(s10Edge, c - float2(1, 0)).r);
    float dy = float(h.sample(s10Edge, c + float2(0, 1)).r) - float(h.sample(s10Edge, c - float2(0, 1)).r);
    return normalize(float3(-dx * depth, -dy * depth, 1.0));
}
/// Direction toward a light at screen angle `ang` (0 = right, 90 = up) and elevation `elev` (radians).
static inline float3 ldir10(float ang, float elev) {
    return normalize(float3(cos(ang) * cos(elev), -sin(ang) * cos(elev), sin(elev)));
}

kernel void fxLight10(texture2d<half, access::sample> src [[texture(0)]],
                      texture2d<half, access::write> dst [[texture(1)]],
                      texture2d<half, access::sample> aux [[texture(2)]],
                      constant EffectParams& p [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(s10Zero, c));
    float4 o = s;
    float t = p.d.x;
    switch (p.i.x) {
        case 0: { // height prep: a.x = luma mix (0 = alpha, 1 = luma * alpha)
            float h = mix(s.a, l10(u10(s)) * s.a, p.a.x);
            o = float4(h, h, h, h);
            break;
        }
        case 1: { // bevel alpha: a = (depth, intensity, angle, 0), b = highlight, c = shadow; aux = soft alpha
            float3 n = nrm10(aux, c, p.a.x);
            float3 L = ldir10(p.a.z, 0.6);
            float sh = dot(n, L) - L.z;
            float hl = max(sh, 0.0) * p.a.y, sd = clamp(max(-sh, 0.0) * p.a.y, 0.0, 1.0);
            float3 col = mix(u10(s), p.c.rgb, sd) + p.b.rgb * hl;
            o = float4(clamp(col, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 2: { // smooth bevel+: a = (depth, highlight, shadow, angle), b = (elev, shininess), c = highlight color
            float3 n = nrm10(aux, c, p.a.x);
            float3 L = ldir10(p.a.w, p.b.x);
            float3 H = normalize(L + float3(0, 0, 1));
            float sh = dot(n, L) - L.z;
            float spec = max(pow(max(dot(n, H), 0.0), p.b.y) - pow(H.z, p.b.y), 0.0);
            float3 col = u10(s) * (1.0 + min(sh, 0.0) * p.a.z * 1.5);
            col += p.c.rgb * (max(sh, 0.0) * 0.5 + spec) * p.a.y;
            o = float4(clamp(col, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 3: { // bump map: a = (depth, intensity, angle, elev); aux = soft luma height
            float3 n = nrm10(aux, c, p.a.x);
            float3 L = ldir10(p.a.z, p.a.w);
            float sh = (dot(n, L) - L.z) / max(L.z, 0.05);
            float3 col = u10(s) * max(1.0 + sh * p.a.y, 0.0);
            o = float4(clamp(col, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 4: { // normal-map lighting: a = (lx, ly, light height, depth), b = light color, c = (ambient, specular, shininess)
            float3 n = nrm10(aux, c, p.a.w);
            float3 L = normalize(float3(p.a.xy - c, max(p.a.z, 1.0)));
            float3 H = normalize(L + float3(0, 0, 1));
            float diff = max(dot(n, L), 0.0);
            float spec = pow(max(dot(n, H), 0.0), max(p.c.z, 1.0)) * p.c.y;
            float3 col = u10(s) * (p.c.x + diff * p.b.rgb) + p.b.rgb * spec;
            o = float4(clamp(col, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 5:
        case 6: { // chrome (5) / gold (6): a = (depth, bands, mix, contrast), b = tint
            float3 n = nrm10(aux, c, p.a.x);
            float3 col = u10(s);
            float lum = l10(col);
            float v = lum * p.a.y + n.y * 1.6 + n.x * 0.5 + c.y / max(size.y, 1.0) * 0.35;
            float env = pow(clamp(0.5 + 0.5 * cos(v * 6.2831853), 0.0, 1.0), max(p.a.w, 0.05));
            float3 H = normalize(ldir10(2.356, 0.8) + float3(0, 0, 1));
            float spec = pow(max(dot(n, H), 0.0), 60.0) * 0.6;
            float3 m;
            if (p.i.x == 6) {
                float3 g0 = float3(0.22, 0.10, 0.02), g1 = float3(0.86, 0.60, 0.16), g2 = float3(1.0, 0.95, 0.72);
                m = env < 0.5 ? mix(g0, g1, env * 2.0) : mix(g1, g2, env * 2.0 - 1.0);
                m += float3(1.0, 0.9, 0.6) * spec;
            } else {
                m = mix(float3(0.10, 0.11, 0.14), float3(1.0), env) * p.b.rgb + spec;
            }
            o = float4(clamp(mix(col, m, p.a.z), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 7: { // glass material: a = (depth, refraction px, opacity, highlight), b.x = angle; aux = soft alpha
            float3 n = nrm10(aux, c, p.a.x);
            float4 q = float4(src.sample(s10Zero, c - n.xy * p.a.y));
            float edge = clamp(length(n.xy) * 2.0, 0.0, 1.0);
            float3 L = ldir10(p.b.x, 0.7);
            float3 H = normalize(L + float3(0, 0, 1));
            float spec = max(pow(max(dot(n, H), 0.0), 40.0) - pow(H.z, 40.0), 0.0);
            float a = s.a * mix(p.a.z, 1.0, edge * 0.7);
            float3 body = u10(q) * 0.85 + 0.08;
            float3 rgb = body * a + (float3(spec) + edge * 0.35) * p.a.w * s.a;
            o = float4(rgb, clamp(a + spec * p.a.w * s.a, 0.0, 1.0));
            break;
        }
        case 8: { // light sweep: a = (dirx, diry, width, intensity), b = color, c = (speed, offset, softness)
            float2 dir = p.a.xy;
            float w = max(p.a.z, 0.5);
            float half_ = 0.5 * (abs(dir.x) * size.x + abs(dir.y) * size.y);
            float proj = dot(c - size * 0.5, dir);
            float center = mix(-half_ - w, half_ + w, fract(t * p.c.x + p.c.y));
            float d = abs(proj - center);
            float band = 1.0 - smoothstep(w * 0.5 * (1.0 - clamp(p.c.z, 0.0, 0.99)), w * 0.5, d);
            float3 light = p.b.rgb * band * p.a.w;
            o = float4(s.rgb + light * s.a, s.a);
            break;
        }
        case 9:
        case 10: { // star glint (9) / rainbow glint (10): a = (threshold, length, intensity, rotation), b = color, i.y = lines
            int lines = clamp(int(p.i.y), 2, 4);
            const int S = 8;
            float3 acc = float3(0.0);
            float thr = p.a.x;
            float3 baseTint = float3(p.b.rgb);
            for (int k = 0; k < 4; k++) {
                if (k >= lines) break;
                float ang = p.a.w + float(k) * 3.14159265 / float(lines);
                float2 dir = float2(cos(ang), sin(ang));
                for (int j = 1; j <= S; j++) {
                    float f = float(j) / float(S);
                    float w = (1.0 - f) * (1.0 - f) + 0.02;
                    float3 tint = p.i.x == 10 ? rainbow10(f * 0.9 + float(k) * 0.17 + t * 0.3) : baseTint;
                    for (int sg = 0; sg < 2; sg++) {
                        float2 off = dir * p.a.y * f * (sg == 0 ? 1.0 : -1.0);
                        float4 q = float4(src.sample(s10Zero, c + off));
                        float b = max(l10(u10(q)) - thr, 0.0) / max(1.0 - thr, 1e-3) * q.a;
                        acc += tint * b * w;
                    }
                }
            }
            float3 g = acc * p.a.z / float(S * lines) * 1.5;
            o = float4(s.rgb + g, max(s.a, clamp(l10(g), 0.0, 1.0)));
            break;
        }
        case 11: { // spotlight: a = (sx, sy, dir angle, cone half), b = color, c = (softness, ambient, intensity, reach)
            float2 v = c - p.a.xy;
            float d = max(length(v), 1e-3);
            float2 dir = float2(cos(p.a.z), sin(p.a.z));
            float ang = acos(clamp(dot(v / d, dir), -1.0, 1.0));
            float cone = max(p.a.w, 1e-3);
            float m = 1.0 - smoothstep(cone * (1.0 - clamp(p.c.x, 0.0, 0.99)), cone, ang);
            float att = 1.0 / (1.0 + (d / max(p.c.w, 1.0)) * (d / max(p.c.w, 1.0)));
            float3 light = p.c.y + m * att * p.c.z * p.b.rgb;
            o = float4(clamp(u10(s) * light, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 12: { // point light glow: a = (x, y, radius, intensity), b = color, c.x = glow
            float d = length(c - p.a.xy) / max(p.a.z, 1.0);
            float f = 1.0 / (1.0 + d * d);
            float3 lit = u10(s) * (0.55 + p.b.rgb * p.a.w * f);
            float3 glow = p.b.rgb * p.c.x * f * f;
            o = float4(clamp(lit, 0.0, 1.0) * s.a + glow, max(s.a, clamp(l10(glow), 0.0, 1.0)));
            break;
        }
        case 13: { // two-tone lighting: a = (depth, key, rim, angle), b = key color, c = rim color
            float3 n = nrm10(aux, c, p.a.x);
            float2 L2 = float2(cos(p.a.w), -sin(p.a.w));
            float slope = dot(n.xy, L2);
            float k = clamp(max(slope, 0.0) * p.a.y * 2.0, 0.0, 1.0);
            float r = clamp(max(-slope, 0.0) * p.a.z * 2.0, 0.0, 1.0);
            float3 col = mix(mix(u10(s), p.b.rgb, k), p.c.rgb, r);
            o = float4(col * s.a, s.a);
            break;
        }
        case 14: { // edge ambient occlusion: a.x = strength, b = color; aux = soft alpha
            float occ = clamp((1.0 - float(aux.sample(s10Zero, c).r)) * 2.0 * p.a.x, 0.0, 1.0);
            o = float4(mix(u10(s), p.b.rgb, occ) * s.a, s.a);
            break;
        }
        case 15: { // inner shadow: a = (offx, offy, opacity, 0), b = color; aux = soft alpha
            float sh = clamp(1.0 - float(aux.sample(s10Zero, c - p.a.xy).r), 0.0, 1.0) * p.a.z;
            o = float4(mix(u10(s), p.b.rgb, sh) * s.a, s.a);
            break;
        }
        case 16: { // emboss color: a = (depth, amount, angle, 0); aux = soft luma height
            float3 n = nrm10(aux, c, p.a.x);
            float3 L = ldir10(p.a.z, 0.5);
            float sh = dot(n, L) - L.z;
            float3 col = u10(s) + sh * p.a.y;
            o = float4(clamp(col, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 17: { // fresnel edge glow: a = (depth, power, intensity, 0), b = color; aux = soft alpha
            float3 n = nrm10(aux, c, p.a.x);
            float fr = pow(clamp(length(n.xy), 0.0, 1.0), max(p.a.y, 0.05)) * p.a.z;
            float3 col = mix(u10(s), p.b.rgb, clamp(fr, 0.0, 1.0)) + p.b.rgb * fr * 0.5;
            o = float4(clamp(col, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 18: { // holographic foil: a = (scale, speed, mix, depth); aux = soft luma height
            float3 n = nrm10(aux, c, p.a.w);
            float3 col = u10(s);
            float lum = l10(col);
            float x = lum * p.a.x + (c.x + c.y) / max(max(size.x, size.y), 1.0) * p.a.x * 0.5 + n.x * 2.0 + n.y * 1.5 + t * p.a.y;
            float3 foil = mix(rainbow10(x), float3(1.0), 0.2) * (0.55 + 0.6 * lum);
            o = float4(clamp(mix(col, foil, p.a.z), 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 19: { // neon tubes: a = (colorize, 0, 0, 0), b = color; aux = soft height
            float h = clamp(float(aux.sample(s10Edge, c).r), 0.0, 1.0);
            float3 tube = p.b.rgb * (0.35 + 0.8 * h) + float3(pow(h, 6.0) * 0.8);
            float3 col = mix(u10(s), tube, p.a.x);
            o = float4(clamp(col, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 20: { // specular highlight: a = (depth, shininess, intensity, angle), b = color, c.x = elevation
            float3 n = nrm10(aux, c, p.a.x);
            float3 L = ldir10(p.a.w, p.c.x);
            float3 H = normalize(L + float3(0, 0, 1));
            float spec = pow(max(dot(n, H), 0.0), max(p.a.y, 1.0)) * p.a.z;
            float lam = clamp(dot(n, L) / max(L.z, 0.05), 0.2, 1.5);
            float3 col = u10(s) * lam + p.b.rgb * spec;
            o = float4(clamp(col, 0.0, 1.0) * s.a, s.a);
            break;
        }
        case 21: { // volumetric beam: a = (sx, sy, dir, spread), b = color, c = (length, intensity, dust, dust scale)
            float2 v = c - p.a.xy;
            float d = max(length(v), 1e-3);
            float2 dir = float2(cos(p.a.z), sin(p.a.z));
            float ang = acos(clamp(dot(v / d, dir), -1.0, 1.0));
            float spread = max(p.a.w, 1e-3);
            float cone = 1.0 - smoothstep(spread * 0.55, spread, ang);
            float fall = pow(clamp(1.0 - d / max(p.c.x, 1.0), 0.0, 1.0), 1.5);
            float streak = 0.7 + 0.3 * n10(float3(ang * 24.0, 0.5, t * 0.6));
            float sc = max(p.c.w, 1.0);
            float dn = n10(float3(c / sc + float2(t * 0.2, -t * 0.35), t * 0.4));
            float speck = step(0.93, h10(floor(c / max(sc * 0.25, 1.0)) + floor(t * 8.0)));
            float dust = mix(1.0, 0.35 + 1.3 * dn + speck * 1.5, clamp(p.c.z, 0.0, 1.0));
            float3 beam = p.b.rgb * cone * fall * streak * dust * p.c.y;
            o = float4(s.rgb + beam, max(s.a, clamp(l10(beam), 0.0, 1.0)));
            break;
        }
        case 23: { // lens dirt combine: a = (intensity, scale, density, 0); aux = blurred highlights
            float sc = max(p.a.y, 1.0);
            float den = clamp(p.a.z, 0.0, 1.0);
            float sm = smoothstep(1.0 - den, 1.15 - den * 0.5, n10(float3(c / sc, 1.7)) * 0.7 + n10(float3(c / (sc * 0.35), 4.2)) * 0.3);
            float s2 = max(sc * 0.4, 2.0);
            float2 cell = floor(c / s2);
            float on = step(1.0 - den * 0.3, h10(cell));
            float2 ctr = (cell + 0.5 + (float2(h10(cell + 7.1), h10(cell - 3.7)) - 0.5) * 0.5) * s2;
            float rr = s2 * (0.12 + 0.22 * h10(cell + 3.3));
            float speck = on * (1.0 - smoothstep(rr * 0.5, rr, length(c - ctr)));
            float dm = clamp(sm + speck, 0.0, 1.0);
            float4 l = float4(aux.sample(s10Zero, c)) * (0.15 + dm * 1.6) * p.a.x;
            o = float4(s.rgb + l.rgb, clamp(s.a + l.a * (1.0 - s.a), 0.0, 1.0));
            break;
        }
        case 24: { // card tilt: a = (rotX, rotY, focal px, shading)
            float cx = cos(p.a.x), sx = sin(p.a.x), cy = cos(p.a.y), sy = sin(p.a.y);
            float f = max(p.a.z, 10.0);
            float3 nr = float3(-cx * sy, sx, -cx * cy);
            float2 pp = c - size * 0.5;
            float3 D = float3(pp, f);
            float dn = dot(D, nr);
            if (dn > -1e-3) { o = float4(0.0); break; }
            float sd = -f * cx * cy / dn;
            if (sd <= 0.0) { o = float4(0.0); break; }
            float3 H = float3(0, 0, -f) + D * sd;
            float x1 = H.x * cy - H.z * sy;
            float z1 = H.x * sy + H.z * cy;
            float y2 = H.y * cx + z1 * sx;
            float4 q = float4(src.sample(s10Zero, size * 0.5 + float2(x1, y2)));
            float3 L = normalize(float3(-0.35, -0.45, -1.0));
            float base = dot(float3(0, 0, -1), L);
            float sh = mix(1.0, clamp(dot(nr, L), 0.0, 1.0) / base, clamp(p.a.w, 0.0, 1.0));
            o = float4(q.rgb * sh, q.a);
            break;
        }
        case 25: { // add aux * a.x
            float4 l = float4(aux.sample(s10Zero, c)) * p.a.x;
            o = float4(s.rgb + l.rgb, clamp(s.a + l.a * (1.0 - s.a), 0.0, 1.0));
            break;
        }
        case 26: { // highlight extract: a = (threshold, tint amount), b = tint
            float3 col = u10(s);
            float b = max(l10(col) - p.a.x, 0.0) / max(1.0 - p.a.x, 1e-3);
            float3 tc = mix(col, p.b.rgb * max(l10(col), 0.2) * 1.5, clamp(p.a.y, 0.0, 1.0));
            o = float4(tc * b * s.a, b * s.a);
            break;
        }
        default: break;
    }
    dst.write(half4(o), gid);
}
