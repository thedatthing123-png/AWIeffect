#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler signal31(address::clamp_to_edge, filter::linear, coord::pixel);

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
