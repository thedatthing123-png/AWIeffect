#include <metal_stdlib>
using namespace metal;
// Reference: supplied AE Motion 2.5 BuiltinEffects/ridges2.xml.
// Simplex noise and ridged multifractal equations retained; native Metal texture/compositing adapter.
struct ParamsAM35 { float4 a; float4 b; float4 c; float4 d; uint4 i; };
constexpr sampler sampleAM35(coord::pixel, address::clamp_to_zero, filter::linear);



        float3 mod289AM35(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
        float2 mod289AM35(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
        float4 mod289AM35(float4 x) {
          return x - floor(x * (1.0 / 289.0)) * 289.0;
        }

        float3 permuteAM35(float3 x) { return mod289AM35(((x*34.0)+1.0)*x); }
        float4 permuteAM35(float4 x) {
             return mod289AM35(((x*34.0)+1.0)*x);
        }

        float snoiseAM35(float2 v) {

            // Precompute values for skewed triangular grid
            const float4 C = float4(0.211324865405187,
                                // (3.0-sqrt(3.0))/6.0
                                0.366025403784439,
                                // 0.5*(sqrt(3.0)-1.0)
                                -0.577350269189626,
                                // -1.0 + 2.0 * C.x
                                0.024390243902439);
                                // 1.0 / 41.0

            // First corner (x0)
            float2 i  = floor(v + dot(v, C.yy));
            float2 x0 = v - i + dot(i, C.xx);

            // Other two corners (x1, x2)
            float2 i1 = float2(0.0);
            i1 = (x0.x > x0.y)? float2(1.0, 0.0):float2(0.0, 1.0);
            float2 x1 = x0.xy + C.xx - i1;
            float2 x2 = x0.xy + C.zz;

            // Do some permutations to avoid
            // truncation effects in permutation
            i = mod289AM35(i);
            float3 p = permuteAM35(
                    permuteAM35( i.y + float3(0.0, i1.y, 1.0))
                        + i.x + float3(0.0, i1.x, 1.0 ));

            float3 m = max(0.5 - float3(
                                dot(x0,x0),
                                dot(x1,x1),
                                dot(x2,x2)
                                ), 0.0);

            m = m*m ;
            m = m*m ;

            // Gradients:
            //  41 pts uniformly over a line, mapped onto a diamond
            //  The ring size 17*17 = 289 is close to a multiple
            //      of 41 (41*7 = 287)

            float3 x = 2.0 * fract(p * C.www) - 1.0;
            float3 h = abs(x) - 0.5;
            float3 ox = floor(x + 0.5);
            float3 a0 = x - ox;

            // Normalise gradients implicitly by scaling m
            // Approximation of: m *= inversesqrt(a0*a0 + h*h);
            m *= 1.79284291400159 - 0.85373472095314 * (a0*a0+h*h);

            // Compute final noise value at P
            float3 g = float3(0.0);
            g.x  = a0.x  * x0.x  + h.x  * x0.y;
            g.yz = a0.yz * float2(x1.x,x2.x) + h.yz * float2(x1.y,x2.y);
            return 130.0 * dot(m, g);
        }


        float4 taylorInvSqrtAM35(float4 r)
        {
          return 1.79284291400159 - 0.85373472095314 * r;
        }

        float snoiseAM35(float3 v)
          {
          const float2  C = float2(1.0/6.0, 1.0/3.0) ;
          const float4  D = float4(0.0, 0.5, 1.0, 2.0);

        // First corner
          float3 i  = floor(v + dot(v, C.yyy) );
          float3 x0 =   v - i + dot(i, C.xxx) ;

        // Other corners
          float3 g = step(x0.yzx, x0.xyz);
          float3 l = 1.0 - g;
          float3 i1 = min( g.xyz, l.zxy );
          float3 i2 = max( g.xyz, l.zxy );

          //   x0 = x0 - 0.0 + 0.0 * C.xxx;
          //   x1 = x0 - i1  + 1.0 * C.xxx;
          //   x2 = x0 - i2  + 2.0 * C.xxx;
          //   x3 = x0 - 1.0 + 3.0 * C.xxx;
          float3 x1 = x0 - i1 + C.xxx;
          float3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
          float3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

        // Permutations
          i = mod289AM35(i);
          float4 p = permuteAM35( permuteAM35( permuteAM35(
                     i.z + float4(0.0, i1.z, i2.z, 1.0 ))
                   + i.y + float4(0.0, i1.y, i2.y, 1.0 ))
                   + i.x + float4(0.0, i1.x, i2.x, 1.0 ));

        // Gradients: 7x7 points over a square, mapped onto an octahedron.
        // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
          float n_ = 0.142857142857; // 1.0/7.0
          float3  ns = n_ * D.wyz - D.xzx;

          float4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

          float4 x_ = floor(j * ns.z);
          float4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

          float4 x = x_ *ns.x + ns.yyyy;
          float4 y = y_ *ns.x + ns.yyyy;
          float4 h = 1.0 - abs(x) - abs(y);

          float4 b0 = float4( x.xy, y.xy );
          float4 b1 = float4( x.zw, y.zw );

          //float4 s0 = float4(lessThan(b0,0.0))*2.0 - 1.0;
          //float4 s1 = float4(lessThan(b1,0.0))*2.0 - 1.0;
          float4 s0 = floor(b0)*2.0 + 1.0;
          float4 s1 = floor(b1)*2.0 + 1.0;
          float4 sh = -step(h, float4(0.0));

          float4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
          float4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

          float3 p0 = float3(a0.xy,h.x);
          float3 p1 = float3(a0.zw,h.y);
          float3 p2 = float3(a1.xy,h.z);
          float3 p3 = float3(a1.zw,h.w);

        //Normalise gradients
          float4 norm = taylorInvSqrtAM35(float4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
          p0 *= norm.x;
          p1 *= norm.y;
          p2 *= norm.z;
          p3 *= norm.w;

        // Mix final noise value
          float4 m = max(0.6 - float4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
          m = m * m;
          return 42.0 * dot( m*m, float4( dot(p0,x0), dot(p1,x1),
                                        dot(p2,x2), dot(p3,x3) ) );
          }

        //float turbulence (float2 st, int OCTAVES, float2 parallax) {
        //    // Initial values
        //    float value = 0.0;
        //    float amplitude = .5;
        //    float frequency = 0.;
        //    //
        //    // Loop of octaves
        //    for (int i = 0; i < OCTAVES; i++) {
        //        value += amplitude * abs(snoiseAM35(st));
        //        st *= 2.;
        //        st += parallax;
        //        amplitude *= .5;
        //    }
        //    return value;
        //}

        float ridgeAM35(float h, float offset) {
            h = abs(h);     // create creases
            h = offset - h; // invert so creases are at top
            h = h * h;      // sharpen creases
            return h;
        }

        float ridgedMFAM35(float2 p, int OCTAVES, float2 parallax, float evo) {
            float lacunarity = 2.0;
            float gain = 0.5;
            float offset = 0.9;

            float sum = 0.0;
            float freq = 1.0, amp = 0.5;
            float prev = 1.0;
            for(int i=0; i < OCTAVES; i++) {
                float n = ridgeAM35(snoiseAM35(float3(p*freq,evo)), offset);
                sum += n*amp;
                sum += n*amp*prev;  // scale by previous octave
                prev = n;
                freq *= lacunarity;
                p += parallax;
                amp *= gain;
            }
            return sum;
        }


        
kernel void fxFractalRidgesAM35(texture2d<half, access::sample> src [[texture(0)]],
                               texture2d<half, access::write> dst [[texture(1)]],
                               constant ParamsAM35& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 original = float4(src.sample(sampleAM35, float2(gid) + 0.5));
    if (original.a <= 0.0 || p.d.w <= 0.0) { dst.write(half4(original), gid); return; }
    float2 st = (float2(gid) + 0.5 - p.a.xy) / max(p.a.zw, float2(1.0));
    st.x *= p.a.z / max(p.a.w, 1.0);
    st += p.b.xy * float2(-1.0, 1.0) / 500.0;
    float2 seed = float2(821.921, 437.317) * p.d.z;
    st += seed - floor(seed / float2(4.365, 7.701)) * float2(4.365, 7.701);
    float2 parallax = p.b.zw * float2(-1.0, 1.0) / 100.0;
    float2 scale = max(p.c.x * p.c.yz, float2(0.0001));
    float value = ridgedMFAM35((st - 0.5) / scale + 0.5, int(p.i.x), parallax, p.c.w) * p.d.x;
    // RGBA8 endpoint constants include alpha; noise is evaluated at full float precision.
    uint ca = p.i.y, cb = p.i.z;
    float4 colorA = float4(float((ca >> 24) & 255), float((ca >> 16) & 255), float((ca >> 8) & 255), float(ca & 255)) / 255.0;
    float4 colorB = float4(float((cb >> 24) & 255), float((cb >> 16) & 255), float((cb >> 8) & 255), float(cb & 255)) / 255.0;
    float4 color = mix(colorA, colorB, clamp(value, 0.0, 1.0));
    float4 result = float4(color.rgb * color.a, color.a) * original.a;
    result += original * (1.0 - color.a);
    dst.write(half4(mix(original, result, p.d.w)), gid);
}
