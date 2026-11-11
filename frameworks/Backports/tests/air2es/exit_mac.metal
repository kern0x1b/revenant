#include <metal_stdlib>
using namespace metal;

struct ExitOut {
    float4 position [[position]];
    float2 uv;
};

constant float2 corners[6] = {float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, -1), float2(1, 1), float2(-1, 1)};

vertex ExitOut exitVertex(uint vid [[vertex_id]]) {
    ExitOut out;
    out.position = float4(corners[vid % 6], 0.0, 1.0);
    out.uv = corners[vid % 6] * 0.5 + 0.5;
    return out;
}

fragment float4 exitFragment(ExitOut in [[stage_in]]) {
    float acc = 0.0;
    int last = 0;
    for (int i = 1; i < 7; i++) {
        float t = float(i) / 7.0;
        acc += t * in.uv.y;
        last = i;
        if (acc > in.uv.x) {
            acc -= t * 0.5;
            break;
        }
    }
    return float4(acc, float(last) / 7.0, in.uv.y, 1.0);
}
