#include <metal_stdlib>
using namespace metal;
struct EffectParams {
    float4 a, b, c, d;
    uint4 i;
};
constexpr sampler layerRead47(address::clamp_to_edge, filter::linear, coord::pixel);
constexpr sampler layerClear47(address::clamp_to_zero, filter::linear, coord::pixel);
static float3 straight47(float4 c) {
    return c.a > 1.e-6 ? c.rgb / c.a : float3(0);
}
static float luma47(float4 c) {
    return dot(straight47(c), float3(.2126, .7152, .0722));
}
static float hash47(float2 q) {
    float3 v = fract(float3(q.xyx) * .1031);
    v += dot(v, v.yzx + 33.33);
    return fract((v.x + v.y) * v.z);
}
static float4 sample47(texture2d<half> image, float2 q, uint edge) {
    float2 size = float2(image.get_width(), image.get_height());
    if (edge == 0)
        return float4(image.sample(layerClear47, q));
    if (edge == 2)
        q = fract(q / size) * size;
    if (edge == 3)
        q = (1 - abs(fract(q / (2 * size)) * 2 - 1)) * size;
    return float4(image.sample(layerRead47, q));
}
static float2 velocity47(texture2d<half> map, float2 q) {
    float4 c = float4(map.sample(layerRead47, q));
    return c.a > 0 ? straight47(c).rg * 2 - 1 : float2(0);
}
static float2 transport47(texture2d<half> map, float2 q, float travel, uint steps) {
    for (uint index = 0; index < steps; index++) {
        float2 v = velocity47(map, q), middle = q + v * travel / (2 * float(steps));
        q += velocity47(map, middle) * travel / float(steps);
    }
    return q;
}
static float3 channel47(float4 c, uint channel) {
    float3 rgb = straight47(c);
    return channel == 0 ? rgb
                        : float3(channel == 4   ? c.a
                                 : channel == 5 ? dot(rgb, float3(.2126, .7152, .0722))
                                                : rgb[min(channel - 1, 2u)]);
}
kernel void fxLayerInteraction47(texture2d<half> source [[texture(0)]],
                                 texture2d<half, access::write> output [[texture(1)]],
                                 texture2d<half> reference [[texture(2)]],
                                 texture2d<half> sourceSoft [[texture(3)]],
                                 texture2d<half> referenceSoft [[texture(4)]], texture2d<half> flow [[texture(5)]],
                                 constant EffectParams &p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height())
        return;
    float2 q = float2(gid) + .5, size = float2(output.get_width(), output.get_height());
    float4 original = float4(source.sample(layerRead47, q)), ref = float4(reference.sample(layerRead47, q)),
           result = original;
    float3 color = straight47(original);
    uint steps = uint(clamp(round(p.d.w), 1.0, 32.0));
    switch (p.i.x) {
    case 0: {
        float3 a = channel47(original, p.i.y), b = channel47(ref, p.i.z), c;
        switch (p.i.w) {
        case 0:
            c = a * b;
            break;
        case 1:
            c = a + b;
            break;
        case 2:
            c = a - b;
            break;
        case 3:
            c = abs(a - b);
            break;
        case 4:
            c = a / max(float3(.001), b);
            break;
        case 5:
            c = min(a, b);
            break;
        default:
            c = max(a, b);
            break;
        }
        c = max(float3(0), c * p.a.z + p.b.x);
        if (p.d.w > 0) {
            float alpha = clamp(dot(c, float3(.2126, .7152, .0722)), 0.0, 1.0);
            result = float4(color * alpha, alpha);
        } else
            result = float4(c * original.a, original.a);
        break;
    }
    case 1:
        result = sample47(source, mix(q, straight47(ref).rg * size, p.a.z * .01), p.i.z);
        break;
    case 2: {
        float2 delta = q - p.c.xy;
        float length = max(.001, sqrt(dot(delta, delta)));
        float2 radial = delta / length, tangent = float2(-radial.y, radial.x), v = velocity47(reference, q);
        result = sample47(source, q + p.a.x * (radial * v.x + tangent * v.y * p.a.z), p.i.z);
        break;
    }
    case 3:
    case 11: {
        float2 uv = transport47(reference, q, p.a.x, min(steps, 16u));
        float4 moved = sample47(source, uv, p.i.z);
        result = p.i.x == 11 ? float4(color * moved.a, moved.a) : moved;
        break;
    }
    case 4: {
        steps = clamp(steps, 2u, 24u);
        float2 point = q - velocity47(reference, q) * p.a.x * .5;
        float total = 0;
        result = float4(0);
        for (uint i = 0; i < steps; i++) {
            float weight = exp(-p.a.z * abs(float(i) / float(steps - 1) - .5));
            result += sample47(source, point, p.i.z) * weight;
            total += weight;
            point = transport47(reference, point, p.a.x / float(steps - 1), 1);
        }
        result /= max(.001, total);
        break;
    }
    case 5: {
        float e = p.a.w;
        float2 g = float2(luma47(float4(referenceSoft.sample(layerRead47, q + float2(e, 0)))) -
                              luma47(float4(referenceSoft.sample(layerRead47, q - float2(e, 0)))),
                          luma47(float4(referenceSoft.sample(layerRead47, q + float2(0, e)))) -
                              luma47(float4(referenceSoft.sample(layerRead47, q - float2(0, e))))) /
                   (2 * e);
        float2 offset = g / sqrt(1 + dot(g, g)) * p.a.x * (1 - 1 / p.a.z);
        float4 a = sample47(source, q + offset * (1 + p.b.x), p.i.z), b = sample47(source, q + offset, p.i.z),
               c = sample47(source, q + offset * (1 - p.b.x), p.i.z);
        float alpha = max(a.a, max(b.a, c.a));
        result = float4(float3(straight47(a).r, straight47(b).g, straight47(c).b) * alpha, alpha);
        break;
    }
    case 6: {
        steps = clamp(steps, 4u, 24u);
        float radius = p.a.x * smoothstep(0.0, max(.001, p.b.x), abs(luma47(ref) - p.a.z));
        result = float4(0);
        for (uint i = 0; i < steps; i++) {
            float angle = float(i) * 2.39996323, r = sqrt((float(i) + .5) / float(steps)) * radius;
            result += sample47(source, q + float2(cos(angle), sin(angle)) * r, p.i.z) / float(steps);
        }
        break;
    }
    case 7: {
        float cell = max(2.0, p.a.y);
        float2 base = floor(q / cell);
        float4 stamp = float4(0);
        for (int y = -1; y <= 1; y++)
            for (int x = -1; x <= 1; x++) {
                float2 index = base + float2(x, y), seed = index + p.d.z;
                if (hash47(seed) > p.a.z)
                    continue;
                float2 center =
                    (index + .5) * cell + (float2(hash47(seed + 13), hash47(seed + 47)) - .5) * 2 * p.a.x;
                float2 local = q - center;
                float angle = (hash47(seed + 93) * 2 - 1) * p.d.x, c = cos(angle), s = sin(angle);
                local = float2(c * local.x - s * local.y, s * local.x + c * local.y);
                float2 uv = local / (cell * max(.1, p.b.x)) + .5;
                if (any(uv < 0) || any(uv > 1))
                    continue;
                float4 tile = float4(reference.sample(layerRead47, uv * size));
                stamp = tile + stamp * (1 - tile.a);
            }
        result = float4((stamp.rgb + color * (1 - stamp.a)) * original.a, original.a);
        break;
    }
    case 8: {
        float3 a = straight47(float4(sourceSoft.sample(layerRead47, q))),
               b = straight47(float4(referenceSoft.sample(layerRead47, q))), sa = 0, sb = 0;
        const float2 axis[4] = {float2(1, 0), float2(-1, 0), float2(0, 1), float2(0, -1)};
        for (uint i = 0; i < 4; i++) {
            float3 da = straight47(float4(source.sample(layerRead47, q + axis[i] * p.a.y))) - a,
                   db = straight47(float4(reference.sample(layerRead47, q + axis[i] * p.a.y))) - b;
            sa += da * da * .25;
            sb += db * db * .25;
        }
        float3 ratio = pow(clamp(sqrt((sb + .0001) / (sa + .0001)), float3(.25), float3(4)), float3(p.b.x));
        result = float4(max(float3(0), mix(color, b + (color - a) * ratio, p.a.z * .01)) * original.a, original.a);
        break;
    }
    case 9: {
        float3 a = straight47(float4(sourceSoft.sample(layerRead47, q))),
               b = straight47(float4(referenceSoft.sample(layerRead47, q)));
        result = float4(max(float3(0), a + (color - a) * p.b.x + (straight47(ref) - b) * p.a.z) * original.a,
                        original.a);
        break;
    }
    case 10: {
        float t = p.a.z * .01, value = luma47(ref);
        if (p.i.y == 1)
            value = 1 - value;
        float keep = t <= 0 ? 1 : t >= 1 ? 0 : smoothstep(t - p.b.x, t + p.b.x, value);
        result = original * keep;
        break;
    }
    case 12: {
        float3 n = straight47(ref) * 2 - 1;
        n = dot(n, n) > 1.e-8 ? normalize(n) : float3(0, 0, 1);
        float3 light = float3(cos(p.d.x) * cos(p.d.y), sin(p.d.x) * cos(p.d.y), sin(p.d.y)),
               h = normalize(light + float3(0, 0, 1));
        float3 f0 = mix(float3(.04), clamp(color, float3(0), float3(1)), p.b.y);
        float3 lightColor = p.c.rgb * p.c.a;
        result = float4((color * p.a.y + color * p.a.z * max(0.0, dot(n, light)) * lightColor +
                         f0 * p.d.z * pow(max(0.0, dot(n, h)), p.b.x) * lightColor) *
                            original.a,
                        original.a);
        break;
    }
    case 13: {
        float depth = max(0.0, (luma47(ref) - p.b.x) / max(.001, p.b.y - p.b.x)), fog = 1 - exp(-depth * p.a.z);
        result = float4(mix(color, p.c.rgb, fog * p.c.a) * original.a, original.a);
        break;
    }
    case 14: {
        steps = clamp(steps, 4u, 32u);
        float2 ray = float2(cos(p.d.x), sin(p.d.x)) * p.a.x, point = q, previous = q;
        float before = -1, after = 0;
        for (uint i = 0; i <= steps; i++) {
            float t = float(i) / float(steps);
            point = q + ray * t;
            float height =
                clamp(.5 + (luma47(float4(reference.sample(layerRead47, point))) - .5) * p.b.x, 0.0, 1.0);
            after = height - (1 - t);
            if (after >= 0)
                break;
            before = after;
            previous = point;
        }
        float weight = after - before > 1.e-6 ? clamp(-before / (after - before), 0.0, 1.0) : 1;
        result = sample47(source, mix(previous, point, weight), p.i.z);
        break;
    }
    case 15: {
        float3 rgb = straight47(ref);
        float value = p.i.z == 3 ? ref.a : p.i.z == 4 ? luma47(ref) : rgb[min(p.i.z, 2u)];
        value = max(0.0, value * p.a.z + p.b.x);
        if (p.i.y == 3) {
            float alpha = clamp(value, 0.0, 1.0);
            result = float4(color * alpha, alpha);
        } else {
            color[min(p.i.y, 2u)] = value;
            result = float4(color * original.a, original.a);
        }
        break;
    }
    case 16: {
        float2 fieldSize = float2(flow.get_width(), flow.get_height());
        float4 measured = float4(flow.sample(layerRead47, q / size * fieldSize));
        float reliability = smoothstep(p.b.y, p.b.y + .2, measured.b);
        result = sample47(source, q - measured.rg * size / fieldSize * p.a.x * reliability, p.i.z);
        break;
    }
    case 17: {
        float occlusion = 0, depth = luma47(ref);
        for (uint direction = 0; direction < 8; direction++)
            for (uint j = 1; j <= 4; j++) {
                float angle = float(direction) * .785398163;
                float t = float(j) / 4;
                float neighbor =
                    luma47(float4(reference.sample(layerRead47, q + float2(cos(angle), sin(angle)) * p.a.y * t)));
                occlusion += max(0.0, (depth - neighbor) * p.d.z - p.b.x) * (1 - t * .6) / 32;
            }
        result = float4(original.rgb * (1 - clamp(occlusion * p.a.z, 0.0, .95)), original.a);
        break;
    }
    case 18: {
        float center = luma47(float4(referenceSoft.sample(layerRead47, q))), occlusion = 0;
        float2 direction = float2(cos(p.d.x), sin(p.d.x));
        float heightScale = max(1.0, min(size.x, size.y) * .15 * p.a.z);
        for (uint i = 1; i <= 16; i++) {
            float travel = p.a.x * float(i) / 16;
            float neighbor = luma47(float4(referenceSoft.sample(layerRead47, q + direction * travel)));
            float obstruction = neighbor - center - travel * tan(p.b.y) / heightScale - p.b.x;
            occlusion = max(occlusion, smoothstep(0.0, .05, obstruction));
        }
        result = float4(original.rgb * (1 - .8 * occlusion), original.a);
        break;
    }
    case 19: {
        float u = pow(clamp(luma47(original), 0.0, 1.0), 1 / p.a.z) + p.b.x;
        if (p.i.y == 1)
            u = fract(u);
        else if (p.i.y == 2)
            u = 1 - abs(fract(u * .5) * 2 - 1);
        else
            u = clamp(u, 0.0, 1.0);
        float4 c = float4(reference.sample(layerRead47, float2(u * size.x, p.a.x * size.y)));
        result = float4((c.a > 1.e-6 ? straight47(c) : color) * original.a, original.a);
        break;
    }
    }
    result.rgb = clamp(result.rgb, float3(0), float3(65504));
    result.a = clamp(result.a, 0.0, 1.0);
    output.write(half4(mix(original, result, p.b.w)), gid);
}
