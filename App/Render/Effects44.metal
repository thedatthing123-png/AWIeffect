#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a,b,c,d;uint4 i; };
constexpr sampler finishSample44(address::clamp_to_edge,filter::linear,coord::pixel);
static float hashFinish44(float2 q) { float3 v=fract(float3(q.xyx)*.1031);v+=dot(v,v.yzx+33.33);return fract((v.x+v.y)*v.z); }
static float noiseFinish44(float2 q) {
    float2 cell=floor(q),f=fract(q);f=f*f*(3-2*f);
    return mix(mix(hashFinish44(cell),hashFinish44(cell+float2(1,0)),f.x),mix(hashFinish44(cell+float2(0,1)),hashFinish44(cell+1),f.x),f.y);
}
struct FinishCells44 { float2 distance;float2 nearestDelta;float2 secondDelta; };
static FinishCells44 cellGeometry44(float2 q) {
    float2 cell=floor(q);float nearest=1.e10,second=1.e10;float2 nearestDelta=float2(0),secondDelta=float2(0);
    for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
        float2 index=cell+float2(x,y),jitter=float2(hashFinish44(index),hashFinish44(index+37.1));
        float2 delta=index+.1+.8*jitter-q;float distance=dot(delta,delta);
        if(distance<nearest) { second=nearest;secondDelta=nearestDelta;nearest=distance;nearestDelta=delta; }
        else if(distance<second) { second=distance;secondDelta=delta; }
    }
    return {sqrt(float2(nearest,second)),nearestDelta,secondDelta};
}
static float2 cellsFinish44(float2 q) { return cellGeometry44(q).distance; }
static float3 straightFinish44(float4 value) { return value.a>1.e-6 ? value.rgb/value.a:float3(0); }
static float imageHeight44(texture2d<half> soft,float2 point) {
    float4 value=float4(soft.sample(finishSample44,point));return dot(straightFinish44(value),float3(.2126,.7152,.0722));
}
static float2 localFinish44(float2 point,constant EffectParams& p) {
    float c=cos(p.b.x),s=sin(p.b.x);return float2(c*point.x+s*point.y,-s*point.x+c*point.y)/p.a.x+float2(.15,.21)*p.d.x;
}
static float surfaceHeight44(texture2d<half> soft,float2 point,constant EffectParams& p) {
    if(p.a.y==0 && p.a.z==0) return 0;
    float2 q=localFinish44(point,p);float profile=0,source=(p.a.z>0 || p.i.x==4) ? imageHeight44(soft,point):0;
    switch(p.i.x) {
        case 0: {
            float wander=noiseFinish44(float2(q.x*.07,q.y*.18))*p.c.w;
            profile=.3*sin(6.2831853*(q.y+wander))+.12*sin(18.849556*(q.y+wander*.7));break;
        }
        case 1: {
            float nearest=cellsFinish44(q).x,pit=max(0.0,1-nearest*nearest);
            profile=-pow(pit,max(.3,p.c.w));break;
        }
        case 2: {
            float first=.5+.5*cos(q.x*6.2831853),second=.5+.5*cos(q.y*6.2831853);
            float over=.5+.45*sin(q.x*3.14159265)*sin(q.y*3.14159265);
            profile=mix(pow(first,p.c.w),pow(second,p.c.w),over);break;
        }
        case 3: { float2 d=cellsFinish44(q);profile=-exp(-(d.y-d.x)/max(.01,p.c.w));break; }
        case 4: profile=pow(clamp(1-source,0.0,1.0),p.c.w)+.08*noiseFinish44(q*2);break;
        case 5: { float x=fract(q.y);profile=x<p.c.w ? x/p.c.w:(1-x)/(1-p.c.w);break; }
        case 6: {
            float broad=abs(noiseFinish44(q)-.5)*2,fine=abs(noiseFinish44(q*2.8+11)-.5)*2;
            profile=pow(max(.0001,broad),p.c.w)+.3*pow(max(.0001,fine),p.c.w);break;
        }
        case 7: profile=.5*sin(6.2831853*(q.y+.3*p.c.w*sin(q.x*2)))+.15*sin(q.x*6.2831853);break;
    }
    // Reduce unresolved micro-relief rather than letting subpixel grooves flash.
    float resolved=1-smoothstep(.2,.65,p.d.w/p.a.x);
    return source*p.a.z+profile*p.a.y*resolved;
}
static float maskingFinish44(float3 w,float3 normal,float3 tangent,float3 bitangent,float ax,float ay) {
    float nz=max(.0001,dot(normal,w)),tx=dot(tangent,w)*ax,ty=dot(bitangent,w)*ay;
    return 2/(1+sqrt(1+(tx*tx+ty*ty)/(nz*nz)));
}
kernel void fxSurfaceFinish44(texture2d<half> source [[texture(0)]],texture2d<half,access::write> output [[texture(1)]],
                              texture2d<half> soft [[texture(2)]],constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width()||gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;float4 original=float4(source.read(gid));
    if(original.a<=1.e-6) { output.write(half4(original),gid);return; }
    float step=max(.5,p.d.w);
    float dx,dy,cellGap=0;
    if(p.i.x==1 || p.i.x==3) {
        // One cellular search supplies both analytic normal derivatives and crack
        // coverage. Avoid four repeated 3x3 cell searches per output pixel.
        FinishCells44 cell=cellGeometry44(localFinish44(uv,p));cellGap=cell.distance.y-cell.distance.x;
        float2 gradient=float2(0);
        if(p.i.x==1) {
            float pit=max(0.0,1-cell.distance.x*cell.distance.x);
            if(pit>0) gradient=-2*p.c.w*pow(max(.0001,pit),p.c.w-1)*cell.nearestDelta;
        } else {
            float width=max(.01,p.c.w);
            float2 gapGradient=cell.nearestDelta/max(.0001,cell.distance.x)-cell.secondDelta/max(.0001,cell.distance.y);
            gradient=exp(-cellGap/width)/width*gapGradient;
        }
        float c=cos(p.b.x),s=sin(p.b.x),resolved=1-smoothstep(.2,.65,p.d.w/p.a.x);
        float2 slope=float2(c*gradient.x-s*gradient.y,s*gradient.x+c*gradient.y)*(p.a.y*resolved/p.a.x);
        if(p.a.z>0) {
            slope.x+=(imageHeight44(soft,uv+float2(step,0))-imageHeight44(soft,uv-float2(step,0)))*p.a.z/(2*step);
            slope.y+=(imageHeight44(soft,uv+float2(0,step))-imageHeight44(soft,uv-float2(0,step)))*p.a.z/(2*step);
        }
        dx=slope.x;dy=slope.y;
    } else {
        dx=(surfaceHeight44(soft,uv+float2(step,0),p)-surfaceHeight44(soft,uv-float2(step,0),p))/(2*step);
        dy=(surfaceHeight44(soft,uv+float2(0,step),p)-surfaceHeight44(soft,uv-float2(0,step),p))/(2*step);
    }
    float3 normal=normalize(float3(-dx,-dy,1)),view=float3(0,0,1);
    float3 light=float3(cos(p.b.y)*cos(p.b.z),sin(p.b.y)*cos(p.b.z),sin(p.b.z)),halfway=normalize(view+light);
    float3 axis=float3(cos(p.b.x),sin(p.b.x),0),tangent=axis-normal*dot(normal,axis);
    tangent=dot(tangent,tangent)>1.e-8 ? normalize(tangent):normalize(cross(float3(0,1,0),normal));
    float3 bitangent=cross(normal,tangent);
    float rough=max(.0064,p.b.w*p.b.w),ax=max(.003,rough*(p.i.x==0 ? .18:p.i.x==2 ? .5:1.0)),ay=max(.003,rough*(p.i.x==0 ? 1.8:p.i.x==2 ? 1.6:1.0));
    float nh=max(.0001,dot(normal,halfway)),nv=max(.0001,normal.z),nl=max(0.0,dot(normal,light));
    float ht=dot(halfway,tangent)/ax,hb=dot(halfway,bitangent)/ay,denominator=ht*ht+hb*hb+nh*nh;
    float distribution=1/(3.14159265*ax*ay*denominator*denominator);
    float masking=maskingFinish44(view,normal,tangent,bitangent,ax,ay)*maskingFinish44(light,normal,tangent,bitangent,ax,ay);
    float3 color=max(float3(0),straightFinish44(original));
    if(p.i.x==5 && p.d.z>0) {
        float2 displacement=normal.xy*p.d.z;
        float4 red=float4(source.sample(finishSample44,uv+displacement)),blue=float4(source.sample(finishSample44,uv-displacement));
        color.r=red.a>1.e-6 ? red.r/red.a:color.r;color.b=blue.a>1.e-6 ? blue.b/blue.a:color.b;
    }
    float3 albedo=pow(color,float3(2.2));
    if(p.i.x==3) albedo*=1-clamp(p.d.y*.01,0.0,1.0)*exp(-cellGap/max(.01,p.c.w));
    float3 f0=mix(float3(.04),clamp(albedo,float3(0),float3(1)),p.c.x);
    if(p.i.x==7) {
        // Three-wavelength coating approximation, not a full spectral film solver.
        float opticalPath=4*3.14159265*1.45*p.d.y*max(.1,nh);
        float3 coating=.04+.25*(.5+.5*cos(opticalPath/float3(650,510,475)));
        f0=mix(f0,coating,.7);
    }
    float vh=max(0.0,dot(view,halfway));float3 fresnel=f0+(1-f0)*pow(1-vh,5.0);
    float3 specular=fresnel*distribution*masking/max(.0001,4*nv*max(.0001,nl))*nl;
    float3 diffuse=albedo*(1-p.c.x)*nl/3.14159265;
    float3 energy=albedo*p.c.z+(diffuse+specular)*p.c.y;
    float3 result=pow(clamp(energy,float3(0),float3(65504)),float3(1.0/2.2))*original.a;
    output.write(half4(mix(original,float4(result,original.a),p.a.w)),gid);
}
