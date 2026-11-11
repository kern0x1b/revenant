#include <metal_stdlib>
using namespace metal;

struct MaskOut {
    float4 position [[position]];
    float2 uv;
};

constant float2 corners[6] = {float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, -1), float2(1, 1), float2(-1, 1)};

constant float2 ring[8] = {float2(0.2, 0.1), float2(0.7, 0.3), float2(0.4, 0.8), float2(-0.3, 0.6),
                           float2(-0.6, 0.1), float2(-0.5, -0.4), float2(0.1, -0.7), float2(0.5, -0.5)};

vertex MaskOut maskVertex(uint vid [[vertex_id]]) {
    MaskOut out;
    out.position = float4(corners[vid % 6], 0.0, 1.0);
    out.uv = corners[vid % 6] * 0.5 + 0.5;
    return out;
}

fragment float4 maskFragment(MaskOut in [[stage_in]]) {
    float acc = 0.0;
#pragma clang loop unroll(disable)
    for (uint i = 0; i < 8; ++i) {
        float2 a = ring[i % 8];
        float2 b = ring[(i + 1) % 8];
        acc += (a.x * b.y - a.y * b.x) + in.uv.x * (a.y - b.y);
    }
    return float4(acc * 0.05 + 0.5, in.uv.y, 0.5, 1.0);
}
