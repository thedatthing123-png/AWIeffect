#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler zero32(address::clamp_to_zero,filter::linear,coord::pixel);

static float2 rotate32(float2 v,float angle) { float c=cos(angle),s=sin(angle); return float2(v.x*c-v.y*s,v.x*s+v.y*c); }
static float hash32(float2 p) { float3 q=fract(float3(p.xyx)*.1031); q+=dot(q,q.yzx+33.33); return fract((q.x+q.y)*q.z); }
static float noise32(float2 p) {
    float2 cell=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash32(cell),hash32(cell+float2(1,0)),f.x),mix(hash32(cell+float2(0,1)),hash32(cell+1.0),f.x),f.y);
}
static int address32(int value,int count,uint edge) {
    if(edge==1) return clamp(value,0,count-1);
    if(edge==2) return ((value%count)+count)%count;
    if(edge==3) { int period=count*2; int v=((value%period)+period)%period; return v<count ? v : period-1-v; }
    return value<0 || value>=count ? -1 : value;
}
static float4 tap32(texture2d<half,access::sample> source,int2 uv,uint edge) {
    int x=address32(uv.x,int(source.get_width()),edge),y=address32(uv.y,int(source.get_height()),edge);
    if(x<0 || y<0) return float4(0);
    return float4(source.sample(zero32,float2(x,y)+.5));
}
static float4 sample32(texture2d<half,access::sample> source,float2 uv,uint edge) {
    if(edge==0) return float4(source.sample(zero32,uv));
    float2 base=floor(uv-.5),f=fract(uv-.5); int2 b=int2(base);
    return mix(mix(tap32(source,b,edge),tap32(source,b+int2(1,0),edge),f.x),
               mix(tap32(source,b+int2(0,1),edge),tap32(source,b+int2(1,1),edge),f.x),f.y);
}
static float2 displacement32(float2 uv,constant EffectParams& p) {
    float scale=max(p.a.y,1.0),shape=p.a.z,t=p.a.w;
    float2 q=rotate32(uv-p.b.xy,-p.b.z)/scale, d=float2(0);
    float r=max(length(q),.0001),angle=atan2(q.y,q.x);
    switch(p.i.x) {
        case 0: {
            float a=q.x*3.0+shape*sin(q.y*2.0+t),b=q.y*3.0+shape*cos(q.x*2.0-t);
            d=float2(cos(b)*cos(a),-sin(a)*sin(b)); break;
        }
        case 1: {
            float2 v=q+float2(t*.3,-t*.2);
            d=float2(noise32(v+float2(shape,0)),noise32(v+float2(7.7,shape)))*2.0-1.0;
            d*=.5+.5*cos(q.x*q.y*shape); break;
        }
        case 2: {
            float branch=sin(q.x*2.0+shape*sin(q.y*3.0+t));
            float thin=exp(-branch*branch*8.0);
            d=float2(branch*.4,thin*sin(q.y+t)); break;
        }
        case 3: {
            float x=q.x+t*.12,cell=floor(x);
            float width=.18+.2*hash32(float2(cell,3));
            float drip=exp(-pow((fract(x)-.5)/width,2.0));
            d=float2(.08*sin(q.y+t),-drip*shape*(.5+.5*sin(q.y+t))); break;
        }
        case 4: {
            float contact=exp(-dot(q,float2(q.x,q.y*shape))*2.0);
            d=-q*contact*(.7+.3*cos(t)); break;
        }
        case 5: {
            float surface=q.y-.15*sin(q.x*3.0+t)*shape;
            float below=smoothstep(-.12,.12,surface);
            d=below*float2(sin(surface*6.0-t),.25*cos(q.x*3.0+t)); break;
        }
        case 6: {
            float falloff=exp(-(q.x*q.x+q.y*q.y/shape)*2.0);
            d=(rotate32(q,falloff*sin(t+1.0)*1.5)-q); break;
        }
        case 7: {
            float2 v=q+shape*float2(sin(q.y*2.0+t*.4),cos(q.x*2.0-t*.3));
            d=float2(sin(v.y*3.0+t),cos(v.x*3.0-t))*.7; break;
        }
        case 8: {
            float2 v=sin(q*3.0+float2(t,-t*.7));
            d=(abs(v)-.5)*shape; d*=1.0/(.5+abs(v.x*v.y)); break;
        }
        case 9: {
            float lane=sin(q.y*3.0+shape*sin(q.x+t));
            d=float2(lane,.2*cos(q.x*2.0+t)*shape); break;
        }
        case 10: {
            float boundary=q.y+shape*.2*sin(q.x*2.0+t);
            d=float2(tanh(clamp(boundary*3.0,-10.0,10.0)),.15*sin(q.x+t)); break;
        }
        case 11: {
            float a=sin(q.y*2.0+t)+sin(q.y*3.13-t*.6)*.3;
            d=float2(a*.5,shape*.25*sin(q.x*2.0+a+t)); break;
        }
        case 12: { d=float2(sin(q.x*6.2831853+t)*shape,.1*sin(q.y+t)); break; }
        case 13: {
            float2 f=fract(q+float2(t*.1,0))-.5;
            float mask=pow(max(0.0,cos(f.x*3.1415927)*cos(f.y*3.1415927)),shape);
            d=f*mask*3.0; break;
        }
        case 14: {
            float2 cell=floor(q+float2(0,t*.12)),f=fract(q+float2(0,t*.12));
            bool upper=f.x+f.y>1.0;
            float direction=hash32(cell+float2(upper ? 9.1 : 0.0,3.7))*6.2831853;
            d=float2(cos(direction),sin(direction))*shape*(.5+.5*sin(t+cell.x)); break;
        }
        case 15: {
            d=float2(q.x*.4*sin(q.y*3.0+t)*shape,.15*cos(q.x*2.0-t)); break;
        }
        case 16: {
            float sector=sin(angle*shape*4.0+t);
            d=float2(-q.y,q.x)/r*sector*exp(-r*.5); break;
        }
        case 17: {
            float spiral=sin(angle*2.0-r*shape*4.0+t);
            d=(q/r+float2(-q.y,q.x)/r*.5)*spiral*.5; break;
        }
        case 18: {
            float2 f=fract(q+float2(t*.08,0))-.5;
            float radius=length(f),lens=pow(max(0.0,1.0-radius*2.0),shape);
            d=f*lens*3.0; break;
        }
        case 19: {
            d=float2(sin(q.y*4.0+t)*cos(q.x*shape*2.0),cos(q.x*4.0-t)*sin(q.y*shape*2.0)); break;
        }
        case 20: {
            float fold=sin(angle*shape*4.0+t)*exp(-r*.25);
            d=float2(-q.y,q.x)/r*fold*.7; d+=q/r*fold*fold*.15; break;
        }
        case 21: {
            float ring=r-fract(t*.3)*3.0;
            float pulse=sin(ring*8.0)*exp(-ring*ring*shape*3.0);
            d=q/r*pulse; break;
        }
        case 22: {
            d=float2(shape*.3*sin(q.x*3.0+q.y+t),sin(q.y*3.0-t)+shape*.2*sin(q.x*5.0+t)); break;
        }
        case 23: {
            float mask=exp(-q.y*q.y*shape*3.0);
            d=float2(mask*(.7+.3*sin(q.x+t)),.1*sin(q.x*3.0-t)*mask); break;
        }
        case 24: {
            float magnification=sin(q.y*2.0+t)*shape;
            d=float2(q.x*magnification*.5,.12*cos(q.y+t)); break;
        }
        case 25: {
            float x=atan(q.x*shape*2.0)/max(shape,.1);
            d=float2((x-q.x)*.7,.15*sin(q.y+t)); d.x*=.7+.3*cos(t); break;
        }
        case 26: {
            float a=sin(q.y*8.0+t),b=sin((q.y+q.x*.08)*8.0*(1.0+shape*.05)-t);
            d=float2((a-b)*.5,(a+b)*.2); break;
        }
        case 27: {
            float plume=pow(.5+.5*sin(q.x*4.0+shape*sin(q.y-t)),2.0);
            d=float2(sin(q.y*5.0-t)*plume,cos(q.x*3.0+t)*plume*.2); break;
        }
        case 28: {
            float gust=noise32(float2(q.x-t,q.y*shape*2.0));
            d=float2((gust-.5)*2.0,.15*sin(q.x+t)*shape); break;
        }
        case 29: {
            float a=abs(sin(q.x*3.0+q.y*shape+t)),b=abs(sin(q.y*3.7-q.x*shape-t*.7));
            d=float2(a-b,(a+b-1.0)*.5); break;
        }
        case 30: {
            float2 left=q-float2(shape*.5,0),right=q+float2(shape*.5,0);
            d=float2(-left.y,left.x)*exp(-dot(left,left)*2.0)-float2(-right.y,right.x)*exp(-dot(right,right)*2.0);
            d*=1.0+.25*sin(t); break;
        }
        case 31: {
            float radius=q.x*q.x/shape+q.y*q.y*shape;
            d=float2(q.x,-q.y)*exp(-radius*2.0)*(1.0+.2*sin(t)); break;
        }
    }
    return uv+rotate32(d,p.b.z)*p.a.x;
}

kernel void fxFlow32(texture2d<half,access::sample> source [[texture(0)]],texture2d<half,access::write> output [[texture(1)]],
                     constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;
    float4 original=float4(source.sample(zero32,uv));
    if(abs(p.a.x)<.00001 || p.b.w<=0.0) { output.write(half4(original),gid); return; }
    int grid=int(clamp(p.i.z,1u,2u)); float4 result=float4(0);
    for(int y=0;y<grid;y++) for(int x=0;x<grid;x++) {
        float2 offset=(float2(x,y)+.5)/float(grid)-.5;
        result+=sample32(source,displacement32(uv+offset,p),p.i.y);
    }
    output.write(half4(mix(original,result/float(grid*grid),p.b.w)),gid);
}
