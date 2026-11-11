#include <metal_stdlib>
using namespace metal;

struct SampleOut {
    float4 position [[position]];
    float2 uv;
};

constant float2 corners[6] = {float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, -1), float2(1, 1), float2(-1, 1)};

constexpr sampler nearestClamp(coord::normalized, address::clamp_to_edge, filter::nearest);

vertex SampleOut sampleVertex(uint vid [[vertex_id]]) {
    SampleOut out;
    out.position = float4(corners[vid % 6], 0.0, 1.0);
    out.uv = corners[vid % 6] * 0.5 + 0.5;
    return out;
}

fragment float4 sampleFragment(SampleOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
    return tex.sample(nearestClamp, in.uv);
}

fragment float4 sampleMinLodFragment(SampleOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
    return tex.sample(nearestClamp, in.uv, min_lod_clamp(1.0));
}
