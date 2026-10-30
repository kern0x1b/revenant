#include "samplers.h"

#include <cstdio>

namespace air2es {

const std::vector<SamplerRow> &samplerTable()
{
    static const std::vector<SamplerRow> rows = {
#include "samplers.inc"
    };
    return rows;
}

namespace {

std::string hex(uint64_t value)
{
    char text[32];
    snprintf(text, sizeof text, "0x%016llx", (unsigned long long)value);
    return text;
}

const char *const kClampToZero = "a clamp-to-zero address, which OpenGL ES 2 does not have";

bool wrapping(const std::string &mode, std::string &glsl, std::string &refusal)
{
    if (mode == "clamp_to_edge" || mode == "repeat") {
        glsl = mode;
        return true;
    }
    if (mode == "mirrored_repeat")
        refusal = "a mirrored repeat address, which OpenGL ES 2 does not have";
    else if (mode == "clamp_to_zero")
        refusal = kClampToZero;
    else
        refusal = "an address mode this emitter does not know: " + mode;
    return false;
}

bool filtering(const std::string &mode, std::string &glsl)
{
    if (mode != "nearest" && mode != "linear")
        return false;
    glsl = mode;
    return true;
}

}

bool decodeSampler(uint64_t state, const std::vector<SamplerRow> &table, GLESSampler &out, std::string &refusal)
{
    for (const SamplerRow &row : table) {
        if (row.state != state)
            continue;
        if (!wrapping(row.s, out.wrapS, refusal) || !wrapping(row.t, out.wrapT, refusal)) {
            // A linear filter blends the edge texels with the zero border, and an emulation of that needs the texture size.
            if (refusal == kClampToZero && (std::string(row.min) == "linear" || std::string(row.mag) == "linear"))
                refusal = "a linear filter and a clamp-to-zero address: the edge texels read as zero, which OpenGL ES 2 does not have, and an emulation needs the size of the texture";
            return false;
        }
        if (!filtering(row.min, out.minFilter) || !filtering(row.mag, out.magFilter)) {
            refusal = std::string("a filter this emitter does not know: ") + row.min + " and " + row.mag;
            return false;
        }
        if (std::string(row.mip) != "none") {
            refusal = std::string("a ") + row.mip + " mipmap filter, and the textures of a translated shader have no mipmaps";
            return false;
        }
        if (std::string(row.coord) != "normalized") {
            refusal = "pixel coordinates, which the translated shader does not scale to texture coordinates";
            return false;
        }
        if (row.lodMin > 0.0f) {
            refusal = "a level-of-detail clamp that starts above zero, which OpenGL ES 2 does not clamp";
            return false;
        }
        if (row.anisotropy > 1) {
            refusal = "anisotropic filtering, which OpenGL ES 2 does not have";
            return false;
        }
        return true;
    }
    refusal = "a constexpr sampler with the state " + hex(state) +
              " that the sampler table does not carry: derive it with tools/metal_sampler_table.lua";
    return false;
}

}
