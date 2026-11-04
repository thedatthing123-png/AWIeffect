#include <metal_stdlib>
using namespace metal;
struct Params24 { float4 a,b,c,d; uint4 i; };
constexpr sampler zero24(coord::pixel, address::clamp_to_zero, filter::linear);
constexpr sampler edge24(coord::pixel, address::clamp_to_edge, filter::linear);
float luma24(float4 c) { return dot(c.a > 1e-6 ? c.rgb / c.a : float3(0), float3(0.2126, 0.7152, 0.0722)); }
bool inside24(texture2d<half, access::read> image, int2 p) {
    return all(p >= 0) && p.x < int(image.get_width()) && p.y < int(image.get_height()) && image.read(uint2(p)).a >= 0.5h;
}
kernel void fx24Seed(texture2d<half, access::read> src [[texture(0)]], texture2d<float, access::write> dst [[texture(1)]], constant Params24& params [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 position = (float2(gid) + 0.5) * params.a.xy;
    int2 p = int2(floor(position)); bool inside = inside24(src, p);
    float2 seed = float2(-1);
    const int2 offsets[4] = {int2(-1,0),int2(1,0),int2(0,-1),int2(0,1)};
    for (int i = 0; i < 4; i++) {
        if (inside != inside24(src, int2(floor(position + float2(offsets[i]) * params.a.xy)))) { seed = position + float2(offsets[i]) * params.a.xy * 0.5; break; }
    }
    dst.write(float4(seed, 0, 1), gid);
}
kernel void fx24Jump(texture2d<float, access::read> src [[texture(0)]], texture2d<float, access::write> dst [[texture(1)]],
                      constant Params24& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 xy = (float2(gid) + 0.5) * p.a.xy, best = float2(-1); float score = INFINITY;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        int2 q = int2(gid) + int2(x,y) * int(p.i.x);
        if (any(q < 0) || q.x >= int(src.get_width()) || q.y >= int(src.get_height())) continue;
        float2 candidate = src.read(uint2(q)).xy;
        if (candidate.x < 0) continue;
        float distance = dot(candidate - xy, candidate - xy);
        if (distance < score) { score = distance; best = candidate; }
    }
    dst.write(float4(best, 0, 1), gid);
}
float2 calibrate24(float2 q, float4 c) {
    float r2 = min(dot(q,q), 16.0), radial = 1 + c.x*r2 + c.y*r2*r2;
    return q * radial + float2(2*c.z*q.x*q.y + c.w*(r2+2*q.x*q.x), c.z*(r2+2*q.y*q.y)+2*c.w*q.x*q.y);
}
kernel void fx24Image(texture2d<half, access::sample> src [[texture(0)]], texture2d<half, access::write> dst [[texture(1)]],
                       texture2d<float, access::read> auxiliary [[texture(2)]], constant Params24& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 xy = float2(gid) + 0.5; float4 original = float4(src.sample(zero24, xy)), result = original;
    if (p.i.x <= 2) {
        uint2 fieldSize = uint2(auxiliary.get_width(), auxiliary.get_height());
        uint2 fieldPixel = min(uint2(xy / p.c.xy * float2(fieldSize)), fieldSize - 1);
        float2 nearest = auxiliary.read(fieldPixel).xy;
        float distance = nearest.x >= 0 ? length(xy-nearest) : 1e6;
        bool inside = original.a >= 0.5;
        float sign = inside ? 1.0 : -1.0;
        if (p.i.x == 0) {
            float value = saturate(0.5 + sign * distance / (2 * max(p.a.x, 0.01)) + p.a.y * 0.5);
            result = float4(float3(value), 1);
        } else if (p.i.x == 1) {
            float spacing = max(p.a.x, 0.1), phase = distance / spacing - p.a.z;
            float edgeDistance = abs(fract(phase + 0.5) - 0.5) * spacing;
            float band = (1 - smoothstep(max(0.0,p.a.y*0.5-0.75),p.a.y*0.5+0.75,edgeDistance)) * (1 - smoothstep(p.a.w-1,p.a.w+1,distance));
            if ((p.i.y == 1 && !inside) || (p.i.y == 2 && inside)) band = 0;
            float alpha = band * p.b.a;
            result = float4(p.b.rgb * alpha + original.rgb * (1-alpha), alpha + original.a*(1-alpha));
        } else {
            float2 direction = distance > 1e-5 && distance < 1e5 ? (xy-nearest)/distance*sign : float2(0);
            float fade = 1 - smoothstep(0.0,max(p.a.y,0.01),distance);
            result = float4(src.sample(zero24, xy + direction * p.a.x * fade));
        }
    } else if (p.i.x == 3) {
        float base = auxiliary.read(gid).a;
        float alpha = saturate(base * p.a.x + (original.a - base) * p.a.y);
        float3 color = original.a > 1e-5 ? original.rgb / original.a : float3(0);
        // Newly expanded pixels use the blurred premultiplied color, avoiding black fringes.
        if (original.a <= 1e-5) { float4 blurred = auxiliary.read(gid); color = blurred.a > 1e-5 ? blurred.rgb / blurred.a : float3(0); }
        result = float4(color * alpha, alpha);
    } else if (p.i.x == 4) {
        float delta = luma24(original) - luma24(auxiliary.read(gid));
        if (p.i.y != 0) delta = -delta;
        float coverage = smoothstep(p.a.x, p.a.x + max(p.a.y,0.0001), delta);
        result = original * mix(1.0, coverage, p.a.z);
    } else if (p.i.x == 5) {
        float radius = max(0.5,p.a.y);
        float dx = luma24(float4(src.sample(edge24,xy+float2(radius,0)))) - luma24(float4(src.sample(edge24,xy-float2(radius,0))));
        float dy = luma24(float4(src.sample(edge24,xy+float2(0,radius)))) - luma24(float4(src.sample(edge24,xy-float2(0,radius))));
        float3 normal = normalize(float3(-dx*p.a.x, (p.i.y != 0 ? dy : -dy)*p.a.x, 1));
        result = float4((normal*0.5+0.5)*original.a,original.a);
    } else if (p.i.x == 6) {
        float2 extent = max(p.d.zw,float2(1)), center = p.d.xy + p.b.xy * extent;
        float scale = max(extent.x,extent.y)*0.5;
        float2 q = (xy-center)/scale, warped;
        if (p.i.y == 0) warped = calibrate24(q,p.a);
        else {
            // Damped Newton solve with a numerical Jacobian, bounded for folded calibration fields.
            warped = q;
            for (int iteration=0; iteration<10; iteration++) {
                float2 f = calibrate24(warped,p.a)-q;
                float epsilon = 0.001;
                float2 jx=(calibrate24(warped+float2(epsilon,0),p.a)-calibrate24(warped-float2(epsilon,0),p.a))/(2*epsilon);
                float2 jy=(calibrate24(warped+float2(0,epsilon),p.a)-calibrate24(warped-float2(0,epsilon),p.a))/(2*epsilon);
                float determinant=jx.x*jy.y-jy.x*jx.y;
                if (abs(determinant)<1e-5) break;
                float2 update=float2(jy.y*f.x-jy.x*f.y,-jx.y*f.x+jx.x*f.y)/determinant;
                warped=clamp(warped-clamp(update,float2(-0.5),float2(0.5)),float2(-4),float2(4));
            }
        }
        result=mix(original,float4(src.sample(zero24,center+warped*scale)),p.b.z);
    } else {
        float2 direction=float2(cos(p.a.y),sin(p.a.y)); float3 rgb=0, weights=0; float alpha=0;
        for (int i=0;i<7;i++) {
            float wavelength=float(i)/6, signedWave=wavelength*2-1;
            float separation=sign(signedWave)*pow(abs(signedWave),p.a.z)*p.a.x;
            float3 spectrum=(wavelength-float3(0.85,0.5,0.15))*4.0;
            float3 weight=exp(-(spectrum*spectrum));
            float4 sample=float4(src.sample(zero24,xy+direction*separation));
            rgb+=sample.rgb*weight; weights+=weight; alpha=max(alpha,sample.a);
        }
        result=mix(original,float4(rgb/max(weights,float3(1e-5)),alpha),p.a.w);
    }
    dst.write(half4(result),gid);
}
