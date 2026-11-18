#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a,b,c,d;uint4 i; };
constexpr sampler poissonSample45(address::clamp_to_zero,filter::linear,coord::pixel);
kernel void fxPoissonPrepare45(texture2d<half> source [[texture(0)]],texture2d<float,access::write> output [[texture(1)]],
                               constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width()||gid.y>=output.get_height()) return;
    float2 size=float2(output.get_width(),output.get_height()),buffer=float2(source.get_width(),source.get_height());
    float2 point=(buffer-p.a.xy)*.5+(float2(gid)+.5)/size*p.a.xy;
    float4 value=float4(source.sample(poissonSample45,point));
    output.write(float4(value.a>1.e-6 ? value.rgb/value.a:float3(0),value.a),gid);
}
static float4 periodicRead45(texture2d<float,access::read> source,int2 point) {
    int2 size=int2(source.get_width(),source.get_height());return source.read(uint2((point+size)%size));
}
static float2 inputGradient45(float4 pixel,float2 spacing,constant EffectParams& p) {
    if(pixel.a<=1.e-6) return float2(0);
    float2 g;
    if(p.i.x==0) {
        float3 n=pixel.rgb*2-1;float norm=length(n);n=norm>1.e-8 ? n/norm:float3(0,0,1);
        g=-n.xy/max(p.b.z,n.z);
    } else g=pixel.rg*2-1;
    return clamp(g,float2(-64),float2(64))*spacing*p.a.z;
}
static float3 reshapeGradient45(float3 g,float spacing,constant EffectParams& p) {
    float magnitude=length(g)*.577350269/max(.0001,spacing);
    float scale=pow(max(.0001,magnitude/max(.002,p.b.y)),p.b.x-1);
    return g*clamp(scale,.05,8.0);
}
kernel void fxPoissonForce45(texture2d<float,access::read> source [[texture(0)]],texture2d<float,access::write> real [[texture(1)]],
                             texture2d<float,access::write> imaginary [[texture(2)]],constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    uint2 size=uint2(real.get_width(),real.get_height());if(any(gid>=size)) return;
    int2 q=int2(gid);float3 force=float3(0);float4 center=source.read(gid);
    if(p.i.x<2) {
        float2 spacing=p.a.xy/(float2(size)*p.c.z),g=inputGradient45(center,spacing,p);
        float2 left=inputGradient45(periodicRead45(source,q-int2(1,0)),spacing,p),up=inputGradient45(periodicRead45(source,q-int2(0,1)),spacing,p);
        force=float3(g.x-left.x+g.y-up.y);
    } else if(p.i.x==2) {
        float2 spacing=p.a.xy/(float2(size)*p.c.z);
        float3 right=periodicRead45(source,q+int2(1,0)).rgb,down=periodicRead45(source,q+int2(0,1)).rgb;
        float3 left=periodicRead45(source,q-int2(1,0)).rgb,up=periodicRead45(source,q-int2(0,1)).rgb;
        force=reshapeGradient45(right-center.rgb,spacing.x,p)-reshapeGradient45(center.rgb-left,spacing.x,p)
             +reshapeGradient45(down-center.rgb,spacing.y,p)-reshapeGradient45(center.rgb-up,spacing.y,p);
    } else {
        if(gid.x==0) force+=source.read(uint2(size.x-1,gid.y)).rgb-center.rgb;
        if(gid.x==size.x-1) force+=source.read(uint2(0,gid.y)).rgb-center.rgb;
        if(gid.y==0) force+=p.c.x*(source.read(uint2(gid.x,size.y-1)).rgb-center.rgb);
        if(gid.y==size.y-1) force+=p.c.x*(source.read(uint2(gid.x,0)).rgb-center.rgb);
    }
    real.write(float4(force,0),gid);imaginary.write(float4(0),gid);
}
static uint reversed45(uint value,uint length) {
    uint result=0;for(uint bit=1;bit<length;bit<<=1) { result=(result<<1)|(value&1);value>>=1; }return result;
}
kernel void fxFFTReorder45(texture2d<float,access::read> real [[texture(0)]],texture2d<float,access::write> nextReal [[texture(1)]],
                          texture2d<float,access::read> imaginary [[texture(2)]],texture2d<float,access::write> nextImaginary [[texture(3)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=nextReal.get_width()||gid.y>=nextReal.get_height()) return;
    uint2 q=uint2(reversed45(gid.x,nextReal.get_width()),reversed45(gid.y,nextReal.get_height()));
    nextReal.write(real.read(q),gid);nextImaginary.write(imaginary.read(q),gid);
}
kernel void fxFFTStage45(texture2d<float,access::read> real [[texture(0)]],texture2d<float,access::write> nextReal [[texture(1)]],
                        texture2d<float,access::read> imaginary [[texture(2)]],texture2d<float,access::write> nextImaginary [[texture(3)]],
                        constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=nextReal.get_width()||gid.y>=nextReal.get_height()) return;
    uint coordinate=p.i.y==0 ? gid.x:gid.y,span=p.i.x,halfSpan=span/2,index=coordinate%span,k=index%halfSpan;
    uint low=coordinate-index+k,high=low+halfSpan;uint2 qa=gid,qb=gid;
    if(p.i.y==0) { qa.x=low;qb.x=high; } else { qa.y=low;qb.y=high; }
    float angle=(p.i.z==0 ? -1.0:1.0)*6.283185307*float(k)/float(span),c=cos(angle),s=sin(angle);
    float4 ar=real.read(qa),ai=imaginary.read(qa),br=real.read(qb),bi=imaginary.read(qb);
    float sign=index<halfSpan ? 1.0:-1.0;
    nextReal.write(ar+sign*(br*c-bi*s),gid);nextImaginary.write(ai+sign*(br*s+bi*c),gid);
}
kernel void fxPoissonDivide45(texture2d<float,access::read> real [[texture(0)]],texture2d<float,access::write> nextReal [[texture(1)]],
                             texture2d<float,access::read> imaginary [[texture(2)]],texture2d<float,access::write> nextImaginary [[texture(3)]],
                             constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=nextReal.get_width()||gid.y>=nextReal.get_height()) return;
    float2 sine=sin(3.141592654*float2(gid)/float2(nextReal.get_width(),nextReal.get_height()));
    float weight=p.i.x==3 ? p.c.x:1.0,denominator=-4*(sine.x*sine.x+weight*sine.y*sine.y);
    if(gid.x==0 && gid.y==0) { nextReal.write(float4(0),gid);nextImaginary.write(float4(0),gid); }
    else { nextReal.write(real.read(gid)/denominator,gid);nextImaginary.write(imaginary.read(gid)/denominator,gid); }
}
kernel void fxPoissonMean45(texture2d<float,access::read> source [[texture(0)]],texture2d<float,access::write> output [[texture(1)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width()||gid.y>=output.get_height()) return;
    uint2 last=uint2(source.get_width()-1,source.get_height()-1),q=gid*2;
    output.write((source.read(min(q,last))+source.read(min(q+uint2(1,0),last))+source.read(min(q+uint2(0,1),last))+source.read(min(q+1,last)))*.25,gid);
}
static float3 interpolatePoisson45(texture2d<float,access::read> source,float2 uv) {
    float2 point=fract(uv)*float2(source.get_width(),source.get_height())-.5,f=fract(point);int2 q=int2(floor(point));
    return mix(mix(periodicRead45(source,q).rgb,periodicRead45(source,q+int2(1,0)).rgb,f.x),
               mix(periodicRead45(source,q+int2(0,1)).rgb,periodicRead45(source,q+1).rgb,f.x),f.y);
}
kernel void fxPoissonFinish45(texture2d<half> source [[texture(0)]],texture2d<half,access::write> output [[texture(1)]],
                             texture2d<float,access::read> solution [[texture(2)]],texture2d<float,access::read> mean [[texture(3)]],
                             constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width()||gid.y>=output.get_height()) return;
    float2 point=float2(gid)+.5,buffer=float2(output.get_width(),output.get_height());
    float4 original=float4(source.sample(poissonSample45,point));
    if(original.a<=1.e-6) { output.write(half4(original),gid);return; }
    float2 uv=(point-(buffer-p.a.xy)*.5)/p.a.xy;float3 potential=interpolatePoisson45(solution,uv)/p.c.y,result;
    if(p.i.x<2) result=clamp(.5+potential/max(1.0,p.a.w),float3(0),float3(1));
    else if(p.i.x==2) result=clamp(potential+mean.read(uint2(0)).rgb,float3(0),float3(65504));
    else result=clamp(original.rgb/original.a-potential,float3(0),float3(65504));
    output.write(half4(mix(original,float4(result*original.a,original.a),p.b.w)),gid);
}
