#include <metal_stdlib>
using namespace metal;

struct FlagOut {
    float4 position [[position]];
    float2 uv;
};

constant float2 corners[6] = {float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, -1), float2(1, 1), float2(-1, 1)};

vertex FlagOut flagVertex(uint vid [[vertex_id]]) {
    FlagOut out;
    out.position = float4(corners[vid % 6], 0.0, 1.0);
    out.uv = corners[vid % 6] * 0.5 + 0.5;
    return out;
}

__attribute__((noinline)) float pick(float x) {
    return x > 0.3 ? x : 0.3 * x;
}

fragment float4 flagFragment(FlagOut in [[stage_in]]) {
    float acc = 0.0;
    bool first = true;
    bool current = true;
#pragma clang loop unroll(disable)
    do {
        current = first;
        acc += pick(in.uv.x * (current ? 0.8 : 0.4));
        first = false;
    } while (current);
    return float4(acc * 0.5 + 0.5, in.uv.y, 0.5, 1.0);
}
