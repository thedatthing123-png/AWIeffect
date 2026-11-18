#include <metal_stdlib>
using namespace metal;
struct EffectParams { float4 a; float4 b; float4 c; float4 d; uint4 i; };

static float hash30(float2 p) {
    float3 q = fract(float3(p.xyx) * .1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
static float noise30(float2 p) {
    float2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash30(i), hash30(i+float2(1,0)), f.x),
               mix(hash30(i+float2(0,1)), hash30(i+1.0), f.x), f.y);
}
// Distance to a repeating band, using an analytic pixel footprint (compute kernels have no derivatives).
static float band30(float phase, float width, float aa) {
    float distance = abs(fract(phase + .5) - .5);
    return 1.0-smoothstep(width*.5-aa, width*.5+aa, distance);
}
static float line30(float distance, float width, float aa) {
    return 1.0-smoothstep(width-aa, width+aa, distance);
}

static bool primeMath30(int value) {
    if(value<2) return false;
    if(value%2==0) return value==2;
    for(int divisor=3;divisor<=101;divisor+=2) {
        if(divisor*divisor>value) break;
        if(value%divisor==0) return false;
    }
    return true;
}
static int hilbertIndex30(int2 point,int size) {
    int index=0;
    for(int step=size/2;step>0;step/=2) {
        int rx=(point.x&step)!=0,ry=(point.y&step)!=0;
        index+=step*step*((3*rx)^ry);
        if(ry==0) {
            if(rx!=0) point=int2(step-1)-point;
            point=point.yx;
        }
    }
    return index;
}
static int2 hilbertPoint30(int index,int size) {
    int2 point=0;
    for(int step=1;step<size;step*=2) {
        int rx=1&(index/2),ry=1&(index^rx);
        if(ry==0) {
            if(rx!=0) point=int2(step-1)-point;
            point=point.yx;
        }
        point+=step*int2(rx,ry);index/=4;
    }
    return point;
}
static float segmentMath30(float2 point,float2 a,float2 b) {
    float2 delta=b-a;
    return length(point-a-delta*clamp(dot(point-a,delta)/max(dot(delta,delta),1.e-8),0.0,1.0));
}
static float2 complexMath30(float2 a,float2 b) { return float2(a.x*b.x-a.y*b.y,a.x*b.y+a.y*b.x); }
kernel void fxMathBackground30(texture2d<half,access::read> source [[texture(0)]],
                              texture2d<half,access::write> output [[texture(1)]],
                              constant EffectParams& p [[buffer(0)]],uint2 gid [[thread_position_in_grid]]) {
    if(gid.x>=output.get_width() || gid.y>=output.get_height()) return;
    float2 delta=(float2(gid)+.5-p.d.xy)/max(p.a.w,1.0);
    float cs=cos(p.d.z),sn=sin(p.d.z);
    float2 q=float2(delta.x*cs+delta.y*sn,-delta.x*sn+delta.y*cs)*p.a.x;
    float a=as_type<float>(p.i.y),b=as_type<float>(p.i.z),c=as_type<float>(p.i.w);
    float phase=p.a.y,aa=max(.00001,p.a.x/max(p.a.w,1.0)),field=0;
    if(p.i.x==0) {
        float2 u=q+float2(sin(phase),cos(phase))*.04;
        float wave=cos(a*3.14159265*u.x+phase)*cos(b*3.14159265*u.y)-cos(b*3.14159265*u.x)*cos(a*3.14159265*u.y+phase);
        field=1-smoothstep(c,c+aa*(a+b),abs(wave));
    } else if(p.i.x==1) {
        int directions=clamp(int(round(a)),3,11);float sum=0;
        for(int n=0;n<directions;n++) {
            float angle=float(n)*3.14159265/float(directions);
            sum+=cos(dot(q,float2(cos(angle),sin(angle)))*b*6.2831853+phase*(1+float(n)*.07));
        }
        field=exp(-abs(sum/float(directions))/max(c,.001));
    } else if(p.i.x==2) {
        float2 uv=q+.5+float2(sin(phase),cos(phase))*.025;
        field=1-smoothstep(.5-aa,.5+aa,max(abs(uv.x-.5),abs(uv.y-.5)));
        float scale=1;
        for(int n=0;n<clamp(int(round(a)),1,6);n++) {
            scale*=3;float2 cell=fract(uv*scale);
            float distance=max(abs(cell.x-.5),abs(cell.y-.5));
            float soft=max(c,min(.25,aa*scale));
            field*=smoothstep(b*.5-soft,b*.5+soft,distance);
        }
    } else if(p.i.x==3) {
        int roots=clamp(int(round(a)),2,6),iterations=clamp(int(round(b)),4,32),steps=0;bool converged=false;
        float2 z=clamp(q*3+float2(cos(phase),sin(phase))*.13,float2(-20),float2(20));
        for(int n=0;n<iterations;n++) {
            float2 power=float2(1,0);
            for(int k=0;k<roots-1;k++) power=complexMath30(power,z);
            float2 residual=complexMath30(power,z)-float2(1,0),derivative=float(roots)*power;
            float denominator=max(dot(derivative,derivative),1.e-8);
            z-=complexMath30(residual,float2(derivative.x,-derivative.y))/denominator;
            z=clamp(z,float2(-20),float2(20));steps=n+1;
            if(dot(residual,residual)<1.e-6) { converged=true;break; }
        }
        float root=round(atan2(z.y,z.x)*float(roots)/6.2831853);
        root=fmod(root+float(roots),float(roots));
        field=converged ? (root+.35+.25*cos(float(steps)*c-phase))/float(roots):0;
    } else if(p.i.x==4) {
        int count=clamp(int(round(a)),9,81)|1;int2 cell=int2(floor(q*float(count)+.5));
        int ring=max(abs(cell.x),abs(cell.y));
        if(ring<=count/2) {
        int value=(2*ring+1)*(2*ring+1);
        if(cell.y==-ring) value-=ring-cell.x;
        else if(cell.x==-ring) value-=2*ring+cell.y+ring;
        else if(cell.y==ring) value-=4*ring+cell.x+ring;
        else value-=6*ring+ring-cell.y;
        float cycle=phase-floor(phase/97)*97;int offset=int(floor(cycle));
        float marked=mix(primeMath30(value+int(round(c))+offset) ? 1.0:0.0,
            primeMath30(value+int(round(c))+(offset+1)%97) ? 1.0:0.0,fract(cycle));
        float2 local=q*float(count)-float2(cell);
        field=marked*(1-smoothstep(b*.5-aa*count,b*.5+aa*count,length(local)));
        }
    } else if(p.i.x==5) {
        int count=1<<clamp(int(round(a)),1,6);int2 cell=int2(floor((q+.5)*float(count)));
        if(all(cell>=0) && all(cell<count)) {
            int index=hilbertIndex30(cell,count);
            float2 center=(float2(cell)+.5)/float(count)-.5;
            float distance=length(q-center);
            if(index>0) distance=min(distance,segmentMath30(q,center,(center+(float2(hilbertPoint30(index-1,count))+.5)/float(count)-.5)*.5));
            if(index<count*count-1) distance=min(distance,segmentMath30(q,center,(center+(float2(hilbertPoint30(index+1,count))+.5)/float(count)-.5)*.5));
            float travel=abs(fract(float(index)/float(count*count)-phase+.5)-.5);
            float light=.35+.65*exp(-travel*travel/max(c*c*.25,.0001));
            float radius=min(b*p.d.w*p.a.x/max(p.a.w,1.0)*.5,.45/float(count));
            field=(1-smoothstep(radius-aa,radius+aa,distance))*light;
        }
    } else {
        float2 left=q-float2(a*.5,0),right=q+float2(a*.5,0);
        float l=max(length(left),.0001),r=max(length(right),.0001);
        float potential=log(l/r),stream=atan2(left.y,left.x)-atan2(right.y,right.x);
        float footprint=aa*b/max(min(l,r),.02);
        field=max(band30(stream*b/6.2831853-phase,c,footprint),.65*band30(potential*b*.2+phase,c,footprint));
    }
    float4 color=mix(p.c,p.b,clamp(field,0.0,1.0));color.rgb*=color.a;
    output.write(half4(mix(float4(source.read(gid)),color,p.a.z)),gid);
}

kernel void fxBackground30(texture2d<float, access::read> input [[texture(0)]],
                           texture2d<float, access::write> out [[texture(1)]],
                           constant EffectParams& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= out.get_width() || gid.y >= out.get_height()) return;
    float2 size = float2(out.get_width(), out.get_height());
    float side = min(size.x, size.y);
    float2 q = (float2(gid)+.5-p.d.xy*size)/side;
    float cs = cos(p.d.z), sn = sin(p.d.z);
    q = float2(q.x*cs+q.y*sn, -q.x*sn+q.y*cs);
    float count = max(.1, p.a.x), width = p.a.y, shape = p.a.z, time = p.a.w;
    float aa = max(.001, count/side), field = 0.0;
    float2 u = q*count + float2(time*.7, time*.37);
    switch (p.i.x) {
        case 0: {
            float r = length(q), angle = atan2(q.y,q.x)/6.2831853;
            float footprint = min(.35, count/(6.2831853*max(r*side,1.0)));
            float softness = as_type<float>(p.i.z);
            field = band30((angle-time+shape*r)*count, width, max(footprint,softness));
            float fade = as_type<float>(p.i.w);
            field *= 1.0-fade*smoothstep(.05,.85,r);
            break;
        }
        case 1: {
            float r = length(q), angle = atan2(q.y,q.x)/6.2831853;
            field = band30(angle*count-r*shape*count-time, width,
                           min(.3, aa*shape + count/(6.2831853*max(r*side,1.0))));
            break;
        }
        case 2: {
            float triangle = abs(fract(u.x*.5)*2.0-1.0);
            field = band30(u.y+triangle*shape, width, aa*(1.0+shape)); break;
        }
        case 3: {
            float2 tile = floor(u), f = abs(fract(u)-.5);
            float horizontal = line30(f.y,width*.5,aa), vertical = line30(f.x,width*.5,aa);
            bool over = fmod(tile.x+tile.y,2.0) == 0.0;
            float base = max(horizontal,vertical);
            float shade = min(horizontal,vertical)*(shape/100.0);
            field = base*(1.0-shade*(over ? .5 : 1.0)); break;
        }
        case 4: {
            float2 tile = floor(u), f = fract(u);
            if (hash30(tile+floor(shape)*float2(17.3,9.7)) > .5) f.x = 1.0-f.x;
            float d = min(abs(length(f)-.5), abs(length(f-1.0)-.5));
            field = line30(d,width*.5,aa); break;
        }
        case 5: {
            float terrain = noise30(q*count+float2(time*.3,0))*.65
                          + noise30(q*count*2.07+float2(0,time*.2))*.25
                          + noise30(q*count*4.13+17.0)*.1;
            field = band30(terrain*shape+time*.15,width,max(.003,aa*shape*.35)); break;
        }
        case 6: {
            // Three adjacent rows overlap; fixed small neighborhood, never a radius-sized loop.
            float row = floor(u.y/shape);
            for (int j=-1;j<=1;j++) {
                float y = row+float(j), shift = fmod(abs(y),2.0)*.5;
                float x = floor(u.x-shift)+.5+shift;
                float2 v = u-float2(x,y*shape);
                float arc = line30(abs(length(v)-.7),width*.5,aa);
                field = max(field, arc * smoothstep(-aa,aa,v.y));
            }
            break;
        }
        case 7: {
            field = max(band30(u.x/shape+u.y,width,aa*(1.0+1.0/shape)),
                        band30(u.x/shape-u.y,width,aa*(1.0+1.0/shape))); break;
        }
        case 8: {
            float2 tile = floor(u), f = fract(u)-.5;
            float wave = .5+.5*sin(tile.x*.6+tile.y*.45-time*6.2831853);
            float radius = width*.5*mix(1.0,.25+.75*wave,shape/100.0);
            field = line30(length(f),radius,aa); break;
        }
        case 9: {
            float2 f = abs(fract(u)-.5);
            float d = min(max(f.x-shape/200.0,f.y-width*.5), max(f.y-shape/200.0,f.x-width*.5));
            field = 1.0-smoothstep(-aa,aa,d); break;
        }
        case 10: {
            float phase = q.y*count+shape*sin(q.x*4.0+time*2.0)+time;
            float wave = .5+.5*sin(phase*6.2831853);
            field = pow(clamp(wave,0.0,1.0), exp2((width-.5)*3.0)); break;
        }
        case 11: {
            float height = clamp(.5-q.y-shape*q.x*q.x+.025*sin(time*3.0+q.x*4.0),0.0,1.0);
            float band = floor(height*count)/count;
            field = mix(band,height,width);
            break;
        }
        case 12: {
            float row = floor(u.y);
            float2 brick = float2(u.x/shape+fmod(abs(row),2.0)*.5,u.y);
            float2 f = min(fract(brick),1.0-fract(brick));
            field = smoothstep(width*.5-aa,width*.5+aa,min(f.x*shape,f.y));
            break;
        }
        case 13: {
            // Herringbone: diagonal integer strips interlock in alternating 2:1 planks.
            float2 v = float2(u.x+u.y,u.y-u.x)*.70710678;
            float2 cell = floor(v), f = fract(v);
            float parity = fmod(abs(cell.x-cell.y),4.0);
            float edge = (parity < 2.0) ? min(f.y,1.0-f.y) : min(f.x,1.0-f.x);
            float end = (parity < 2.0) ? min(fract(v.x*.5),1.0-fract(v.x*.5))*2.0
                                               : min(fract(v.y*.5),1.0-fract(v.y*.5))*2.0;
            field = smoothstep(width*.5-aa,width*.5+aa,min(edge,end));
            field *= 1.0-(shape/100.0)*(parity >= 2.0 ? .8 : .15);
            break;
        }
        case 14: {
            float x = band30(u.x,width,aa), y = band30(u.y,width,aa);
            float pins = max(band30(u.x+shape,.025,aa),band30(u.y-shape,.025,aa));
            field = max(pins,(x+y)*.35+x*y*.3); break;
        }
        case 15: {
            float minor = max(band30(u.x*shape,width,aa*shape),band30(u.y*shape,width,aa*shape));
            float major = max(band30(u.x,width/shape*1.8,aa),band30(u.y,width/shape*1.8,aa));
            field = max(minor*.4,major); break;
        }
        case 16: {
            float2 v = float2(u.x,u.y/shape);
            field = max(band30(v.y,width,aa),max(band30(v.x*.8660254+v.y*.5,width,aa),
                                                band30(v.x*.8660254-v.y*.5,width,aa))); break;
        }
        case 17: {
            float r = length(q), angle = atan2(q.y,q.x)/6.2831853;
            float rings = band30(r*count-time,width,aa);
            float spokes = band30(angle*shape-time,width,min(.3,shape/(6.2831853*max(r*side,1.0))));
            field = max(rings,spokes); break;
        }
        case 18: {
            field = band30(length(float2(q.x/shape,q.y))*count-time,width,aa); break;
        }
        case 19: {
            float phase = atan2(q.y,q.x)/6.2831853*count+length(q)*shape+time;
            field = pow(.5+.5*cos(phase*6.2831853),exp2((width-.5)*3.0)); break;
        }
        case 20: {
            float distance = abs(q.x/shape)+abs(q.y);
            field = pow(.5+.5*cos((distance*count-time)*6.2831853),exp2((width-.5)*3.0)); break;
        }
        case 21: {
            float2 v = q*count;
            float a = sin(v.x*1.7+time)*cos(v.y*1.3-time*.6);
            float b = sin(v.y*2.1+v.x*.5+time*.8);
            field = smoothstep(-shape,shape,(a+b*.6)+(width-.5)*3.0); break;
        }
        case 22: {
            float2 tile = floor(u), f = fract(u);
            if (fmod(abs(tile.x+tile.y),2.0) > .5) f = 1.0-f;
            field = band30(length(f)*shape-time,width,aa*shape); break;
        }
        case 23: {
            float2 v = float2(q.x*cos(shape)+q.y*sin(shape),-q.x*sin(shape)+q.y*cos(shape));
            float a = band30(q.x*count+time,width,aa);
            float b = band30(v.x*count-time*.7,width,aa);
            field = abs(a-b); break;
        }
        case 24: {
            float2 tile = floor(u), f = fract(u)-.5;
            float random = hash30(tile+floor(shape)*float2(9.1,17.3));
            if (random < .5) f = f.yx;
            float trace = min(max(abs(f.y)-width*.5,-f.x),max(abs(f.x)-width*.5,f.y));
            float pad = abs(length(f)-width*1.2);
            field = max(1.0-smoothstep(-aa,aa,trace),line30(pad,width*.35,aa)); break;
        }
        case 25: {
            float2 v = float2(u.x,u.y*.65), tile = floor(v), f = fract(v)-.5;
            bool one = hash30(tile+floor(shape)*float2(7.7,13.1)) > .5;
            if (one) {
                field = max(line30(abs(f.x),width*.5,aa)*step(abs(f.y),.33),
                            line30(abs(f.y-.33),width*.5,aa)*step(abs(f.x),.2));
            } else {
                float d = length(float2(f.x/.22,f.y/.34));
                field = line30(abs(d-1.0),width*2.0,aa*4.0);
            }
            break;
        }
        case 26: {
            float row = floor(q.y*shape+time*.37);
            float x = q.x*count+time*.7;
            float random = hash30(float2(floor(x),row));
            float edge = band30(q.y*shape+time*.37,.88,max(.002,shape/side));
            field = edge*(1.0-smoothstep(width-.035,width+.035,random)); break;
        }
        case 27: {
            float2 cell = floor(u), f = abs(fract(u)-.5);
            float pane = line30(max(f.x,f.y),width*.5,aa);
            float occupancy = hash30(cell+float2(5.1,8.9));
            float threshold = shape/100.0 + .12*sin(time*3.0+hash30(cell)*6.2831853);
            field = pane*mix(.08,1.0,smoothstep(occupancy-.05,occupancy+.05,threshold)); break;
        }
        case 28: {
            // Nearest of two staggered triangular lattices gives regular hexagonal Voronoi cells.
            float2 v = float2(u.x/shape,u.y), spacing = float2(1.7320508,3.0);
            float2 a = v-spacing*floor(v/spacing+.5);
            float2 b = v-spacing*(floor((v-float2(.8660254,1.5))/spacing+.5))-float2(.8660254,1.5);
            float2 f = dot(a,a)<dot(b,b) ? a : b;
            float hex = max(abs(f.x)*.8660254+abs(f.y)*.5,abs(f.y));
            field = line30(abs(hex-1.0),width*.5,aa); break;
        }
        case 29: {
            float2 cell = floor(u), f = fract(u);
            bool upper = f.x+f.y > 1.0;
            float tone = hash30(cell+float2(upper ? 13.1 : 0.0,upper ? 7.7 : 0.0));
            float edge = min(min(min(f.x,1.0-f.x),min(f.y,1.0-f.y)),abs(f.x+f.y-1.0)*.7071);
            field = smoothstep(width*.5-aa,width*.5+aa,edge)*mix(.5,tone,shape/100.0); break;
        }
        case 30: {
            float2 cell = floor(u), f = fract(u);
            bool horizontal = fmod(abs(cell.x+cell.y),2.0)<.5;
            if (!horizontal) f = f.yx;
            float edge = min(min(f.x,1.0-f.x),min(fract(f.y*2.0),1.0-fract(f.y*2.0))*.5);
            field = smoothstep(width*.5-aa,width*.5+aa,edge)*(1.0-(horizontal ? .1 : .8)*shape/100.0); break;
        }
        case 31: {
            float2 tile = floor(u), f = fract(u)-.5;
            float diagonal = fmod(abs(tile.x+tile.y),2.0)<.5 ? f.x+f.y : f.x-f.y;
            float stitch = line30(abs(diagonal)*.7071,width*.5,aa);
            field = stitch*(1.0-smoothstep(shape*.005-aa,shape*.005+aa,max(abs(f.x),abs(f.y)))); break;
        }
        case 32: {
            float2 pixel = floor(u*4.0), f = floor(fract(pixel/4.0)*4.0);
            int x = int(f.x), y = int(f.y);
            int high = ((x&1) ^ (y&1))*2 + (y&1);
            int low = (((x>>1)&1) ^ ((y>>1)&1))*2 + ((y>>1)&1);
            float threshold = (float(high*4+low)+.5)/16.0;
            float density = width+(shape/100.0)*.5*sin(q.x*4.0+q.y*2.0+time*4.0);
            field = smoothstep(threshold-.015,threshold+.015,density); break;
        }
        case 33: {
            float a = length(q-float2(shape*.5,0.0)), b = length(q+float2(shape*.5,0.0));
            float wave = .5+.25*cos((a*count-time)*6.2831853)+.25*cos((b*count-time)*6.2831853);
            field = smoothstep(1.0-width-.05,1.0-width+.05,wave); break;
        }
        case 34: {
            float wave = shape*sin(q.x*9.0+time*2.0)*cos(q.x*3.0-time);
            float a = band30(q.y*count+wave,width,aa*(1.0+shape));
            float b = band30(q.y*count-wave+.5,width,aa*(1.0+shape));
            field = max(a,b); break;
        }
        case 35: {
            float x = u.x+shape*sin(q.y*7.0+time*2.0);
            float y = u.y+shape*sin(q.x*7.0-time*2.0);
            field = max(band30(x,width,aa*(1.0+shape)),band30(y,width,aa*(1.0+shape))); break;
        }
        default: break;
    }
    float4 color = mix(p.c,p.b,clamp(field,0.0,1.0));
    color.rgb *= color.a;
    float4 source = input.read(gid);
    out.write(p.i.y != 0 ? color : mix(source,color,p.d.w),gid);
}
