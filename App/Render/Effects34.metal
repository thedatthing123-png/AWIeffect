#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler reveal34(address::clamp_to_zero,filter::linear,coord::pixel);
static float hash34(float2 p) { float3 q=fract(float3(p.xyx)*.1031); q+=dot(q,q.yzx+33.33); return fract((q.x+q.y)*q.z); }
static float noise34(float2 p) {
    float2 cell=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash34(cell),hash34(cell+float2(1,0)),f.x),mix(hash34(cell+float2(0,1)),hash34(cell+1.0),f.x),f.y);
}
static float2 rotate34(float2 v,float angle) { float c=cos(angle),s=sin(angle); return float2(v.x*c-v.y*s,v.x*s+v.y*c); }

kernel void fxReveal34(texture2d<half,access::sample> source [[texture(0)]],texture2d<half,access::write> output [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 size=float2(output.get_width(),output.get_height()),uv=float2(gid)+.5;
    float4 original=float4(source.sample(reveal34,uv));
    float progress=p.a.x;
    if(progress<=0.0) { output.write(half4(original),gid); return; }
    if(progress>=1.0) { output.write(half4(original*(1.0-p.b.w)),gid); return; }
    float side=min(size.x,size.y),count=p.a.z,detail=p.a.w;
    float2 q=rotate34((uv-p.b.xy*size)/side,-p.b.z),u=q*count,f=fract(u)-.5,cell=floor(u);
    float radius=length(q),angle=atan2(q.y,q.x)/6.2831853;
    float field=.5;
    switch(p.i.x) {
        case 0: {
            int2 v=int2(floor(u*4.0)); int x=((v.x%4)+4)%4,y=((v.y%4)+4)%4;
            int hi=((x&1)^(y&1))*2+(y&1),lo=(((x>>1)&1)^((y>>1)&1))*2+((y>>1)&1);
            field=pow((float(hi*4+lo)+.5)/16.0,detail); break;
        }
        case 1: case 6: {
            float nearest=100.0,second=100.0;
            for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
                float2 neighbor=cell+float2(x,y);
                float2 offset=float2(hash34(neighbor),hash34(neighbor+17.7))-.5;
                float distance=length(u-(neighbor+.5+offset*min(detail,1.5)*.5));
                if(distance<nearest) {second=nearest;nearest=distance;} else second=min(second,distance);
            }
            field=p.i.x==1 ? clamp(nearest*.9,0.0,1.0) : clamp((second-nearest)*detail,0.0,1.0); break;
        }
        case 2: field=fract(angle*detail+radius*count*.3); break;
        case 3: field=fract(angle+floor(radius*count)*detail*.17); break;
        case 4: field=radius/(.55+.12*cos(angle*6.2831853*count)*detail); break;
        case 5: field=.5+.25*sin(u.x+detail*sin(u.y))+.25*cos(u.y-detail*cos(u.x)); break;
        case 7: field=fract(u.x+fmod(abs(cell.y),2.0)*.5)*.7+hash34(float2(cell.y,0))*.3*min(detail,1.0); break;
        case 8: field=length(float2(f.x/detail,f.y))*1.4142136; break;
        case 9: field=abs(length(f)-detail*.12)*3.0; break;
        case 10: field=fract(q.y+.5+hash34(float2(cell.x,0))*detail*.5+cell.y/count*.2); break;
        case 11: field=radius/(.3+.3*hash34(float2(floor(angle*count),3))*detail); break;
        case 12: field=abs(q.x)*1.5+abs(sin(q.y*count))*detail*.12; break;
        case 13: field=q.x+.5+(noise34(float2(q.y*count,0))-.5)*detail*.3+(noise34(float2(q.y*count*4.0,7))-.5)*detail*.07; break;
        case 14: field=q.x+.5+hash34(float2(cell.y,1))*detail*.35+abs(f.y)*.12; break;
        case 15: field=min(abs(f.x),abs(f.y))*(2.0+detail)+hash34(cell)*.12; break;
        case 16: field=abs(sin(u.y+detail*sin(q.x*4.0)))*.85+.1*sin(u.x); break;
        case 17: field=fract(atan2(f.y,f.x)/6.2831853*detail+length(f)*2.0+hash34(cell)*.3); break;
        case 18: { float terrain=noise34(q*count)*.7+noise34(q*count*2.1)*.3; field=fract(terrain*detail*4.0); break; }
        case 19: { float2 drift=float2(hash34(cell),hash34(cell+7.7))-.5; field=length(f-drift*detail*.25)*1.5; break; }
        case 20: { float s=sin(detail),c=cos(detail); field=min(abs(fract(u.x*c+u.y*s)-.5),abs(fract(u.x*c-u.y*s)-.5))*2.0; break; }
        case 21: field=max(abs(f.x),abs(f.y))*.9+fmod(abs(cell.x+cell.y),2.0)*detail*.2; break;
        case 22: field=q.x+.5+sin(q.y*count)*detail*.05; break;
        case 23: field=abs(q.y)*1.6+hash34(float2(cell.y,0))*detail*.15+abs(q.x)*.1; break;
    }
    field=clamp(field,0.0,1.0);
    if(p.i.y!=0) field=1.0-field;
    float softness=max(.5/side,p.a.y/side);
    float visibility=smoothstep(progress-softness,progress+softness,field);
    float4 picture=original;
    if(p.i.x==2) {
        float2 twisted=rotate34(uv-p.b.xy*size,progress*detail*.2)+p.b.xy*size;
        picture=float4(source.sample(reveal34,twisted));
    } else if(p.i.x==12) {
        picture=float4(source.sample(reveal34,uv+float2(0,progress*detail*side*.08*sin(count))));
    } else if(p.i.x==22) {
        float2 offset=float2(detail*progress*side*.03,0);
        float4 red=float4(source.sample(reveal34,uv+offset)),blue=float4(source.sample(reveal34,uv-offset));
        float alpha=max(original.a,max(red.a,blue.a));
        picture=float4(min(float3(red.r,original.g,blue.b),float3(alpha)),alpha);
    }
    output.write(half4(mix(original,picture*visibility,p.b.w)),gid);
}
