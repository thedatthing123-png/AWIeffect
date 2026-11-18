#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler change38(address::clamp_to_zero,filter::linear,coord::pixel);
static float reliefLight38(float4 value) { return dot(value.rgb,float3(.2126,.7152,.0722)); }
kernel void fxContourSource38(texture2d<half,access::sample> source [[texture(0)]],
                             texture2d<half,access::write> output [[texture(1)]],
                             texture2d<half,access::sample> soft [[texture(2)]],
                             constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;
    float4 original=float4(source.sample(change38,uv)),surround=float4(soft.sample(change38,uv));
    float response=max(length(original.rgb-surround.rgb)*.57735027,abs(original.a-surround.a)*.5);
    float knee=max(.0001,p.a.y*.5);
    float value=smoothstep(p.a.x-knee,p.a.x+knee,response)*original.a;
    output.write(half4(value),gid);
}
kernel void fxGlassSurface38(texture2d<half,access::sample> source [[texture(0)]],
                            texture2d<half,access::write> refraction [[texture(1)]],
                            texture2d<half,access::sample> soft [[texture(2)]],
                            texture2d<half,access::write> reflection [[texture(3)]],
                            constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=refraction.get_width() || gid.y>=refraction.get_height()) return;
    float2 uv=float2(gid)+.5;float stepSize=max(p.b.z,.5);
    float dx=reliefLight38(float4(soft.sample(change38,uv+float2(stepSize,0))))-reliefLight38(float4(soft.sample(change38,uv-float2(stepSize,0))));
    float dy=reliefLight38(float4(soft.sample(change38,uv+float2(0,stepSize))))-reliefLight38(float4(soft.sample(change38,uv-float2(0,stepSize))));
    float2 gradient=float2(dx,dy)*.5;
    float3 normal=normalize(float3(-gradient*p.a.x,1));
    float3 light=float3(cos(p.b.x)*cos(p.b.y),sin(p.b.x)*cos(p.b.y),sin(p.b.y));
    float3 halfway=normalize(light+float3(0,0,1));
    float4 refracted=float4(source.sample(change38,uv+gradient*p.a.x*p.a.y));
    float facing=pow(max(0.0,dot(normal,halfway)),max(2.0,p.a.z));
    float highlight=facing*clamp(length(gradient)*abs(p.a.x),0.0,1.0)*refracted.a;
    refraction.write(half4(refracted),gid);reflection.write(half4(highlight),gid);
}
kernel void fxSurfaceComposite38(texture2d<half,access::read> original [[texture(0)]],
                                texture2d<half,access::write> output [[texture(1)]],
                                texture2d<half,access::read> surface [[texture(2)]],
                                texture2d<half,access::read> core [[texture(3)]],
                                texture2d<half,access::read> halo [[texture(4)]],
                                constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float4 input=float4(original.read(gid)),base=p.a.w>0 ? float4(0):float4(surface.read(gid));
    float sharp=max(0.0,float(core.read(gid).r))*p.a.x*p.b.a;
    float broad=max(0.0,float(halo.read(gid).r))*p.a.y*p.c.a;
    float3 energy=pow(max(float3(0),p.b.rgb),float3(2.2))*sharp+pow(max(float3(0),p.c.rgb),float3(2.2))*broad;
    if(max(energy.r,max(energy.g,energy.b))<1.e-8) {
        output.write(half4(mix(input,base,p.a.z)),gid);return;
    }
    float emissionAlpha=clamp(sharp+broad,0.0,1.0);
    float alpha=base.a+emissionAlpha-base.a*emissionAlpha;
    float3 baseLinear=base.a>1.e-6 ? pow(max(base.rgb/base.a,float3(0)),float3(2.2))*base.a:float3(0);
    float3 rgb=pow((baseLinear+energy)/max(alpha,1.e-6),float3(1.0/2.2))*alpha;
    output.write(half4(clamp(mix(input,float4(rgb,alpha),p.a.z),float4(0),float4(65504))),gid);
}
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
