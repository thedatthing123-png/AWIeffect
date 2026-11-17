#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler generator35(address::clamp_to_zero,filter::linear,coord::pixel);
static float hash35(float2 p) { float3 q=fract(float3(p.xyx)*.1031); q+=dot(q,q.yzx+33.33); return fract((q.x+q.y)*q.z); }
static float2 rotate35(float2 v,float angle) { float c=cos(angle),s=sin(angle); return float2(v.x*c-v.y*s,v.x*s+v.y*c); }
static float segment35(float2 p,float2 a,float2 b) { float2 v=b-a; return length(p-a-v*clamp(dot(p-a,v)/max(dot(v,v),.00001),0.0,1.0)); }
static float box35(float2 p,float2 extent) { float2 q=abs(p)-extent; return length(max(q,0.0))+min(max(q.x,q.y),0.0); }
static float line35(float distance,float width,float aa) { return 1.0-smoothstep(width-aa,width+aa,distance); }
static float2 chebyshev35(float x,int degree) {
    float a=1,b=x,da=0,db=1;
    for(int i=2;i<=degree;i++) { float c=2.0*x*b-a,dc=2.0*b+2.0*x*db-da; a=b;b=c;da=db;db=dc; }
    return degree==0 ? float2(1,0) : float2(b,db);
}
static float geometry35(float2 q,constant EffectParams& p) {
    float radius=length(q),angle=atan2(q.y,q.x),detail=p.a.z;
    float width=p.a.y/max(p.a.x,1.0)*.5,aa=1.0/max(p.a.x,1.0),distance=100.0;
    switch(p.i.x) {
        case 0: {
            float span=detail*3.14159265/180.0;
            float phase=angle<0.0 ? angle+6.2831853 : angle;
            distance=abs(radius-.4);
            float endpoint=length(q-float2(cos(span),sin(span))*.4);
            if(phase>span) distance=min(endpoint,length(q-float2(.4,0)));
            break;
        }
        case 1: {
            float2 v=abs(q); float arm=detail/100.0;
            distance=min(segment35(v,float2(.4,.4),float2(.4-arm,.4)),segment35(v,float2(.4,.4),float2(.4,.4-arm))); break;
        }
        case 2: {
            float2 v=abs(q); float gap=detail/100.0;
            distance=min(segment35(v,float2(.4+gap,.4),float2(.65+gap,.4)),segment35(v,float2(.4,.4+gap),float2(.4,.65+gap))); break;
        }
        case 3: {
            float border=abs(box35(q,float2(.4,.48)));
            float2 f=float2(abs(q.x)-.47,(fract(q.y*detail+.5)-.5)/detail);
            distance=min(border,abs(box35(f,float2(.025,.3/detail)))); break;
        }
        case 4: {
            float normalized=angle/1.2;
            float id=floor(normalized*detail),local=abs(fract(normalized*detail)-.5);
            float extent=.25+.35*hash35(float2(id,7));
            distance=local*radius/detail*1.2;
            if(abs(angle)>.55 || radius<.12 || radius>extent) distance=100.0;
            break;
        }
        case 5: {
            float phase=(angle/6.2831853+.5)*detail;
            float tooth=1.0-abs(fract(phase)*2.0-1.0);
            float length=.2+.25*hash35(float2(floor(phase),3));
            float edge=max(aa,width);
            return smoothstep(.15-edge,.15+edge,radius)*line35(radius,.15+tooth*length,edge);
        }
        case 6: distance=abs(radius-(.37+.04*sin(angle*detail))); break;
        case 7: {
            float sweep=detail/100.0*6.2831853;
            float phase=angle<0 ? angle+6.2831853 : angle;
            distance=abs(radius-.4);
            if(phase>sweep) distance=min(length(q-float2(.4,0)),length(q-float2(cos(sweep),sin(sweep))*.4));
            break;
        }
        case 8: {
            float head=detail/100.0;
            distance=min(segment35(q,float2(-.45,0),float2(.45,0)),min(segment35(q,float2(.45,0),float2(.45-head,head*.6)),segment35(q,float2(.45,0),float2(.45-head,-head*.6)))); break;
        }
        case 9: {
            float count=max(2.0,detail),cell=1.0/count;
            float2 v=float2(fract((q.x+.5)*count)*cell-cell*.5,q.y);
            distance=min(segment35(v,float2(-cell*.35,-.15),float2(cell*.35,0)),segment35(v,float2(cell*.35,0),float2(-cell*.35,.15)));
            if(abs(q.x)>.5) distance=100.0; break;
        }
        case 10: {
            float gap=detail/100.0;
            distance=min(segment35(q,float2(-.45,0),float2(-gap*.5,0)),segment35(q,float2(gap*.5,0),float2(.45,0)));
            distance=min(distance,segment35(float2(abs(q.x),q.y),float2(.45,-.15),float2(.45,.15))); break;
        }
        case 11: {
            float tail=detail/100.0;
            distance=abs(box35(q,float2(.36,.24))-.06);
            distance=min(distance,min(segment35(q,float2(-.15,.3),float2(-.28,.3+tail)),segment35(q,float2(-.28,.3+tail),float2(.02,.3)))); break;
        }
        case 12: distance=abs(radius-(.38+.05*sin(angle*detail)+.025*sin(angle*detail*2.0+.6))); break;
        case 13: {
            float phase=fract(angle/1.5707963+.5)-.5;
            distance=abs(radius-.4);
            if(abs(phase)<detail/200.0) distance=100.0;
            distance=min(distance,min(segment35(abs(q),float2(.03,0),float2(.1,0)),segment35(abs(q),float2(0,.03),float2(0,.1)))); break;
        }
        case 14: {
            float x=floor((q.x+.5)*detail+.5)/detail-.5;
            float major=fmod(abs(floor((x+.5)*detail+.5)),5.0)<.5 ? .18 : .09;
            distance=min(segment35(q,float2(-.5,0),float2(.5,0)),segment35(q,float2(x,0),float2(x,major)));
            if(abs(q.x)>.51) distance=100.0; break;
        }
        case 15: {
            float phase=angle/6.2831853-radius*detail*2.0;
            float error=abs(fract(phase+.5)-.5);
            distance=error/max(sqrt(detail*detail*4.0+1.0/max(radius*radius*39.4784,.001)),.001);
            if(radius>.5 || radius<.025) distance=100.0; break;
        }
        case 16: {
            float2 v=clamp(q*2.2,-.999,.999);
            int degree=int(clamp(round(detail),2.0,8.0));
            float2 a=chebyshev35(v.x,degree),b=chebyshev35(v.y,degree+1);
            distance=abs(a.x-b.x)/max(length(float2(a.y,b.y))*2.2,.001);
            if(max(abs(q.x),abs(q.y))>.46) distance=100.0; break;
        }
        case 17: {
            float corner=detail/100.0;
            distance=abs(box35(q,float2(.5,.35)-corner)+corner); break;
        }
        case 18: {
            float jagged=sin(q.x*43.0)+.4*sin(q.x*79.0+1.0);
            distance=max(abs(q.x)-.5,abs(q.y)-.16-jagged*detail/2000.0);
            return 1.0-smoothstep(-max(aa,width),max(aa,width),distance);
        }
        case 19: {
            float border=abs(box35(q,float2(.45,.35)));
            float x=(fract(q.x*detail+.5)-.5)/detail;
            distance=min(border,abs(box35(float2(x,abs(q.y)-.42),float2(.25/detail,.025)))); break;
        }
        case 20: {
            float gap=detail/200.0; float2 v=abs(q);
            distance=min(segment35(v,float2(gap,0),float2(.45,0)),segment35(v,float2(0,gap),float2(0,.45))); break;
        }
        case 21: {
            float2 v=abs(q)-detail/100.0;
            distance=min(abs(length(v)-.07),min(segment35(v,float2(-.1,0),float2(.1,0)),segment35(v,float2(0,-.1),float2(0,.1)))); break;
        }
        case 22: {
            float head=detail/100.0;
            distance=segment35(q,float2(-.45,0),float2(.45,0));
            float2 v=float2(abs(q.x),q.y);
            distance=min(distance,min(segment35(v,float2(.45,0),float2(.45-head,head*.6)),segment35(v,float2(.45,0),float2(.45-head,-head*.6)))); break;
        }
        case 23: {
            float span=detail*3.14159265/180.0;
            float arc=abs(radius-.32);
            if(angle<0 || angle>span) arc=100.0;
            distance=min(arc,min(segment35(q,float2(0),float2(.5,0)),segment35(q,float2(0),float2(cos(span),sin(span))*.5))); break;
        }
    }
    return line35(distance,width,aa);
}

static float particleMask35(float2 v,float size,uint mode,float seed,float clock) {
    v/=max(size,.2); float r=length(v),distance=100.0;
    switch(mode) {
        case 24: distance=length(float2(v.x*1.5,v.y))-1.0+.15*sin(v.y*3.0); break;
        case 25: distance=abs(v.x+.15*sin(v.y*2.0))-.3*(1.0-clamp(abs(v.y)/2.0,0.0,1.0)); distance=max(distance,abs(v.y)-2.0); break;
        case 26: return exp(-dot(v,v)*2.0)+max(0.0,1.0-v.y/5.0)*exp(-v.x*v.x*12.0)*step(0.0,v.y)*step(v.y,5.0);
        case 27: distance=box35(v,float2(.6+abs(sin(clock+seed))*.4,1.3)); break;
        case 28: distance=max(abs(v.x-.3*sin(v.y*2.0+clock))-.22,abs(v.y)-2.0); break;
        case 29: distance=r-(.8+.18*sin(atan2(v.y,v.x)*5.0+seed)); break;
        case 30: distance=max(abs(v.x)+abs(v.y)*.7,abs(v.y))-1.0; break;
        case 31: distance=box35(rotate35(v,.6*sin(seed+clock)),float2(.65,.3)); break;
        case 32: distance=min(length(v-float2(0,-.7))-.5,segment35(v,float2(0,-.4),float2(.3,1.7))-.1); break;
        case 33: return exp(-dot(v,v)*1.5)+exp(-pow(v.x-.2*sin(v.y),2.0)*15.0)*max(0.0,1.0-v.y/4.0)*step(0.0,v.y)*step(v.y,4.0)*.4;
        case 34: distance=max(abs(v.x)*.866+v.y*.5,-v.y)-.9; break;
        case 35: distance=abs(r-.8)-.15; break;
        case 36: distance=max(abs(v.x-.3*sin(v.y*2.0+clock))-.1,abs(v.y)-1.5); break;
        case 37: return exp(-v.x*v.x*2.0-v.y*v.y*.15);
        case 38: distance=abs(v.x)+abs(v.y)-1.0; break;
        default: return exp(-dot(v,v)*1.2)*(.6+.4*sin(seed+clock));
    }
    return 1.0-smoothstep(-.2,.2,distance);
}

kernel void fxGenerate35(texture2d<half,access::sample> source [[texture(0)]],texture2d<half,access::write> output [[texture(1)]],
                         constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 size=float2(output.get_width(),output.get_height()),uv=float2(gid)+.5;
    float4 generated=float4(0);
    if(p.i.z==0) {
        float2 q=rotate35(uv-p.c.xy,-p.c.z)/max(p.a.x,1.0);
        float alpha=geometry35(q,p)*p.b.a;
        generated=float4(p.b.rgb*alpha,alpha);
    } else {
        float side=min(size.x,size.y),density=max(2.0,p.a.y),cellSize=side/density;
        float time=p.a.z,seed=as_type<float>(p.i.w);
        float2 q=rotate35(uv-p.c.xy,-p.c.z)/cellSize-float2(time*.15,time*.65);
        float2 cell=floor(q);
        for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
            float2 id=cell+float2(x,y),salt=id+seed*float2(7.7,13.1);
            float random=hash35(salt),second=hash35(salt+19.7);
            float2 head=id+.5+float2(random-.5,second-.5)*.65;
            head.x+=sin(time+random*6.2831853)*p.a.w*.15;
            float2 v=(q-head)*cellSize;
            float particleSize=min(p.a.x*(.5+.5*second),cellSize*.25);
            v=rotate35(v,time*(random-.5)+random*6.2831853);
            float coverage=clamp(particleMask35(v,particleSize,p.i.x,random*6.2831853,time),0.0,1.0);
            float4 color=mix(p.b,p.d,second);
            float alpha=coverage*color.a*(.45+.55*random);
            generated.rgb+=color.rgb*alpha*(1.0-generated.a);
            generated.a+=alpha*(1.0-generated.a);
        }
    }
    float4 original=float4(source.sample(generator35,uv));
    generated*=p.c.w;
    output.write(half4(p.i.y!=0 ? generated : generated+original*(1.0-generated.a)),gid);
}
