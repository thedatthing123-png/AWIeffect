#include <metal_stdlib>
using namespace metal;

// Pixel Motion Blur (footage): block-matching motion estimate between the previous and current frame at low
// resolution, then a blur along each pixel's motion vector at full resolution.
struct MotionParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler mbs(address::clamp_to_edge, filter::linear, coord::normalized);

static inline float mlum(float4 c) { return dot(c.rgb, float3(0.299, 0.587, 0.114)); }

// flow (low res): rg = motion in uv units (current -> previous direction reversed = how the pixel moved).
// a.x = search radius in flow texels.
kernel void flowEstimate(texture2d<half, access::sample> prev [[texture(0)]],
                         texture2d<half, access::write> flow [[texture(1)]],
                         texture2d<half, access::sample> cur [[texture(2)]],
                         constant MotionParams& p [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= flow.get_width() || gid.y >= flow.get_height()) return;
    float2 size = float2(flow.get_width(), flow.get_height());
    float2 uv = (float2(gid) + 0.5) / size;
    float2 texel = 1.0 / size;
    int R = int(clamp(p.a.x, 1.0, 8.0));
    float best = 1e9; float2 bestD = 0.0;
    for (int dy = -R; dy <= R; dy++) {
        for (int dx = -R; dx <= R; dx++) {
            float2 d = float2(dx, dy) * texel;
            float sad = 0.0;
            for (int py = -1; py <= 1; py++) {
                for (int px = -1; px <= 1; px++) {
                    float2 o = float2(px, py) * texel;
                    sad += abs(mlum(float4(cur.sample(mbs, uv + o))) - mlum(float4(prev.sample(mbs, uv + o + d))));
                }
            }
            // Slight bias toward no motion so flat areas don't wander.
            sad += length(float2(dx, dy)) * 0.002;
            if (sad < best) { best = sad; bestD = d; }
        }
    }
    // The pixel came from uv + bestD in the previous frame, so it moved by -bestD.
    flow.write(half4(half2(-bestD), 0.0h, 1.0h), gid);
}

// a.x = amount (shutter, 1 = one frame of motion), a.y = max blur in uv, a.z samples,
// a.w = 1 keeps each pixel's own coverage (footage: blur the picture, never make the layer see-through).
kernel void flowBlur(texture2d<half, access::sample> cur [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     texture2d<half, access::sample> flow [[texture(2)]],
                     constant MotionParams& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    float2 v = float2(flow.sample(mbs, uv).rg) * p.a.x;
    float l = length(v);
    if (l > p.a.y) v *= p.a.y / l;
    float4 acc = 0.0;
    int N = p.a.z > 0 ? clamp(int(p.a.z), 6, 48) : 12;
    for (int k = 0; k < N; k++) {
        float f = (float(k) / float(N - 1) - 0.5);
        acc += float4(cur.sample(mbs, uv + v * f));
    }
    float4 o = acc / float(N);
    if (p.a.w > 0.5) {
        float a = float(cur.sample(mbs, uv).a);
        o = o.a > 1e-4 ? float4(o.rgb / o.a * a, a) : float4(cur.sample(mbs, uv));
    }
    dst.write(half4(o), gid);
}

// Motion blur: running sum of shutter samples. dst = acc + sample * a.x (a.x = 1 / sample count).
kernel void fxAccumulate(texture2d<half, access::read> acc [[texture(0)]],
                         texture2d<half, access::read> sample [[texture(1)]],
                         texture2d<half, access::write> dst [[texture(2)]],
                         constant MotionParams& p [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    dst.write(half4(float4(acc.read(gid)) + float4(sample.read(gid)) * p.a.x), gid);
}
