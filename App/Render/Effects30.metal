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
        default: {
            float height = clamp(.5-q.y-shape*q.x*q.x+.025*sin(time*3.0+q.x*4.0),0.0,1.0);
            float band = floor(height*count)/count;
            field = mix(band,height,width);
            break;
        }
    }
    float4 color = mix(p.c,p.b,clamp(field,0.0,1.0));
    color.rgb *= color.a;
    float4 source = input.read(gid);
    out.write(p.i.y != 0 ? color : mix(source,color,p.d.w),gid);
}
