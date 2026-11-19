#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a,b,c,d;uint4 i; };
constexpr sampler contourSample41(address::clamp_to_zero,filter::linear,coord::pixel);
static float contourValue41(texture2d<half> source,float2 point,uint mode) {
    float4 value=float4(source.sample(contourSample41,point));
    return mode==0 ? value.a:dot(value.rgb,float3(.2126,.7152,.0722));
}
kernel void fxContourSeed41(texture2d<half> source [[texture(0)]],texture2d<float,access::write> output [[texture(1)]],
                            constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    uint2 size=uint2(output.get_width(),output.get_height());if(any(gid>=size)) return;
    float2 scale=p.a.xy/float2(size),point=(float2(gid)+.5)*scale;
    float value=contourValue41(source,point,p.i.y),threshold=p.a.z;
    float2 best=float2(-1);float bestDistance=1.e30;
    const int2 directions[8]={int2(-1,0),int2(1,0),int2(0,-1),int2(0,1),int2(-1,-1),int2(1,-1),int2(-1,1),int2(1,1)};
    for(uint index=0;index<8;index++) {
        float2 delta=float2(directions[index])*scale;
        float neighbor=contourValue41(source,point+delta,p.i.y);
        if((value>=threshold)==(neighbor>=threshold)) continue;
        float fraction=clamp((threshold-value)/(neighbor-value),0.0,1.0);
        float2 seed=clamp(point+delta*fraction,float2(0),p.a.xy);
        float distance=dot(seed-point,seed-point);
        if(distance<bestDistance) { best=seed;bestDistance=distance; }
    }
    output.write(float4(best,0,0),gid);
}
kernel void fxContourFlood41(texture2d<float,access::read> input [[texture(0)]],texture2d<float,access::write> output [[texture(1)]],
                             constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    int2 size=int2(output.get_width(),output.get_height());if(any(int2(gid)>=size)) return;
    float2 point=(float2(gid)+.5)*p.a.xy/float2(size),best=float2(-1);float bestDistance=1.e30;
    int jump=int(p.i.x);
    for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
        int2 samplePoint=int2(gid)+int2(x,y)*jump;
        if(any(samplePoint<0)||any(samplePoint>=size)) continue;
        float2 candidate=input.read(uint2(samplePoint)).xy;
        if(candidate.x<0) continue;
        float distance=dot(candidate-point,candidate-point);
        // Stable tie breaking avoids flickering color choices at medial ridges.
        bool tie=distance==bestDistance && (candidate.y<best.y || (candidate.y==best.y && candidate.x<best.x));
        if(distance<bestDistance || tie) { best=candidate;bestDistance=distance; }
    }
    output.write(float4(best,0,0),gid);
}
static float2 contourSeed41(texture2d<float,access::read> field,float2 point,float2 canvas) {
    int2 size=int2(field.get_width(),field.get_height());
    int2 index=clamp(int2(floor(point/canvas*float2(size))),int2(0),size-1);
    return field.read(uint2(index)).xy;
}
// x is signed distance (positive inside), yz the outward normal, w validity.
static float4 contourGeometry41(texture2d<half> source,texture2d<float,access::read> field,float2 point,constant EffectParams& p) {
    float2 seed=contourSeed41(field,point,p.a.xy);
    if(seed.x<0) return float4(0);
    float threshold=float(p.i.w>>1)/65535.0;
    bool inside=contourValue41(source,point,p.i.w&1)>=threshold;
    float2 delta=point-seed;float distance=length(delta);
    float2 normal=distance>1.e-5 ? delta/distance*(inside ? -1.0:1.0):float2(0);
    return float4(distance*(inside ? 1.0:-1.0),normal,1);
}
static float3 contourStraight41(float4 color) { return color.a>1.e-6 ? color.rgb/color.a:float3(0); }
static float4 contourOver41(float4 base,float3 color,float alpha) {
    return float4(color*alpha+base.rgb*(1-alpha),alpha+base.a*(1-alpha));
}
kernel void fxContourFinish41(texture2d<half> source [[texture(0)]],texture2d<half,access::write> output [[texture(1)]],
                              texture2d<float,access::read> field [[texture(2)]],constant EffectParams& p [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width()||gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;float4 original=float4(source.read(gid));
    float4 geometry=contourGeometry41(source,field,uv,p);
    if(geometry.w==0) { output.write(half4(original),gid);return; }
    float distance=geometry.x,depth=abs(distance),range=max(.5,abs(p.a.z));float2 normal=geometry.yz;
    float2 seed=contourSeed41(field,uv,p.a.xy);float4 result=original;
    switch(p.i.x) {
        case 0: result=float4(float3(clamp(.5+distance/(2*range),0.0,1.0)),1);break;
        case 1: result=float4(clamp(.5+(seed-uv)/(2*range),float2(0),float2(1)),.5,1);break;
        case 2: {
            if(distance>=0) break;
            float alpha=pow(clamp(1-depth/range,0.0,1.0),max(.1,p.c.x));
            float4 boundary=float4(source.sample(contourSample41,seed-normal*p.c.y));
            if(boundary.a<=1.e-6) break;
            result=float4(original.rgb+contourStraight41(boundary)*alpha*(1-original.a),original.a+alpha*(1-original.a));break;
        }
        case 3: {
            float weight=clamp(p.b.w*.01,0.0,1.0)*exp(-depth/range);
            float2 position=mix(uv,seed,weight);
            float4 sampleColor=float4(source.sample(contourSample41,position));
            result=float4(contourStraight41(sampleColor)*original.a,original.a);break;
        }
        case 4: {
            float spacing=max(1.0,p.b.x),fraction=fract(distance/spacing-p.b.z);
            float stripe=min(fraction,1-fraction)*spacing;
            float width=spacing*p.b.y*.005;
            float alpha=(1-smoothstep(max(0.0,width-.75),width+.75,stripe))*(1-smoothstep(range-1,range+1,depth))*p.d.a;
            if((p.i.y==1 && distance<0)||(p.i.y==2 && distance>0)) alpha=0;
            result=contourOver41(original,p.d.rgb,alpha);break;
        }
        case 5: {
            float step=max(.5,p.b.y);
            float dx=contourGeometry41(source,field,uv+float2(step,0),p).x-contourGeometry41(source,field,uv-float2(step,0),p).x;
            float dy=contourGeometry41(source,field,uv+float2(0,step),p).x-contourGeometry41(source,field,uv-float2(0,step),p).x;
            float magnitude=length(float2(dx,dy))/(2*step);
            float ridge=(1-smoothstep(max(0.0,p.b.w-.15),p.b.w,magnitude))*smoothstep(range,range+step,distance);
            result=float4(float3(ridge),1);break;
        }
        case 6: {
            float weight=pow(clamp(1-depth/range,0.0,1.0),max(.2,p.c.w));
            float4 sampleColor=float4(source.sample(contourSample41,uv+normal*p.b.w*weight));
            result=float4(contourStraight41(sampleColor)*original.a,original.a);break;
        }
        case 7: {
            float2 point=uv;uint steps=clamp(p.i.z,1u,12u);
            for(uint index=0;index<steps;index++) {
                float4 g=contourGeometry41(source,field,point,p);
                float2 tangent=float2(-g.z,g.y);
                point+=tangent*(p.b.w/float(steps))*exp(-abs(g.x)/range)*g.w;
            }
            float4 sampleColor=float4(source.sample(contourSample41,point));
            result=float4(contourStraight41(sampleColor)*original.a,original.a);break;
        }
        case 8: {
            float delta=abs(distance-p.a.z),core=exp(-.5*pow(delta/max(.5,p.b.y),2.0));
            float halo=exp(-delta/max(1.0,p.c.z));
            float energy=(core+.35*halo)*p.b.w*p.d.a;
            float alpha=1-exp(-energy);
            result=float4(min(original.rgb+p.d.rgb*energy,float3(65504)),original.a+alpha*(1-original.a));break;
        }
        case 9: {
            float spacing=max(1.0,p.b.x),fold=(1-abs(fract(depth/spacing+p.b.z)*2-1))*spacing;
            float direction=distance>=0 ? -1.0:1.0;
            float2 position=seed+normal*fold*direction;
            float4 sampleColor=float4(source.sample(contourSample41,position));
            float weight=clamp(p.b.w*.01,0.0,1.0)*exp(-depth/range);
            result=float4(mix(original.rgb,contourStraight41(sampleColor)*original.a,weight),original.a);break;
        }
    }
    output.write(half4(mix(original,result,p.a.w)),gid);
}
