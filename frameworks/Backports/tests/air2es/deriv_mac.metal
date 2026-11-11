#include <metal_stdlib>
using namespace metal;

struct DerivOut {
    float4 position [[position]];
    float2 uv;
    float3 color;
};

constant float2 corners[6] = {float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, -1), float2(1, 1), float2(-1, 1)};

vertex DerivOut derivVertex(uint vid [[vertex_id]]) {
    DerivOut out;
    out.position = float4(corners[vid % 6], 0.0, 1.0);
    out.uv = corners[vid % 6] * 0.5 + 0.5;
    out.color = float3(out.uv.x * out.uv.y, out.uv.y, 0.5);
    return out;
}

fragment float4 derivFragment(DerivOut in [[stage_in]]) {
    float2 d = dfdx(in.uv) * 16.0 + 0.5;
    float w = fwidth(in.color).x * 32.0;
    return float4(d.x, d.y, w, 1.0);
}
