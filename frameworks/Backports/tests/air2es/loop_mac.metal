#include <metal_stdlib>
using namespace metal;

struct LoopOut {
    float4 position [[position]];
    float2 uv;
};

struct LoopSettings {
    float4 viewport;
};

constant float2 corners[6] = {float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, -1), float2(1, 1), float2(-1, 1)};

vertex LoopOut loopVertex(uint vid [[vertex_id]]) {
    LoopOut out;
    out.position = float4(corners[vid % 6], 0.0, 1.0);
    out.uv = corners[vid % 6] * 0.5 + 0.5;
    return out;
}

fragment float4 loopFragment(LoopOut in [[stage_in]], const device float4 *planes [[buffer(1)]],
                             constant LoopSettings &settings [[buffer(2)]]) {
    float acc = 0.0;
    int last = -1;
    for (uint i = 0; i < uint(settings.viewport.z); ++i) {
        acc += planes[i].x * in.uv.x + planes[i].y * in.uv.y + planes[i].z;
        last = int(i);
    }
    return float4(acc * 0.05 + 0.5, float(last) * 0.1 + 0.5, in.uv.y, 1.0);
}
