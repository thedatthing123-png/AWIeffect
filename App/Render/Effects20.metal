#include <metal_stdlib>
using namespace metal;

struct EffectParams20 { float4 a; float4 b; float4 c; float4 d; uint4 i; };

constexpr sampler s20(address::clamp_to_zero, filter::linear);

// Flip (2D / 3D card flip, like AE CC Basic 3D / Alight Motion Flip): the layer is a card turned around a pivot and
// seen through a camera. a = (angle around Y rad, tilt around X rad, spin around Z rad, camera distance px);
// b = (pivot x, pivot y px, layer half w, half h px); c = back side color; i.x back mode (0 mirror, 1 same, 2 hidden,
// 3 color), i.y shading on.
kernel void fx20Flip(texture2d<half, access::sample> src [[texture(0)]],
                     texture2d<half, access::write> dst [[texture(1)]],
                     constant EffectParams20& p [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 size = float2(dst.get_width(), dst.get_height());
    float2 c = float2(gid) + 0.5 - p.b.xy;
    float cy = cos(p.a.x), sy = sin(p.a.x), cx = cos(p.a.y), sx = sin(p.a.y), cz = cos(p.a.z), sz = sin(p.a.z);
    // R = Rz * Ry * Rx (card local -> world).
    float3x3 Rx = float3x3(float3(1, 0, 0), float3(0, cx, sx), float3(0, -sx, cx));
    float3x3 Ry = float3x3(float3(cy, 0, -sy), float3(0, 1, 0), float3(sy, 0, cy));
    float3x3 Rz = float3x3(float3(cz, sz, 0), float3(-sz, cz, 0), float3(0, 0, 1));
    float3x3 R = Rz * Ry * Rx;
    float3 n = R * float3(0, 0, 1);
    float D = max(p.a.w, 50.0);
    float3 eye = float3(0, 0, -D);
    float3 dir = float3(c, 0) - eye;
    float denom = dot(dir, n);
    if (abs(denom) < 1e-5) { dst.write(half4(0), gid); return; }
    float t = -dot(eye, n) / denom;
    if (t <= 0) { dst.write(half4(0), gid); return; }
    float3 X = eye + dir * t;
    float3 local = transpose(R) * X;
    bool back = dot(n, X - eye) > 0.0;
    float2 uv = local.xy;
    if (any(abs(uv) > p.b.zw)) { dst.write(half4(0), gid); return; }
    float4 col;
    if (back) {
        if (p.i.x == 2) { dst.write(half4(0), gid); return; }
        if (p.i.x == 3) {
            float a = float(src.sample(s20, p.b.xy + uv).a);
            col = float4(p.c.rgb * a, a);
        } else {
            // Mirror: the back shows the image as seen through the card; Same: reads normally.
            float2 q = p.i.x == 0 ? uv : float2(-uv.x, uv.y);
            col = float4(src.sample(s20, p.b.xy + q));
        }
    } else {
        col = float4(src.sample(s20, p.b.xy + uv));
    }
    if (p.i.y != 0) {
        // Simple lighting from the camera: darker as the card turns edge-on.
        float lit = 0.55 + 0.45 * abs(n.z);
        col.rgb *= lit;
    }
    dst.write(half4(col), gid);
    (void)size;
}
