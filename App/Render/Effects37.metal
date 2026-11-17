#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler finish37(address::clamp_to_zero,filter::linear,coord::pixel);
constexpr sampler clean37(address::clamp_to_edge,filter::linear,coord::pixel);
static float3 straight37(float4 color) { return color.a>.00001 ? color.rgb/color.a:float3(0); }
static float luma37(float3 color) { return dot(color,float3(.2126,.7152,.0722)); }

static float3 yuvRetro37(float3 color) {
    float y=dot(color,float3(.299,.587,.114));return float3(y,(color.b-y)*.492,(color.r-y)*.877);
}
static float2 rotateRetro37(float2 q,float angle) {
    float c=cos(angle),s=sin(angle);return float2(q.x*c-q.y*s,q.x*s+q.y*c);
}
kernel void fxRetro37(texture2d<half,access::sample> source [[texture(0)]],
                      texture2d<half,access::write> output [[texture(1)]],
                      constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;float4 original=float4(source.sample(finish37,uv));
    if(p.i.x==0) {
        float3 sum=0;float weights=0;
        for(uint tap=0;tap<24;tap++) {
            float t=(float(tap)+.5)/24.0,weight=exp(-p.a.y*t);
            sum+=float3(source.sample(finish37,uv+float2(0,t*p.a.x*p.a.z)).rgb)*weight;weights+=weight;
        }
        sum/=max(weights,.00001);
        output.write(half4(float4(sum,clamp(max(sum.r,max(sum.g,sum.b)),0.0,1.0))),gid);return;
    }
    if(p.i.x==1) {
        float period=max(p.a.x,.1),linePhase=floor(uv.y/max(p.b.x,.05))*3.14159265359+p.a.z;
        float3 decoded=0;
        for(uint tap=0;tap<12;tap++) {
            float offset=(float(tap)-5.5)*period*.25;
            float2 q=uv+float2(offset,0);
            float phase=q.x*6.28318530718/period+linePhase;
            float3 color=yuvRetro37(straight37(float4(source.sample(clean37,q))));
            float carrier=color.x+(color.y*cos(phase)+color.z*sin(phase))*p.a.y;
            decoded+=float3(carrier,carrier*cos(phase)*2.0,carrier*sin(phase)*2.0)/12.0;
        }
        float3 rgb=float3(decoded.x+1.140*decoded.z,decoded.x-.395*decoded.y-.581*decoded.z,decoded.x+2.033*decoded.y);
        float4 result=float4(min(max(rgb,0.0)*original.a,float3(65504.0)),original.a);
        output.write(half4(mix(original,result,p.a.w)),gid);return;
    }
    float2 center=p.b.yz,relative=uv-center;
    float2 r=center+rotateRetro37(relative,-p.a.x)/max(p.a.z,.01)+float2(p.b.x,0);
    float2 b=center+rotateRetro37(relative,-p.a.y)/max(p.a.w,.01)-float2(p.b.x,0);
    float4 red=float4(source.sample(finish37,r)),blue=float4(source.sample(finish37,b));
    float4 result=float4(red.r,original.g,blue.b,max(original.a,max(red.a,blue.a)));
    output.write(half4(mix(original,result,p.b.w)),gid);
}
kernel void fxPhosphor37(texture2d<half,access::sample> accumulated [[texture(0)]],
                         texture2d<half,access::write> output [[texture(1)]],
                         texture2d<half,access::sample> previous [[texture(2)]],
                         constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;
    float4 current=float4(accumulated.sample(finish37,uv)),old=float4(previous.sample(finish37,uv));
    float3 rgb=max(current.rgb,old.rgb*p.a.xyz);
    float alpha=max(current.a,old.a*max(p.a.x,max(p.a.y,p.a.z)));
    output.write(half4(float4(rgb,alpha)),gid);
}
static float hashDrawing37(float2 p) {
    float3 q=fract(float3(p.xyx)*.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);
}
static float noiseDrawing37(float2 p) {
    float2 cell=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hashDrawing37(cell),hashDrawing37(cell+float2(1,0)),f.x),
               mix(hashDrawing37(cell+float2(0,1)),hashDrawing37(cell+1.0),f.x),f.y);
}
static float toneDrawing37(texture2d<half,access::sample> image,float2 uv) {
    return luma37(straight37(float4(image.sample(clean37,uv))));
}
static float2 gradientDrawing37(texture2d<half,access::sample> image,float2 uv,float radius) {
    return float2(toneDrawing37(image,uv+float2(radius,0))-toneDrawing37(image,uv-float2(radius,0)),
                  toneDrawing37(image,uv+float2(0,radius))-toneDrawing37(image,uv-float2(0,radius)))*.5;
}
kernel void fxDrawing37(texture2d<half,access::sample> source [[texture(0)]],
                        texture2d<half,access::write> output [[texture(1)]],
                        texture2d<half,access::sample> smoothSource [[texture(2)]],
                        constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;float4 original=float4(source.sample(finish37,uv));
    if(original.a<=.00001 && p.i.x!=4) { output.write(half4(original),gid);return; }
    float3 current=straight37(original),result=current;
    float radius=max(p.a.x,.5),tone=clamp(luma37(current),0.0,1.0),ink=0;
    if(p.i.x==0) {
        float2 gradient=gradientDrawing37(smoothSource,uv,max(radius*.5,1.0));
        float2 tangent=length(gradient)>.0001 ? normalize(float2(-gradient.y,gradient.x)):float2(1,0);
        float3 sum=0;float weights=0,tolerance=max(p.a.z,.01);
        for(int tap=-4;tap<=4;tap++) {
            float t=float(tap)/4.0;
            float4 color=float4(source.sample(finish37,uv+tangent*t*p.a.y));
            float3 straight=straight37(color),delta=straight-current;
            float weight=exp(-2.0*t*t-dot(delta,delta)/(tolerance*tolerance))*color.a;
            sum+=straight*weight;weights+=weight;
        }
        result=weights>.00001 ? sum/weights:current;
    } else if(p.i.x==1 || p.i.x==2) {
        float2 center=(floor(uv/radius)+.5)*radius,q=uv-center;
        float2 gradient=gradientDrawing37(smoothSource,center,max(radius*.15,1.0));
        float2 base=float2(cos(p.b.x),sin(p.b.x));
        float2 normal=length(gradient)>.0001 ? normalize(gradient):base;
        if(dot(normal,base)<0) normal=-normal;
        if(p.i.x==1) {
            normal=normalize(mix(base,normal,clamp(p.a.z,0.0,1.0)));
            float spacing=max(p.a.y,1.0),distance=abs(fract(dot(q,normal)/spacing+.5)-.5)*spacing;
            float darkness=1.0-clamp(toneDrawing37(smoothSource,center),0.0,1.0);
            ink=darkness<=0 ? 0:1.0-smoothstep(darkness*spacing*.5-.6,darkness*spacing*.5+.6,distance);
        } else {
            if(length(gradient)<=.0001) normal=float2(1,0);
            float2 tangent=float2(-normal.y,normal.x);
            float c=cos(p.b.x),s=sin(p.b.x);tangent=float2(tangent.x*c-tangent.y*s,tangent.x*s+tangent.y*c);
            float along=dot(q,tangent),across=dot(q,float2(-tangent.y,tangent.x));
            float strokeRadius=max(radius*p.a.z*.5,.5),halfLength=max(radius*p.a.y*.5-strokeRadius,0.0);
            float distance=length(float2(max(abs(along)-halfLength,0.0),across))-strokeRadius;
            float coverage=1.0-smoothstep(-.6,.6,distance);
            result=mix(float3(.97),straight37(float4(smoothSource.sample(clean37,center))),coverage);
        }
    } else if(p.i.x==3) {
        float seed=as_type<float>(p.i.z);
        float2 q=uv/radius+float2(seed*.137,seed*.731);
        float coarse=noiseDrawing37(q),fine=noiseDrawing37(q*2.73+7.1);
        float pits=mix(coarse,fine,clamp(p.a.z,0.0,1.0)*.65);
        float darkness=pow(1.0-tone,p.a.y);
        ink=smoothstep(pits-.08,pits+.08,darkness);
    } else if(p.i.x==4) {
        float2 gradient=gradientDrawing37(smoothSource,uv,max(radius*.5,1.0));
        float magnitude=length(gradient);
        float2 direction=magnitude>.00001 ? gradient/magnitude:float2(0);
        float2 offset=direction*p.a.y*clamp(magnitude*p.a.z,0.0,1.0);
        float4 shifted=float4(source.sample(finish37,uv+offset));
        output.write(half4(mix(original,shifted,p.a.w)),gid);return;
    } else if(p.i.x==5 || p.i.x==6) {
        float center=toneDrawing37(smoothSource,uv);
        float xx=toneDrawing37(smoothSource,uv+float2(radius,0))+toneDrawing37(smoothSource,uv-float2(radius,0))-2.0*center;
        float yy=toneDrawing37(smoothSource,uv+float2(0,radius))+toneDrawing37(smoothSource,uv-float2(0,radius))-2.0*center;
        if(p.i.x==5) result=float3(clamp(p.a.z+(xx+yy)*p.a.y,0.0,1.0));
        else {
            float xy=(toneDrawing37(smoothSource,uv+float2(radius,radius))-toneDrawing37(smoothSource,uv+float2(radius,-radius))
                    -toneDrawing37(smoothSource,uv+float2(-radius,radius))+toneDrawing37(smoothSource,uv-float2(radius,radius)))*.25;
            float sign=p.i.y==0 ? 1.0:-1.0;
            float eigen=.5*(sign*(xx+yy)+sqrt((xx-yy)*(xx-yy)+4.0*xy*xy));
            ink=smoothstep(p.a.z,p.a.z+.08,max(eigen,0.0)*p.a.y);
        }
    } else if(p.i.x==7) {
        float2 q=uv-p.b.yz;
        float phase=length(q)/radius+atan2(q.y,q.x)*p.a.y/6.28318530718+p.b.x/6.28318530718;
        float distance=abs(fract(phase)-.5)*radius,darkness=pow(1.0-tone,p.a.z);
        ink=darkness<=0 ? 0:1.0-smoothstep(darkness*radius*.5-.6,darkness*radius*.5+.6,distance);
    } else {
        float surround=toneDrawing37(smoothSource,uv),softness=max(p.a.z*.35,.002);
        float gate=smoothstep(softness*.25,softness,tone-surround*p.a.y);
        result=mix(current,1.0-clamp(current,0.0,1.0),gate);
    }
    if(p.i.x==1 || p.i.x==3 || p.i.x==6 || p.i.x==7) {
        float3 paper=mix(current,p.d.rgb,clamp(p.d.a,0.0,1.0));
        result=mix(paper,p.c.rgb,clamp(ink*p.c.a,0.0,1.0));
    }
    output.write(half4(float4(min(max(mix(current,result,p.a.w),0.0)*original.a,float3(65504.0)),original.a)),gid);
}

kernel void fxFrequency37(texture2d<half,access::sample> source [[texture(0)]],
                          texture2d<half,access::write> output [[texture(1)]],
                          texture2d<half,access::sample> nearScale [[texture(2)]],
                          texture2d<half,access::sample> middleScale [[texture(3)]],
                          texture2d<half,access::sample> farScale [[texture(4)]],
                          constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;
    float4 original=float4(source.sample(finish37,uv));
    if(original.a<=.00001) { output.write(half4(original),gid);return; }
    // Normalize by each surround's own coverage: transparent padding is missing
    // data, not a black illumination estimate.
    float3 current=straight37(original),near=straight37(float4(nearScale.sample(finish37,uv)));
    float3 middle=straight37(float4(middleScale.sample(finish37,uv))),result=current;
    if(p.i.x==0) {
        float3 fine=current-near,medium=near-middle;
        result=middle*p.a.z+medium*p.a.y+fine*p.a.x;
    } else if(p.i.x==1) {
        result=float3(p.b.y)+(near-middle)*p.b.x;
    } else {
        float3 far=straight37(float4(farScale.sample(finish37,uv)));
        float luminance=luma37(current),floorValue=max(p.c.x,.001);
        float surround=(log(max(luma37(near),floorValue))+log(max(luma37(middle),floorValue))
                        +log(max(luma37(far),floorValue)))/3.0;
        float reflectance=log(max(luminance,floorValue))-surround;
        // A bounded analytic tone mapping, not the paper's image-wide percentile
        // normalization. Label this editable local-detail adaptation accordingly.
        float target=.5+.5*tanh(clamp(reflectance*p.b.w,-8.0,8.0));
        float mapped=mix(luminance,target,p.b.z);
        result=luminance>.00001 ? current*mapped/luminance:current;
    }
    result=max(result,0.0);
    float3 premultiplied=mix(current,result,p.a.w)*original.a;
    output.write(half4(float4(min(premultiplied,float3(65504.0)),original.a)),gid);
}

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
            float luminance=luma37(current);
            float3 chroma=mean-float3(luma37(mean));
            float minimumChroma=min(chroma.r,min(chroma.g,chroma.b));
            // Compress chroma toward neutral if needed instead of clipping
            // channels, which would accidentally raise the preserved luminance.
            float saturation=minimumChroma<0 ? min(1.0,luminance/-minimumChroma):1.0;
            result=float3(luminance)+chroma*saturation;
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
