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

// Each instance reads its own element of a constant buffer (instanceStride), and a uniform array element picked by an
// int uniform. The color is (tint.x, gain[pick].y, tint.z), so every column shows the element of its own instance.
struct InstanceQuad {
    float4 rect;
    float4 tint;
};

struct InstanceFrame {
    float4 gain[3];
};

vertex InstanceVertex element_column_vertex(uint vid [[vertex_id]], uint iid [[instance_id]],
                                            device const float2 *corners [[buffer(0)]],
                                            constant InstanceQuad *quads [[buffer(1)]],
                                            constant InstanceFrame &frame [[buffer(2)]],
                                            constant int &pick [[buffer(3)]]) {
    float2 corner = corners[vid];
    constant InstanceQuad &quad = quads[iid];
    InstanceVertex out;
    out.position = float4((float(iid) + corner.x) * (2.0 / 3.0) - 1.0, corner.y, 0.0, 1.0);
    out.color = float4(quad.tint.x, frame.gain[pick].y, quad.tint.z, 1.0);
    return out;
}

fragment float4 element_column_fragment(InstanceVertex in [[stage_in]]) {
    return in.color;
}

// The matrix frame. The vertex stage multiplies a known vector by the model and then the projection, and writes the
// products and one element of each matrix into the color, so the host compares each channel with its own reference.
struct MatrixFrame {
    float4x4 model;
    float4x4 projection;
    float3x3 normal;
};

vertex InstanceVertex matrix_column_vertex(uint vid [[vertex_id]], uint iid [[instance_id]],
                                           device const float2 *corners [[buffer(0)]],
                                           constant MatrixFrame &frame [[buffer(1)]]) {
    float2 corner = corners[vid];
    float4 p = frame.projection * (frame.model * float4(1.0, 2.0, 3.0, 1.0));
    InstanceVertex out;
    out.position = float4((float(iid) + corner.x) * (2.0 / 3.0) - 1.0, corner.y, 0.0, 1.0);
    out.color = float4(p.x / 255.0, p.y / 255.0, frame.model[3][1] / 255.0, frame.normal[2][1] / 255.0);
    return out;
}

fragment float4 matrix_column_fragment(InstanceVertex in [[stage_in]]) {
    return in.color;
}
