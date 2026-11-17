#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler matte33(address::clamp_to_zero,filter::linear,coord::pixel);
static float3 straight33(float4 value) { return value.a>.00001 ? value.rgb/value.a : float3(0); }
static float luma33(float3 value) { return dot(value,float3(.2126,.7152,.0722)); }

kernel void fxRGBTime33(texture2d<half,access::read> red [[texture(0)]],
                       texture2d<half,access::write> output [[texture(1)]],
                       texture2d<half,access::read> green [[texture(2)]],
                       texture2d<half,access::read> blue [[texture(3)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    half4 r=red.read(gid),g=green.read(gid),b=blue.read(gid);
    output.write(half4(r.r,g.g,b.b,max(r.a,max(g.a,b.a))),gid);
}
kernel void fxTemporalAccumulate33(texture2d<half,access::read> accumulated [[texture(0)]],
                                 texture2d<half,access::write> output [[texture(1)]],
                                 texture2d<half,access::read> frame [[texture(2)]],
                                 constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float4 a=float4(accumulated.read(gid)),b=float4(frame.read(gid));
    float4 result=a;
    if(p.i.x==0) {
        b*=p.a.x;
        if(p.i.y==0) result=b;
        else if(p.i.z==0) result=float4(a.rgb+b.rgb,a.a+b.a-a.a*b.a);
        else if(p.i.z==1) result=a+b*(1-a.a);
        else if(p.i.z==2) result=max(a,b);
        else result=min(a,b);
    } else if(p.i.x==1) result=a+b*p.a.x;
    else if(p.i.y==0) result=b;
    else result=p.i.w==0 ? max(a,b):min(a,b);
    output.write(half4(clamp(result,float4(-65504),float4(65504))),gid);
}
kernel void fxTemporalFinish33(texture2d<half,access::read> accumulated [[texture(0)]],
                             texture2d<half,access::write> output [[texture(1)]],
                             texture2d<half,access::read> minimum [[texture(2)]],
                             constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float4 result=float4(accumulated.read(gid));
    if(p.i.x==1) result/=max(p.a.x,1.e-6);
    if(p.i.x==2) {
        float4 lower=float4(minimum.read(gid));
        if(p.i.y==1) result=lower;
        if(p.i.y==2) result=float4(max(float3(0),result.rgb-lower.rgb),result.a);
    }
    result.a=clamp(result.a,0.0,1.0);
    output.write(half4(result),gid);
}

kernel void fxTimeSlice33(texture2d<half,access::sample> accumulated [[texture(0)]],
                          texture2d<half,access::write> output [[texture(1)]],
                          texture2d<half,access::sample> frame [[texture(2)]],
                          constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 size=float2(output.get_width(),output.get_height()),uv=float2(gid)+.5;
    float2 delta=uv-p.b.xy*size,axis=float2(cos(p.b.z),sin(p.b.z));
    float field=p.i.x==0 ? .5+dot(delta,axis)/max(dot(abs(axis),size),1.0)
                         : length(delta)/max(length(size)*.5,1.0);
    float position=clamp(field,0.0,1.0)*(p.a.y-1.0);
    float weight=p.i.y==0 ? (floor(position+.5)==p.a.x ? 1.0:0.0):max(0.0,1.0-abs(position-p.a.x));
    float4 result=float4(accumulated.sample(matte33,uv))+float4(frame.sample(matte33,uv))*weight;
    output.write(half4(result),gid);
}
kernel void fxTimeComposite33(texture2d<half,access::sample> original [[texture(0)]],
                              texture2d<half,access::write> output [[texture(1)]],
                              texture2d<half,access::sample> processed [[texture(2)]],
                              constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;
    output.write(half4(mix(float4(original.sample(matte33,uv)),float4(processed.sample(matte33,uv)),p.a.x)),gid);
}
kernel void fxTimeDifference33(texture2d<half,access::sample> source [[texture(0)]],
                               texture2d<half,access::write> output [[texture(1)]],
                               texture2d<half,access::sample> previous [[texture(2)]],
                               constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;
    float4 current=float4(source.sample(matte33,uv)),old=float4(previous.sample(matte33,uv));
    float alpha=max(current.a,old.a);
    float3 delta=abs(current.rgb-old.rgb);
    if(p.i.y==1) delta=float3(abs(luma33(current.rgb)-luma33(old.rgb)));
    if(p.i.y==2) delta=float3(abs(current.a-old.a));
    float4 result=float4(min(delta*p.a.x,float3(65504.0)),alpha);
    output.write(half4(mix(current,result,p.a.y)),gid);
}
kernel void fxTimeMedian33(texture2d<half,access::sample> source [[texture(0)]],
                           texture2d<half,access::write> output [[texture(1)]],
                           texture2d<half,access::sample> previous [[texture(2)]],
                           texture2d<half,access::sample> next [[texture(3)]],
                           constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;
    float4 current=float4(source.sample(matte33,uv)),a=float4(previous.sample(matte33,uv)),b=float4(next.sample(matte33,uv));
    float4 median=max(min(current,a),min(max(current,a),b));
    output.write(half4(mix(current,median,p.a.x)),gid);
}
static float threshold33(float value,float threshold,float softness) {
    float spread=max(.0001,softness*.5);
    return smoothstep(threshold-spread,threshold+spread,value);
}
kernel void fxMatte33(texture2d<half,access::sample> source [[texture(0)]],texture2d<half,access::write> output [[texture(1)]],
                      texture2d<half,access::sample> blurred [[texture(2)]],texture2d<half,access::sample> reference [[texture(3)]],
                      constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;
    float4 src=float4(source.sample(matte33,uv)),soft=float4(blurred.sample(matte33,uv)),ref=float4(reference.sample(matte33,uv));
    float3 color=straight33(src),smoothed=straight33(soft),other=straight33(ref);
    float maximum=max(color.r,max(color.g,color.b)),minimum=min(color.r,min(color.g,color.b));
    float saturation=maximum>.0001 ? (maximum-minimum)/maximum : 0.0;
    float value=0.0,mask=1.0; bool direct=false;
    switch(p.i.x) {
        case 0: value=p.i.y==3 ? src.a : color[min(p.i.y,2u)]; break;
        case 1: value=saturation; break;
        case 2: value=length(color-p.b.rgb)/1.7320508; break;
        case 3: value=abs(luma33(color)-luma33(smoothed))*3.0; break;
        case 4: value=length(color-smoothed)*2.0; break;
        case 5: value=1.0-abs(luma33(color)-p.a.x)*2.0; mask=threshold33(value,1.0-p.c.x/100.0,p.a.y); direct=true; break;
        case 6: value=1.0-saturation; break;
        case 7: {
            uint channel=min(p.i.y,2u);
            float dominant=color[channel]-max(color[(channel+1)%3],color[(channel+2)%3]);
            mask=1.0-threshold33(dominant,p.a.x,p.a.y); direct=true; break;
        }
        case 8: {
            mask=threshold33(max(0.0,soft.a-src.a)*3.0,p.a.x,p.a.y);
            if(p.i.z!=0) mask=1.0-mask;
            float alpha=mask*soft.a;
            float4 fringe=p.i.w==1 ? float4(float3(mask),1) : float4(smoothed*alpha,alpha);
            output.write(half4(mix(src,fringe,p.a.w)),gid); return;
        }
        case 9: value=min(src.a,soft.a); break;
        case 10: {
            float2 cell=floor(uv/max(p.a.z,1.0));
            int x=int(cell.x)%4,y=int(cell.y)%4;
            int high=((x&1)^(y&1))*2+(y&1),low=(((x>>1)&1)^((y>>1)&1))*2+((y>>1)&1);
            float target=(float(high*4+low)+.5)/16.0;
            mask=threshold33(src.a+(p.a.x-.5)*.5,target,p.a.y*.1);
            if(src.a>=.99999) mask=1.0;
            if(src.a<=.00001) mask=0.0;
            direct=true; break;
        }
        case 11: {
            float levels=max(2.0,p.c.x);
            float scaled=clamp(src.a+(p.a.x-.5)*.3,0.0,1.0)*(levels-1.0);
            float cell=floor(scaled),fraction=fract(scaled);
            mask=(cell+smoothstep(.5-p.a.y*.5,.5+p.a.y*.5,fraction))/(levels-1.0); direct=true; break;
        }
        case 12: value=length(color-other)/1.7320508; break;
        case 13: value=abs(luma33(color)-luma33(other)); break;
        case 14: case 15: {
            float fringe=clamp(soft.a-src.a*.65,0.0,1.0);
            mask=threshold33(fringe,p.a.x*.6,p.a.y);
            if(p.i.z!=0) mask=1.0-mask;
            float3 treated=p.i.x==14 ? mix(color,other,mask*.8) : max(float3(0),color-other*mask*.35);
            float4 result=p.i.w==1 ? float4(float3(mask),1) : float4(treated*src.a,src.a);
            output.write(half4(mix(src,result,p.a.w)),gid); return;
        }
    }
    if(!direct) mask=threshold33(value,p.a.x,p.a.y);
    if(p.i.z!=0) mask=1.0-mask;
    float alpha=clamp(src.a*mask,0.0,1.0);
    float4 result=p.i.w==1 ? float4(float3(mask),1) : float4(color*alpha,alpha);
    output.write(half4(mix(src,result,p.a.w)),gid);
}
