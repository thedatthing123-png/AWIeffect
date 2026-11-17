#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler matte33(address::clamp_to_zero,filter::linear,coord::pixel);
static float3 straight33(float4 value) { return value.a>.00001 ? value.rgb/value.a : float3(0); }
static float luma33(float3 value) { return dot(value,float3(.2126,.7152,.0722)); }
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
