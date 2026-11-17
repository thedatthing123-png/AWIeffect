#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler change38(address::clamp_to_zero,filter::linear,coord::pixel);
kernel void fxChangeComposite38(texture2d<half,access::sample> source [[texture(0)]],
                                texture2d<half,access::write> output [[texture(1)]],
                                texture2d<half,access::sample> composed [[texture(2)]],
                                texture2d<half,access::sample> light [[texture(3)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;float3 emission=float3(light.sample(change38,uv).rgb);
    output.write(max(emission.r,max(emission.g,emission.b))<=.000001 ? source.sample(change38,uv):composed.sample(change38,uv),gid);
}
kernel void fxChangeSource38(texture2d<half,access::sample> source [[texture(0)]],
                             texture2d<half,access::write> output [[texture(1)]],
                             texture2d<half,access::sample> previous [[texture(2)]],
                             constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;
    float4 current=float4(source.sample(change38,uv)),old=float4(previous.sample(change38,uv));
    float3 delta=abs(current.rgb-old.rgb);
    if(p.i.x==1) delta=float3(abs(dot(current.rgb-old.rgb,float3(.2126,.7152,.0722))));
    if(p.i.x==2) delta=float3(abs(current.a-old.a));
    float brightness=max(delta.r,max(delta.g,delta.b)),knee=max(p.a.y,.0001);
    float soft=clamp(brightness-p.a.x+knee,0.0,2.0*knee);
    soft=soft*soft/(4.0*knee);
    float contribution=max(soft,brightness-p.a.x)/max(brightness,.0001);
    float3 light=max(delta*contribution,0.0);
    light=mix(light,p.b.rgb*max(light.r,max(light.g,light.b)),clamp(p.a.z*p.b.a,0.0,1.0));
    float alpha=clamp(max(light.r,max(light.g,light.b)),0.0,1.0);
    output.write(half4(float4(min(light,float3(65504.0)),alpha)),gid);
}
