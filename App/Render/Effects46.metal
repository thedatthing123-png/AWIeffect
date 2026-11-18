#include <metal_stdlib>
using namespace metal;
struct EffectParams {
    float4 a, b, c, d;
    uint4 i;
};
constexpr sampler spectralRead46(address::clamp_to_zero, filter::linear, coord::pixel);
kernel void fxSpectralPrepare46(texture2d<half> source [[texture(0)]],
                                texture2d<float, access::write> real [[texture(1)]],
                                texture2d<float, access::write> imaginary [[texture(2)]],
                                constant EffectParams &p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= real.get_width() || gid.y >= real.get_height())
        return;
    float2 uv = (float2(gid) + .5) / float2(real.get_width(), real.get_height()),
           buffer = float2(source.get_width(), source.get_height()), span = p.c.xy;
    if (p.i.x == 11) {
        if (p.i.y == 1) {
            uv = (fract(uv + .5) - .5) * 2 * p.c.xy / (max(.1, p.a.x) * p.d.zw) + .5;
            span = p.d.zw;
        } else
            uv = (uv - .5) * 2 + .5;
    }
    float4 value = float4(0);
    if (all(uv >= 0) && all(uv <= 1))
        value = float4(source.sample(spectralRead46, (buffer - span) * .5 + uv * span));
    float3 rgb = value.a > 1.e-6 ? value.rgb / value.a : float3(0);
    if (p.i.x == 7 && value.a > 1.e-6)
        rgb = log(max(float3(.0001), rgb));
    if (p.i.x == 11) {
        rgb = value.rgb;
        if (p.i.y == 1) {
            float energy = pow(max(0.0, dot(value.rgb, float3(.2126, .7152, .0722))), p.a.y);
            rgb = float3(energy);
            value.a = energy;
        }
    }
    real.write(float4(rgb, value.a), gid);
    imaginary.write(float4(0), gid);
}
kernel void fxSpectralAnchor46(texture2d<float, access::read> source [[texture(0)]],
                               texture2d<float, access::write> mean [[texture(1)]],
                               constant EffectParams &p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (any(gid > 0))
        return;
    mean.write(source.read(uint2(0)) / p.c.w, uint2(0));
}
static float hash46(float2 q) {
    float3 v = fract(float3(q.xyx) * .1031);
    v += dot(v, v.yzx + 33.33);
    return fract((v.x + v.y) * v.z);
}
kernel void fxSpectralModify46(texture2d<float, access::read> real [[texture(0)]],
                               texture2d<float, access::write> nextReal [[texture(1)]],
                               texture2d<float, access::read> imaginary [[texture(2)]],
                               texture2d<float, access::write> nextImaginary [[texture(3)]],
                               texture2d<float, access::read> refReal [[texture(4)]],
                               texture2d<float, access::read> refImaginary [[texture(5)]],
                               texture2d<float, access::read> mean [[texture(6)]],
                               texture2d<float, access::read> refMean [[texture(7)]],
                               constant EffectParams &p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    uint2 size = uint2(nextReal.get_width(), nextReal.get_height());
    if (any(gid >= size))
        return;
    float2 k = float2(gid) / float2(size);
    k = select(k, k - 1, k > .5);
    float radius = length(k), direction = dot(k, float2(cos(p.b.x), sin(p.b.x)));
    float4 r = real.read(gid), i = imaginary.read(gid);
    float4 magnitude = sqrt(r * r + i * i), gain = float4(1);
    float phase = 0;
    bool dc = all(gid == 0),
         selfConjugate = (gid.x == 0 || gid.x * 2 == size.x) && (gid.y == 0 || gid.y * 2 == size.y);
    switch (p.i.x) {
    case 0: {
        float lo = min(p.a.x, p.a.y), hi = max(p.a.x, p.a.y),
              band = smoothstep(lo - p.a.z, lo + p.a.z, radius) * (1 - smoothstep(hi - p.a.z, hi + p.a.z, radius));
        gain = float4(p.i.z == 0 ? band : 1 - band);
        break;
    }
    case 1: {
        float angle = atan2(k.y, k.x) - p.b.x;
        float delta = abs(atan2(sin(angle), cos(angle)));
        delta = min(delta, 3.141592654 - delta);
        float gate = 1 - smoothstep(p.a.x * .5 * .017453293, p.a.x * .5 * .017453293 + .17453293, delta);
        gain = float4(1 - gate * p.a.y * .01);
        break;
    }
    case 2: {
        float2 center = p.d.xy - .5;
        float distance = min(length(k - center), length(k + center));
        gain = float4(1 - p.a.y * .01 * exp(-.5 * distance * distance / (p.a.x * p.a.x)));
        break;
    }
    case 3:
        gain = pow(float4(p.a.y) / max(float4(.000001), magnitude / p.c.w + p.a.y), float4(p.a.x));
        break;
    case 4: {
        bool negative = k.x < 0 || (k.x == 0 && k.y < 0);
        float2 canonical = negative ? -k : k;
        phase = (hash46(canonical * float2(size) + p.b.z) * 2 - 1) * 3.141592654 * p.a.x + p.b.y * p.a.x;
        phase *= negative ? -1.0 : 1.0;
        break;
    }
    case 5:
        phase = (direction > 0 ? 1.0 : direction < 0 ? -1.0 : 0.0) * p.a.x * .017453293;
        break;
    case 6: {
        float cycle = fract(radius / p.a.x - p.a.z), distance = min(cycle, 1 - cycle);
        gain = float4(.1 + .9 * (1 - smoothstep(p.a.y * .5 - .03, p.a.y * .5 + .03, distance)));
        break;
    }
    case 7:
        gain = float4(mix(p.a.y, p.a.z, 1 - exp(-radius * radius / (2 * p.a.x * p.a.x))));
        break;
    case 9:
        r = log(1 + magnitude / max(.000001, p.a.x * p.c.w));
        i = float4(0);
        break;
    case 10: {
        float2 cycles = k * float2(size) * p.c.z / p.c.xy;
        float h = exp(-19.7392088 * p.a.x * p.a.x * dot(cycles, cycles));
        gain = float4(min(p.a.z, (1 + p.a.y) * h / (h * h + p.a.y)));
        break;
    }
    case 11: {
        float energy = refMean.read(uint2(0)).r * p.c.w;
        if (energy > 1.e-8) {
            float a = refReal.read(gid).r / energy, b = refImaginary.read(gid).r / energy;
            float4 old = r;
            r = old * a - i * b;
            i = old * b + i * a;
        }
        break;
    }
    case 12: {
        float4 a = refReal.read(gid), b = refImaginary.read(gid), rr = r * a + i * b, ii = i * a - r * b;
        float4 length = sqrt(rr * rr + ii * ii);
        float4 scale = pow(max(length, float4(.000001)), float4(p.a.y));
        float2 cycles = k * float2(size) * p.c.z / p.c.xy;
        float window = exp(-19.7392088 * p.a.x * p.a.x * dot(cycles, cycles));
        r = rr / scale * window;
        i = ii / scale * window;
        if (dc) {
            r = 0;
            i = 0;
        }
        break;
    }
    case 13: {
        float4 a = refReal.read(gid), b = refImaginary.read(gid);
        float3 referenceMagnitude = sqrt(a.rgb * a.rgb + b.rgb * b.rgb);
        float3 referenceDC = refMean.read(uint2(0)).rgb;
        float3 sourceDC = mean.read(uint2(0)).rgb;
        float3 ratio = sourceDC / max(float3(.000001), referenceDC);
        float3 target = mix(magnitude.rgb, referenceMagnitude * ratio, p.a.x);
        target = select(magnitude.rgb, target, referenceDC > float3(.000001));
        float3 phaseR =
            select(float3(1), r.rgb / max(float3(.000001), magnitude.rgb), magnitude.rgb > float3(.000001));
        float3 phaseI =
            select(float3(0), i.rgb / max(float3(.000001), magnitude.rgb), magnitude.rgb > float3(.000001));
        r.rgb = target * phaseR;
        i.rgb = target * phaseI;
        break;
    }
    case 14: {
        float k = direction * 4;
        phase = p.a.x * k * k * k;
        break;
    }
    }
    if (dc && p.i.x != 7 && p.i.x != 9 && p.i.x != 11 && p.i.x != 12)
        gain = float4(1);

    bool nyquist = gid.x * 2 == size.x || gid.y * 2 == size.y;
    if (selfConjugate || nyquist)
        phase = 0;
    if (nyquist && (p.i.x == 1 || p.i.x == 2))
        gain = float4(1);
    r *= gain;
    i *= gain;
    float c = cos(phase), s = sin(phase);
    nextReal.write(r * c - i * s, gid);
    nextImaginary.write(r * s + i * c, gid);
}
static float4 interpolate46(texture2d<float, access::read> source, float2 uv) {
    uint2 size = uint2(source.get_width(), source.get_height());
    float2 point = fract(uv) * float2(size) - .5, f = fract(point);
    int2 q = int2(floor(point)), n = int2(size);
    uint2 a = uint2((q + n) % n), b = uint2((q + int2(1, 0) + n) % n), c = uint2((q + int2(0, 1) + n) % n),
          d = uint2((q + 1 + n) % n);
    return mix(mix(source.read(a), source.read(b), f.x), mix(source.read(c), source.read(d), f.x), f.y);
}
kernel void fxSpectralFinish46(texture2d<half> source [[texture(0)]],
                               texture2d<half, access::write> output [[texture(1)]],
                               texture2d<float, access::read> real [[texture(2)]],
                               texture2d<float, access::read> imaginary [[texture(3)]],
                               texture2d<float, access::read> mean [[texture(4)]],
                               constant EffectParams &p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height())
        return;
    float2 q = float2(gid) + .5, buffer = float2(output.get_width(), output.get_height()),
           uv = (q - (buffer - p.c.xy) * .5) / p.c.xy;
    float4 original = float4(source.sample(spectralRead46, q)), anchor = mean.read(uint2(0));
    if (anchor.a <= 1.e-8) {
        output.write(half4(original), gid);
        return;
    }
    float4 value;
    float4 result;
    if (p.i.x == 8) {
        float2 freq = fract(uv + .5);
        uint2 size = uint2(real.get_width(), real.get_height()), index = min(size - 1, uint2(freq * float2(size)));
        float3 r = real.read(index).rgb, i = imaginary.read(index).rgb, magnitude = sqrt(r * r + i * i) / p.c.w;
        float3 color = log(1 + p.a.x * magnitude * 64) / log(1 + p.a.x);
        if (p.i.z == 1) {
            float phase = atan2(i.r, r.r);
            color = (.5 + .5 * cos(phase + float3(0, 2.0943951, 4.1887902))) * clamp(length(color) * 2, 0.0, 1.0);
        }
        result = float4(clamp(color, float3(0), float3(1)), 1);
    } else {
        float2 position = p.i.x == 11 ? uv * .5 + .25 : (p.i.x == 9 || p.i.x == 12) ? uv + .5 : uv;
        value = interpolate46(real, position) / p.c.w;
        if (p.i.x == 9 || p.i.x == 12)
            result = float4(clamp(abs(value.rgb) * p.b.w, float3(0), float3(1)), 1);
        else if (p.i.x == 11) {
            float alpha = clamp(value.a, 0.0, 1.0);
            float3 rgb = max(float3(0), value.rgb);
            if (p.i.z == 1) {
                rgb = alpha > 1.e-6 ? rgb / alpha * original.a : float3(0);
                alpha = original.a;
            }
            result = float4(rgb, alpha);
        } else {
            float3 color = p.i.x == 7 ? exp(clamp(value.rgb, float3(-20), float3(10))) : value.rgb;
            result = float4(max(float3(0), color) * original.a, original.a);
        }
    }
    result.rgb = clamp(result.rgb, float3(0), float3(65504));
    output.write(half4(mix(original, result, p.a.w)), gid);
}
