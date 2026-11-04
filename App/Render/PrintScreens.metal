#include <metal_stdlib>
using namespace metal;
struct ScreenParams { float4 a,b,c,d; uint4 i; };
constexpr sampler screenSampler(coord::pixel, address::clamp_to_zero, filter::linear);
float2x2 screenRotation(float angle) { return float2x2(cos(angle), sin(angle), -sin(angle), cos(angle)); }
float screenPlate(texture2d<half, access::sample> src, float2 xy, constant ScreenParams& p, float angle, int channel) {
    float2x2 rotation = screenRotation(angle);
    float2 grid = rotation * (xy - p.d.zw) * p.a.x;
    float row = floor(grid.y + 0.5), shift = (int(row) & 1) != 0 ? p.a.z : 0;
    float2 center = float2(floor(grid.x + shift + 0.5) - shift, row);
    float4 sample = float4(src.sample(screenSampler, transpose(rotation) * (center / p.a.x) + p.d.zw));
    float black = min(1 - sample.r, min(1 - sample.g, 1 - sample.b)) * p.d.x;
    float3 cmy = black >= 0.99999 ? float3(0) : (1 - sample.rgb - black) / max(1e-5, 1 - black);
    float ink = channel == 3 ? black : cmy[channel];
    return smoothstep(0.4, 0.6, max(0.0, 2 * p.a.y - length(grid - center)) * ink) * sample.a;
}
kernel void fxPrintScreens(texture2d<half, access::sample> src [[texture(0)]], texture2d<half, access::write> dst [[texture(1)]],
                           constant ScreenParams& p [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 xy = float2(gid) + 0.5;
    float4 original = float4(src.sample(screenSampler, xy)), result;
    if (p.i.x == 0) {
        float cyan = screenPlate(src, xy, p, p.a.w + M_PI_F / 12, 0);
        float magenta = screenPlate(src, xy, p, p.a.w + M_PI_F * 5 / 12, 1);
        float yellow = screenPlate(src, xy, p, p.a.w, 2);
        float black = screenPlate(src, xy, p, p.a.w + M_PI_F / 4, 3);
        result = float4(saturate(float3(1 - cyan - black, 1 - magenta - black, 1 - yellow - black)) * original.a, original.a);
    } else {
        float2x2 rotation = screenRotation(p.a.w);
        float2 grid = rotation * (xy - p.d.zw) * p.a.x;
        float nearest = floor(grid.y + p.a.z + 0.5) - p.a.z;
        float distance = abs(grid.y - nearest);
        float2 samplePoint = transpose(rotation) * (float2(grid.x, nearest) / p.a.x) + p.d.zw;
        float4 sample = float4(src.sample(screenSampler, samplePoint));
        float luminance = dot(sample.rgb, float3(0.2126, 0.7152, 0.0722));
        float weight = smoothstep(0.4, 0.6, luminance + 1 - sample.a + distance + p.a.y - 0.5);
        float4 ink = float4(p.b.rgb * p.b.a, p.b.a), paper = float4(p.c.rgb * p.c.a, p.c.a);
        result = mix(ink, paper, weight) * original.a;
    }
    dst.write(half4(mix(original, result, p.d.y)), gid);
}
