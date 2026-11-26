#include <metal_stdlib>
using namespace metal;

struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

kernel void fxShapedLightSweep(texture2d<half, access::read> input [[texture(0)]],
                               texture2d<half, access::write> output [[texture(1)]],
                               constant EffectParams& p [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    const float4 src = float4(input.read(gid));
    if (src.a <= 0.00001) {
        output.write(half4(src), gid);
        return;
    }

    const float edge = abs(dot(float2(gid) + 0.5 - p.a.xy, p.a.zw)) / max(0.5, p.b.x);
    const float profile = pow(1 - smoothstep(p.b.y, 1.0, edge), p.b.z);
    const float3 color = src.rgb / src.a;
    const float response = mix(1.0, saturate(dot(color, float3(0.2126, 0.7152, 0.0722))), p.d.x);
    const float3 light = p.c.rgb * (p.c.a * profile * response * p.b.w);
    const float3 result = p.i.x == 1 ? color + light : color + (1 - saturate(color)) * saturate(light);
    output.write(half4(float4(result * src.a, src.a)), gid);
}

kernel void fxLightIrisWipe(texture2d<half, access::read> input [[texture(0)]],
                           texture2d<half, access::write> output [[texture(1)]],
                           constant EffectParams& p [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    if (p.a.z >= 1.0) {
        output.write(half4(0), gid);
        return;
    }

    const float4 src = float4(input.read(gid));
    const float2 size = float2(output.get_width(), output.get_height());
    const float2 farCorner = max(abs(p.a.xy), abs(size - p.a.xy));
    const float feather = max(0.5, p.a.w);
    const float radius = mix(-feather, length(farCorner) + feather, p.a.z);
    const float edge = length(float2(gid) + 0.5 - p.a.xy) - radius;
    const float matte = smoothstep(-feather, feather, edge);
    const float envelope = smoothstep(0.0, 0.1, p.a.z) * (1 - smoothstep(0.88, 1.0, p.a.z));
    const float light = (1 - smoothstep(0.0, max(1.0, p.b.x), abs(edge))) * envelope * p.b.y * p.c.a;
    const float3 tint = p.i.x == 1 ? src.rgb : p.c.rgb * src.a;
    output.write(half4(float4((src.rgb + tint * light) * matte, src.a * matte)), gid);
}
