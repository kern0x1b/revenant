#include <metal_stdlib>
using namespace metal;

// One fragment function per intrinsic that air2es maps to GLSL ES 1.00. Each reads the texel at its pixel centre and
// applies the intrinsic, and es2_main.m computes the same value on the host (revenant_expect) for the same texel
// bytes. The function names are the map keys of that reference, so a function and its check share a name.
// The r8 and rg8 functions read a plane the way NV12 is read: the first channel of R8, and the first two of RG8.

constexpr sampler pixelSampler(coord::normalized, address::clamp_to_edge, filter::nearest);

static half4 texel(texture2d<half> src, float4 position)
{
    float2 size = float2(src.get_width(), src.get_height());
    return src.sample(pixelSampler, position.xy / size);
}

fragment float4 fast_saturate_f32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    return float4(saturate(float(v.x) * 2.0 - 0.5), 0.0, 0.0, 1.0);
}

fragment float4 fast_saturate_v2f32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    float2 s = saturate(float2(v.xy) * 2.0 - 0.5);
    return float4(s, 0.0, 1.0);
}

fragment float4 fast_saturate_v3f32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    float3 s = saturate(float3(v.xyz) * 2.0 - 0.5);
    return float4(s, 1.0);
}

fragment float4 fabs_v3f16(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    half3 a = abs(v.xyz - 0.5h);
    return float4(float3(a), 1.0);
}

fragment float4 dot_v2f16(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    half d = dot(v.xy, v.zw);
    return float4(float(d) * 0.5, 0.0, 0.0, 1.0);
}

fragment float4 mix_v2f32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    float2 m = mix(float2(v.xy), float2(v.zw), float2(v.w));
    return float4(m, 0.0, 1.0);
}

fragment float4 mix_v3f16(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    half3 m = mix(v.xyz, half3(0.25h), v.w);
    return float4(float3(m), 1.0);
}

fragment float4 mix_v4f16(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    half4 m = mix(v, v.wzyx, 0.5h);
    return float4(m);
}

fragment float4 fmin_v3f16(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    half3 m = min(v.xyz, half3(0.5h));
    return float4(float3(m), 1.0);
}

fragment float4 fmin_f16(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    half m = min(v.x, v.y);
    return float4(float(m), 0.0, 0.0, 1.0);
}

fragment float4 tan_f16(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    half t = tan(v.x * 0.7h);
    return float4(float(t), 0.0, 0.0, 1.0);
}

fragment float4 fast_tan_f32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    float t = tan(float(v.x) * 0.7);
    return float4(t, 0.0, 0.0, 1.0);
}

fragment float4 sqrt_f16(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    half s = sqrt(v.x);
    return float4(float(s), 0.0, 0.0, 1.0);
}

fragment float4 clamp_v3f16(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    half3 c = clamp(v.xyz, 0.25h, 0.75h);
    return float4(float3(c), 1.0);
}

fragment float4 fast_exp_f32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    float e = exp(-3.0 * float(v.x));
    return float4(e, 0.0, 0.0, 1.0);
}

fragment float4 sin_f16(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    half s = sin(v.x * 3.0h) * 0.5h + 0.5h;
    return float4(float(s), 0.0, 0.0, 1.0);
}

fragment float4 cos_f16(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    half c = cos(v.x * 3.0h) * 0.5h + 0.5h;
    return float4(float(c), 0.0, 0.0, 1.0);
}

fragment float4 fast_floor_f32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    float f = floor(float(v.x) * 4.0) * 0.25;
    return float4(f, 0.0, 0.0, 1.0);
}

fragment float4 fast_fmax_v3f32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    float3 m = max(float3(v.xyz), 0.5);
    return float4(m, 1.0);
}

fragment float4 fast_pow_v3f32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    float3 p = pow(float3(v.xyz), float3(2.0));
    return float4(p, 1.0);
}

// The derivative of a linear ramp is the same for any pair of neighbours, so this checks fwidth without relying on how
// the device picks the neighbour: the ramp rises 0.25 per 64 pixels in x and 0.5 per 64 in y, so fwidth is 0.75 / 64.
fragment float4 fwidth_f32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    float ramp = position.x / 64.0 * 0.25 + position.y / 64.0 * 0.5;
    float w = fwidth(ramp) * 16.0;
    return float4(w, 0.0, 0.0, 1.0);
}

// A switch on a value with three cases and a default, each arm writing one value, so the translator lowers a switch
// terminator as an if / else if chain with a phi.
fragment float4 switch_f32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    float a = 0.25;
    switch (int(float(v.x) * 3.0 + 0.5)) {
        case 0:
            a = float(v.y);
            break;
        case 1:
            a = float(v.z) * 0.5;
            break;
        case 2:
            a = 1.0 - float(v.w);
            break;
        default:
            break;
    }
    return float4(a, 0.0, 0.0, 1.0);
}

// The planes of NV12 as the Metal backport binds them: R8 for luma and RG8 for chroma.
fragment float4 r8(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    return float4(float(v.x), 0.0, 0.0, 1.0);
}

fragment float4 rg8(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    return float4(float(v.x), float(v.y), 0.0, 1.0);
}

// The unsigned integer max, divide and remainder of compositeRoundVideo. Both operands are bytes of the texel, converted
// from float the way the kernel converts its own operands, and the divisor is a maximum, so it is never zero.
fragment float4 max_u_i32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    uint p = uint(float(v.x) * 255.0 + 0.5);
    uint q = uint(float(v.y) * 255.0 + 0.5);
    return float4(float(max(p, q)) / 255.0, 0.0, 0.0, 1.0);
}

fragment float4 udiv_u_i32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    uint p = uint(float(v.x) * 255.0 + 0.5);
    uint q = uint(float(v.y) * 255.0 + 0.5);
    return float4(float(p / max(q, 1u)) / 255.0, 0.0, 0.0, 1.0);
}

fragment float4 urem_u_i32(float4 position [[position]], texture2d<half> src [[texture(0)]])
{
    half4 v = texel(src, position);
    uint p = uint(float(v.x) * 255.0 + 0.5);
    uint q = uint(float(v.y) * 255.0 + 0.5);
    return float4(float(p % max(q, 1u)) / 255.0, 0.0, 0.0, 1.0);
}
