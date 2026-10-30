#include <metal_stdlib>
using namespace metal;

struct InstanceVertex {
    float4 position [[position]];
    float4 color;
};

vertex InstanceVertex instance_column_vertex(uint vid [[vertex_id]], uint iid [[instance_id]],
                                             device const float2 *corners [[buffer(0)]]) {
    float2 corner = corners[vid];
    InstanceVertex out;
    out.position = float4((float(iid) + corner.x) * (2.0 / 3.0) - 1.0, corner.y, 0.0, 1.0);
    out.color = float4(float(iid + 1u) / 255.0, 0.0, 0.0, 1.0);
    return out;
}

fragment float4 instance_column_fragment(InstanceVertex in [[stage_in]]) {
    return in.color;
}
