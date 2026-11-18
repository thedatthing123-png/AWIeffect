#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler data39(address::clamp_to_edge,filter::linear,coord::pixel);
static float4 straightData39(texture2d<half,access::sample> image,float2 uv) {
    float4 value=float4(image.sample(data39,uv));
    return float4(value.a>1.e-6 ? value.rgb/value.a:float3(0),value.a);
}
static float2 vectorData39(texture2d<half,access::sample> image,float2 uv) {
    float4 value=straightData39(image,uv);return value.a>0 ? value.rg*2-1:float2(0);
}
static float3 unitData39(float3 value) { return dot(value,value)>1.e-10 ? normalize(value):float3(0,0,1); }
static float2 directionData39(float2 value) { return dot(value,value)>1.e-10 ? normalize(value):float2(0); }
static float3 normalData39(texture2d<half,access::sample> image,float2 uv) {
    float4 value=straightData39(image,uv);return value.a>0 ? unitData39(value.rgb*2-1):float3(0,0,1);
}
static float scalarData39(texture2d<half,access::sample> image,float2 uv,uint channel) {
    float4 value=straightData39(image,uv);return channel==1 ? value.a:dot(value.rgb,float3(.2126,.7152,.0722));
}
static float2 rotateData39(float2 v,float angle) { return float2(v.x*cos(angle)-v.y*sin(angle),v.x*sin(angle)+v.y*cos(angle)); }
static float noiseData39(float2 point) {
    float3 q=fract(float3(point.xyx)*.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);
}
kernel void fxData39(texture2d<half,access::sample> source [[texture(0)]],
                     texture2d<half,access::write> output [[texture(1)]],
                     texture2d<half,access::sample> reference [[texture(2)]],
                     constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 uv=float2(gid)+.5,size=float2(output.get_width(),output.get_height());
    float4 original=float4(source.sample(data39,uv)),straight=straightData39(source,uv);
    if(original.a<=0 || p.a.w<=0) { output.write(half4(original),gid);return; }
    float2 vector=straight.rg*2-1;float3 normal=unitData39(straight.rgb*2-1),color=straight.rgb;
    float alpha=original.a,spacing=max(p.a.x,.5),gain=p.a.y;
    if(p.i.x<=4 || p.i.x==14 || p.i.x==15) {
        float2 left=vectorData39(source,uv-float2(spacing,0)),right=vectorData39(source,uv+float2(spacing,0));
        float2 top=vectorData39(source,uv-float2(0,spacing)),bottom=vectorData39(source,uv+float2(0,spacing));
        float2 dx=(right-left)/(2*spacing),dy=(bottom-top)/(2*spacing);
        float response=0;
        if(p.i.x==0) {
            float gx=(scalarData39(source,uv+float2(spacing,0),0)-scalarData39(source,uv-float2(spacing,0),0))/(2*spacing);
            float gy=(scalarData39(source,uv+float2(0,spacing),0)-scalarData39(source,uv-float2(0,spacing),0))/(2*spacing);
            color=float3(float2(gx,gy)*gain*.5+.5,.5);
        } else if(p.i.x==15) color=float3((left+right+top+bottom-4*vector)*gain/(spacing*spacing)*.5+.5,straight.b);
        else {
            if(p.i.x==1) response=dx.y-dy.x;
            if(p.i.x==2) response=dx.x+dy.y;
            if(p.i.x==3) {
                float shear=(dx.y+dy.x)*.5,mean=(dx.x+dy.y)*.5;
                float spread=sqrt(max(0.0,(dx.x-dy.y)*(dx.x-dy.y)*.25+shear*shear));
                response=p.i.y==0 ? mean+spread:p.i.y==1 ? mean-spread:shear;
            }
            if(p.i.x==4) { response=(1+gain*dx.x)*(1+gain*dy.y)-gain*gain*dy.x*dx.y-1;gain=1; }
            if(p.i.x==14) {
                float2 direction=directionData39(vector);
                float2 ddx=(directionData39(right)-directionData39(left))/(2*spacing);
                float2 ddy=(directionData39(bottom)-directionData39(top))/(2*spacing);
                float2 turning=ddx*direction.x+ddy*direction.y;
                response=direction.x*turning.y-direction.y*turning.x;
            }
            color=float3(.5+atan(response*gain)/3.14159265359);
        }
    } else if(p.i.x==5) color=float3(directionData39(vector)*gain*.5+.5,straight.b);
    else if(p.i.x==6) color=float3(fract((atan2(vector.y,vector.x)+p.b.y)/6.28318530718*p.b.x+.5));
    else if(p.i.x==7) color=float3(clamp(length(vector)*gain+p.a.z,0.0,1.0));
    else if(p.i.x==8) {
        float count=max(2.0,round(p.b.x)),angle=atan2(vector.y,vector.x)-p.b.y;
        angle=round(angle*count/6.28318530718)*6.28318530718/count+p.b.y;
        color=float3(float2(cos(angle),sin(angle))*length(vector)*.5+.5,straight.b);
    } else if(p.i.x==9) {
        float count=max(2.0,round(p.b.x)),maximum=max(gain,.001);
        float magnitude=round(length(vector)/maximum*count)*maximum/count;
        color=float3(directionData39(vector)*magnitude*.5+.5,straight.b);
    } else if(p.i.x==10) color=float3(rotateData39(vector,p.b.y)*.5+.5,straight.b);
    else if(p.i.x==11) {
        float angle=atan2(uv.y-p.d.y,uv.x-p.d.x);
        color=float3(rotateData39(vector,p.i.y==0 ? -angle:angle)*.5+.5,straight.b);
    } else if(p.i.x==12) {
        int count=clamp(int(round(p.b.x)),1,24);float2 point=uv;
        for(int n=0;n<count;n++) {
            float2 first=vectorData39(source,point),mid=point-first*p.c.x/(2*count);
            point-=vectorData39(source,mid)*p.c.x/count;
        }
        color=straightData39(source,point).rgb;
    } else if(p.i.x==13) {
        int count=clamp(int(round(p.b.x)),4,32);float sum=0,weight=0;
        for(int side=-1;side<=1;side+=2) {
            float2 point=uv;
            for(int n=0;n<count;n++) {
                float w=1-float(n)/float(count);
                sum+=noiseData39(floor(point/p.c.w)+p.d.w+float2(p.d.z,p.d.z*.37))*w;weight+=w;
                float stepSize=p.c.x/(2*float(count));
                float2 first=directionData39(vectorData39(source,point));
                float2 mid=point+first*stepSize*.5*float(side);
                point+=directionData39(vectorData39(source,mid))*stepSize*float(side);
            }
        }
        color=float3(sum/max(weight,.0001));
    } else if(p.i.x==16) {
        float gx=(scalarData39(source,uv+float2(spacing,0),p.i.y)-scalarData39(source,uv-float2(spacing,0),p.i.y))/(2*spacing);
        float gy=(scalarData39(source,uv+float2(0,spacing),p.i.y)-scalarData39(source,uv-float2(0,spacing),p.i.y))/(2*spacing);
        color=unitData39(float3(-gx*gain,-gy*gain,1))*.5+.5;
    } else if(p.i.x==17) color=unitData39(float3(normal.xy*gain,normal.z))*.5+.5;
    else if(p.i.x==18) {
        normal.yz=rotateData39(normal.yz,p.b.z);normal.zx=rotateData39(normal.zx,p.b.y);normal.xy=rotateData39(normal.xy,p.b.w);
        color=normal*.5+.5;
    } else if(p.i.x==19 || p.i.x==20) {
        float3 light=float3(cos(p.b.y)*cos(p.b.z),sin(p.b.y)*cos(p.b.z),sin(p.b.z));
        if(p.i.x==19) {
            float width=max(.001,p.c.z*.5),mask=smoothstep(p.c.y-width,p.c.y+width,dot(normal,light));
            if(p.i.y==0) alpha*=mask;else color=float3(mask);
        } else {
            float diffuse=max(0.0,dot(normal,light)),specular=pow(max(0.0,dot(normal,unitData39(light+float3(0,0,1)))),max(2.0,p.b.x));
            color=p.c.rgb*p.c.a*(p.a.x+p.a.y*diffuse)+p.a.z*specular;
        }
    } else if(p.i.x==21) {
        float3 left=normalData39(source,uv-float2(spacing,0)),right=normalData39(source,uv+float2(spacing,0));
        float3 top=normalData39(source,uv-float2(0,spacing)),bottom=normalData39(source,uv+float2(0,spacing));
        float curvature=-(right.x-left.x+bottom.y-top.y)/(4*spacing);
        color=float3(.5+atan(curvature*gain)/3.14159265359);
    } else if(p.i.x==22) {
        if(p.i.y==0) {
            float z=(normal.z<0 ? -1:1)*max(abs(normal.z),p.c.y);
            color=float3(-normal.xy/z*gain*.5+.5,.5);
        } else color=unitData39(float3(-vector*gain,1))*.5+.5;
    } else if(p.i.x==23) {
        float3 ray=reflect(float3(0,0,-1),normal);
        float2 coord=float2(fract(atan2(ray.z,ray.x)/6.28318530718+.5+p.b.y/6.28318530718),acos(clamp(ray.y,-1.0,1.0))/3.14159265359);
        float4 environment=straightData39(reference,coord*float2(reference.get_width(),reference.get_height()));
        color=environment.rgb*gain;alpha*=environment.a;
    } else if(p.i.x==24) {
        float3 facing=normal.z>=0 ? normal:-normal;float coverage=0;
        for(int channel=0;channel<3;channel++) {
            float ior=max(1.001,p.a.y+p.a.z*(float(channel)-1));
            float3 ray=refract(float3(0,0,-1),facing,1/ior);
            float2 point=uv+ray.xy/max(-ray.z,.05)*p.c.x;
            float4 sample=straightData39(reference,point/size*float2(reference.get_width(),reference.get_height()));
            color[channel]=sample[channel];coverage=max(coverage,sample.a);
        }
        alpha*=coverage;
    } else if(p.i.x==25) {
        float3 detail=normalData39(reference,uv/size*float2(reference.get_width(),reference.get_height()));
        detail=unitData39(float3(detail.xy*gain,mix(1.0,detail.z,min(1.0,gain))));float3 combined;
        if(p.i.y==0) {
            float3 t=normal+float3(0,0,1),u=detail*float3(-1,-1,1);
            combined=abs(t.z)>.0001 ? t*dot(t,u)/t.z-u:normal;
        } else if(p.i.y==1) combined=float3(normal.xy+detail.xy,normal.z*detail.z);
        else combined=mix(normal,detail,clamp(gain*.5,0.0,1.0));
        color=unitData39(combined)*.5+.5;
    }
    float4 result=float4(clamp(color,float3(-65504),float3(65504))*alpha,alpha);
    output.write(half4(clamp(mix(original,result,p.a.w),float4(-65504),float4(65504))),gid);
}
