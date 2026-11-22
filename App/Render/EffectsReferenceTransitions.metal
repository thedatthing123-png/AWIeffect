#include <metal_stdlib>
using namespace metal;

struct ReferenceTransitionParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler referenceTransitionSampler(coord::pixel, address::clamp_to_zero, filter::linear);

static float2 refTransitionHash(float2 p, float seed) {
    float3 q = fract(float3(p.x, p.y, p.x) * float3(.1031, .1030, .0973) + seed * .017);
    q += dot(q, q.yzx + 33.33);
    return fract((q.xx + q.yz) * q.zy);
}
static float refTransitionNoise(float2 p, float seed) {
    float2 cell = floor(p), f = fract(p), u = f*f*(3.-2.*f);
    return mix(mix(refTransitionHash(cell,seed).x,refTransitionHash(cell+float2(1,0),seed).x,u.x),
               mix(refTransitionHash(cell+float2(0,1),seed).x,refTransitionHash(cell+float2(1,1),seed).x,u.x),u.y);
}

kernel void fxLiquidLensReference(texture2d<half, access::sample> source [[texture(0)]],
                                 texture2d<half, access::write> output [[texture(1)]],
                                 constant ReferenceTransitionParams& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 pixel = float2(gid)+.5;
    if (p.a.x <= 0.) { output.write(source.sample(referenceTransitionSampler,pixel),gid); return; }
    if (p.a.x >= 1.) { output.write(half4(0),gid); return; }
    float2 rectSize = max(p.d.zw,float2(1)), uv = (pixel-p.d.xy)/rectSize;
    float2 direction = float2(cos(p.a.y),sin(p.a.y)), tangent = float2(-direction.y,direction.x);
    float span = max(abs(direction.x)+abs(direction.y),.001);
    float across = dot(uv-.5,direction)/span+.5;
    float along = dot((uv-.5)*rectSize/min(rectSize.x,rectSize.y),tangent);
    float field = refTransitionNoise(float2(along*p.a.w,p.c.x*.35),p.c.y)*.67;
    field += refTransitionNoise(float2(along*p.a.w*2.03+17.,p.c.x*.61),p.c.y)*.33;
    float envelope = sin(p.a.x*M_PI_F);
    float boundary = mix(-.25,1.25,p.a.x)+(field-.5)*p.a.z*.45*envelope;
    float distance = (across-boundary)*min(rectSize.x,rectSize.y);
    float width = max(p.b.y,1.);
    float band = exp(-distance*distance/(width*width))*envelope;
    float2 displacement = direction*p.b.x*band + tangent*(field-.5)*p.b.x*.2*band;
    float2 samplePoint = pixel+displacement;
    float4 mid = float4(source.sample(referenceTransitionSampler,samplePoint));
    float4 red = float4(source.sample(referenceTransitionSampler,samplePoint+displacement*p.b.z*.25));
    float4 blue = float4(source.sample(referenceTransitionSampler,samplePoint-displacement*p.b.z*.25));
    float feather = max(.5,p.b.w);
    float coverage = smoothstep(-feather,feather,distance);
    float alpha = max(mid.a,max(red.a,blue.a));
    output.write(half4(float4(red.r,mid.g,blue.b,alpha)*coverage),gid);
}

struct RefTransitionCell { float2 id; float2 center; float nearest; float second; };
static RefTransitionCell refTransitionCell(float2 point, float jitter, float seed) {
    float2 grid = floor(point);
    RefTransitionCell cell = { float2(0),float2(0),1e10,1e10 };
    for (int y=-1;y<=1;y++) for (int x=-1;x<=1;x++) {
        float2 id=grid+float2(x,y), center=id+.5+(refTransitionHash(id,seed)-.5)*jitter;
        float2 delta=point-center;
        float d=dot(delta,delta);
        if (d<cell.nearest) { cell.second=cell.nearest; cell.nearest=d; cell.id=id; cell.center=center; }
        else cell.second=min(cell.second,d);
    }
    return cell;
}
kernel void fxVoronoiPeelReference(texture2d<half, access::sample> source [[texture(0)]],
                                 texture2d<half, access::write> output [[texture(1)]],
                                 constant ReferenceTransitionParams& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 pixel=float2(gid)+.5;
    if (p.a.x<=0.) { output.write(source.sample(referenceTransitionSampler,pixel),gid);return; }
    if (p.a.x>=1.) { output.write(half4(0),gid);return; }
    float2 rect=max(p.d.zw,float2(1)), ratio=rect/min(rect.x,rect.y);
    float2 uv=(pixel-p.d.xy)/rect, point=uv*ratio*p.a.y;
    RefTransitionCell cell=refTransitionCell(point,p.a.z,p.c.z);
    float2 random=refTransitionHash(cell.id,p.c.z), center=cell.center/(ratio*p.a.y);
    float delay=random.x;
    if (p.i.x==1) {
        float2 origin=clamp(p.b.xy,0.,1.);
        float farthest=length(max(origin,1.-origin)*ratio);
        delay=clamp(length((center-origin)*ratio)/max(farthest,.001),0.,1.);
    } else if (p.i.x>=2) {
        float2 direction=float2(cos(p.b.z),sin(p.b.z));
        delay=clamp(dot(center-.5,direction)/(abs(direction.x)+abs(direction.y))+.5,0.,1.);
        if (p.i.x==3) delay=1.-delay;
    }
    float local=clamp((p.a.x-delay*p.a.w)/max(1.-p.a.w,.05),0.,1.);
    float ease=local*local*(3.-2.*local), scale=max(.001,1.-ease*p.c.x);
    float2 delta=(point-cell.center)/scale;
    float turn=p.b.w*ease*(random.y*1.5+.25), c=cos(turn),s=sin(turn);
    float2 mapped=cell.center+float2(c*delta.x+s*delta.y,-s*delta.x+c*delta.y);
    RefTransitionCell sampled=refTransitionCell(mapped,p.a.z,p.c.z);
    float inside=all(sampled.id==cell.id)?1.:0.;
    float edge=max(0.,sqrt(sampled.second)-sqrt(sampled.nearest));
    float soft=max(.00001,p.c.y*p.a.y/min(rect.x,rect.y));
    float coverage=inside*smoothstep(0.,soft,edge)*(1.-smoothstep(.8,1.,local));
    float2 samplePixel=p.d.xy+mapped/(ratio*p.a.y)*rect;
    output.write(source.sample(referenceTransitionSampler,samplePixel)*half(coverage),gid);
}
