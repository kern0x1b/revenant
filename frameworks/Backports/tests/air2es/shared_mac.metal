#include <metal_stdlib>
using namespace metal;

struct SharedOut {
    float4 position [[position]];
    float2 uv;
};

constant float2 corners[6] = {float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, -1), float2(1, 1), float2(-1, 1)};

struct StoneUniforms {
    float4 viewport;
    float4 parameters;
};

struct LensFields {
    float4 viewport;
    float4 parameters;
};

vertex SharedOut sharedVertex(uint vid [[vertex_id]]) {
    SharedOut out;
    out.position = float4(corners[vid], 0.0, 1.0);
    out.uv = corners[vid] * 0.5 + 0.5;
    return out;
}

fragment float4 sharedFragment(SharedOut in [[stage_in]],
                               constant StoneUniforms &u [[buffer(1)]],
                               constant LensFields &lens [[buffer(3)]]) {
    float2 p = (in.position.xy - lens.viewport.xy) / lens.viewport.z;
    return float4(p.x * u.viewport.z, p.y * lens.viewport.w, u.parameters.x, lens.parameters.y);
}
