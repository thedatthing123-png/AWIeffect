#include <metal_stdlib>
using namespace metal;
struct EffectParams {
    float4 a, b, c, d;
    uint4 i;
};
constexpr sampler clamp48(address::clamp_to_edge, filter::linear, coord::pixel);
constexpr sampler clear48(address::clamp_to_zero, filter::linear, coord::pixel);
static float4 sm48(texture2d<half> t, float2 q) {
    return float4(t.sample(clear48, q));
}
static float3 rgb48(float4 c) {
    return c.a > 1e-6 ? c.rgb / c.a : float3(0);
}
static float lum48(float4 c) {
    return dot(rgb48(c), float3(.2126, .7152, .0722));
}
static float hash48(float2 q) {
    return fract(sin(dot(q, float2(127.1, 311.7))) * 43758.5453);
}
static float2 rot48(float2 q, float a) {
    return float2(cos(a) * q.x - sin(a) * q.y, sin(a) * q.x + cos(a) * q.y);
}
static float2 grad48(texture2d<half> t, float2 q, float h) {
    return float2(lum48(sm48(t, q + float2(h, 0))) - lum48(sm48(t, q - float2(h, 0))),
                  lum48(sm48(t, q + float2(0, h))) - lum48(sm48(t, q - float2(0, h)))) /
           (2 * h);
}
static float seg48(float2 q, float2 a, float2 b) {
    float2 d = b - a;
    return length(q - a - d * clamp(dot(q - a, d) / max(dot(d, d), 1e-5), 0.0, 1.0));
}
static float4 over48(float4 a, float4 b) {
    return a + b * (1 - a.a);
}
static float4 node48(texture2d<float, access::read> t, int2 q) {
    if (any(q < 0) || q.x >= int(t.get_width()) || q.y >= int(t.get_height()))
        return 0;
    return t.read(uint2(q));
}
// Prepare bounded chord integrals or image-feature nodes once, not once per output pixel.
kernel void fxCraftPrepare48(texture2d<half> source [[texture(0)]],
                             texture2d<float, access::write> nodes [[texture(1)]],
                             texture2d<half> soft [[texture(2)]], constant EffectParams &p [[buffer(0)]],
                             constant float4 *layout [[buffer(1)]], uint2 g [[thread_position_in_grid]]) {
    if (g.x >= nodes.get_width() || g.y >= nodes.get_height())
        return;
    float2 size = layout[0].xy, origin = layout[0].zw;
    float cell = max(p.a.x, 1.0);
    float4 result = 0;
    if (p.i.x == 6) {
        float a = float(g.x) / float(nodes.get_width()) * 6.2831853 + p.d.x,
              b = fract(float(g.x) * .6180339 + p.d.z * .071 + p.d.y * .03) * 6.2831853;
        float r = min(size.x, size.y) * .46;
        float2 x = origin + size * .5 + r * float2(cos(a), sin(a)),
               y = origin + size * .5 + r * float2(cos(b), sin(b));
        if (g.y == 0)
            result = float4(x, y);
        else {
            float4 sum = 0;
            for (uint k = 0; k < 12; k++)
                sum += sm48(source, mix(x, y, (float(k) + .5) / 12));
            sum /= 12;
            result = float4(rgb48(sum), clamp((1 - lum48(sum)) * sum.a * p.a.z, 0.0, 1.0));
        }
    } else {
        int2 start = int2(floor(-origin / cell));
        float2 center = origin + (float2(int2(g) + start) + .5) * cell;
        if (p.i.x == 13) {
            float2 gradient = grad48(soft, center, max(1.0, p.d.w));
            float2 q = center + gradient / max(length(gradient), .01) * cell * p.a.y * .01;
            float4 c = sm48(source, q);
            result = float4(q, lum48(c), c.a);
        } else {
            float best = -1;
            for (uint k = 0; k < 9; k++) {
                float2 q = center + (float2(int(k) % 3, int(k) / 3) - 1) * cell * .25;
                q += float2(sin(p.d.y + hash48(center + p.d.z) * 6.28),
                            cos(p.d.y + hash48(center - p.d.z) * 6.28)) *
                     cell * .08;
                float xx = 0, xy = 0, yy = 0;
                for (int j = -1; j <= 1; j++)
                    for (int i = -1; i <= 1; i++) {
                        float2 v = grad48(soft, q + float2(i, j) * p.a.y, max(.5, p.d.w));
                        xx += v.x * v.x;
                        xy += v.x * v.y;
                        yy += v.y * v.y;
                    }
                float score = max(0.0, (xx * yy - xy * xy) / max(xx + yy, 1e-6)) * as_type<float>(p.i.z) * 12;
                if (score > best) {
                    best = score;
                    result = float4(q, clamp(score, 0.0, 4.0), sm48(source, q).a);
                }
            }
        }
    }
    nodes.write(result, g);
}
kernel void fxCraft48(texture2d<half> source [[texture(0)]], texture2d<half, access::write> output [[texture(1)]],
                      texture2d<half> soft [[texture(2)]], texture2d<float, access::read> field [[texture(3)]],
                      texture2d<float, access::read> nodes [[texture(4)]],
                      texture2d<half> reference [[texture(5)]],
                      texture2d<half, access::write> background [[texture(6)]],
                      constant EffectParams &p [[buffer(0)]], constant float4 *layout [[buffer(1)]],
                      uint2 g [[thread_position_in_grid]]) {
    if (g.x >= output.get_width() || g.y >= output.get_height())
        return;
    float2 q = float2(g) + .5, size = float2(output.get_width(), output.get_height()), origin = layout[0].zw,
           layerSize = layout[0].xy, local = q - origin;
    float u = max(.35, p.d.w), cell = max(p.a.x, 1.0);
    float4 original = sm48(source, q), base = original, result = original;
    float3 color = rgb48(original), light = 0;
    uint mode = p.i.x;
    if (mode == 0) {
        float2 point = rot48(local, p.d.x), id = floor(point / cell), v = fract(point / cell) - .5;
        float4 sample = sm48(source, origin + rot48((id + .5) * cell, -p.d.x));
        float radius = .48 * pow(clamp(1 - lum48(sample), 0.0, 1.0), p.a.y) * p.a.z;
        float d = length(v);
        if (p.i.y == 1)
            d = abs(v.x) + abs(v.y);
        if (p.i.y == 2)
            d = min(max(abs(v.x), abs(v.y) * 3), max(abs(v.x) * 3, abs(v.y)));
        if (p.i.y == 3)
            d = max(abs(v.x) * .4, abs(v.y));
        float coverage = 1 - smoothstep(radius - u / cell, radius + u / cell, d);
        float4 ink = p.b, paper = p.c;
        float4 c = mix(paper, ink, coverage);
        result = float4(c.rgb * c.a * original.a, c.a * original.a);
    }
    if (mode == 1 || mode == 2 || mode == 14) {
        uint2 at = uint2(clamp(q / size * float2(field.get_width(), field.get_height()), float2(0),
                               float2(field.get_width() - 1, field.get_height() - 1)));
        float2 seed = field.read(at).xy;
        if (seed.x >= 0) {
            float2 gradient = 0;
            for (uint axis = 0; axis < 2; axis++) {
                float2 off = axis == 0 ? float2(u, 0) : float2(0, u);
                float4 a = sm48(source, seed + off), b = sm48(source, seed - off);
                gradient[axis] = p.i.w == 0 ? a.a - b.a : lum48(a) * a.a - lum48(b) * b.a;
            }
            float2 n = length(gradient) > .0001 ? -normalize(gradient) : normalize(q - seed + float2(.0001, 0));
            float2 tangent = float2(-n.y, n.x);
            float value = p.i.w == 0 ? original.a : lum48(original) * original.a;
            float distance = length(q - seed) * (value >= as_type<float>(p.i.z) ? 1 : -1);
            if (mode == 1) {
                float phase = dot(seed - origin, tangent) / cell;
                float along = (phase - round(phase)) * cell;
                float2 v = float2(dot(q - seed, n), along);
                float d = max(abs(v.x) - p.a.y * .5, abs(v.y) - p.a.z * .5);
                float a = (1 - smoothstep(-u, u, d)) * p.b.a;
                result = over48(float4(p.b.rgb * a, a), original);
            }
            if (mode == 2 && distance < 0) {
                float travel = -distance / max(p.a.x, .01);
                float phase = dot(seed - origin, tangent) / max(p.a.y, 1.0) - p.a.z * travel * travel;
                float d = abs(phase - round(phase)) * p.a.y;
                float width = u * (1 - travel) * 1.2;
                float a = (1 - smoothstep(width, width + u, d)) * (1 - smoothstep(.95, 1.0, travel));
                float4 edge = sm48(source, seed - n * 2 * u);
                float3 c = mix(rgb48(edge), p.b.rgb, p.b.a);
                result = over48(original, float4(c * a * edge.a, a * edge.a));
            }
            if (mode == 14 && p.a.x > 0) {
                float remaining = smoothstep(p.a.x - u, p.a.x + u, distance);
                float charFactor = smoothstep(p.a.x + p.a.y, p.a.x + p.a.y + p.a.z, distance);
                base = float4(color * mix(float3(.025), float3(1), charFactor) * original.a * remaining,
                              original.a * remaining);
                light = p.b.rgb * p.b.a * exp(-abs(distance - p.a.x) / max(p.a.y, .1)) * base.a * 3;
            }
        }
        if (mode == 14)
            result = float4(light, clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0));
    }
    if (mode == 3) {
        float levels = max(2.0, round(p.a.x)), l = lum48(original), level = floor(l * levels);
        float shadow = 0;
        float2 direction = float2(cos(p.d.x), sin(p.d.x));
        for (uint k = 1; k <= 8; k++) {
            float other = floor(lum48(sm48(source, q - direction * p.a.y * float(k) / 4)) * levels);
            shadow = max(shadow, other > level ? exp(-float(k) * .3) : 0.0);
        }
        float quantized = (level + .5) / levels;
        result = float4(color * quantized / max(l, .02) * (1 - shadow * p.a.z) * original.a, original.a);
    }
    if (mode == 4) {
        float2 v = rot48(local, p.d.x);
        float f = fract(v.x / cell + p.a.y * .5), shift = (f - .5) * cell * p.a.z;
        float2 at = q + rot48(float2(shift, 0), -p.d.x);
        float4 a = sm48(source, at),
               b = float4(
                   reference.sample(clear48, at / size * float2(reference.get_width(), reference.get_height())));
        result = mix(a, b, smoothstep(.47, .53, f));
    }
    if (mode == 5) {
        float2 id = floor(local / cell), v = (fract(local / cell) - .5) * 2;
        float tilt = p.a.y * .0174533 + sin(hash48(id + p.d.z) * 6.283 + p.d.y) * .25;
        float3 normal = normalize(float3(sin(tilt), .2 * sin(p.d.y + hash48(id)), cos(tilt)));
        float d = length(float2(v.x / max(.2, abs(cos(tilt))), v.y));
        float a = (1 - smoothstep(1 - p.a.z - u / cell, 1 - p.a.z + u / cell, d));
        float4 c = sm48(source, origin + (id + .5) * cell);
        float shading =
            .4 + .6 * max(0.0, normal.z) + pow(max(0.0, dot(normal, normalize(float3(-.4, -.5, 1)))), 30) * 2;
        result = float4(rgb48(c) * shading * c.a * a, c.a * a);
    }
    if (mode == 6) {
        float coverage = 0;
        for (uint k = 0; k < nodes.get_width(); k++) {
            float4 ends = nodes.read(uint2(k, 0)), weight = nodes.read(uint2(k, 1));
            float line = 1 - smoothstep(p.a.y * .5, p.a.y * .5 + u, seg48(q, ends.xy, ends.zw));
            coverage += line * weight.a * .3;
        }
        float4 c = mix(p.c, p.b, clamp(coverage, 0.0, 1.0));
        result = float4(c.rgb * c.a * original.a, c.a * original.a);
    }
    if (mode == 7 || mode == 13) {
        int2 start = int2(floor(-origin / cell)), id = int2(floor(local / cell)) - start;
        for (int j = -1; j <= 1; j++)
            for (int i = -1; i <= 1; i++) {
                int2 index = id + int2(i, j);
                float4 n = node48(nodes, index);
                if (n.w <= 0)
                    continue;
                if (mode == 7) {
                    float reach = cell * p.a.z;
                    float2 v = rot48(q - n.xy, p.d.x);
                    float d = min(seg48(v, float2(-reach, 0), float2(reach, 0)),
                                  seg48(v, float2(0, -reach), float2(0, reach)));
                    light += p.b.rgb * p.b.a * n.z * n.w * exp(-d / max(.7, u)) *
                             (1 - smoothstep(reach * .65, reach, length(v)));
                } else {
                    if (p.i.y == 1)
                        light += rgb48(sm48(source, n.xy)) * p.b.rgb * p.b.a *
                                 exp(-length(q - n.xy) / max(u, p.a.z)) * n.w;
                    for (uint k = 0; k < 3; k++) {
                        int2 off = k == 0 ? int2(1, 0) : k == 1 ? int2(0, 1) : int2(1, 1);
                        float4 m = node48(nodes, index + off);
                        float strength =
                            smoothstep(as_type<float>(p.i.z), as_type<float>(p.i.z) + .1, (n.z + m.z) * .5) *
                            min(n.w, m.w);
                        float line = 1 - smoothstep(p.a.z * .5, p.a.z * .5 + u, seg48(q, n.xy, m.xy));
                        light += (rgb48(sm48(source, n.xy)) + rgb48(sm48(source, m.xy))) * .5 * p.b.rgb * p.b.a *
                                 line * strength;
                    }
                }
            }
        result = float4(light, clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0));
    }
    if (mode == 8) {
        float2 at = q;
        for (uint k = 0; k < 8; k++) {
            float2 gradient = grad48(soft, at, u), tangent = rot48(float2(-gradient.y, gradient.x), p.d.x);
            tangent /= max(length(tangent), .001);
            float4 c = sm48(source, at);
            float edge = length(rgb48(c) - rgb48(sm48(soft, at))) * c.a;
            light += p.b.rgb * p.b.a * edge * p.a.z / 8;
            at -= tangent * p.a.x / 8;
        }
        result = float4(light, clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0));
    }
    if (mode == 9) {
        float weight = 0;
        for (uint k = 0; k < 12; k++) {
            float f = float(k) / 11, w = exp(-f * p.a.z);
            for (uint channel = 0; channel < 3; channel++) {
                float angle = p.d.x + (float(channel) - 1) * .25;
                float2 at = q - f * p.a.x * float2(cos(angle), sin(angle));
                float4 c = sm48(source, at);
                light[channel] += abs(rgb48(c)[channel] - rgb48(sm48(soft, at))[channel]) * c.a * w;
            }
            weight += w;
        }
        light = light / max(weight, .01) * p.b.rgb * p.b.a * 4;
        result = float4(light, clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0));
    }
    if (mode == 10) {
        float2 gradient = grad48(soft, q, u);
        float c = lum48(sm48(soft, q)),
              xx = (lum48(sm48(soft, q + float2(u, 0))) + lum48(sm48(soft, q - float2(u, 0))) - 2 * c) / (u * u),
              yy = (lum48(sm48(soft, q + float2(0, u))) + lum48(sm48(soft, q - float2(0, u))) - 2 * c) / (u * u);
        float xy = (lum48(sm48(soft, q + float2(u, u))) - lum48(sm48(soft, q + float2(u, -u))) -
                    lum48(sm48(soft, q + float2(-u, u))) + lum48(sm48(soft, q - float2(u, u)))) /
                   (4 * u * u);
        float det = (1 - p.a.x * xx) * (1 - p.a.x * yy) - p.a.x * p.a.x * xy * xy;
        float focus = clamp(1 / max(.08, abs(det)) - 1, 0.0, 8.0) * p.a.z;
        base = sm48(source, q - gradient * p.a.x);
        light = base.rgb * focus * p.b.rgb * p.b.a;
        result = float4(light, clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0));
    }
    if (mode == 11) {
        float2 gradient = grad48(soft, q, u), n = gradient / max(length(gradient), .001);
        float4 a = sm48(source, q + n * p.a.x), b = sm48(source, q - n * p.a.x);
        base = float4(float3(rgb48(a).r, color.g, rgb48(b).b) * original.a, original.a);
        float edge = max(0.0, abs(lum48(original) - lum48(sm48(soft, q))) - p.a.z);
        light = p.b.rgb * p.b.a * edge * original.a * 5;
        result = float4(light, clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0));
    }
    if (mode == 12) {
        result = 0;
        int2 id = int2(floor(local / cell));
        for (int j = -1; j <= 1; j++)
            for (int i = -1; i <= 1; i++) {
                float2 key = float2(id + int2(i, j));
                float2 center = origin + (key + .5) * cell +
                                (float2(hash48(key + p.d.z), hash48(key + 17 + p.d.z)) - .5) * cell * p.a.y;
                float angle = (hash48(key + 8 + p.d.z) - .5) * 2 * p.a.z * .0174533 +
                              sin(p.d.y + hash48(key)) * p.a.z * .003 + p.d.x;
                float2 v = rot48(q - center, -angle);
                float d = max(abs(v.x), abs(v.y));
                float coverage = 1 - smoothstep(cell * .46 - u, cell * .46 + u, d);
                float4 c = sm48(source, origin + (key + .5) * cell + v);
                float2 shadowLocal = rot48(q - center - float2(2, 3) * u, -angle);
                float shadow =
                    (1 - smoothstep(cell * .46, cell * .46 + 3 * u, max(abs(shadowLocal.x), abs(shadowLocal.y)))) *
                    .25 * sm48(source, origin + (key + .5) * cell).a;
                result = over48(float4(0, 0, 0, shadow), result);
                float border = 1 - smoothstep(cell * .46 - as_type<float>(p.i.z) - u,
                                              cell * .46 - as_type<float>(p.i.z) + u, d);
                float present = sm48(source, origin + (key + .5) * cell).a;
                float4 paper = float4(p.c.rgb * p.c.a, p.c.a);
                c = mix(paper, c, border);
                c *= coverage * present;
                result = over48(c, result);
            }
    }
    background.write(half4(clamp(base, -65500.0, 65500.0)), g);
    output.write(half4(clamp(result, -65500.0, 65500.0)), g);
}
