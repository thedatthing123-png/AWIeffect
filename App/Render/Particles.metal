#include <metal_stdlib>
using namespace metal;

// Particle System: stateless particles (each one's whole life is a function of its index + time), drawn as
// instanced quads into the layer's buffer. Premultiplied rgba16Float like the rest of the renderer.
struct ParticleUniforms {
    float4 emit;      // x,y center (buffer px), z,w size (buffer px)
    float4 life;      // x rate /s, y life s, z life random 0-1, w time s
    float4 motion;    // x speed px/s, y speed random 0-1, z direction rad, w spread rad
    float4 forces;    // x gravity px/s², y wind px/s², z turbulence px, w turbulence scale px
    float4 look;      // x size px, y size random 0-1, z size at end (x of start), w opacity
    float4 fade;      // x fade in 0-1 of life, y fade out 0-1, z spin rad/s, w spin random 0-1
    float4 colorA;    // start color (straight rgb, a)
    float4 colorB;    // end color
    float4 view;      // x depth spread px, y focal px, z buffer width, w buffer height
    uint4  mode;      // x emitter (0 point,1 box,2 line,3 ring), y sprite, z count, w seed
};

struct PVOut {
    float4 pos [[position]];
    float2 uv;
    float4 color;     // premultiplied
    float sprite;
};

static float ph(float n) { return fract(sin(n * 12.9898 + 78.233) * 43758.5453); }
static float pnoise(float3 p) {
    float3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n = i.x + i.y * 57.0 + i.z * 113.0;
    return mix(mix(mix(ph(n), ph(n + 1.0), f.x), mix(ph(n + 57.0), ph(n + 58.0), f.x), f.y),
               mix(mix(ph(n + 113.0), ph(n + 114.0), f.x), mix(ph(n + 170.0), ph(n + 171.0), f.x), f.y), f.z) * 2.0 - 1.0;
}

vertex PVOut particleVertex(uint vid [[vertex_id]], uint iid [[instance_id]], constant ParticleUniforms& u [[buffer(0)]]) {
    PVOut o;
    o.pos = float4(-2.0, -2.0, 0.0, 1.0); o.uv = 0.0; o.color = 0.0; o.sprite = 0.0;
    float rate = max(u.life.x, 0.01);
    float n = float(u.mode.z);
    float cycleLen = n / rate;
    float t = u.life.w;
    float born0 = float(iid) / rate;
    float cycle = floor((t - born0) / cycleLen);
    if (t < born0) return o;
    float birth = born0 + cycle * cycleLen;
    float seed = float(iid) * 1.618 + cycle * 97.13 + float(u.mode.w) * 31.7;
    float r1 = ph(seed), r2 = ph(seed + 1.1), r3 = ph(seed + 2.3), r4 = ph(seed + 3.7), r5 = ph(seed + 4.9), r6 = ph(seed + 6.1);
    float life = u.life.y * (1.0 - u.life.z * r1);
    float age = t - birth;
    if (age < 0.0 || age > life) return o;
    float k = age / max(life, 1e-4);

    // Emitter shape.
    float2 p0 = u.emit.xy;
    if (u.mode.x == 1u) p0 += (float2(r2, r3) - 0.5) * u.emit.zw;
    else if (u.mode.x == 2u) p0 += float2((r2 - 0.5) * u.emit.z, 0.0);
    else if (u.mode.x == 3u) { float a = r2 * 6.2831853; p0 += float2(cos(a), sin(a)) * u.emit.zw * 0.5; }

    float ang = u.motion.z + (r4 - 0.5) * u.motion.w;
    float spd = u.motion.x * (1.0 - u.motion.y * r5);
    float2 v0 = float2(cos(ang), sin(ang)) * spd;
    float2 pos = p0 + v0 * age + 0.5 * float2(u.forces.y, u.forces.x) * age * age;
    float2 vel = v0 + float2(u.forces.y, u.forces.x) * age;
    if (u.forces.z > 0.0) {
        float sc = max(u.forces.w, 1.0);
        float3 q = float3(pos / sc, age * 0.6 + seed * 0.01);
        pos += float2(pnoise(q), pnoise(q + 19.7)) * u.forces.z * k;
    }
    // Depth: particles spread in z, smaller and closer to the center when far (parallax).
    float z = (r6 - 0.5) * u.view.x;
    float persp = u.view.y / max(u.view.y + z, 1.0);
    float2 center = u.view.zw * 0.5;
    pos = center + (pos - center) * persp;

    float size = u.look.x * (1.0 - u.look.y * r3) * mix(1.0, u.look.z, k) * persp;
    float alpha = u.look.w;
    if (u.fade.x > 0.0) alpha *= clamp(k / u.fade.x, 0.0, 1.0);
    if (u.fade.y > 0.0) alpha *= clamp((1.0 - k) / u.fade.y, 0.0, 1.0);
    float4 col = mix(u.colorA, u.colorB, k);
    alpha *= col.a;

    float2 corner = float2((vid & 1u) ? 1.0 : -1.0, (vid & 2u) ? 1.0 : -1.0);
    float2 axisX, axisY;
    if (u.mode.y == 2u) {
        // Spark: stretched along its motion (built-in motion blur).
        float2 d = length(vel) > 1e-3 ? normalize(vel) : float2(1.0, 0.0);
        float len = max(size, length(vel) * 0.035 * persp + size);
        axisX = d * len * 0.5; axisY = float2(-d.y, d.x) * size * 0.25;
    } else {
        float rot = u.fade.z * (1.0 - u.fade.w * r2) * age + r4 * 6.2831853;
        float cs = cos(rot), sn = sin(rot);
        axisX = float2(cs, sn) * size * 0.5; axisY = float2(-sn, cs) * size * 0.5;
    }
    float2 px = pos + axisX * corner.x + axisY * corner.y;
    o.pos = float4(px.x / u.view.z * 2.0 - 1.0, 1.0 - px.y / u.view.w * 2.0, 0.0, 1.0);
    o.uv = corner * 0.5 + 0.5;
    o.color = float4(col.rgb * alpha, alpha);
    o.sprite = float(u.mode.y);
    return o;
}

fragment half4 particleFragment(PVOut in [[stage_in]], texture2d<half, access::sample> custom [[texture(0)]]) {
    float2 q = in.uv * 2.0 - 1.0;
    float r = length(q);
    float a;
    uint s = uint(in.sprite + 0.5);
    if (s == 0u) a = pow(max(1.0 - r, 0.0), 2.2);                                   // soft glow
    else if (s == 1u) a = 1.0 - smoothstep(0.8, 1.0, r);                              // dot
    else if (s == 2u) a = pow(max(1.0 - length(float2(q.x * 0.6, q.y)), 0.0), 1.5);  // spark core
    else if (s == 3u) {                                                                // star
        float ang = atan2(q.y, q.x);
        float spike = 0.35 + 0.65 * pow(abs(cos(ang * 2.5)), 6.0);
        a = 1.0 - smoothstep(spike * 0.85, spike, r);
        a = max(a, pow(max(1.0 - r, 0.0), 3.0));
    } else if (s == 4u) {                                                              // shard
        float d = abs(q.x) * 1.6 + abs(q.y) * 0.7;
        a = 1.0 - smoothstep(0.85, 1.0, d);
    } else if (s == 5u) a = smoothstep(0.55, 0.75, r) * (1.0 - smoothstep(0.85, 1.0, r)); // ring
    else {                                                                             // custom layer
        constexpr sampler cs(address::clamp_to_zero, filter::linear);
        float4 c = float4(custom.sample(cs, in.uv));
        return half4(c * in.color.a);
    }
    return half4(in.color * a);
}
