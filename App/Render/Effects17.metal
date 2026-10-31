#include <metal_stdlib>
using namespace metal;

// Batch 17: 3D-look procedurals — tiny raymarched solids (cube, sphere, torus, cylinder, pyramid, octahedron, star
// prism, heart, hollow box, ring), input-textured projections (tunnel, skybox, sphere/cylinder wrap, page flip, cube
// flip, rotating plane) and 3D scenes (floor grid, starfield planes, skyline, seascape, clouds, point cloud, orbit
// particles) plus an alpha extrusion.
// rgba16Float premultiplied, sRGB-encoded (same as the other batches).
// Common: d.x = time, d.y = blend 0-1, d.z = only (1 = drop the input), i.x = mode,
// i.y = 0 additive (g = light) / 1 over (g straight + ga coverage) / 2 replace (pc premultiplied, mixed by blend).
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler sm17Zero(address::clamp_to_zero, filter::linear, coord::pixel);
constexpr sampler sm17Rep(address::repeat, filter::linear, coord::normalized);
constexpr sampler sm17Edge(address::clamp_to_edge, filter::linear, coord::normalized);

static inline float lum17(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
static float h17(float2 p) { float3 q = fract(float3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
static float h173(float3 p) { p = fract(p * float3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
static float n17(float3 x) {
    float3 i = floor(x), f = fract(x); float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(h173(i), h173(i + float3(1, 0, 0)), u.x), mix(h173(i + float3(0, 1, 0)), h173(i + float3(1, 1, 0)), u.x), u.y),
               mix(mix(h173(i + float3(0, 0, 1)), h173(i + float3(1, 0, 1)), u.x), mix(h173(i + float3(0, 1, 1)), h173(i + float3(1, 1, 1)), u.x), u.y), u.z);
}
static float fbm17(float3 x) {
    float v = 0.0, a = 0.5;
    for (int k = 0; k < 3; k++) { v += a * n17(x); x = x * 2.03 + float3(17.1, 9.2, 3.3); a *= 0.5; }
    return v;
}
static inline float3 rx17(float3 v, float a) { float cs = cos(a), sn = sin(a); return float3(v.x, v.y * cs - v.z * sn, v.y * sn + v.z * cs); }
static inline float3 ry17(float3 v, float a) { float cs = cos(a), sn = sin(a); return float3(v.x * cs + v.z * sn, v.y, -v.x * sn + v.z * cs); }
static inline float2 r2d17(float2 v, float a) { float cs = cos(a), sn = sin(a); return float2(v.x * cs - v.y * sn, v.x * sn + v.y * cs); }
static inline float dot217(float2 v) { return dot(v, v); }

static float box17(float3 p, float3 b) {
    float3 q = abs(p) - b;
    return length(max(q, float3(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}
static float ext17(float d2, float z, float h) {
    float2 w = float2(d2, abs(z) - h);
    return min(max(w.x, w.y), 0.0) + length(max(w, float2(0.0)));
}
static float star17(float2 p, float r, float rf) {
    const float2 k1 = float2(0.809016994375, -0.587785252292);
    const float2 k2 = float2(-k1.x, k1.y);
    p.x = abs(p.x);
    p -= 2.0 * max(dot(k1, p), 0.0) * k1;
    p -= 2.0 * max(dot(k2, p), 0.0) * k2;
    p.x = abs(p.x);
    p.y -= r;
    float2 ba = rf * float2(-k1.y, k1.x) - float2(0.0, 1.0);
    float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
    return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}
static float heart17(float2 p) {
    p.x = abs(p.x);
    if (p.y + p.x > 1.0) return sqrt(dot217(p - float2(0.25, 0.75))) - 0.35355339;
    return sqrt(min(dot217(p - float2(0.0, 1.0)), dot217(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}
static float pyr17(float3 p, float h) {
    float m2 = h * h + 0.25;
    p.xz = abs(p.xz);
    p.xz = (p.z > p.x) ? p.zx : p.xz;
    p.xz -= 0.5;
    float3 q = float3(p.z, h * p.y - 0.5 * p.x, h * p.x + 0.5 * p.y);
    float s = max(-q.x, 0.0);
    float t = clamp((q.y - 0.5 * p.z) / (m2 + 0.25), 0.0, 1.0);
    float a = m2 * (q.x + s) * (q.x + s) + q.y * q.y;
    float b = m2 * (q.x + 0.5 * t) * (q.x + 0.5 * t) + (q.y - m2 * t) * (q.y - m2 * t);
    float d2 = min(q.y, -q.x * m2 - q.y * 0.5) > 0.0 ? 0.0 : min(a, b);
    return sqrt(max((d2 + q.z * q.z) / m2, 0.0)) * sign(max(q.z, -p.y));
}
static float frame17(float3 p, float3 b, float e) {
    p = abs(p) - b;
    float3 q = abs(p + e) - e;
    return min(min(
        length(max(float3(p.x, q.y, q.z), float3(0.0))) + min(max(p.x, max(q.y, q.z)), 0.0),
        length(max(float3(q.x, p.y, q.z), float3(0.0))) + min(max(q.x, max(p.y, q.z)), 0.0)),
        length(max(float3(q.x, q.y, p.z), float3(0.0))) + min(max(q.x, max(q.y, p.z)), 0.0));
}
// Unit-scale solids (radius ~1).
static float sdf17(float3 q, int sh) {
    switch (sh) {
        case 0: return box17(q, float3(0.68)) - 0.05;
        case 1: return length(q) - 1.0;
        case 2: { float2 w = float2(length(q.xz) - 0.72, q.y); return length(w) - 0.3; }
        case 3: { float2 d = abs(float2(length(q.xz), q.y)) - float2(0.65, 0.85); return min(max(d.x, d.y), 0.0) + length(max(d, float2(0.0))); }
        case 4: { float k = 1.6; return pyr17(q / k + float3(0.0, 0.4, 0.0), 1.0) * k; }
        case 5: return (abs(q.x) + abs(q.y) + abs(q.z) - 1.15) * 0.57735;
        case 6: return ext17(star17(q.xy, 1.0, 0.45), q.z, 0.28) - 0.02;
        case 7: { float k = 1.7; float d2 = heart17(q.xy / k + float2(0.0, 0.55)) * k; return ext17(d2 + 0.08, q.z, 0.22) - 0.08; }
        case 8: return frame17(q, float3(0.75), 0.12);
        default: { float d2 = abs(length(q.xy) - 0.78) - 0.18; return ext17(d2, q.z, 0.16) - 0.03; }
    }
}
static inline float3 obj17(float3 pos, float2 ang) { return rx17(ry17(pos, ang.y), ang.x); }
static float map17(float3 pos, int sh, float2 ang, float S) { return sdf17(obj17(pos, ang) / S, sh) * S; }
static float3 nrm17(float3 pos, int sh, float2 ang, float S) {
    const float e = 0.0015;
    const float2 k = float2(1.0, -1.0);
    float3 n = k.xyy * map17(pos + k.xyy * e, sh, ang, S) + k.yyx * map17(pos + k.yyx * e, sh, ang, S)
             + k.yxy * map17(pos + k.yxy * e, sh, ang, S) + k.xxx * map17(pos + k.xxx * e, sh, ang, S);
    return n / max(length(n), 1e-6);
}

// Simple sky used by the seascape (also for reflections).
static float3 sky17(float3 rd, float3 sd, float3 skyCol) {
    float3 hor = mix(skyCol, float3(1.0, 0.85, 0.7), 0.55) * 1.2;
    float3 col = mix(hor, skyCol, clamp(rd.y * 3.0, 0.0, 1.0));
    float sdot = max(dot(rd, sd), 0.0);
    col += float3(1.0, 0.85, 0.6) * (pow(sdot, 300.0) * 2.0 + pow(sdot, 8.0) * 0.3);
    return col;
}

// Cloud density in a slab y = 0.6..1.4 (rounded bottoms, wispy tops).
static float cld17(float3 pos, float3 off, float cov) {
    float hy = clamp((pos.y - 0.6) / 0.8, 0.0, 1.0);
    float prof = smoothstep(0.0, 0.18, hy) * smoothstep(1.0, 0.45, hy);
    float3 q = pos * 1.1 + off;
    float d = fbm17(q) + 0.12 * n17(q * 4.1 + off * 0.5);
    return max(d * prof - (1.0 - cov) * (0.55 + 0.35 * hy), 0.0);
}

kernel void fx3D17(texture2d<half, access::sample> src [[texture(0)]],
                   texture2d<half, access::write> dst [[texture(1)]],
                   texture2d<half, access::sample> aux [[texture(2)]],
                   constant EffectParams& p [[buffer(0)]],
                   uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float4 s = float4(src.sample(sm17Zero, c));
    float t = p.d.x;
    float mn = max(min(size.x, size.y), 1.0);
    float2 ctr = size * 0.5;
    float2 uv = float2(c.x - ctr.x, ctr.y - c.y) / mn * 2.0;   // y up, +-1 on the short side
    float3 g = float3(0.0);
    float ga = 0.0;
    float4 pc = float4(0.0);
    int mode = int(p.i.x);

    if (mode < 10) {
        // Raymarched solids: a = (rotX speed, rotY speed, size 0-1, light angle), b = color.
        float2 ang = float2(0.45 + p.a.x * t, 0.6 + p.a.y * t);
        float S = max(p.a.z, 0.02) * 1.3;
        float3 ro = float3(0.0, 0.0, -3.5);
        float3 rd = normalize(float3(uv, 2.5));
        float tt = 0.5, best = 1e9, bt = 3.5;
        bool hit = false;
        for (int k = 0; k < 64; k++) {
            float d = map17(ro + rd * tt, mode, ang, S);
            float rr = d / tt;
            if (rr < best) { best = rr; bt = tt; }
            if (d < 0.0008 * tt) { hit = true; bt = tt; break; }
            tt += d * 0.9;
            if (tt > 7.0) break;
        }
        float cov = hit ? 1.0 : 1.0 - smoothstep(0.0, 0.9 / mn, best);
        if (cov > 0.0) {
            float3 pos = ro + rd * bt;
            float3 n = nrm17(pos, mode, ang, S);
            float3 q = obj17(pos, ang) / S;
            float pat = 0.8 + 0.2 * smoothstep(-0.15, 0.15, sin(q.x * 6.0) * sin(q.y * 6.0) * sin(q.z * 6.0));
            float3 L = normalize(float3(cos(p.a.w), sin(p.a.w), -0.9));
            float dif = max(dot(n, L), 0.0);
            float3 hv = normalize(L - rd);
            float spec = pow(max(dot(n, hv), 0.0), 32.0) * 0.5;
            float rim = pow(1.0 - max(dot(n, -rd), 0.0), 3.0) * 0.25;
            g = p.b.rgb * (0.22 + 0.85 * dif) * pat + float3(spec + rim);
            ga = cov;
        }
    } else {
        switch (mode) {
            case 10: { // infinite tunnel: a = (speed, repeat, twist, fog 0-1)
                float r = max(length(uv), 1e-3);
                float an = atan2(uv.y, uv.x);
                float z = 0.6 / r;
                float rep = max(floor(p.a.y + 0.5), 1.0);
                float u = an / 6.2831853 * rep + p.a.z * z * 0.15;
                float v = z * 0.35 + t * p.a.x;
                float4 tx = float4(src.sample(sm17Rep, float2(u, v)));
                float f = mix(1.0, clamp(r * 1.6, 0.0, 1.0), clamp(p.a.w, 0.0, 1.0));
                pc = tx * f;
                break;
            }
            case 11: { // cube skybox: a = (yaw, pitch, fov rad, 0)
                float fl = 1.0 / tan(clamp(p.a.z, 0.2, 3.0) * 0.5);
                float3 rd = normalize(float3(uv, fl));
                rd = ry17(rx17(rd, p.a.y), p.a.x);
                float3 ad = abs(rd);
                float2 fuv;
                if (ad.x >= ad.y && ad.x >= ad.z) fuv = float2(-rd.z * sign(rd.x), -rd.y) / ad.x;
                else if (ad.y >= ad.z) fuv = float2(rd.x, rd.z * sign(rd.y)) / ad.y;
                else fuv = float2(rd.x * sign(rd.z), -rd.y) / ad.z;
                float e = max(abs(fuv.x), abs(fuv.y));
                float sh = mix(1.0, 0.65, smoothstep(0.8, 1.0, e));
                pc = float4(src.sample(sm17Edge, fuv * 0.5 + 0.5)) * sh;
                break;
            }
            case 12: { // sphere map: a = (radius px, spin, tilt, shading)
                float R = max(p.a.x, 2.0);
                float2 q = float2(c.x - ctr.x, ctr.y - c.y) / R;
                float rr = dot(q, q);
                float4 col = float4(0.0);
                if (rr < 1.0) {
                    float3 nv = float3(q.x, q.y, -sqrt(max(1.0 - rr, 0.0)));
                    float3 n = ry17(rx17(nv, p.a.z), p.a.y);
                    float u = atan2(n.x, -n.z) / 6.2831853 + 0.5;
                    float v = 0.5 - asin(clamp(n.y, -1.0, 1.0)) / 3.14159265;
                    float4 tx = float4(src.sample(sm17Rep, float2(u, v)));
                    float shd = clamp(p.a.w, 0.0, 1.0);
                    float3 L = normalize(float3(-0.5, 0.55, -0.7));
                    float lam = max(dot(nv, L), 0.0);
                    float3 Hh = normalize(L + float3(0.0, 0.0, -1.0));
                    float spec = pow(max(dot(nv, Hh), 0.0), 40.0) * 0.7 * shd;
                    float rim = pow(1.0 + nv.z, 3.0) * 0.35 * shd;
                    float sh = mix(1.0, 0.2 + 0.95 * lam, shd);
                    float cov = clamp((1.0 - sqrt(rr)) * R, 0.0, 1.0);
                    col = float4(tx.rgb * sh + (spec + rim) * tx.a, tx.a) * cov;
                }
                float2 sq = (q - float2(0.12, -0.16)) * float2(1.0, 1.15);
                float sa = clamp(p.b.x, 0.0, 1.0) * 0.6 * (1.0 - smoothstep(0.75, 1.3, length(sq)));
                pc = col + float4(0.0, 0.0, 0.0, sa * (1.0 - col.a));
                break;
            }
            case 13: { // cylinder wrap: a = (radius px, spin, height px, shading)
                float R = max(p.a.x, 2.0), H = max(p.a.z, 2.0);
                float qx = (c.x - ctr.x) / R;
                float4 col = float4(0.0);
                if (abs(qx) < 1.0) {
                    float nz = sqrt(max(1.0 - qx * qx, 0.0));
                    float v = (c.y - ctr.y - nz * R * 0.12) / H + 0.5;   // curved top/bottom edges (seen from slightly above)
                    if (v > 0.0 && v < 1.0) {
                        float an = asin(clamp(qx, -1.0, 1.0)) + p.a.y;
                        float u = fract(an / 6.2831853 + 0.5);
                        float4 tx = float4(src.sample(sm17Rep, float2(u, v)));
                        float shd = clamp(p.a.w, 0.0, 1.0);
                        float3 nv = float3(qx, 0.0, -nz);
                        float3 L = normalize(float3(-0.55, 0.35, -0.75));
                        float lam = max(dot(nv, L), 0.0);
                        float3 Hh = normalize(L + float3(0.0, 0.0, -1.0));
                        float spec = pow(max(dot(nv, Hh), 0.0), 24.0) * 0.6 * shd;
                        float rim = pow(1.0 - nz, 3.0) * 0.3 * shd;
                        float sh = mix(1.0, 0.2 + 0.95 * lam, shd);
                        float cov = clamp((1.0 - abs(qx)) * R, 0.0, 1.0) * clamp(min(v, 1.0 - v) * H, 0.0, 1.0);
                        col = float4(tx.rgb * sh + (spec + rim) * tx.a, tx.a) * cov;
                    }
                }
                float2 so = float2((c.x - ctr.x - R * 0.15) / (R * 1.2), (c.y - (ctr.y + H * 0.5 + R * 0.12)) / (R * 0.25));
                float sa = clamp(p.b.x, 0.0, 1.0) * 0.6 * (1.0 - smoothstep(0.3, 1.0, length(so)));
                pc = col + float4(0.0, 0.0, 0.0, sa * (1.0 - col.a));
                break;
            }
            case 14: { // page flip: a = (angle rad, eye distance px, shading, 0)
                // a.w = page size 0-1 (page centred, hinged on its left edge), b.x = ground shadow 0-1
                float th = p.a.x, cs = cos(th), sn = sin(th);
                float zf = clamp(p.a.w, 0.1, 1.0);
                float Wp = size.x * zf, Hp = size.y * zf;
                float3 O = float3(ctr.x - Wp * 0.5, ctr.y - Hp * 0.5, 0.0);
                float3 E = float3(ctr, -p.a.y);
                float3 D = float3(c - ctr, p.a.y);
                float3 n = float3(sn, 0.0, cs);
                float dn = dot(n, D);
                float shd = clamp(p.a.z, 0.0, 1.0);
                float4 col = float4(0.0);
                if (abs(dn) > 1e-5) {
                    float sp = dot(n, O - E) / dn;
                    float3 P = E + D * sp;
                    float u = (P.x - O.x) * cs - P.z * sn;
                    float vy = P.y - O.y;
                    if (sp > 0.0 && u >= 0.0 && u <= Wp && vy >= 0.0 && vy <= Hp) {
                        float4 tx = float4(src.sample(sm17Zero, float2(u / Wp * size.x, vy / Hp * size.y)));
                        float3 nf = n * (cs >= 0.0 ? -1.0 : 1.0);          // normal facing the viewer
                        float3 L = normalize(float3(-0.45, -0.5, -0.75));  // pixel space, y down
                        float lam = max(dot(nf, L), 0.0);
                        float3 Hh = normalize(L + float3(0.0, 0.0, -1.0));
                        float spec = pow(max(dot(nf, Hh), 0.0), 30.0) * 0.6 * shd * clamp(sn * 3.0, 0.0, 1.0);
                        float sh = mix(1.0, 0.35 + 0.9 * lam, shd);
                        sh *= 1.0 - 0.3 * shd * abs(sn) * smoothstep(0.55, 1.0, u / Wp);   // soft curl toward the free edge
                        if (cs < 0.0) sh *= 0.75;
                        float cov = clamp(min(min(u, Wp - u), min(vy, Hp - vy)) + 0.5, 0.0, 1.0);
                        col = float4(tx.rgb * sh + spec * tx.a, tx.a) * cov;
                    }
                }
                float den2 = cs + 0.35 * sn;
                float sa = 0.0;
                if (den2 > 0.05) {
                    float s2 = (c.x - O.x) / den2;
                    float yy = c.y - O.y - s2 * sn * 0.25;
                    float bw = 2.0 + max(s2, 0.0) * sn * 0.08;
                    float inx = smoothstep(-bw, bw, s2) * (1.0 - smoothstep(Wp - bw, Wp + bw, s2));
                    float iny = smoothstep(-bw, bw, yy) * (1.0 - smoothstep(Hp - bw, Hp + bw, yy));
                    sa = clamp(p.b.x, 0.0, 1.0) * 0.55 * inx * iny * clamp(sn * 3.0, 0.0, 1.0);
                }
                pc = col + float4(0.0, 0.0, 0.0, sa * (1.0 - col.a));
                break;
            }
            case 15: { // cube flip: a = (angle rad, eye distance px, shading, 0)
                float th = p.a.x;
                float3 hb = float3(size.x * 0.5, size.y * 0.5, size.x * 0.5);
                float3 Cc = float3(ctr, hb.z);
                float3 E = float3(ctr, -p.a.y);
                float3 D = float3(c - ctr, p.a.y);
                float3 o = ry17(E - Cc, -th);
                float3 d = ry17(D, -th);
                float3 ds = select(float3(1e-6), d, abs(d) > 1e-6);
                float3 t1 = (-hb - o) / ds, t2 = (hb - o) / ds;
                float3 tn = min(t1, t2), tf = max(t1, t2);
                float tmin = max(tn.x, max(tn.y, tn.z));
                float tmax = min(tf.x, min(tf.y, tf.z));
                if (tmin <= tmax && tmin > 0.0) {
                    float3 L = o + d * tmin;
                    float2 px;
                    float3 nl;
                    if (tn.x >= tn.y && tn.x >= tn.z) { nl = float3(sign(L.x), 0.0, 0.0); px = float2(L.x > 0.0 ? L.z + hb.z : hb.z - L.z, L.y + hb.y); }
                    else if (tn.z >= tn.y) { nl = float3(0.0, 0.0, sign(L.z)); px = float2(L.z < 0.0 ? L.x + hb.x : hb.x - L.x, L.y + hb.y); }
                    else { nl = float3(0.0, sign(L.y), 0.0); px = float2(L.x + hb.x, L.z + hb.z); }
                    px.x *= size.x / max(2.0 * (abs(nl.x) > 0.5 ? hb.z : hb.x), 1.0);
                    float3 nw = ry17(nl, th);
                    float sh = mix(1.0, 0.3 + 0.7 * max(-nw.z, 0.0), clamp(p.a.z, 0.0, 1.0));
                    pc = float4(src.sample(sm17Zero, px)) * sh;
                }
                break;
            }
            case 16: { // rotating plane: a = (rotX, rotY, eye distance px, shading)
                float3 C = float3(ctr, 0.0);
                float3 E = float3(ctr, -p.a.z);
                float3 D = float3(c - ctr, p.a.z);
                float3 nw = ry17(rx17(float3(0.0, 0.0, 1.0), p.a.x), p.a.y);
                float dn = dot(D, nw);
                if (abs(dn) > 1e-5) {
                    float sp = dot(C - E, nw) / dn;
                    if (sp > 0.0) {
                        float3 P = E + D * sp;
                        float3 lv = rx17(ry17(P - C, -p.a.y), -p.a.x);
                        float2 px = lv.xy + ctr;
                        float sh = mix(1.0, 0.35 + 0.65 * abs(nw.z), clamp(p.a.w, 0.0, 1.0));
                        pc = float4(src.sample(sm17Zero, px)) * sh;
                    }
                }
                break;
            }
            case 17: { // floor grid 360: a = (yaw, cell, cam height, line width), b = color, c.x = glow
                float3 rd = normalize(float3(uv.x, uv.y - 0.25, 1.6));
                rd.xz = r2d17(rd.xz, p.a.x);
                float cell = max(p.a.y, 0.05);
                float m = 0.0, fade = 0.0;
                if (rd.y < -1e-3) {
                    float sp = max(p.a.z, 0.05) / (-rd.y);
                    float2 xz = (rd.xz * sp) / cell;
                    float2 f = abs(fract(xz + 0.5) - 0.5);
                    float fw = sp * 1.25 / (mn * cell) * (1.0 + 0.25 / max(-rd.y, 0.05));
                    float lw = clamp(p.a.w, 0.002, 0.45);
                    float2 lm = 1.0 - smoothstep(float2(lw), float2(lw + fw), f);
                    m = max(lm.x, lm.y);
                    m = mix(m, min(lw * 2.5, 1.0), clamp(fw * 1.5, 0.0, 1.0));
                    fade = exp(-sp * 0.06 / cell);
                }
                float hg = exp(-abs(rd.y) * 18.0) * p.c.x;
                g = p.b.rgb * (m * fade * 1.5 + hg);
                break;
            }
            case 18: { // starfield planes: a = (speed, density, size px, roll), b = color
                float2 q = r2d17(uv, p.a.w);
                float dens = max(p.a.y, 0.5);
                float acc = 0.0;
                for (int k = 0; k < 8; k++) {
                    float fk = float(k);
                    float z = fract((fk + 0.5) / 8.0 - t * p.a.x * 0.15) * 4.0 + 0.05;
                    float2 P = q * z * dens + float2(fk * 13.1, fk * 7.7);
                    float2 id = floor(P);
                    float hs = h17(id + fk * 3.7);
                    if (hs > 0.55) continue;
                    float2 sp = id + 0.25 + 0.5 * float2(h17(id * 1.3 + 2.1), h17(id * 0.7 + 5.3 + fk));
                    float2 dpx = (P - sp) / (z * dens) * mn * 0.5;
                    float r = max(p.a.z, 0.3) * clamp(1.5 / z, 0.3, 4.0);
                    float m = exp(-dot(dpx, dpx) / (r * r));
                    float fd = smoothstep(4.05, 2.5, z) * smoothstep(0.05, 0.35, z);
                    acc += m * fd * (0.5 + hs);
                }
                g = p.b.rgb * acc;
                ga = clamp(acc, 0.0, 1.0);
                break;
            }
            case 19: { // city skyline: a = (scroll px, width px, height 0-1, window density), b = building, c = window color
                float groundY = size.y * 0.97;
                for (int L = 0; L < 3; L++) {
                    float fl = float(L);
                    float bw = max(p.a.y, 3.0) * (0.6 + 0.3 * fl);
                    float xx = c.x + p.a.x * (0.4 + 0.3 * fl) + fl * 137.0;
                    float id = floor(xx / bw);
                    float fx = fract(xx / bw);
                    float hgt = size.y * clamp(p.a.z, 0.0, 1.0) * (0.3 + 0.7 * h17(float2(id, fl * 7.0))) * (0.6 + 0.2 * fl);
                    float top = groundY - hgt;
                    float bx = (id + 0.5) * bw - p.a.x * (0.4 + 0.3 * fl) - fl * 137.0;
                    bool rightSide = bx < ctr.x;
                    float fxs = rightSide ? fx : 1.0 - fx;
                    float shade = 0.5 + 0.25 * fl;
                    if (fxs > 0.05 && fxs < 0.75 && c.y > top && c.y < groundY) {
                        float3 col = p.b.rgb * shade;
                        float win = max(bw * 0.12, 1.5);
                        float2 wq = float2((fxs - 0.05) * bw, c.y - top - win) / win;
                        if (wq.y > 0.0 && fract(wq.x) < 0.55 && fract(wq.y) < 0.5 && h17(floor(wq) + id * 3.1 + fl) < p.a.w)
                            col = p.c.rgb;
                        g = col; ga = 1.0;
                    } else if (fxs >= 0.75 && fxs < 0.92) {
                        float stop = top + (fxs - 0.75) * bw * 0.6;
                        if (c.y > stop && c.y < groundY) { g = p.b.rgb * shade * 0.55; ga = 1.0; }
                    }
                }
                break;
            }
            case 20: { // seascape: a = (wave height, speed, cam height, sun angle), b = water, c = sky
                float3 rd = normalize(float3(uv.x, uv.y + 0.1, 1.5));
                float3 sd = normalize(float3(cos(p.a.w), 0.1 + 0.4 * max(sin(p.a.w), 0.0), 1.5));
                float3 col;
                if (rd.y < -1e-3) {
                    float sp = max(p.a.z, 0.05) / (-rd.y);
                    float2 xz = rd.xz * sp + float2(0.0, t * p.a.y * 0.5);
                    float2 gr = float2(0.0);
                    for (int k = 0; k < 4; k++) {
                        float fk = float(k);
                        float2 dk = float2(cos(fk * 1.7 + 0.3), sin(fk * 1.7 + 0.3));
                        float fq = 1.2 * pow(1.8, fk), am = 0.12 / pow(1.9, fk);
                        gr += am * fq * dk * cos(dot(dk, xz) * fq + t * p.a.y * (1.0 + fk * 0.6));
                    }
                    gr *= p.a.x;
                    float3 n = normalize(float3(-gr.x, 1.0, -gr.y));
                    float3 rf = reflect(rd, n);
                    rf.y = abs(rf.y);
                    float fr = pow(1.0 - max(dot(n, -rd), 0.0), 4.0) * 0.8 + 0.1;
                    float3 water = p.b.rgb * (0.3 + 0.5 * max(dot(n, sd), 0.0));
                    col = mix(water, sky17(rf, sd, p.c.rgb), fr);
                    col = mix(col, sky17(float3(rd.x, 0.0, rd.z), sd, p.c.rgb), 1.0 - exp(-sp * 0.03));
                } else {
                    col = sky17(rd, sd, p.c.rgb);
                }
                g = col; ga = 1.0;
                break;
            }
            case 21: { // volumetric clouds: a = (coverage 0-1, speed, density, 0), b = color
                // a.w = sun angle. Light scattering: one shadow tap toward the sun per step, bright tops, dark
                // bases, forward-scatter silver lining when looking toward the sun.
                float3 rd = normalize(float3(uv.x, uv.y * 0.55 + 0.62, 1.0));
                float3 L = normalize(float3(cos(p.a.w) * 0.8, 0.45, sin(p.a.w) * 0.8));
                float cov = clamp(p.a.x, 0.0, 1.0), dens = max(p.a.z, 0.0);
                float T = 1.0;
                float3 acc = float3(0.0);
                if (rd.y > 0.01) {
                    float t0 = 0.6 / rd.y, t1 = min(1.4 / rd.y, t0 + 6.0);
                    float dt = (t1 - t0) / 24.0;
                    float3 off = float3(t * p.a.y * 0.3, 0.0, t * p.a.y);
                    float mu = max(dot(rd, L), 0.0);
                    float phase = 0.8 + 1.8 * pow(mu, 6.0) + 0.6 * pow(mu, 32.0);
                    float3 shadowCol = p.b.rgb * float3(0.42, 0.47, 0.58);
                    float jit = h17(c) * 0.8;
                    for (int k = 0; k < 24; k++) {
                        float3 pos = rd * (t0 + dt * (float(k) + jit));
                        float den = cld17(pos, off, cov);
                        if (den <= 0.002) continue;
                        float dl = cld17(pos + L * 0.18, off, cov);
                        float shad = exp(-dl * dens * 5.0);
                        float hy = clamp((pos.y - 0.6) / 0.8, 0.0, 1.0);
                        float3 amb = mix(shadowCol, p.b.rgb * 0.85, hy);
                        float edge = exp(-den * 6.0);                      // thin edges catch the light (silver lining)
                        float3 lc = amb * 0.7 + p.b.rgb * shad * phase * (0.6 + 0.6 * edge);
                        float as = 1.0 - exp(-den * dt * dens * 9.0);
                        acc += T * as * lc;
                        T *= 1.0 - as;
                        if (T < 0.02) break;
                    }
                }
                ga = (1.0 - T) * smoothstep(0.01, 0.12, rd.y);
                g = acc / max(1.0 - T, 1e-3);
                break;
            }
            case 22: { // point cloud sphere: a = (rotX, rotY, radius px, dot px), b = color, c.x = count
                // c = far color, d.w = point count. Ray/sphere hit (front + back), then the nearest points of a
                // latitude-banded lattice around each hit: dense, O(1) per pixel.
                float2 ang = float2(0.45 + p.a.x * t, 0.6 + p.a.y * t);
                float R = max(p.a.z, 2.0);
                float2 w = float2(c.x - ctr.x, ctr.y - c.y) / R;
                float3 ro = float3(0.0, 0.0, -3.0), rd = normalize(float3(w, 3.0));
                float nb = max(3.0, floor(sqrt(clamp(p.d.w, 20.0, 2000.0) / 1.27) + 0.5));
                float dlat = 3.14159265 / nb;
                float dpx = max(p.a.w, 0.3);
                float3 acc = float3(0.0);
                float rho = length(cross(rd, -ro));                         // ray distance from the sphere centre
                acc += mix(p.b.rgb, p.c.rgb, 0.4) * 0.2 * exp(-abs(rho - 1.0) * 7.0);   // soft atmospheric bloom
                float bq = dot(ro, rd), disc = bq * bq - (dot(ro, ro) - 1.0);
                if (disc > 0.0) {
                    float sq = sqrt(disc);
                    for (int hh = 0; hh < 2; hh++) {
                        float3 P = ro + rd * (-bq + (hh == 0 ? -sq : sq));
                        float f = clamp((P.z + 1.0) * 0.5, 0.0, 1.0);        // 0 near .. 1 far
                        float persp = 3.0 / (P.z + 3.0);
                        float3 O = ry17(rx17(P, -ang.x), -ang.y);
                        float lat = asin(clamp(O.y, -1.0, 1.0)), lon = atan2(O.z, O.x);
                        float bi = floor((lat + 1.5707963) / dlat);
                        float sz = dpx * persp * mix(1.4, 0.65, f);
                        float bri = mix(1.5, 0.28, f);
                        float3 pcol = mix(p.b.rgb, p.c.rgb, f);
                        float sum = 0.0;
                        for (int bb = -1; bb <= 1; bb++) {
                            float i = bi + float(bb);
                            if (i < 0.0 || i >= nb) continue;
                            float li = -1.5707963 + (i + 0.5) * dlat;
                            float m = max(1.0, floor(2.0 * nb * cos(li) + 0.5));
                            float st = 6.2831853 / m;
                            float of = h17(float2(i, 3.7)) * st;
                            float ql = of + floor((lon - of) / st + 0.5) * st;
                            float3 Q = float3(cos(li) * cos(ql), sin(li), cos(li) * sin(ql));
                            float d = length(O - Q) * R * persp;
                            sum += exp(-d * d / (sz * sz)) + 0.22 * exp(-d * d / (sz * sz * 5.0));
                        }
                        acc += pcol * bri * sum;
                    }
                }
                g = acc;
                ga = clamp(lum17(acc), 0.0, 1.0);
                break;
            }
            case 23: { // orbit particles: a = (speed, radius px, tilt, dot px), b = color, c.x = count
                // c.x = count (<= 64), c.y = trail 0-1. Each particle is a fading streak along its orbit, sized and
                // dimmed by distance from the focal plane (depth-of-field look) plus a soft glow halo.
                int N = int(clamp(p.c.x, 1.0, 64.0));
                float R = max(p.a.y, 2.0);
                float dpx = max(p.a.w, 0.3);
                float trl = clamp(p.c.y, 0.0, 1.0);
                float3 acc = float3(0.0);
                for (int k = 0; k < 64; k++) {
                    if (k >= N) break;
                    float fk = float(k);
                    float h1 = h17(float2(fk, 1.3)), h2 = h17(float2(fk, 7.1)), h3 = h17(float2(fk, 3.9)), h4 = h17(float2(fk, 9.4));
                    float rk = 0.35 + 0.65 * h1;
                    float wsp = p.a.x * (0.6 + 0.8 * h2) / rk;
                    float a0 = h4 * 6.2831853 + t * wsp;
                    float a1 = a0 - sign(wsp) * trl * 1.1 * clamp(abs(wsp), 0.3, 2.0);
                    float inc = p.a.z + (h2 - 0.5) * 1.2, node = h3 * 6.2831853;
                    float3 q0 = ry17(rx17(float3(cos(a0), 0.0, sin(a0)) * rk, inc), node);
                    float3 q1 = ry17(rx17(float3(cos(a1), 0.0, sin(a1)) * rk, inc), node);
                    float z0 = q0.z + 3.0, z1 = q1.z + 3.0;
                    float2 s0 = ctr + float2(q0.x, -q0.y) * (3.0 / z0) * R;
                    float2 s1 = ctr + float2(q1.x, -q1.y) * (3.0 / z1) * R;
                    float dof = 1.0 + 2.2 * abs(q0.z);
                    float sz = dpx * (3.0 / z0) * dof;
                    float2 pa = c - s0, ba = s1 - s0;
                    float hh = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
                    float2 dv = pa - ba * hh;
                    float d2 = dot(dv, dv);
                    float wd = sz * (1.0 - 0.6 * hh);
                    if (d2 > wd * wd * 40.0) continue;
                    float bri = (1.35 - 0.4 * (q0.z + 1.0)) / dof;
                    float fade = (1.0 - hh) * (1.0 - hh);
                    float3 pcol = mix(p.b.rgb, p.b.gbr, h1 * 0.35);
                    float core = exp(-d2 / (wd * wd));
                    float halo = 0.3 * exp(-d2 / (wd * wd * 8.0));
                    acc += (pcol * (core + halo) + float3(core * 0.35)) * bri * mix(1.0, fade, 0.9);
                }
                g = acc;
                ga = clamp(lum17(acc), 0.0, 1.0);
                break;
            }
            default: { // extrude flat: a = (depth px, angle, shade 0-1, 0), b = side color
                // a.w = layer-color mix 0-1. 48 stacked alpha copies form the side wall; the wall is lit near the
                // front face and darkens with depth, with a thin highlight along the crease.
                float2 dir = float2(cos(p.a.y), sin(p.a.y));
                float ea = 0.0, kk = 1.0;
                bool fnd = false;
                float3 lcol = float3(0.0);
                for (int k = 1; k <= 48; k++) {
                    float4 sm = float4(src.sample(sm17Zero, c - dir * p.a.x * (float(k) / 48.0)));
                    if (!fnd && sm.a > 0.5) { fnd = true; kk = float(k) / 48.0; lcol = sm.rgb / max(sm.a, 1e-3); }
                    ea = max(ea, sm.a);
                }
                float shade = clamp(p.a.z, 0.0, 1.0);
                float3 side = mix(p.b.rgb, lcol * 0.85, clamp(p.a.w, 0.0, 1.0));
                float sh = mix(1.12, 1.0 - shade, smoothstep(0.0, 1.0, kk));
                sh *= 1.0 + 0.4 * (1.0 - smoothstep(0.0, 0.08, kk));         // crease highlight next to the face
                sh *= 1.0 - 0.25 * shade * smoothstep(0.8, 1.0, kk);         // occlusion at the back end
                float4 ex = float4(side * sh * ea, ea);
                pc = p.d.z > 0.5 ? ex * (1.0 - s.a) : s + ex * (1.0 - s.a);
                break;
            }
        }
    }

    float4 base = p.d.z > 0.5 ? float4(0.0) : s;
    float bl = clamp(p.d.y, 0.0, 1.0);
    float4 o;
    if (p.i.y == 0u) {
        float3 Lg = clamp(g, float3(0.0), float3(8.0)) * bl;
        o = float4(base.rgb + Lg, max(base.a, clamp(max(ga * bl, lum17(Lg)), 0.0, 1.0)));
    } else if (p.i.y == 1u) {
        float a = clamp(ga, 0.0, 1.0) * bl;
        o = float4(clamp(g, 0.0, 4.0) * a + base.rgb * (1.0 - a), a + base.a * (1.0 - a));
    } else {
        o = clamp(pc, float4(0.0), float4(8.0)) * bl + base * (1.0 - bl);
    }
    o = select(o, float4(0.0), isnan(o));
    dst.write(half4(o), gid);
}
