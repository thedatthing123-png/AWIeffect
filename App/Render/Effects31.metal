#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler signal31(address::clamp_to_edge, filter::linear, coord::pixel);
constexpr sampler flowZero31(address::clamp_to_zero,filter::linear,coord::pixel);
static float flowLight31(texture2d<half,access::sample> image,float2 uv) {
    float4 c=float4(image.sample(signal31,uv));
    return dot(c.rgb,float3(.2126,.7152,.0722))+.15*c.a;
}
kernel void fxSolveFlow31(texture2d<half,access::sample> current [[texture(0)]],
                         texture2d<half,access::write> output [[texture(1)]],
                         texture2d<half,access::sample> previous [[texture(2)]],
                         texture2d<half,access::sample> estimate [[texture(3)]],
                         constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5,size=float2(output.get_width(),output.get_height());
    float2 priorSize=float2(estimate.get_width(),estimate.get_height());
    float2 motion=float2(estimate.sample(signal31,uv/size*priorSize).rg)*size/priorSize;
    float a=0,b=0,c=0,d=0,e=0,error=0;
    int radius=int(clamp(p.i.x,1u,2u)),count=(2*radius+1)*(2*radius+1);
    for(int y=-radius;y<=radius;y++) for(int x=-radius;x<=radius;x++) {
        float2 point=uv+float2(x,y),oldPoint=point-motion;
        float residual=flowLight31(previous,oldPoint)-flowLight31(current,point);
        float gx=(flowLight31(previous,oldPoint+float2(1,0))-flowLight31(previous,oldPoint-float2(1,0))+
                  flowLight31(current,point+float2(1,0))-flowLight31(current,point-float2(1,0)))*.25;
        float gy=(flowLight31(previous,oldPoint+float2(0,1))-flowLight31(previous,oldPoint-float2(0,1))+
                  flowLight31(current,point+float2(0,1))-flowLight31(current,point-float2(0,1)))*.25;
        a+=gx*gx;b+=gx*gy;c+=gy*gy;d+=gx*residual;e+=gy*residual;error+=residual*residual;
    }
    float trace=a+c,regularizer=trace*.005+1.e-6;
    a+=regularizer;c+=regularizer;
    float determinant=max(a*c-b*b,1.e-12);
    float2 update=float2(c*d-b*e,a*e-b*d)/determinant;
    update*=min(1.0,2.0/max(length(update),1.e-6));
    motion+=update*p.a.z;
    float normalizedLength=length(motion/max(p.a.xy,float2(.0001)));
    motion/=max(1.0,normalizedLength);
    float confidence=trace/(trace+.001)*exp(-40*error/float(count));
    if(!all(isfinite(motion))) { motion=0;confidence=0; }
    output.write(half4(float4(motion,confidence,1)),gid);
}
static float flowHash31(float2 q) { return fract(sin(dot(q,float2(127.1,311.7)))*43758.5453); }
static float3 flowHue31(float hue) {
    return clamp(abs(fract(hue+float3(0,2.0/3.0,1.0/3.0))*6-3)-1,0.0,1.0);
}
kernel void fxMeasuredFlow31(texture2d<half,access::sample> source [[texture(0)]],
                            texture2d<half,access::write> output [[texture(1)]],
                            texture2d<half,access::sample> flow [[texture(2)]],
                            texture2d<half,access::sample> previous [[texture(3)]],
                            constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5,size=float2(output.get_width(),output.get_height());
    float2 flowSize=float2(flow.get_width(),flow.get_height()),fieldUV=uv;
    float block=max(1.0,p.b.y);
    if(p.i.x==3) fieldUV=(floor(uv/block)+.5)*block;
    float4 measured=float4(flow.sample(signal31,fieldUV/size*flowSize));
    float reliability=smoothstep(p.a.z,min(1.0,p.a.z+.15),measured.b);
    float2 vector=measured.rg*size/flowSize*reliability;
    float4 original=float4(source.sample(flowZero31,uv)),result=original;
    if(p.i.x==0) result=float4(source.sample(flowZero31,uv-vector*p.a.x));
    if(p.i.x==1) {
        int samples=int(clamp(p.i.z,2u,16u));result=0;
        for(int n=0;n<samples;n++) {
            float fraction=(float(n)+.5)/float(samples)-.5;
            result+=float4(source.sample(flowZero31,uv-vector*p.a.x*fraction))/float(samples);
        }
    }
    if(p.i.x==2) {
        float range=max(1.0,p.b.x),magnitude=length(vector)/range;
        float3 color=flowHue31(atan2(vector.y,vector.x)/6.28318530718+.5)*clamp(magnitude,0.0,1.0);
        if(p.i.y==1) color=float3(clamp(.5+vector/(2*range),0.0,1.0),clamp(magnitude,0.0,1.0));
        if(p.i.y==2) color=float3(clamp(magnitude,0.0,1.0));
        result=float4(color*original.a,original.a);
    }
    if(p.i.x==3) {
        float2 cell=floor(uv/block);
        float clock=floor(p.a.w),fraction=fract(p.a.w);
        float randomness=mix(flowHash31(cell+p.c.x+clock),flowHash31(cell+p.c.x+clock+1),fraction*fraction*(3-2*fraction));
        float carry=p.b.z*(.35+randomness*1.3);
        float4 dragged=float4(previous.sample(flowZero31,uv-vector*carry));
        result=mix(original,dragged,p.b.w);
    }
    output.write(half4(mix(original,result,p.a.y)),gid);
}

static bool sortLess31(uint segmentA,float keyA,uint orderA,uint segmentB,float keyB,uint orderB) {
    return segmentA<segmentB || (segmentA==segmentB && (keyA<keyB || (keyA==keyB && orderA<orderB)));
}
// Independent bitonic network on (segment, key, original position). Sorting the
// segment first keeps unselected pixels and run boundaries fixed in the window.
kernel void fxSegmentSort31(texture2d<half,access::sample> source [[texture(0)]],
                            texture2d<half,access::write> output [[texture(1)]],
                            constant EffectParams& p [[buffer(0)]],
                            uint lane [[thread_index_in_threadgroup]],uint3 group [[threadgroup_position_in_grid]]) {
    threadgroup half4 colors[256];threadgroup float keys[256];
    threadgroup uint segments[256];threadgroup uint orders[256];threadgroup uint selected[256];
    uint span=p.i.w,lanes=uint(p.b.x),position=group.x*span+lane;
    uint2 pixel=p.i.x==0 ? uint2(position,group.y):uint2(group.y,position);
    bool valid=lane<span && pixel.x<output.get_width() && pixel.y<output.get_height();
    half4 original=valid ? source.sample(signal31,float2(pixel)+.5):half4(0);
    float4 color=float4(original);float3 straight=color.a>.00001 ? color.rgb/color.a:float3(0);
    float luminance=dot(straight,float3(.2126,.7152,.0722));
    float maximum=max(straight.r,max(straight.g,straight.b)),minimum=min(straight.r,min(straight.g,straight.b));
    float delta=maximum-minimum,key=luminance;
    if(p.i.y==1) {
        key=0;
        if(delta>.00001) {
            if(maximum==straight.r) key=(straight.g-straight.b)/delta;
            else if(maximum==straight.g) key=2.0+(straight.b-straight.r)/delta;
            else key=4.0+(straight.r-straight.g)/delta;
            key=fract(key/6.0);
        }
    } else if(p.i.y==2) key=maximum>.00001 ? delta/maximum:0;
    colors[lane]=original;keys[lane]=p.i.z!=0 ? -key:key;orders[lane]=lane;
    selected[lane]=valid && color.a>.00001 && luminance>=p.a.x && luminance<=p.a.y ? 1u:0u;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if(lane==0) {
        uint segment=0;
        for(uint i=0;i<lanes;i++) {
            if(i>0 && (selected[i]==0 || selected[i-1]==0)) segment++;
            segments[i]=segment;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for(uint size=2;size<=lanes;size<<=1) for(uint distance=size>>1;distance>0;distance>>=1) {
        uint other=lane^distance;
        half4 ownColor=colors[lane],peerColor=colors[other];
        float ownKey=keys[lane],peerKey=keys[other];
        uint ownSegment=segments[lane],peerSegment=segments[other],ownOrder=orders[lane],peerOrder=orders[other];
        bool lower=((lane&size)==0)==((lane&distance)==0);
        bool peerFirst=sortLess31(peerSegment,peerKey,peerOrder,ownSegment,ownKey,ownOrder);
        bool ownFirst=sortLess31(ownSegment,ownKey,ownOrder,peerSegment,peerKey,peerOrder);
        bool swap=lower ? peerFirst:ownFirst;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        colors[lane]=swap ? peerColor:ownColor;keys[lane]=swap ? peerKey:ownKey;
        segments[lane]=swap ? peerSegment:ownSegment;orders[lane]=swap ? peerOrder:ownOrder;
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if(valid) {
        half4 result=p.a.z>=1.0 ? colors[lane]:half4(mix(float4(original),float4(colors[lane]),p.a.z));
        output.write(result,pixel);
    }
}

static float hash31(float2 cell, float seed) {
    uint2 q = uint2(int2(floor(cell)));
    uint v = q.x*1664525u + q.y*1013904223u + uint(seed*101.0+7919.0);
    v ^= v>>16; v *= 2246822519u; v ^= v>>13; v *= 3266489917u; v ^= v>>16;
    return float(v)*(1.0/4294967295.0);
}
static float moving31(float2 cell, float clock, float seed) {
    float t = fract(clock); t = t*t*(3.0-2.0*t);
    return mix(hash31(cell,seed+floor(clock)*17.0),hash31(cell,seed+(floor(clock)+1.0)*17.0),t);
}
static float4 sample31(texture2d<half,access::sample> source,float2 uv) { return float4(source.sample(signal31,uv)); }
static float luminance31(float3 value) { return dot(value,float3(.2126,.7152,.0722)); }
static float4 split31(texture2d<half,access::sample> source,float2 uv,float2 offset) {
    float4 r=sample31(source,uv+offset), g=sample31(source,uv), b=sample31(source,uv-offset);
    float alpha=max(r.a,max(g.a,b.a));
    return float4(float3(r.r,g.g,b.b),alpha);
}

kernel void fxSignal31(texture2d<half,access::sample> source [[texture(0)]],
                       texture2d<half,access::write> output [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 size=float2(output.get_width(),output.get_height()), uv=float2(gid)+.5;
    float4 original=sample31(source,uv), result=original;
    float amount=p.a.x, scale=max(p.a.y,1.0), detail=p.a.z, clock=p.a.w, seed=p.b.x;
    float2 cell=floor(uv/scale), center=size*.5;
    float n=moving31(cell,clock,seed), row=moving31(float2(cell.y,0),clock,seed+7.0);
    float column=moving31(float2(cell.x,0),clock,seed+13.0), phase=clock+seed*.017;
    switch(p.i.x) {
        case 0: {
            float y=floor(uv.y/scale)*scale+scale*.5+(row-.5)*detail*2.0;
            result=sample31(source,float2(uv.x,y)); break;
        }
        case 1: {
            float displacement=column*detail*(.3+.7*uv.y/size.y);
            result=sample31(source,uv-float2(0,displacement)); break;
        }
        case 2: {
            float axis=size.x*detail/100.0;
            result=mix(original,sample31(source,float2(axis*2.0-uv.x,uv.y)),smoothstep(.2,.8,row)); break;
        }
        case 3: {
            float2 displacement=float2(n-.5,moving31(cell,clock,seed+31.0)-.5)*detail*2.0;
            result=split31(source,uv,displacement); break;
        }
        case 4: {
            float4 block=sample31(source,(cell+.5)*scale+float2((n-.5)*scale,0));
            float3 straight=original.a>1e-5 ? original.rgb/original.a : float3(0);
            float3 chroma=block.a>1e-5 ? block.rgb/block.a : float3(0);
            float l=luminance31(straight), cl=luminance31(chroma);
            float levels=max(2.0,detail);
            result.rgb=clamp(l+floor((chroma-cl)*levels+.5)/levels,0.0,1.0)*original.a; break;
        }
        case 5: {
            float field=fmod(floor(uv.y/scale),2.0)<.5 ? -1.0 : 1.0;
            result=sample31(source,uv+float2(field*detail*(.3+.7*row),0)); break;
        }
        case 6: {
            float grain=hash31(floor(uv/max(detail,1.0)),floor(clock*8.0)+seed);
            float dropout=smoothstep(.25,.75,row);
            result.rgb=mix(original.rgb,float3(grain*original.a),dropout); break;
        }
        case 7: {
            float position=fract(phase*.13)*size.y;
            float band=exp(-pow((uv.y-position)/scale,2.0));
            float shift=detail*band*(.5+.5*sin(uv.y*.09+phase));
            result=sample31(source,uv+float2(shift,0)); break;
        }
        case 8: {
            float y=fract((uv.y+phase*size.y*.07)/size.y)*size.y;
            float seam=exp(-pow((y-size.y*.95)/scale,2.0));
            result=sample31(source,float2(uv.x+detail*seam,y)); break;
        }
        case 9: {
            float3 permutation=mix(original.gbr,original.brg,row);
            result.rgb=mix(original.rgb,permutation,detail/100.0); break;
        }
        case 10: {
            float exposure=exp2((n-.5)*detail*2.0);
            result.rgb=max(original.rgb*exposure,0.0); break;
        }
        case 11: {
            float2 displacement=float2(n-.5,moving31(cell,clock,seed+23.0)-.5)*detail*2.0;
            result=sample31(source,uv+displacement); break;
        }
        case 12: {
            result=split31(source,uv,float2((row-.5)*detail*2.0,0)); break;
        }
        case 13: {
            float carrier=sin(uv.y/scale*6.2831853+phase);
            float brightness=carrier*(detail/100.0)*(.3+.7*row);
            result.rgb=max(original.rgb+brightness*original.a*.5,0.0); break;
        }
        case 14: {
            bool vertical=p.i.y==1;
            float reach=detail*(vertical ? column : row);
            float4 sum=float4(0);
            for(int tap=0;tap<8;tap++) {
                float2 delta=vertical ? float2(0,reach*float(tap)/7.0) : float2(reach*float(tap)/7.0,0);
                sum+=sample31(source,uv-delta);
            }
            result=sum/8.0; break;
        }
        case 16: {
            float coverage=smoothstep(1.0-detail/100.0-.08,1.0-detail/100.0+.08,n);
            result.rgb=mix(original.rgb,original.a-original.rgb,coverage); break;
        }
        case 17: {
            float levels=max(2.0,detail*(.4+row));
            if(original.a>1e-5) result.rgb=floor(original.rgb/original.a*levels+.5)/levels*original.a;
            break;
        }
        case 18: {
            float2 offset=float2(cos(phase),sin(phase))*scale;
            result=mix(original,split31(source,uv,offset),detail/100.0); break;
        }
        case 19: {
            float staircase=fmod(floor((uv.y+phase*scale)/scale),5.0)-2.0;
            result=sample31(source,uv+float2(staircase*detail,0)); break;
        }
        case 20: {
            float strip=floor((uv.x+uv.y)*.7071/scale);
            float displacement=(moving31(float2(strip,0),clock,seed)-.5)*detail*2.0;
            result=sample31(source,uv+float2(displacement,-displacement)*.7071); break;
        }
        case 21: {
            float2 quadrant=fmod(abs(cell),2.0)*2.0-1.0;
            result=sample31(source,uv+quadrant*detail*(.35+.65*n)); break;
        }
        case 22: {
            float wave=sin(uv.y/scale*6.2831853+phase)*sin(uv.y/size.y*5.0+phase*.7);
            result=sample31(source,uv+float2(wave*detail,0)); break;
        }
        case 23: {
            float pulse=scale/min(size.x,size.y)*(.35+.65*sin(phase))*(detail/100.0);
            float4 r=sample31(source,center+(uv-center)*(1.0+pulse));
            float4 b=sample31(source,center+(uv-center)*(1.0-pulse));
            float alpha=max(original.a,max(r.a,b.a));
            result=float4(float3(r.r,original.g,b.b),alpha); break;
        }
        case 24: {
            float length=max(1.0,detail*(.3+.7*(p.i.y==1 ? column : row)));
            float2 coordinate=p.i.y==1 ? float2(uv.x,(floor(uv.y/length)+.5)*length)
                                      : float2((floor(uv.x/length)+.5)*length,uv.y);
            result=sample31(source,coordinate); break;
        }
        case 26: {
            float4 right=sample31(source,uv+float2(1,0)), down=sample31(source,uv+float2(0,1));
            float edge=clamp(length(original.rgb-right.rgb)+length(original.rgb-down.rgb),0.0,1.0);
            result=mix(original,sample31(source,uv+float2((row-.5)*detail*2.0,0)),edge); break;
        }
        case 27: {
            float ramp=fract(uv.y/scale)-.5;
            result=sample31(source,uv+float2(ramp*detail*(row*2.0-1.0),0)); break;
        }
        case 28: {
            float l=original.a>1e-5 ? luminance31(original.rgb/original.a) : 0.0;
            float2 displacement=float2(l-.5,n-.5)*detail*2.0;
            result=sample31(source,uv+displacement); break;
        }
        case 29: {
            float levels=max(2.0,detail);
            float4 other=sample31(source,uv+float2(scale*sin(phase),0));
            if(original.a>1e-5 && other.a>1e-5) {
                float3 base=floor(original.rgb/original.a*levels)/levels;
                float3 low=fract(other.rgb/other.a*levels)/levels;
                result.rgb=min(base+low,1.0)*original.a;
            }
            break;
        }
        case 30: {
            float sign=fmod(floor(uv.y/scale),2.0)<.5 ? -1.0 : 1.0;
            result=sample31(source,uv+float2(sign*detail*sin(phase+.5),0)); break;
        }
        case 31: {
            float localY=fract((uv.y+(n-.5)*detail*2.0)/size.y)*size.y;
            result=sample31(source,float2(uv.x,localY)); break;
        }
    }
    result.rgb=max(result.rgb,0.0); result.a=clamp(result.a,0.0,1.0);
    output.write(half4(mix(original,result,clamp(amount*p.b.y,0.0,1.0))),gid);
}
