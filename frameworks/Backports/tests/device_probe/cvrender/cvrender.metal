#include <metal_stdlib>
using namespace metal;

// The render-pass checks of CVRenderProbe. The fill writes a known pattern into a CoreVideo texture, which the CPU then
// reads from the pixel buffer. The copy samples a CoreVideo texture through the clean texture coordinates that
// CVMetalTextureGetCleanTexCoords returns, so a flipped texture comes out in the orientation of its pixel buffer.

constexpr sampler pixelSampler(coord::normalized, address::clamp_to_edge, filter::nearest);

struct VertexOut {
    float4 position [[position]];
};

// A strip of four vertices covers the whole target.
vertex VertexOut cv_quad_vertex(uint vid [[vertex_id]])
{
    float v = float(vid);
    float row = floor(v * 0.5);
    VertexOut out;
    out.position = float4(2.0 * v - 4.0 * row - 1.0, 2.0 * row - 1.0, 0.0, 1.0);
    return out;
}

// The pattern of cvplanes_main.m, which has the +0.25 offset so the byte conversion is exact.
fragment float4 cv_fill(float4 position [[position]])
{
    float x = floor(position.x);
    float y = floor(position.y);
    return float4(fmod(x * 3.0 + y * 5.0, 256.0) + 0.25, fmod(x * 7.0 + y * 2.0 + 11.0, 256.0) + 0.25,
                  fmod(x * 2.0 + y * 9.0 + 23.0, 256.0) + 0.25, 255.25) / 255.0;
}

struct CleanCoords {
    float2 lowerLeft;
    float2 lowerRight;
    float2 upperRight;
    float2 upperLeft;
};

fragment float4 cv_copy(float4 position [[position]], texture2d<half> src [[texture(0)]],
                        constant CleanCoords &clean [[buffer(0)]])
{
    float2 f = position.xy / 64.0;
    float2 top = mix(clean.upperLeft, clean.upperRight, f.x);
    float2 bottom = mix(clean.lowerLeft, clean.lowerRight, f.x);
    float2 uv = mix(top, bottom, f.y);
    return float4(src.sample(pixelSampler, uv));
}
