#include <metal_stdlib>
using namespace metal;

// Alight Motion-style warps (own implementation, matching AM's controls and behaviour).
struct EffectParamsAM { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler sAM(address::clamp_to_zero, filter::linear);

static float hAM(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
static float nAM(float2 p) {
    float2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hAM(i), hAM(i + float2(1, 0)), u.x), mix(hAM(i + float2(0, 1)), hAM(i + float2(1, 1)), u.x), u.y);
}
// fbm in 0..1; each octave drifts by `par` (parallax) a little more than the last, so animating Parallax flows.
static float fbmAM(float2 p, float2 par, int oct, float gain) {
    float v = 0.0, a = 0.5, norm = 0.0;
    for (int k = 0; k < 9; k++) {
        if (k >= oct) break;
        v += a * nAM(p + par * float(k + 1));
        norm += a; a *= gain; p = p * 2.0 + float2(3.7, 1.9);
    }
    return v / max(norm, 1e-4);
}

// Wave Warp (AM): a = (wave angle rad, warp angle rad, spacing, magnitude %), b = layer rect (x,y,w,h px),
// c = (phase cycles, damping, damping spacing, damping origin), i.x screen space.
kernel void fx20AMWave(texture2d<half, access::sample> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       constant EffectParamsAM& p [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float2 st = p.i.x != 0 ? c / size : (c - p.b.xy) / max(p.b.zw, float2(1.0));
    float2 dir = float2(cos(p.a.x), -sin(p.a.x));
    float along = dot(st, dir);
    float sd = 1.0;
    float far = clamp(abs(along - p.c.w), 0.0, 1.0);
    if (p.c.z < 0.0) sd = 1.0 - far * (-p.c.z);
    else if (p.c.z > 0.0) sd = 1.0 - (1.0 - far) * p.c.z;
    float space = p.a.z * sd;
    float ph = along * space;
    float dist = abs(space) > 1e-5 ? abs(ph / space) : 0.0;
    float md = 1.0;
    float far2 = clamp(abs(dist - p.c.w), 0.0, 1.0);
    if (p.c.y < 0.0) md = 1.0 - far2 * (-p.c.y);
    else if (p.c.y > 0.0) md = 1.0 - (1.0 - far2) * p.c.y;
    float2 warp = float2(cos(p.a.y), -sin(p.a.y)) * (p.a.w * md / 100.0) * sin(ph + p.c.x * 6.2831853);
    float2 ref = p.i.x != 0 ? size : p.b.zw;
    dst.write(src.sample(sAM, c + warp * ref), gid);
}

// Fractal Warp (AM): a = (position x, y, parallax x, y), b = layer rect, c = (magnitude, detail, lacunarity, octaves),
// d.x pin falloff, i.x screen space, i.y pinning (0 none, 1 all, 2 top, 3 bottom, 4 left, 5 right).
kernel void fx20AMFractal(texture2d<half, access::sample> src [[texture(0)]],
                          texture2d<half, access::write> dst [[texture(1)]],
                          constant EffectParamsAM& p [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5;
    float2 ref = p.i.x != 0 ? size : max(p.b.zw, float2(1.0));
    float2 st = p.i.x != 0 ? c / size : (c - p.b.xy) / ref;
    float2 sta = st * float2(ref.x / ref.y, 1.0) + p.a.xy / 1000.0 * float2(-1.0, 1.0);
    float2 par = p.a.zw / 200.0 * float2(-1.0, 1.0);
    int oct = int(clamp(p.c.w, 1.0, 9.0));
    float2 b = (sta - 0.5) * 3.0 * p.c.y + 0.5;
    float dx = fbmAM(b, par, oct, p.c.z);
    float dy = fbmAM(b + float2(25.3, 12.9) * 3.0 * p.c.y, par, oct, p.c.z);
    float pin = 1.0;
    if (p.i.y != 0) {
        float2 uv = clamp((c - p.b.xy) / max(p.b.zw, float2(1.0)), 0.0, 1.0);
        float s = max(p.d.x, 0.01);
        float top = smoothstep(0.0, s, uv.y), bot = smoothstep(0.0, s, 1.0 - uv.y), lf = smoothstep(0.0, s, uv.x), rt = smoothstep(0.0, s, 1.0 - uv.x);
        pin = p.i.y == 1 ? top * bot * lf * rt : (p.i.y == 2 ? top : (p.i.y == 3 ? bot : (p.i.y == 4 ? lf : rt)));
    }
    dst.write(src.sample(sAM, c + float2(dx - 0.5, dy - 0.5) * p.c.x * ref * pin), gid);
}
