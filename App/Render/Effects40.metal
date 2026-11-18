#include <metal_stdlib>
using namespace metal;
struct SurfaceParams40 { float4 a,b,c,d,e,f,g;uint4 i; };
constexpr sampler surfaceSample40(address::clamp_to_zero,filter::linear,coord::normalized);
static float hashSurface40(float2 point) {
    float3 q=fract(float3(point.xyx)*.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);
}
static float noiseSurface40(float2 point) {
    float2 cell=floor(point),f=fract(point);f=f*f*(3-2*f);
    return mix(mix(hashSurface40(cell),hashSurface40(cell+float2(1,0)),f.x),mix(hashSurface40(cell+float2(0,1)),hashSurface40(cell+1),f.x),f.y);
}
static float2 rotateSurface40(float2 point,float angle) {
    return float2(point.x*cos(angle)-point.y*sin(angle),point.x*sin(angle)+point.y*cos(angle));
}
static float3 viewSurface40(float3 point,constant SurfaceParams40& p) {
    point.xz=rotateSurface40(point.xz,p.d.x);point.yz=rotateSurface40(point.yz,p.d.y);point.xy=rotateSurface40(point.xy,p.d.z);
    return point;
}
static float3 positionSurface40(float2 uv,int2 cell,uint orientation,constant SurfaceParams40& p,texture2d<half> height) {
    float2 frameUV=uv;
    uv=(uv-.5)*p.g.xy/max(p.b.xy,float2(1))+.5;
    float2 q=(uv-.5)*p.b.xy;float side=max(1.0,min(p.b.x,p.b.y));
    float amplitude=p.a.x,frequency=p.a.y,shape=p.a.z,phase=p.d.w;
    float3 point=float3(q,0);
    switch(p.i.x) {
        case 0: case 11: {
            if(abs(amplitude)<.00001) break;
            float radius=p.b.x/amplitude,theta=amplitude*(uv.x-.5);
            point.x=radius*sin(theta);point.z=radius*(1-cos(theta));
            if(p.i.x==11) point.z*=sign(uv.x-.5);
            break;
        }
        case 1: point.xz=rotateSurface40(point.xz,amplitude*(uv.y-.5));break;
        case 2: {
            float2 local=q/side;float aspect=max(shape,.1),width=max(frequency,.1);
            point.z=amplitude*exp(-(local.x*local.x/aspect+local.y*local.y*aspect)/(width*width)*4);break;
        }
        case 3: point.z=amplitude*(uv.x-.5)*(uv.y-.5)*4;break;
        case 4: {
            if(abs(amplitude)<.00001) break;
            float radius=p.b.x/amplitude*(1+frequency*(uv.y-.5)*1.5),theta=amplitude*(uv.x-.5);
            point.x=radius*sin(theta);point.z=radius*(1-cos(theta));break;
        }
        case 5: {
            if(abs(amplitude)<.00001) break;
            float base=p.b.x/amplitude,radius=base*(1+frequency*(uv.x-.5)),theta=amplitude*(uv.x-.5);
            point.x=radius*sin(theta);point.z=base-radius*cos(theta);break;
        }
        case 6: {
            float folds=max(1.0,round(frequency)),triangle=abs(fract(uv.x*folds)-.5)-.25;
            point.x*=cos(amplitude);point.z=triangle*2*sin(amplitude)*p.b.x/folds;break;
        }
        case 7: {
            float radius=length(q)/side;
            point.z=amplitude*sin(radius*frequency*6.2831853-phase)*exp(-shape*radius);break;
        }
        case 8: point.z=amplitude*uv.x*sin(uv.x*frequency*6.2831853-phase)*cos(uv.y*3.14159265+shape*phase);break;
        case 9: {
            float curve=max(frequency,.1);
            point.z=amplitude*(cosh(clamp((uv.x-.5)*curve,-4.0,4.0))-1)/max(cosh(min(curve*.5,4.0))-1,.0001);break;
        }
        case 10: {
            float radius=side*.35*frequency,cross=q.y*shape,theta=(uv.x-.5)*6.2831853,twist=(uv.x-.5)*amplitude;
            point=float3((radius+cross*cos(twist))*sin(theta),cross*sin(twist),(radius+cross*cos(twist))*cos(theta)-radius);break;
        }
        case 12: {
            float count=max(1.0,round(frequency)),angle=amplitude*(1+shape*sin(float(cell.x)*.8+float(cell.y)*1.3));
            float left=(float(cell.x)/count-.5)*p.g.x,local=(frameUV.x-float(cell.x)/count)*p.g.x;
            point.x=left+local*cos(angle);point.z=local*sin(angle);break;
        }
        case 13: {
            float2 local=q/side*frequency+p.e.w;
            float broad=noiseSurface40(local+float2(phase*.3,-phase*.2))-.5;
            float fine=noiseSurface40(local*2.7-float2(phase*.2,phase*.3))-.5;
            point.z=amplitude*(broad*2+shape*fine*.7);break;
        }
        case 14: {
            float count=max(2.0,round(frequency));
            point.z=orientation==0 ? amplitude*cos(3.14159265*(frameUV.x*count-.5+floor(frameUV.y*count))):
                -amplitude*cos(3.14159265*(frameUV.y*count-.5+floor(frameUV.x*count)));break;
        }
        case 15: {
            float2 first=normalize(float2(1,.3)),second=normalize(float2(-.4,1));
            float t=dot(q/side,first)*frequency*6.2831853-phase,s=dot(q/side,second)*frequency*10.681415+phase*.8;
            point.xy+=amplitude*shape*(first*cos(t)+second*cos(s)*.5);
            point.z=amplitude*(sin(t)+sin(s)*.5);break;
        }
        case 16: {
            float radius=side*.45*(shape+(1-shape)*frameUV.y),theta=frameUV.x*6.2831853;
            point=float3(radius*sin(theta),radius*cos(theta),amplitude*((float(cell.x)+.5)/float(p.i.y)*2-1)*.8);break;
        }
        case 17: point.z=amplitude*(hashSurface40(round(uv*frequency)+p.e.w)*2-1);break;
        case 18: {
            float corners=mix(mix(p.f.x,p.f.y,uv.x),mix(p.f.z,p.f.w,uv.x),uv.y);
            point.z=amplitude*(corners-frequency*16*uv.x*(1-uv.x)*uv.y*(1-uv.y));break;
        }
        case 19: {
            float2 local=fract(uv*max(1.0,round(frequency)))*2-1;
            point.z=amplitude*pow(max(0.0,1-dot(local,local)),max(.2,shape));break;
        }
        case 20: {
            float2 texcoord=(p.b.zw*.5+(uv-.5)*p.b.xy)/p.b.zw;
            float4 pixel=float4(height.sample(surfaceSample40,texcoord));
            float light=pixel.a>1.e-6 ? dot(pixel.rgb/pixel.a,float3(.2126,.7152,.0722)):0;
            point.z=amplitude*(pow(clamp(light,0.0,1.0),max(.2,shape))-.5);break;
        }
    }
    return point;
}
struct SurfaceVertex40 {
    float4 position [[position]];
    float2 texcoord,domain;float3 normal;
    float3 flatNormal [[flat]];uint orientation [[flat]];
};
vertex SurfaceVertex40 surfaceVertex40(uint vertexID [[vertex_id]],uint instanceID [[instance_id]],
                                      constant SurfaceParams40& p [[buffer(0)]],texture2d<half> height [[texture(0)]]) {
    const uint2 corners[6]={uint2(0,0),uint2(1,0),uint2(0,1),uint2(1,0),uint2(1,1),uint2(0,1)};
    uint index=vertexID/6;int2 cell=int2(index%p.i.y,index/p.i.y);float2 grid=float2(p.i.y,p.i.z);
    float2 uv=(float2(cell)+float2(corners[vertexID%6]))/grid;
    float3 point=positionSurface40(uv,cell,instanceID,p,height);
    float epsilon=.0005;
    float3 du=positionSurface40(uv+float2(epsilon,0),cell,instanceID,p,height)-positionSurface40(uv-float2(epsilon,0),cell,instanceID,p,height);
    float3 dv=positionSurface40(uv+float2(0,epsilon),cell,instanceID,p,height)-positionSurface40(uv-float2(0,epsilon),cell,instanceID,p,height);
    float3 normal=-cross(du,dv);
    float2 a=(float2(cell)+float2(corners[(vertexID%6)/3*3]))/grid;
    float2 b=(float2(cell)+float2(corners[(vertexID%6)/3*3+1]))/grid;
    float2 c=(float2(cell)+float2(corners[(vertexID%6)/3*3+2]))/grid;
    float3 pa=positionSurface40(a,cell,instanceID,p,height),pb=positionSurface40(b,cell,instanceID,p,height),pc=positionSurface40(c,cell,instanceID,p,height);
    float3 face=-cross(pb-pa,pc-pa);
    point=viewSurface40(point,p);normal=viewSurface40(normal,p);face=viewSurface40(face,p);
    float distance=max(1.0,p.c.z),z=distance+point.z,w=z/distance;
    float2 anchor=float2(p.c.x/p.b.z*2-1,1-p.c.y/p.b.w*2);
    SurfaceVertex40 output;
    output.position=float4(point.x/p.b.z*2+anchor.x*w,-point.y/p.b.w*2+anchor.y*w,4.0/3.95*(z-distance*.05)/distance,w);
    output.texcoord=(p.b.zw*.5+(uv-.5)*p.g.xy)/p.b.zw;output.domain=uv;
    output.normal=normal;output.flatNormal=face;output.orientation=instanceID;
    return output;
}
fragment half4 surfaceFragment40(SurfaceVertex40 input [[stage_in]],constant SurfaceParams40& p [[buffer(0)]],
                                 texture2d<half> source [[texture(0)]]) {
    float4 color=float4(source.sample(surfaceSample40,input.texcoord));
    if(p.i.x==14) {
        float2 local=fract(input.domain*max(2.0,round(p.a.y)))-.5;
        float coordinate=input.orientation==0 ? local.y:local.x;
        float aa=max(.0001,length(fwidth(input.domain))*max(2.0,round(p.a.y)));
        color*=1-smoothstep(p.a.z*.5-aa,p.a.z*.5+aa,abs(coordinate));
    }
    if(color.a<.0001) discard_fragment();
    float3 n=p.i.x==17 ? input.flatNormal:input.normal;
    n=dot(n,n)>1.e-12 ? normalize(n):float3(0,0,-1);if(n.z>0) n=-n;
    float3 light=float3(cos(p.e.x)*cos(p.e.y),sin(p.e.x)*cos(p.e.y),-sin(p.e.y));
    float shade=mix(1.0,.35+.85*max(0.0,dot(n,light)),p.e.z);
    return half4(float4(min(color.rgb*shade,float3(65504)),color.a));
}
