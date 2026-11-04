#include <metal_stdlib>
using namespace metal;
struct DeepParams { float4 a,b,c,d; uint4 i; };
constexpr sampler deepSampler(coord::normalized, address::clamp_to_zero, filter::linear);

kernel void fxDeepSource(texture2d<half, access::sample> src [[texture(0)]], texture2d<half, access::write> dst [[texture(1)]],
                         constant DeepParams& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 uv = (float2(gid)+0.5)/float2(dst.get_width(),dst.get_height());
    float4 s = float4(src.sample(deepSampler,uv));
    float3 color = s.a > 1e-6 ? max(s.rgb/s.a,0.0) : float3(0);
    float luminance = dot(color,float3(0.2126,0.7152,0.0722));
    float threshold = p.a.x > 1e-6 ? smoothstep(p.a.x-p.a.y,p.a.x+p.a.y,luminance) : 1.0;
    if (p.a.z > 0.5) color = pow(color,float3(2.2));
    dst.write(half4(float4(color*s.a*threshold,s.a*threshold)),gid);
}

kernel void fxDeepAccumulate(texture2d<half, access::read> src [[texture(0)]], texture2d<half, access::write> dst [[texture(1)]],
                             texture2d<half, access::sample> level [[texture(2)]], constant DeepParams& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 uv = (float2(gid)+0.5)/float2(dst.get_width(),dst.get_height());
    dst.write(half4(float4(src.read(gid))+float4(level.sample(deepSampler,uv))*p.a.x),gid);
}

kernel void fxDeepComposite(texture2d<half, access::sample> src [[texture(0)]], texture2d<half, access::write> dst [[texture(1)]],
                            texture2d<half, access::sample> glow [[texture(2)]], constant DeepParams& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 uv = (float2(gid)+0.5)/float2(dst.get_width(),dst.get_height());
    float4 original = float4(src.sample(deepSampler,uv));
    float3 light = max(float3(glow.sample(deepSampler,uv).rgb)*p.b.rgb*p.a.x,0.0);
    if (p.a.z > 0.5) light = pow(light,float3(1.0/2.2));
    float gray = dot(light,float3(0.2126,0.7152,0.0722));
    light = max(mix(float3(gray),light,1+p.a.y),0.0);
    float peak = max(light.r,max(light.g,light.b));
    // Smooth hue-preserving shoulder keeps high exposure finite without channel clipping.
    if (peak > 0) light *= (1-exp(-peak))/peak;
    float coverage = clamp(max(light.r,max(light.g,light.b)),0.0,1.0);
    float4 result = p.i.x != 0 ? float4(light,coverage) : float4(original.rgb+light,original.a+coverage*(1-original.a));
    float maximum = max(result.r,max(result.g,result.b));
    if (maximum > result.a && maximum > 0) result.rgb *= result.a/maximum;
    dst.write(half4(mix(original,result,p.a.w)),gid);
}

kernel void fxProxyPremultiply(texture2d<half, access::read> src [[texture(0)]], texture2d<half, access::write> dst [[texture(1)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    half4 color = src.read(gid); color.rgb *= color.a; dst.write(color,gid);
}
