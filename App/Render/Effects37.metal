#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler finish37(address::clamp_to_zero,filter::linear,coord::pixel);
constexpr sampler clean37(address::clamp_to_edge,filter::linear,coord::pixel);
static float3 straight37(float4 color) { return color.a>.00001 ? color.rgb/color.a:float3(0); }
static float luma37(float3 color) { return dot(color,float3(.2126,.7152,.0722)); }

kernel void fxCleanup37(texture2d<half,access::sample> source [[texture(0)]],
                         texture2d<half,access::write> output [[texture(1)]],
                         constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;
    float4 original=float4(source.sample(clean37,uv));
    if(original.a<=.00001) { output.write(half4(original),gid);return; }
    float3 colors[9];uint count=0;
    float3 minimum=float3(INFINITY),maximum=float3(-INFINITY),weighted=0;
    float weight=0;
    for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
        float4 sample=float4(source.sample(clean37,uv+float2(x,y)*p.a.x));
        // Transparent neighbors are absent data, not black paint.
        if(sample.a<=.00001) continue;
        float3 color=straight37(sample);
        colors[count]=color;count++;
        weighted+=color*sample.a;weight+=sample.a;
        if(x!=0 || y!=0) { minimum=min(minimum,color);maximum=max(maximum,color); }
    }
    float3 current=straight37(original),result=current;
    if(count>1) {
        if(p.i.x==0 || p.i.x==4) {
            // A bounded nine-element insertion sort, ranked by luma rather than
            // separate channel medians that could manufacture an unrelated hue.
            for(uint i=1;i<count;i++) {
                float3 value=colors[i];uint j=i;
                while(j>0 && luma37(colors[j-1])>luma37(value)) { colors[j]=colors[j-1];j--; }
                colors[j]=value;
            }
            if(p.i.x==0) result=colors[count/2];
            else {
                result=0;
                uint start=count>2 ? 1u:0u,end=count>2 ? count-1:count;
                for(uint i=start;i<end;i++) result+=colors[i];
                result/=float(end-start);
            }
        } else if(p.i.x==1) result=clamp(current,minimum,maximum);
        else if(p.i.x==2) {
            float3 mean=weighted/max(weight,.00001);
            result=max(mean+float3(luma37(current)-luma37(mean)),0.0);
        } else if(p.i.x==3) result=weighted/max(weight,.00001);
        else {
            float low=luma37(minimum),high=luma37(maximum),luma=luma37(current);
            // Stabilize nearly flat neighborhoods; do not amplify tiny roundoff.
            float mapped=clamp((luma-low)/max(high-low,.08),0.0,1.0);
            result=luma>.00001 ? current*mapped/luma:current;
        }
    }
    result=mix(current,result,p.a.y);
    output.write(half4(float4(max(result,0.0)*original.a,original.a)),gid);
}

static float3 hsv37(float hue,float saturation) {
    float h=fract(hue)*6.0;
    float3 pure=clamp(float3(abs(h-3.0)-1.0,2.0-abs(h-2.0),2.0-abs(h-4.0)),0.0,1.0);
    return mix(float3(1),pure,saturation);
}
static float3 hot37(float3 original,constant EffectParams& p) {
    float luminance=pow(clamp(dot(original,float3(.2126,.7152,.0722)),0.0,1.0),1.0/max(p.b.x,.1));
    float3 tint;float saturation=p.a.y;
    if(p.i.x==1) {
        float cutoff=clamp(p.b.y,.01,.99);
        float high=clamp((luminance-cutoff)/(1.0-cutoff),0.0,1.0);
        tint=mix(hsv37(p.a.x,p.a.y),hsv37(p.a.z,p.a.w),high);
    } else {
        float hue=fract(p.a.x),low=floor(hue*6.0)/6.0,high=low+1.0/6.0;
        bool upper=(hue-low)>(high-hue);
        float dark=upper ? low : high,light=upper ? high : low;
        tint=luminance<.5 ? mix(hsv37(dark,saturation),hsv37(hue,saturation),luminance*2.0)
                           : mix(hsv37(hue,saturation),hsv37(light,saturation),(luminance-.5)*2.0);
    }
    // Separate chroma from brightness, then scale chroma with luminance to keep black neutral.
    float y=dot(tint,float3(.299,.587,.114));
    float u=(tint.b-y)*.492,v=(tint.r-y)*.877;
    u*=luminance;v*=luminance;
    float3 result=float3(luminance+1.140*v,luminance-.395*u-.581*v,luminance+2.033*u);
    float shoulder=max(0.0,(luminance-.85)/.15);
    result=mix(result,float3(1),clamp(shoulder*shoulder*saturation*p.b.z,0.0,1.0));
    return max(result,0.0);
}

kernel void fxFinish37(texture2d<half,access::sample> source [[texture(0)]],texture2d<half,access::write> output [[texture(1)]],
                       texture2d<half,access::sample> auxiliary [[texture(2)]],constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;float4 original=float4(source.sample(finish37,uv)),result=original;
    if(p.i.x==0) {
        float block=max(p.a.x,1.0);float2 center=(floor(uv/block)+.5)*block;
        if(p.i.y==0) result=float4(auxiliary.sample(finish37,center));
        else {
            result=float4(0);
            for(int y=0;y<2;y++) for(int x=0;x<2;x++) {
                float2 offset=(float2(x,y)-.5)*block*.5;
                result+=float4(auxiliary.sample(finish37,center+offset))*.25;
            }
        }
        output.write(half4(mix(original,result,p.a.y)),gid);return;
    }
    float3 straight=original.a>.00001 ? original.rgb/original.a : float3(0);
    result=float4(hot37(straight,p)*original.a,original.a);
    output.write(half4(mix(original,result,p.b.w)),gid);
}
