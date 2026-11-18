#include <metal_stdlib>
using namespace metal;

// Constant-cost gathering from prefiltered emission: no radius-sized pixel loops.
constexpr sampler optical36(address::clamp_to_zero,filter::linear,coord::pixel);
static float3 opticalRGB36(texture2d<half,access::sample> source,float2 uv) {
    return float3(source.sample(optical36,uv).rgb);
}
static float3 spectralSample36(texture2d<half,access::sample> source,float2 uv,float2 offset) {
    return float3(source.sample(optical36,uv+offset).r,
                  source.sample(optical36,uv).g,source.sample(optical36,uv-offset).b);
}
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
kernel void fxOptical36(texture2d<half,access::sample> source [[texture(0)]],
                        texture2d<half,access::write> output [[texture(1)]],
                        constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5,center=p.b.xy;
    float3 light=0;
    if(p.i.x==0 || p.i.x==5) {
        // A thin circular aperture gather. Softness is applied before this pass.
        for(uint tap=0;tap<24;tap++) {
            float angle=(float(tap)+.5)*6.28318530718/24.0;
            float2 direction=float2(cos(angle),sin(angle));
            if(p.i.x==0) light+=opticalRGB36(source,uv+direction*p.a.x)/24.0;
            else {
                float2 position=uv+direction*p.a.x;
                light+=spectralSample36(source,position,direction*p.a.x*p.a.y*.65)/24.0;
            }
        }
    } else if(p.i.x==1) {
        float2 delta=uv-center;
        float radial=length(delta);
        float2 direction=radial>.001 ? delta/radial:float2(0);
        float total=0;
        for(uint ghost=0;ghost<min(p.i.y,8u);ghost++) {
            // Each reflection is a scaled, inverted source image; not a generated dot.
            float scale=.35+(float(ghost)+1.0)*p.a.x;
            float weight=1.0/(1.0+float(ghost));
            float2 position=center-delta/scale;
            light+=spectralSample36(source,position,direction*p.a.y)*weight;
            total+=weight;
        }
        light/=max(total,.001);
    } else if(p.i.x==2) {
        float2 delta=uv-center;
        float total=0;
        for(uint tap=0;tap<24;tap++) {
            float t=float(tap)/23.0,angle=p.a.x*t;
            float c=cos(angle),s=sin(angle),weight=exp(-2.5*t);
            float2 rotated=float2(delta.x*c-delta.y*s,delta.x*s+delta.y*c);
            light+=opticalRGB36(source,center+rotated/max(1.0-p.a.y*t,.1))*weight;
            total+=weight;
        }
        light/=total;
    } else if(p.i.x==3) {
        float2 axis=float2(cos(p.a.y),sin(p.a.y)),normal=float2(-axis.y,axis.x);
        float total=0;
        for(uint tap=0;tap<24;tap++) {
            float t=(float(tap)+.5)/24.0,weight=exp(-3.0*t);
            float2 along=axis*t*p.a.x,across=normal*p.a.z*t;
            light+=(opticalRGB36(source,uv+along+across)*p.c.rgb*p.c.a
                    +opticalRGB36(source,uv-along-across)*p.d.rgb*p.d.a)*weight*.5;
            total+=weight;
        }
        light/=total;
    } else if(p.i.x==4) {
        float sides=float(clamp(p.i.y,3u,12u));
        for(uint tap=0;tap<24;tap++) {
            float perimeter=(float(tap)+.5)*sides/24.0;
            float corner=floor(perimeter),along=fract(perimeter);
            float a=corner*6.28318530718/sides+p.a.y,b=a+6.28318530718/sides;
            float2 offset=mix(float2(cos(a),sin(a)),float2(cos(b),sin(b)),along)*p.a.x;
            light+=opticalRGB36(source,uv+offset)/24.0;
        }
    }
    light=max(light,0.0);
    // The light compositor consumes emission alpha independently of straight RGB.
    output.write(half4(half3(light),half(clamp(max(light.r,max(light.g,light.b)),0.0,1.0))),gid);
}
constexpr sampler field36(address::clamp_to_zero,filter::linear,coord::pixel);

// Independent scalar formulation of the published Ashima/Gustavson simplex lattice.
// Mathematical permutation/gradient conventions preserve the inspected ridges behavior.
// Attribution and MIT terms: Resources/NOISE-LICENSE.txt.
static float mod289_36(float x) { return x-floor(x/289.0)*289.0; }
static float permutation36(float x) { return mod289_36((34.0*x+1.0)*x); }
static float simplex36(float3 point) {
    float3 lattice=floor(point+(point.x+point.y+point.z)/3.0);
    float3 origin=point-lattice+(lattice.x+lattice.y+lattice.z)/6.0;
    float3 order=float3(origin.x>=origin.y ? 1:0,origin.y>=origin.z ? 1:0,origin.z>=origin.x ? 1:0);
    float3 complement=1.0-order;
    float3 first=min(order,complement.zxy),second=max(order,complement.zxy);
    lattice=float3(mod289_36(lattice.x),mod289_36(lattice.y),mod289_36(lattice.z));
    float sum=0.0;
    for(int corner=0;corner<4;corner++) {
        float3 offset=corner==0 ? float3(0) : (corner==1 ? first : (corner==2 ? second : float3(1)));
        float3 relative=origin-offset+float(corner)/6.0;
        float weight=max(0.6-dot(relative,relative),0.0);
        float hash=permutation36(permutation36(permutation36(lattice.z+offset.z)+lattice.y+offset.y)+lattice.x+offset.x);
        float gradientIndex=hash-49.0*floor(hash/49.0);
        float gx=floor(gradientIndex/7.0)*(2.0/7.0)-(13.0/14.0);
        float gy=(gradientIndex-floor(gradientIndex/7.0)*7.0)*(2.0/7.0)-(13.0/14.0);
        float gz=1.0-abs(gx)-abs(gy);
        if(gz<=0.0) { gx-=(floor(gx)*2.0+1.0); gy-=(floor(gy)*2.0+1.0); }
        float3 gradient=float3(gx,gy,gz);
        gradient*=1.79284291400159-0.85373472095314*dot(gradient,gradient);
        float square=weight*weight;
        sum+=square*square*dot(gradient,relative);
    }
    return sum*42.0;
}
static float hash36(float2 p) { float3 q=fract(float3(p.xyx)*.1031); q+=dot(q,q.yzx+33.33); return fract((q.x+q.y)*q.z); }
static float fbm36(float3 p) {
    float sum=0.0,weight=.5;
    for(int octave=0;octave<4;octave++) {sum+=(simplex36(p)*.5+.5)*weight;p=p*2.03+float3(7.1,3.7,1.3);weight*=.5;}
    return clamp(sum/.9375,0.0,1.0);
}
static float2 cells36(float2 q,float time,uint metric) {
    float2 base=floor(q); float first=100.0,second=100.0;
    for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
        float2 cell=base+float2(x,y);
        float2 random=float2(hash36(cell),hash36(cell+17.7));
        float2 center=cell+.5+.35*sin(random*6.2831853+time*.3);
        float2 delta=abs(q-center);
        float distance=metric==1 ? delta.x+delta.y : (metric==2 ? max(delta.x,delta.y) : length(delta));
        if(distance<first) {second=first;first=distance;} else second=min(second,distance);
    }
    return float2(first,second);
}
static float procedural36(float2 q,float evolution,float detail,uint mode) {
    float3 point=float3(q,evolution);
    bool needsBase=mode==12 || mode==13 || mode==14 || mode==15 || mode==16 || mode==17 || mode==18 || mode==19
                || mode==18 || mode==26 || mode==27 || mode==29 || mode==30 || mode==35;
    float base=needsBase ? fbm36(point) : 0.0,field=0.0;
    switch(mode) {
        case 1: field=pow(max(0.0,1.0-abs(simplex36(point))),detail); break;
        case 2: {
            float amplitude=.5,weight=1.0,sum=0.0;
            for(int octave=0;octave<4;octave++) {
                float n=simplex36(point)*.5+.5;
                sum+=n*amplitude*weight;weight=clamp(n*detail,0.0,1.0);point*=2.01;amplitude*=.5;
            }
            field=sum*1.6; break;
        }
        case 3: {
            float product=1.0;
            for(int octave=0;octave<4;octave++) {product*=.4+.6*(simplex36(point)*.5+.5);point*=1.91;}
            field=pow(product,.5/detail); break;
        }
        case 4: {
            float2 bend=float2(fbm36(point),fbm36(point+7.7))-.5;
            field=fbm36(float3(q+bend*detail*3.0,evolution)); break;
        }
        case 5: {
            float epsilon=.04;
            float dx=simplex36(point+float3(epsilon,0,0))-simplex36(point-float3(epsilon,0,0));
            float dy=simplex36(point+float3(0,epsilon,0))-simplex36(point-float3(0,epsilon,0));
            field=length(float2(dy,-dx))*detail*4.0; break;
        }
        case 6: field=pow(clamp(cells36(q,evolution,0).x,0.0,1.0),detail); break;
        case 7: field=clamp(cells36(q,evolution,0).y*.7*detail,0.0,1.0); break;
        case 8: {float2 c=cells36(q,evolution,0);field=exp(-(c.y-c.x)*detail*9.0);break;}
        case 9: field=clamp(cells36(q,evolution,1).x/detail,0.0,1.0); break;
        case 10: field=clamp(cells36(q,evolution,2).x/detail,0.0,1.0); break;
        case 11: {
            float a=sin(q.x*3.0+detail*sin(q.y*2.0+evolution)),b=sin(q.y*3.1-detail*cos(q.x+evolution));
            field=exp(-abs(a+b)*detail*3.0); break;
        }
        case 12: field=.5+.5*sin(q.x*5.0+(base-.5)*detail*10.0); break;
        case 13: field=.5+.5*sin(length(q)*8.0+(base-.5)*detail*5.0); break;
        case 14: field=pow(.5+.5*sin(q.y*16.0+(base-.5)*detail*9.0),2.0); break;
        case 15: field=exp(-abs(simplex36(point+float3(base*detail,0,0)))*4.0/detail); break;
        case 16: field=fbm36(float3(q.x*3.0,q.y*.4,evolution)+base*detail); break;
        case 17: field=clamp(base*.65+fbm36(point*.41+7.1)*.55-.15/detail,0.0,1.0); break;
        case 18: field=smoothstep(.25,.75,base+q.y*.2*detail); break;
        case 19: {
            float tongue=fbm36(float3(q.x*2.0,q.y-evolution,evolution*.3));
            field=clamp(tongue*detail-abs(q.x)*.15-q.y*.12,0.0,1.0); break;
        }
        case 20: field=pow(1.0-clamp(cells36(float2(q.x*1.7,q.y*.5-evolution),evolution,0).x,0.0,1.0),detail); break;
        case 21: field=.5+.25*sin(q.x*3.0+detail*sin(q.y*2.0+evolution))+.25*cos(q.y*3.2+detail*sin(q.x-evolution)); break;
        case 22: field=exp(-abs(simplex36(point)+.3*simplex36(point*2.1))*16.0/detail); break;
        case 23: {float2 c=cells36(q,evolution,0);field=exp(-c.x*c.x*25.0/detail);break;}
        case 24: field=.5+.5*sin(q.x*5.0+detail*sin(q.y*4.0+evolution)+sin(q.x+q.y)); break;
        case 25: {float distance=cells36(q,evolution,0).x;field=exp(-pow((distance-.4)*7.0,2.0))*detail*.5+distance*.2;break;}
        case 26: field=pow(1.0-abs(simplex36(float3(q.x,q.y*.4,evolution))),detail)*(.5+.5*base); break;
        case 27: field=.5+.5*sin(q.y*20.0+(base-.5)*detail*8.0); break;
        case 28: field=pow(fbm36(float3(q.x*.2,q.y*5.0,evolution)),detail); break;
        case 29: {float2 c=cells36(q,evolution,1);field=clamp((c.y-c.x)*detail*2.0+base*.25,0.0,1.0);break;}
        case 30: {float2 c=cells36(q+(base-.5)*detail,evolution,0);field=exp(-(c.y-c.x)*12.0);break;}
        case 31: field=clamp(abs(simplex36(float3(q.x*detail,q.y*.3,evolution))-simplex36(float3(q.x*.3,q.y*detail,evolution))),0.0,1.0); break;
        case 32: {
            float2 cell=floor(q);float sum=0.0;
            for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
                float2 id=cell+float2(x,y),delta=q-id-.5;
                float phase=hash36(id)*6.2831853+evolution;
                sum+=cos(delta.x*detail*9.0+phase)*exp(-dot(delta,delta)*3.0);
            }
            field=.5+sum*.3;break;
        }
        case 33: field=.5+.25*cos(q.x*detail*4.0+evolution)*sin(q.y*3.0-evolution)+.25*sin(q.x*7.0-evolution)*cos(q.y*detail*5.0); break;
        case 34: {float2 cell=floor(q),f=fract(q);field=fbm36(float3(f*detail+hash36(cell)*20.0,evolution));break;}
        case 35: field=.5+.5*cos(length(q)*12.0+(base-.5)*detail*9.0); break;
    }
    return clamp(field,0.0,1.0);
}

kernel void fxField36(texture2d<half,access::sample> source [[texture(0)]],texture2d<half,access::write> output [[texture(1)]],
                      constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 size=float2(output.get_width(),output.get_height()),uv=float2(gid)+.5;
    float4 original=float4(source.sample(field36,uv));
    uint mode=p.i.x&255u;float value=0.0;
    if(mode==0) {
        float2 coordinates=uv/size;coordinates.x*=size.x/size.y;
        coordinates+=p.d.yz;
        float2 seeded=float2(821.921,437.317)*p.a.w;
        coordinates+=seeded-floor(seeded/float2(4.365,7.701))*float2(4.365,7.701);
        float2 scale=p.a.y<0 ? float2(p.a.x-p.a.y,p.a.x) : float2(p.a.x,p.a.x+p.a.y);
        coordinates=(coordinates-.5)*scale+.5;
        float2 parallax=float2(as_type<float>(p.i.z),as_type<float>(p.i.w));
        float frequency=1.0,amplitude=.5,previous=1.0;
        for(uint octave=0;octave<min(p.i.y,9u);octave++) {
            float crest=.9-abs(simplex36(float3(coordinates*frequency,p.d.x)));
            float ridge=crest*crest;
            value+=ridge*amplitude*(1.0+previous);
            previous=ridge;frequency*=2.0;coordinates+=parallax;amplitude*=.5;
        }
        value*=p.a.z;
    } else {
        float2 q=(uv-p.d.xy)/max(p.a.x,1.0);
        float c=cos(p.d.z),s=sin(p.d.z);q=float2(q.x*c+q.y*s,-q.x*s+q.y*c);
        // A seed changes the turbulence, not the location of the front/taper.
        // Large coordinate offsets previously saturated Storm Front and Fire Tongues.
        if(mode==18 || mode==19) {
            float seededTime=p.a.z+hash36(float2(p.a.w,17.0))*53.0;
            value=procedural36(q,seededTime,p.a.y,mode);
        } else {
            q+=float2(p.a.w*.371,p.a.w*.173);
            value=procedural36(q,p.a.z,p.a.y,mode);
        }
    }
    float4 color=mix(p.b,p.c,value);
    color.a=clamp(color.a,0.0,1.0);color.rgb=max(color.rgb,0.0)*color.a;
    if((p.i.x&256u)!=0) output.write(half4(color*p.d.w),gid);
    else {
        float alpha=clamp(color.a*p.d.w,0.0,1.0);
        float3 rgb=color.rgb*p.d.w*original.a+original.rgb*(1.0-alpha);
        output.write(half4(float4(rgb,float(original.a))),gid);
    }
}
