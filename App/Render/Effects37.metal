#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
static float guideValue37(float3 rgb) {
    float light=max(0.0,dot(rgb,float3(.2126,.7152,.0722)));
    return light/(1+light);
}
kernel void fxGuidedMoments37(texture2d<half,access::read> source [[texture(0)]],
                             texture2d<half,access::write> scalar [[texture(1)]],
                             texture2d<half,access::write> cross [[texture(2)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=scalar.get_width() || gid.y>=scalar.get_height()) return;
    float4 original=float4(source.read(gid));
    float3 rgb=original.a>1.e-6 ? original.rgb/original.a:float3(0);
    float guide=guideValue37(rgb);
    scalar.write(half4(float4(guide*guide*original.a,guide*original.a,0,original.a)),gid);
    cross.write(half4(float4(original.rgb*guide,original.a)),gid);
}
kernel void fxGuidedCoefficients37(texture2d<half,access::read> source [[texture(0)]],
                                  texture2d<half,access::write> coefficientA [[texture(1)]],
                                  texture2d<half,access::read> meanRGB [[texture(2)]],
                                  texture2d<half,access::read> meanScalar [[texture(3)]],
                                  texture2d<half,access::read> meanCross [[texture(4)]],
                                  texture2d<half,access::write> coefficientB [[texture(5)]],
                                  constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=coefficientA.get_width() || gid.y>=coefficientA.get_height()) return;
    float alpha=float(source.read(gid).a);
    float4 scalar=float4(meanScalar.read(gid)),mean=float4(meanRGB.read(gid)),cross=float4(meanCross.read(gid));
    float weight=max(scalar.a,1.e-6),guide=scalar.g/weight;
    float3 color=mean.rgb/max(mean.a,1.e-6);
    float variance=max(0.0,scalar.r/weight-guide*guide);
    float3 covariance=cross.rgb/max(cross.a,1.e-6)-guide*color;
    float3 a=clamp(covariance/(variance+p.a.x*p.a.x),float3(-16),float3(16));
    float3 b=color-a*guide;
    coefficientA.write(half4(float4(a*alpha,alpha)),gid);
    coefficientB.write(half4(float4(clamp(b*alpha,float3(-65504),float3(65504)),alpha)),gid);
}
kernel void fxGuidedFinish37(texture2d<half,access::read> source [[texture(0)]],
                            texture2d<half,access::write> output [[texture(1)]],
                            texture2d<half,access::read> coefficientA [[texture(2)]],
                            texture2d<half,access::read> coefficientB [[texture(3)]],
                            constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float4 original=float4(source.read(gid)),a=float4(coefficientA.read(gid)),b=float4(coefficientB.read(gid));
    if(original.a<=0) { output.write(half4(original),gid);return; }
    float3 color=a.rgb/max(a.a,1.e-6)*guideValue37(original.rgb/original.a)+b.rgb/max(b.a,1.e-6);
    color=clamp(color,float3(0),float3(65504))*original.a;
    output.write(half4(float4(mix(original.rgb,color,p.a.y),original.a)),gid);
}
kernel void fxTVPrepare37(texture2d<half,access::read> source [[texture(0)]],
                         texture2d<half,access::write> state [[texture(1)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=state.get_width() || gid.y>=state.get_height()) return;
    float4 original=float4(source.read(gid));
    float light=original.a>1.e-6 ? dot(original.rgb/original.a,float3(.2126,.7152,.0722)):0;
    light=clamp(light,0.0,4096.0);
    state.write(half4(float4(light,light,light,original.a)),gid);
}
kernel void fxTVDual37(texture2d<half,access::read> state [[texture(0)]],
                      texture2d<half,access::write> output [[texture(1)]],
                      texture2d<half,access::read> previous [[texture(2)]],
                      constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float4 center=float4(state.read(gid));
    if(center.a<=0) { output.write(half4(0),gid);return; }
    uint2 last=uint2(state.get_width()-1,state.get_height()-1);
    float4 right=float4(state.read(min(gid+uint2(1,0),last))),bottom=float4(state.read(min(gid+uint2(0,1),last)));
    float2 gradient=float2(right.a>0 ? right.g-center.g:0,bottom.a>0 ? bottom.g-center.g:0);
    float2 dual=float2(previous.read(gid).rg)+.25*gradient;
    dual/=max(1.0,length(dual)/max(p.a.x,.00001));
    output.write(half4(float4(dual,0,1)),gid);
}
kernel void fxTVPrimal37(texture2d<half,access::read> state [[texture(0)]],
                        texture2d<half,access::write> output [[texture(1)]],
                        texture2d<half,access::read> dual [[texture(2)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float4 center=float4(state.read(gid));
    if(center.a<=0) { output.write(half4(0),gid);return; }
    float2 current=float2(dual.read(gid).rg);
    float left=gid.x>0 ? float(dual.read(gid-uint2(1,0)).r):0;
    float top=gid.y>0 ? float(dual.read(gid-uint2(0,1)).g):0;
    float divergence=current.x-left+current.y-top;
    float value=clamp((center.r+.25*(divergence+center.b))/1.25,0.0,4096.0);
    output.write(half4(float4(value,clamp(2*value-center.r,-8192.0,8192.0),center.b,center.a)),gid);
}
kernel void fxTVFinish37(texture2d<half,access::read> source [[texture(0)]],
                        texture2d<half,access::write> output [[texture(1)]],
                        texture2d<half,access::read> state [[texture(2)]],
                        constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float4 original=float4(source.read(gid)),solution=float4(state.read(gid));
    if(original.a<=0) { output.write(half4(original),gid);return; }
    float3 rgb=original.rgb/original.a;
    float light=dot(rgb,float3(.2126,.7152,.0722)),target=max(0.0,light+solution.r-solution.b);
    float3 chroma=rgb-light;
    float minimum=min(chroma.r,min(chroma.g,chroma.b));
    float compression=minimum<0 ? min(1.0,target/max(-minimum,1.e-6)):1.0;
    float3 result=max(float3(0),target+chroma*compression)*original.a;
    output.write(half4(float4(min(mix(original.rgb,result,p.a.w),float3(65504)),original.a)),gid);
}
constexpr sampler nonlinear37(address::clamp_to_edge,filter::linear,coord::pixel);
static float3 nonlinearColor37(texture2d<half,access::sample> image,float2 uv,float3 fallback) {
    float4 pixel=float4(image.sample(nonlinear37,uv));
    return pixel.a>1.e-6 ? pixel.rgb/pixel.a:fallback;
}
kernel void fxNonlinear37(texture2d<half,access::sample> source [[texture(0)]],
                         texture2d<half,access::write> output [[texture(1)]],
                         constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;float4 original=float4(source.sample(nonlinear37,uv));
    if(original.a<=0 || p.a.x<=0) { output.write(half4(original),gid);return; }
    float3 center=original.rgb/original.a;float stepSize=max(.5,p.a.z);
    float3 left=nonlinearColor37(source,uv-float2(stepSize,0),center),right=nonlinearColor37(source,uv+float2(stepSize,0),center);
    float3 top=nonlinearColor37(source,uv-float2(0,stepSize),center),bottom=nonlinearColor37(source,uv+float2(0,stepSize),center);
    float3 lo=min(center,min(min(left,right),min(top,bottom))),hi=max(center,max(max(left,right),max(top,bottom)));
    float3 result=center;
    if(p.i.x==0) {
        float3 delta=0;float3 neighbors[4]={left,right,top,bottom};
        for(int n=0;n<4;n++) {
            float3 difference=neighbors[n]-center;
            float contrast=dot(difference,difference)/(3*max(p.a.y*p.a.y,1.e-6));
            float conduction=p.i.y==0 ? exp(-contrast):1/(1+contrast);
            delta+=difference*conduction;
        }
        result+=delta*(.22*p.a.x);
    } else if(p.i.x==1) {
        float3 weights=float3(.2126,.7152,.0722);
        float c=dot(center,weights),l=dot(left,weights),r=dot(right,weights),t=dot(top,weights),b=dot(bottom,weights);
        float speed=-sign(l+r+t+b-4*c);
        float gx=speed>0 ? max(max(l-c,r-c),0.0):max(max(c-l,c-r),0.0);
        float gy=speed>0 ? max(max(t-c,b-c),0.0):max(max(c-t,c-b),0.0);
        float target=max(0.0,c+speed*length(float2(gx,gy))*.18*p.a.x);
        result=c>1.e-6 ? center*(target/c):float3(target);
    } else {
        float3 weights=float3(.2126,.7152,.0722);
        float gx=dot(right-left,weights)*.5,gy=dot(bottom-top,weights)*.5;
        float3 tl=nonlinearColor37(source,uv+float2(-stepSize,-stepSize),center);
        float3 tr=nonlinearColor37(source,uv+float2(stepSize,-stepSize),center);
        float3 bl=nonlinearColor37(source,uv+float2(-stepSize,stepSize),center);
        float3 br=nonlinearColor37(source,uv+float2(stepSize,stepSize),center);
        float3 hxx=left+right-2*center,hyy=top+bottom-2*center,hxy=(br+tl-tr-bl)*.25;
        float epsilon=1.e-5;
        float3 delta=((gy*gy+epsilon*.5)*hxx-2*gx*gy*hxy+(gx*gx+epsilon*.5)*hyy)/(gx*gx+gy*gy+epsilon);
        result+=delta*(.15*p.a.x);
    }
    result=clamp(result,lo,hi);
    output.write(half4(float4(min(result*original.a,float3(65504)),original.a)),gid);
}

static float cosineBasis37(uint frequency,uint position) {
    return (frequency==0 ? .35355339059:.5)*cos((2*float(position)+1)*float(frequency)*.196349540849);
}
kernel void fxDCTBlocks37(texture2d<half,access::read> source [[texture(0)]],
                         texture2d<half,access::write> output [[texture(1)]],
                         constant EffectParams& p [[buffer(0)]],
                         uint lane [[thread_index_in_threadgroup]],uint3 group [[threadgroup_position_in_grid]]) {
    threadgroup float3 work[64];threadgroup float3 coefficients[64];threadgroup half4 pixels[64];
    uint x=lane%8,y=lane/8;uint2 pixel=group.xy*8+uint2(x,y);
    uint2 safe=min(pixel,uint2(source.get_width()-1,source.get_height()-1));
    half4 original=source.read(safe);pixels[lane]=original;
    float3 rgb=original.a>half(.00001) ? float3(original.rgb)/float(original.a):float3(0);
    float light=dot(rgb,float3(.299,.587,.114));
    coefficients[lane]=float3(light-.5,(rgb.b-light)*.492,(rgb.r-light)*.877);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    float3 row=0;
    for(uint n=0;n<8;n++) row+=coefficients[y*8+n]*cosineBasis37(x,n);
    work[lane]=row;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    float3 coefficient=0;
    for(uint n=0;n<8;n++) coefficient+=work[n*8+x]*cosineBasis37(y,n);
    float frequency=sqrt(float(x*x+y*y));
    float stepSize=p.a.x*(1+pow(max(1.0,frequency),p.a.y))*.0625;
    float3 step=max(float3(stepSize,stepSize*p.a.z,stepSize*p.a.z),float3(1.e-7));
    if(!(p.i.y!=0 && lane==0)) {
        if(p.i.x==0) coefficient=round(coefficient/step)*step;
        else coefficient=sign(coefficient)*max(abs(coefficient)-step,float3(0));
    }
    coefficients[lane]=coefficient;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    float3 column=0;
    for(uint n=0;n<8;n++) column+=coefficients[n*8+x]*cosineBasis37(n,y);
    work[lane]=column;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    float3 reconstructed=0;
    for(uint n=0;n<8;n++) reconstructed+=work[y*8+n]*cosineBasis37(n,x);
    float lum=reconstructed.x+.5;
    float red=lum+reconstructed.z/.877,blue=lum+reconstructed.y/.492;
    float green=(lum-.299*red-.114*blue)/.587;
    float alpha=float(pixels[lane].a);
    float3 color=max(float3(0),float3(red,green,blue))*alpha;
    if(pixel.x<output.get_width() && pixel.y<output.get_height()) {
        output.write(half4(float4(min(mix(float3(pixels[lane].rgb),color,p.a.w),float3(65504)),alpha)),pixel);
    }
}

kernel void fxDoGInk37(texture2d<half,access::read> source [[texture(0)]],
                      texture2d<half,access::write> output [[texture(1)]],
                      texture2d<half,access::read> near [[texture(2)]],
                      texture2d<half,access::read> far [[texture(3)]],
                      constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float4 original=float4(source.read(gid)),a=float4(near.read(gid)),b=float4(far.read(gid));
    float3 first=a.a>1.e-6 ? a.rgb/a.a:float3(0),second=b.a>1.e-6 ? b.rgb/b.a:float3(0);
    float difference=dot(first-p.a.x*second,float3(.2126,.7152,.0722));
    float paper=difference>=p.a.y ? 1.0:1+tanh(p.a.z*(difference-p.a.y));
    float ink=1-clamp(paper,0.0,1.0);
    float3 color=p.b.rgb*p.b.a*ink+p.c.rgb*p.c.a*(1-ink);
    float alpha=(p.b.a*ink+p.c.a*(1-ink))*original.a;
    float4 result=float4(color*original.a,alpha);
    output.write(half4(mix(original,result,p.a.w)),gid);
}

// Separable rectangular morphology. Scratch textures contain scalar fields;
// only the first pass reads unpremultiplied image luminance. Boundary replication
// prevents dark padding from eroding a flat image at its buffer boundary.
kernel void fxExtrema37(texture2d<half,access::read> source [[texture(0)]],
                       texture2d<half,access::write> output [[texture(1)]],
                       constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float result=p.i.z!=0 ? -INFINITY:INFINITY;
    int2 size=int2(source.get_width(),source.get_height());
    int radius=int(clamp(p.i.x,1u,48u));
    for(int offset=-radius;offset<=radius;offset++) {
        int2 point=int2(gid)+(p.i.y==0 ? int2(offset,0):int2(0,offset));
        half4 value=source.read(uint2(clamp(point,int2(0),size-1)));
        float scalar=float(value.r);
        if(p.i.w!=0) scalar=value.a>half(.00001) ? dot(float3(value.rgb)/float(value.a),float3(.2126,.7152,.0722)):0.0;
        result=p.i.z!=0 ? max(result,scalar):min(result,scalar);
    }
    output.write(half4(half3(result),half(1)),gid);
}

kernel void fxMorphology37(texture2d<half,access::read> source [[texture(0)]],
                          texture2d<half,access::write> output [[texture(1)]],
                          texture2d<half,access::read> envelope [[texture(2)]],
                          texture2d<half,access::read> other [[texture(3)]],
                          constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    half4 original=source.read(gid);
    if(original.a<=half(0) || p.a.y<=0) { output.write(original,gid); return; }
    float3 rgb=float3(original.rgb)/float(original.a);
    float light=dot(rgb,float3(.2126,.7152,.0722));
    float a=float(envelope.read(gid).r),b=float(other.read(gid).r),target=a;
    if(p.i.x==2) target=max(0.0,light-a)*p.a.x;
    if(p.i.x==3) target=max(0.0,a-light)*p.a.x;
    if(p.i.x==4) target=max(0.0,b-a)*p.a.x;
    if(p.i.x==5) target=(a+b)*.5;
    float3 color=float3(target);
    if(p.i.x<2 || p.i.x==5) {
        // Preserve source chroma where possible, shrinking only enough to avoid
        // negative channels when the envelope reduces luminance.
        float3 chroma=rgb-light;
        float minimum=min(chroma.r,min(chroma.g,chroma.b));
        float chromaScale=minimum<0 ? min(1.0,target/max(-minimum,1.e-6)):1.0;
        color=max(float3(0),target+chroma*chromaScale);
    }
    output.write(half4(float4(mix(float3(original.rgb),color*float(original.a),p.a.y),float(original.a))),gid);
}
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
    float4 original=float4(source.read(gid));
    if(original.a<=.00001) { output.write(half4(0),gid);return; }
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
