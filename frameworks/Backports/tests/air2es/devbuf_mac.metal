#include <metal_stdlib>
using namespace metal;

struct BlobOut {
    float4 position [[position]];
};

struct BlobSettings {
    float4 viewport;
};

vertex BlobOut callBlobVertex(uint vid [[vertex_id]], const device float *positions [[buffer(1)]]) {
    BlobOut out;
    float x = positions[vid % 7];
    out.position = float4(x, x * x - 0.2, 0.0, 1.0);
    return out;
}

fragment float4 blobFragment(BlobOut in [[stage_in]], constant BlobSettings &settings [[buffer(2)]]) {
    return float4(in.position.xy * (settings.viewport.z / 128.0), settings.viewport.w, 1.0);
}
