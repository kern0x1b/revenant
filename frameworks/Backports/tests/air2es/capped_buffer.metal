#include <metal_stdlib>
using namespace metal;

struct CappedOut {
    float4 position [[position]];
};

vertex CappedOut callBlobVertex(uint vid [[vertex_id]], const device float *positions [[buffer(1)]]) {
    CappedOut out;
    out.position = float4(positions[vid % 7], positions[2], 0.0, 1.0);
    return out;
}

vertex CappedOut uncappedVertex(uint vid [[vertex_id]], const device float *positions [[buffer(1)]]) {
    CappedOut out;
    out.position = float4(positions[vid % 7], 0.0, 0.0, 1.0);
    return out;
}
