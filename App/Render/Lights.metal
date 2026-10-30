#include <metal_stdlib>
using namespace metal;

// AE-style 3D lights applied to one 3D layer's local buffer (premultiplied rgba16Float, sRGB-encoded).
struct LightGPU {
    float4 posType;      // xyz world position, w type (0 point, 1 spot, 2 parallel, 3 ambient)
    float4 dirCone;      // xyz direction the light points (spot/parallel), w cos(cone half-angle)
    float4 color;        // rgb * intensity, w cone feather (0-1)
    float4 falloff;      // x radius (0 = none), y shadow darkness unused, zw unused
};

struct LightPass {
    float4 w0;           // local (x,y) -> world: world = w0.xyz*x + w1.xyz*y + w2.xyz
    float4 w1;
    float4 w2;
    float4 normal;       // world-space plane normal facing the camera
    float4 camPos;       // xyz camera position
    float4 tex;          // x,y = texture px -> local: local = tex.xy * px + tex.zw  (uniform scale in x, offset)
    uint4 count;         // x = number of lights
};

kernel void applyLights(texture2d<half, access::read> src [[texture(0)]],
                        texture2d<half, access::write> dst [[texture(1)]],
                        constant LightPass& lp [[buffer(0)]],
                        constant LightGPU* lights [[buffer(1)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 s = float4(src.read(gid));
    if (s.a <= 0.0001) { dst.write(half4(s), gid); return; }
    float2 local = float2(gid) * lp.tex.x + lp.tex.zw;
    float3 P = lp.w0.xyz * local.x + lp.w1.xyz * local.y + lp.w2.xyz;
    float3 N = normalize(lp.normal.xyz);
    float3 V = normalize(lp.camPos.xyz - P);
    float3 light = float3(0.0);
    for (uint i = 0; i < min(lp.count.x, 8u); i++) {
        LightGPU L = lights[i];
        uint type = uint(L.posType.w + 0.5);
        if (type == 3u) { light += L.color.rgb; continue; }
        float3 Ld;
        float atten = 1.0;
        if (type == 2u) {
            Ld = normalize(-L.dirCone.xyz);
        } else {
            float3 d = L.posType.xyz - P;
            float dist = max(length(d), 1e-3);
            Ld = d / dist;
            if (L.falloff.x > 0.0) atten = clamp(1.0 - dist / L.falloff.x, 0.0, 1.0);
            if (type == 1u) {
                float c = dot(-Ld, normalize(L.dirCone.xyz));
                float inner = mix(L.dirCone.w, 1.0, 1.0 - clamp(L.color.w, 0.0, 1.0));
                atten *= smoothstep(L.dirCone.w, max(inner, L.dirCone.w + 1e-3), c);
            }
        }
        float ndl = abs(dot(N, Ld));           // planes are lit from either side (AE accepts lights two-sided)
        float3 H = normalize(Ld + V);
        float spec = pow(max(abs(dot(N, H)), 0.0), 40.0) * 0.25;
        light += L.color.rgb * atten * (ndl + spec);
    }
    float3 rgb = s.rgb * light;
    dst.write(half4(half3(rgb), half(s.a)), gid);
}
