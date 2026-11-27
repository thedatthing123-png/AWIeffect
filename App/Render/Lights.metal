#include <metal_stdlib>
using namespace metal;

// AE-style 3D lights applied to one 3D layer's local buffer (premultiplied rgba16Float, sRGB-encoded).
struct LightGPU {
    float4 posType;      // xyz world position, w type (0 point, 1 spot, 2 parallel, 3 ambient)
    float4 dirCone;      // xyz direction the light points (spot/parallel), w cos(cone half-angle)
    float4 color;        // rgb * intensity, w cone feather (0-1)
    float4 falloff;      // x radius (0 = none), y shadow darkness, z edge blur, w distance spread (%)
};

struct LightPass {
    float4 w0;           // local (x,y) -> world: world = w0.xyz*x + w1.xyz*y + w2.xyz
    float4 w1;
    float4 w2;
    float4 normal;       // world-space plane normal facing the camera
    float4 camPos;       // xyz camera position
    float4 tex;          // x,y = texture px -> local: local = tex.xy * px + tex.zw  (uniform scale in x, offset)
    uint4 count;         // x: lights, y: casters, z: accepts shadows, w: layer half height as float bits
    float4 surface;      // depth in layer pixels, normal strength, roughness, specular
    uint4 surfaceFlags;  // normal, depth, convention and relief shadow flags, material enabled
};

// A layer that casts shadows: world -> its local px (rows of the inverse world matrix), its plane, half size.
struct ShadowCaster {
    float4 inv0;
    float4 inv1;
    float4 plane;        // xyz normal, w = dot(normal, point on plane)
    float4 halfSize;     // xy
};

struct RelightSourceParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

kernel void fxRelightSource(texture2d<half, access::sample> source [[texture(0)]],
                            texture2d<half, access::write> output [[texture(1)]],
                            texture2d<half, access::sample> base [[texture(2)]],
                            texture2d<half, access::sample> alpha [[texture(3)]],
                            constant RelightSourceParams& params [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    constexpr sampler sampleMap(coord::normalized, address::clamp_to_edge, filter::linear);
    const float2 uv = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());
    half4 color = source.sample(sampleMap, uv);
    if (params.i.x == 1u) color.rgb = base.sample(sampleMap, uv).rgb;
    if (params.i.y == 1u) {
        const half4 coverage = alpha.sample(sampleMap, uv);
        color.a *= coverage.r * coverage.a;
    }
    output.write(color, gid);
}

float reliefDepth(texture2d<half, access::sample> depth, float2 uv, uint flags) {
    constexpr sampler sampleMap(coord::normalized, address::clamp_to_edge, filter::linear);
    const float d = saturate(float(depth.sample(sampleMap, uv).r));
    return (flags & 1u) != 0 ? 1 - d : d;
}

kernel void applyLights(texture2d<half, access::sample> src [[texture(0)]],
                        texture2d<half, access::write> dst [[texture(1)]],
                        constant LightPass& lp [[buffer(0)]],
                        constant LightGPU* lights [[buffer(1)]],
                        constant ShadowCaster* casters [[buffer(2)]],
                        array<texture2d<half, access::sample>, 4> casterTex [[texture(2)]],
                        texture2d<half, access::sample> normalMap [[texture(6)]],
                        texture2d<half, access::sample> depthMap [[texture(7)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 s = float4(src.read(gid));
    if (s.a <= 0.0001) { dst.write(half4(s), gid); return; }
    float2 local = float2(gid) * lp.tex.x + lp.tex.zw;
    float3 P = lp.w0.xyz * local.x + lp.w1.xyz * local.y + lp.w2.xyz;
    float3 N = normalize(lp.normal.xyz);
    constexpr sampler sampleMap(coord::normalized, address::clamp_to_edge, filter::linear);
    constexpr sampler sampleCoverage(coord::normalized, address::clamp_to_zero, filter::linear);
    const float3 faceNormal = N;
    const float3 tangent = lp.w0.xyz / max(1e-5, length(lp.w0.xyz));
    const float3 down = lp.w1.xyz / max(1e-5, length(lp.w1.xyz));
    const float2 mapSize = max(float2(lp.tex.y, as_type<float>(lp.count.w)) * 2, float2(1));
    const float2 uv = local / mapSize + 0.5;
    const bool onMap = all(uv >= 0) && all(uv <= 1);
    const bool hasDepth = lp.surfaceFlags.y == 1u && lp.surface.x > 0 && onMap;
    const bool hasNormal = lp.surfaceFlags.x == 1u && onMap;
    const uint flags = lp.surfaceFlags.z;
    float height = 0;
    if (hasDepth) {
        height = (reliefDepth(depthMap, uv, flags) - 0.5) * lp.surface.x;
        P += faceNormal * height;
    }
    if (hasNormal) {
        const float3 direction = float3(normalMap.sample(sampleMap, uv).rgb) * 2 - 1;
        const float y = (flags & 2u) != 0 ? direction.y : -direction.y;
        N = normalize(faceNormal * max(0.05, direction.z) + (direction.x * tangent + y * down) * lp.surface.y);
        if (lp.surface.y == 0) N = faceNormal;
    } else if (hasDepth) {
        const float2 d = 1.0 / max(float2(depthMap.get_width(), depthMap.get_height()), float2(1));
        const float dx = reliefDepth(depthMap, uv + float2(d.x, 0), flags) - reliefDepth(depthMap, uv - float2(d.x, 0), flags);
        const float dy = reliefDepth(depthMap, uv + float2(0, d.y), flags) - reliefDepth(depthMap, uv - float2(0, d.y), flags);
        const float2 slope = float2(dx, dy) * lp.surface.x / max(2 * d * mapSize, float2(0.01));
        N = normalize(faceNormal - (slope.x * tangent + slope.y * down) * lp.surface.y);
    }
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
        // Shadows: is a casting layer between this point and the light? (its real alpha, so cut-outs cast their shape)
        if (atten > 0.0 && L.falloff.y > 0.0 && lp.count.z == 1u) {
            float occ = 0.0;
            float maxT = type == 2u ? 1e7 : length(L.posType.xyz - P);
            for (uint k = 0; k < min(lp.count.y, 4u); k++) {
                ShadowCaster C = casters[k];
                float denom = dot(C.plane.xyz, Ld);
                if (abs(denom) < 1e-5) continue;
                float t = (C.plane.w - dot(C.plane.xyz, P)) / denom;
                if (t <= 1.0 || t >= maxT) continue;
                float4 X = float4(P + Ld * t, 1.0);
                float2 q = float2(dot(C.inv0, X), dot(C.inv1, X));
                float2 size = 2.0 * max(C.halfSize.xy, float2(1e-3));
                float2 uv = q / size + 0.5;
                // The penumbra grows away from contact. Finite lights also narrow it as the caster nears the receiver.
                float separation = type == 2u ? t : t * clamp(1.0 - t / maxT, 0.0, 1.0);
                float blur = L.falloff.z + min(100.0, separation * L.falloff.w * 0.001);
                float2 radius = blur / size;
                if (any(uv < -radius) || any(uv > 1.0 + radius)) continue;
                constexpr sampler ss(address::clamp_to_zero, filter::linear);
                float coverage = float(casterTex[k].sample(ss, uv).a);
                if (blur > 0.0) {
                    // Two rings filter the projected cutout edge. The zero-blur path stays a single read.
                    coverage *= 4.0;
                    for (int y = -1; y <= 1; y++) {
                        for (int x = -1; x <= 1; x++) {
                            if (x == 0 && y == 0) continue;
                            float2 offset = float2(x, y) * radius * 0.7071068;
                            coverage += float(casterTex[k].sample(ss, uv + offset * 0.5).a);
                            coverage += float(casterTex[k].sample(ss, uv + offset).a);
                        }
                    }
                    coverage /= 20.0;
                }
                occ = max(occ, coverage);
            }
            atten *= 1.0 - occ * L.falloff.y;
        }
        // Test the ray against the depth field in local UVs. Ignore transparent silhouette gaps.
        const float facing = dot(faceNormal, Ld);
        if (hasDepth && facing > 0.02 && (flags & 4u) != 0 && atten > 0.001) {
            const float2 along = float2(dot(tangent, Ld), dot(down, Ld)) /
                max(float2(length(lp.w0.xyz), length(lp.w1.xyz)), float2(1e-4));
            const float reach = min(lp.surface.x / max(0.1, facing), length(mapSize) * 0.4);
            const float limit = type == 2u ? reach : min(reach, distance(P, L.posType.xyz));
            float blocked = 0;
            for (uint j = 1; j <= 8; ++j) {
                const float travel = limit * float(j) / 8;
                const float2 at = uv + along * travel / mapSize;
                if (any(at < 0) || any(at > 1)) break;
                const float2 sourceUV = ((at - 0.5) * mapSize - lp.tex.zw + lp.tex.x * 0.5) /
                    (lp.tex.x * float2(src.get_width(), src.get_height()));
                const float alpha = float(src.sample(sampleCoverage, sourceUV).a);
                const float obstruction = (reliefDepth(depthMap, at, flags) - 0.5) * lp.surface.x - height - travel * facing;
                blocked = max(blocked, smoothstep(0.75, 3.0, obstruction) * alpha);
            }
            atten *= 1 - 0.8 * blocked;
        }
        const bool material = lp.surfaceFlags.w == 1u;
        const float ndl = material ? saturate(dot(N, Ld)) : abs(dot(N, Ld));
        float3 halfVector = Ld + V;
        float3 H = halfVector / max(length(halfVector), 1e-5);
        const float spec = material
            ? pow(saturate(dot(N, H)), mix(128.0, 4.0, lp.surface.z)) * lp.surface.w * ndl
            : pow(max(abs(dot(N, H)), 0.0), 40.0) * 0.25;
        light += L.color.rgb * atten * (ndl + spec);
    }
    float3 rgb = s.rgb * light;
    dst.write(half4(half3(rgb), half(s.a)), gid);
}
