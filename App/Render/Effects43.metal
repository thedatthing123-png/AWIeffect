#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a,b,c,d;uint4 i; };
constexpr sampler temporalSample43(address::clamp_to_zero,filter::linear,coord::normalized);
static float change43(float4 a,float4 b) { return max(length(a.rgb-b.rgb)*.577350269,abs(a.a-b.a)); }
kernel void fxTemporalAnalysis43(texture2d<half> source [[texture(0)]],texture2d<half,access::write> output [[texture(1)]],
                                array<texture2d<half>,8> frames [[texture(2)]],constant EffectParams& p [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width()||gid.y>=output.get_height()) return;
    float2 size=float2(output.get_width(),output.get_height()),uv=(float2(gid)+.5)/size;
    float4 original=float4(source.sample(temporalSample43,uv));uint count=clamp(p.i.y,2u,8u);
    if(p.i.x==8) {
        uint columns=clamp(p.i.z,2u,4u),rows=(count+columns-1)/columns;
        float2 grid=float2(columns,rows),tilePoint=uv*grid,local=fract(tilePoint),tilePixels=size/grid;
        uint index=min(uint(floor(tilePoint.y)),rows-1)*columns+min(uint(floor(tilePoint.x)),columns-1);
        float2 halfGap=min(float2(.45),float2(p.c.x)*.5/max(tilePixels,float2(1)));
        float4 tile=float4(0);
        if(index<count && all(local>=halfGap) && all(local<=1-halfGap))
            tile=float4(frames[index].sample(temporalSample43,(local-halfGap)/max(float2(.001),1-2*halfGap)));
        output.write(half4(mix(original,tile,p.a.x)),gid);return;
    }
    float4 values[8];float4 mean=float4(0),variance=float4(0);float coverage=0;
    for(uint index=0;index<count;index++) { values[index]=float4(frames[index].sample(temporalSample43,uv));mean+=values[index]/float(count);coverage=max(coverage,values[index].a); }
    if(p.i.x==0 || p.i.x==5) for(uint index=0;index<count;index++) { float4 delta=values[index]-mean;variance+=delta*delta/float(count); }
    float4 result=original;
    switch(p.i.x) {
        case 0: result=float4(clamp(sqrt(max(variance.rgb,float3(0)))*p.a.y,float3(0),float3(1))*coverage,coverage);break;
        case 1: {
            float occupied=0,knee=max(.0001,p.a.w*.5);
            for(uint index=1;index<count;index++) occupied+=smoothstep(p.a.z-knee,p.a.z+knee,change43(values[index],values[index-1]));
            float value=occupied/float(count-1);result=float4(float3(value)*coverage,coverage);break;
        }
        case 2: {
            float best=0,when=0;
            for(uint index=1;index<count;index++) { float change=change43(values[index],values[index-1]);if(change>best) { best=change;when=float(index)/float(count-1); } }
            float weight=clamp((best-p.a.z)*p.a.y,0.0,1.0);
            float3 palette=.5+.5*cos(6.283185307*(when+float3(0,.333333333,.666666667)));
            result=float4(palette*weight*coverage,coverage);break;
        }
        case 3: {
            float3 response=abs(values[0].rgb-2*values[1].rgb+values[2].rgb)*p.a.y;
            result=float4(clamp(response,float3(0),float3(1))*coverage,coverage);break;
        }
        case 4: {
            // Stable insertion sort keeps whole premultiplied pixels together.
            for(uint index=1;index<count;index++) {
                float4 value=values[index];float light=dot(value.rgb,float3(.2126,.7152,.0722));uint cursor=index;
                while(cursor>0 && dot(values[cursor-1].rgb,float3(.2126,.7152,.0722))>light) { values[cursor]=values[cursor-1];cursor--; }
                values[cursor]=value;
            }
            float rank=clamp(p.b.x,0.0,1.0)*float(count-1);uint low=uint(floor(rank)),high=min(low+1,count-1);
            result=mix(values[low],values[high],fract(rank));break;
        }
        case 5: {
            float4 sum=float4(0);float weightSum=0;float3 sigma=sqrt(max(variance.rgb,float3(0)))+max(.001,p.b.z);
            for(uint index=0;index<count;index++) {
                float3 deviation=abs(values[index].rgb-mean.rgb)/sigma;
                float distance=max(deviation.x,max(deviation.y,deviation.z));
                float weight=1-smoothstep(p.b.y,p.b.y+.25,distance);
                sum+=values[index]*weight;weightSum+=weight;
            }
            result=weightSum>.0001 ? sum/weightSum:mean;break;
        }
        case 6: {
            float3 covariance=float3(0);float timeVariance=0;
            for(uint index=0;index<count;index++) { float t=float(index)/float(count-1)-.5;covariance+=(values[index].rgb-mean.rgb)*t;timeVariance+=t*t; }
            float3 slope=covariance/max(.0001,timeVariance);
            result=float4(clamp(.5+slope*p.a.y*.5,float3(0),float3(1))*coverage,coverage);break;
        }
        case 7: {
            float3 real=float3(0),imaginary=float3(0);float energy=0,cycles=min(p.b.w,float(count-1)*.5);
            for(uint index=0;index<count;index++) {
                float t=float(index)/float(count-1),weight=.5-.5*cos(6.283185307*(float(index)+.5)/float(count));
                float phase=6.283185307*cycles*t;float3 value=values[index].rgb-mean.rgb;
                real+=value*cos(phase)*weight;imaginary+=value*sin(phase)*weight;energy+=weight;
            }
            float3 amplitude=2*sqrt(real*real+imaginary*imaginary)/max(.0001,energy);
            result=float4(clamp(amplitude*p.a.y,float3(0),float3(1))*coverage,coverage);break;
        }
    }
    output.write(half4(mix(original,result,p.a.x)),gid);
}
