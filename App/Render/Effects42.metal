#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a,b,c,d;uint4 i; };
constexpr sampler projectionSample42(address::clamp_to_zero,filter::linear,coord::pixel);
static float2 nonzeroSign42(float2 v) { return select(float2(-1),float2(1),v>=0); }
static float3 sphereRay42(float2 uv) {
    float longitude=(uv.x-.5)*6.283185307,latitude=(.5-uv.y)*3.141592654;
    return float3(sin(longitude)*cos(latitude),sin(latitude),cos(longitude)*cos(latitude));
}
static float2 sphereUV42(float3 ray) { return float2(atan2(ray.x,ray.z)/6.283185307+.5,.5-asin(clamp(ray.y,-1.0,1.0))/3.141592654); }
static float3 rotateRay42(float3 ray,float3 angles) {
    float c=cos(angles.z),s=sin(angles.z);ray.xy=float2(c*ray.x-s*ray.y,s*ray.x+c*ray.y);
    c=cos(angles.y);s=sin(angles.y);ray.yz=float2(c*ray.y-s*ray.z,s*ray.y+c*ray.z);
    c=cos(angles.x);s=sin(angles.x);ray.xz=float2(c*ray.x+s*ray.z,-s*ray.x+c*ray.z);return ray;
}
static float3 cubeRay42(float2 uv) {
    uint2 tile=min(uint2(2,1),uint2(floor(uv*float2(3,2))));float2 q=fract(uv*float2(3,2))*2-1;
    uint face=tile.y*3+tile.x;float3 ray;
    switch(face) {
        case 0:ray=float3(1,-q.y,-q.x);break;case 1:ray=float3(-1,-q.y,q.x);break;
        case 2:ray=float3(q.x,1,q.y);break;case 3:ray=float3(q.x,-1,-q.y);break;
        case 4:ray=float3(q.x,-q.y,1);break;default:ray=float3(-q.x,-q.y,-1);break;
    }
    return normalize(ray);
}
static float2 cubeUV42(float3 ray) {
    float3 a=abs(ray);uint face;float2 q;
    if(a.x>=a.y && a.x>=a.z) { face=ray.x>=0 ? 0:1;q=float2(ray.x>=0 ? -ray.z:ray.z,-ray.y)/max(a.x,1.e-8); }
    else if(a.y>=a.z) { face=ray.y>=0 ? 2:3;q=float2(ray.x,ray.y>=0 ? ray.z:-ray.z)/max(a.y,1.e-8); }
    else { face=ray.z>=0 ? 4:5;q=float2(ray.z>=0 ? ray.x:-ray.x,-ray.y)/max(a.z,1.e-8); }
    return (float2(face%3,face/3)+(q*.5+.5))/float2(3,2);
}
static float3 octaRay42(float2 uv) {
    float2 q=float2(uv.x*2-1,1-uv.y*2);float3 ray=float3(q,1-abs(q.x)-abs(q.y));
    if(ray.z<0) ray.xy=(1-abs(ray.yx))*nonzeroSign42(ray.xy);
    return normalize(ray);
}
static float2 octaUV42(float3 ray) {
    ray/=max(1.e-8,abs(ray.x)+abs(ray.y)+abs(ray.z));
    float2 q=ray.z<0 ? (1-abs(ray.yx))*nonzeroSign42(ray.xy):ray.xy;
    return float2(q.x*.5+.5,.5-q.y*.5);
}
static float3 dualRay42(float2 uv,thread bool& valid) {
    bool rear=uv.x>=.5;float2 q=float2(fract(uv.x*2)*2-1,1-uv.y*2);float radius=length(q);
    if(radius>1) { valid=false;return float3(0,0,1); }
    float angle=radius*1.570796327;float2 axis=radius>1.e-8 ? q/radius:float2(0);
    return float3(axis.x*sin(angle)*(rear ? -1.0:1.0),axis.y*sin(angle),cos(angle)*(rear ? -1.0:1.0));
}
static float2 dualUV42(float3 ray) {
    bool rear=ray.z<0;float angle=acos(clamp(abs(ray.z),0.0,1.0)),radius=angle/1.570796327;
    float2 xy=float2(ray.x*(rear ? -1.0:1.0),ray.y);float norm=length(xy);
    float2 q=norm>1.e-8 ? xy/norm*radius:float2(0);
    return float2((q.x*.5+.5+(rear ? 1.0:0.0))*.5,.5-q.y*.5);
}
static float4 panoramaRead42(texture2d<half> source,float2 uv,float2 extent,uint layout) {
    float2 buffer=float2(source.get_width(),source.get_height()),origin=(buffer-extent)*.5;
    if(layout==0) {
        // Explicit horizontal wrap blends across the ERP seam without wrapping latitude.
        float x=fract(uv.x)*extent.x-.5;float left=floor(x),fraction=fract(x);
        float2 a=float2(origin.x+fmod(left+extent.x,extent.x)+.5,origin.y+clamp(uv.y*extent.y,.5,extent.y-.5));
        float2 b=a;b.x=origin.x+fmod(left+1+extent.x,extent.x)+.5;
        return mix(float4(source.sample(projectionSample42,a)),float4(source.sample(projectionSample42,b)),fraction);
    }
    // Keep bilinear footprints inside each cube face or fisheye tile.
    float2 tiles=layout==1 ? float2(3,2):layout==3 ? float2(2,1):float2(1);
    float2 tile=floor(clamp(uv,float2(0),float2(.999999))*tiles),lo=tile/tiles*extent+.5,hi=(tile+1)/tiles*extent-.5;
    return float4(source.sample(projectionSample42,origin+clamp(uv*extent,lo,hi)));
}
static float4 projection42(texture2d<half> source,float2 point,constant EffectParams& p) {
    float2 buffer=float2(source.get_width(),source.get_height()),uv=(point-(buffer-p.a.xy)*.5)/p.a.xy;
    if(any(uv<0)||any(uv>1)) return float4(0);
    float2 q=float2(uv.x*2-1,1-uv.y*2);float aspect=p.a.x/max(1.0,p.a.y);bool valid=true;float3 ray;
    if(p.i.x==0) ray=normalize(float3(q.x*tan(p.a.z*.5),q.y*tan(p.a.z*.5)/aspect,1));
    else if(p.i.x==2) ray=cubeRay42(uv);
    else if(p.i.x==4) ray=octaRay42(uv);
    else if(p.i.x==6) ray=dualRay42(uv,valid);
    else if(p.i.x>=8) {
        float longitude,latitude,x=q.x*p.a.z*.5,y=q.y*p.a.z*.5/aspect;
        if(p.i.x==9) { float scale=2*tan(p.a.z*.25);x=q.x*scale;y=q.y*scale/aspect;longitude=2*atan(x*.5);latitude=atan(y*(1+cos(longitude))*.5); }
        else { longitude=x;if(p.i.x==8) latitude=atan(y);else if(p.i.x==10) latitude=2*atan(exp(clamp(y,-10.0,10.0)))-1.570796327;
            else { valid=abs(y)<=1;latitude=asin(clamp(y,-1.0,1.0)); } }
        ray=float3(sin(longitude)*cos(latitude),sin(latitude),cos(longitude)*cos(latitude));
    } else ray=sphereRay42(uv);
    if(!valid) return float4(0);
    ray=rotateRay42(ray,p.b.xyz);uint layout=0;float2 inputUV;
    if(p.i.x==3) { inputUV=cubeUV42(ray);layout=1; }
    else if(p.i.x==5) { inputUV=octaUV42(ray);layout=2; }
    else if(p.i.x==7) { inputUV=dualUV42(ray);layout=3; }
    else inputUV=sphereUV42(ray);
    return panoramaRead42(source,inputUV,p.a.xy,layout);
}
kernel void fxProjection42(texture2d<half> source [[texture(0)]],texture2d<half,access::write> output [[texture(1)]],
                           constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width()||gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5;float4 color;
    if(p.i.y==0) color=projection42(source,uv,p);
    else {
        color=float4(0);for(uint y=0;y<2;y++) for(uint x=0;x<2;x++) color+=projection42(source,uv+float2(float(x)*.5-.25,float(y)*.5-.25),p)*.25;
    }
    float4 original=float4(source.sample(projectionSample42,uv));output.write(half4(mix(original,color,p.a.w)),gid);
}
