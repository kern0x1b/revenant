// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Rasterize triangles whose pixels a guest GLSL ES fragment shader colours.

#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string>
#include <vector>

#include "graphics/gles_rasterizer.hpp"
#include "graphics/glsl_es.hpp"

namespace shade {

struct DisplayFrame;

// One vertex as the vertex shader left it: gl_Position and the values of its
// varyings, laid out as GlesShadedVarying says.
struct GlesShadedVertex {
    std::array<float, 4> position { 0.0F, 0.0F, 0.0F, 1.0F };
    std::vector<float> varyings;
};

// Where a varying of the fragment shader starts in GlesShadedVertex::varyings.
// The floats of an array follow each other, element by element.
struct GlesShadedVarying {
    const glsl::Variable* variable { };
    std::uint32_t offset { };
};

// The most floats of varyings a program may pass from its vertex shader to its
// fragment shader (the device has eight vectors of four).
inline constexpr std::uint32_t maximum_shaded_varying_floats = 32U;

// How the varyings of a vertex shader reach the fragment shader of the same
// program: the fragment shader's varyings fix the order, and each is read from
// the vertex shader's variable of that name.
struct GlesVaryingLayout {
    struct Source {
        const glsl::Variable* written { };
        std::uint32_t offset { };
    };

    std::vector<GlesShadedVarying> fragment;
    std::vector<Source> vertex;
    std::uint32_t floats { };
};

// Fails, saying which varying, unless every varying the fragment shader reads
// is declared by the vertex shader with the same name, type and array size,
// and the program passes no more than maximum_shaded_varying_floats.
[[nodiscard]] bool layout_varyings(const glsl::Module& vertex,
    const glsl::Module& fragment, GlesVaryingLayout& layout, std::string& error);

// Copies the varyings a vertex shader run left into floats laid out as the
// layout says. Every write is checked against the size of the result.
[[nodiscard]] bool collect_varyings(const glsl::Instance& vertex,
    const GlesVaryingLayout& layout, std::vector<float>& floats,
    std::string& error);

class GlesShadedRasterizer {
public:
    // Draws the triangles of the primitive mode (triangles, strips and fans)
    // into frame with the viewport, scissor, colour mask and blend factors of
    // state; a texture is sampled through state.texture_units[unit] for the
    // unit a sampler uniform holds. Output is stored as the shader wrote it,
    // not premultiplied again. Returns false, with the reason in error, when
    // the primitive is not one of those or the shader cannot run.
    [[nodiscard]] static bool draw(DisplayFrame& frame,
        std::span<const GlesShadedVertex> vertices, std::uint32_t mode,
        const GlesRasterState& state, glsl::Instance& fragment,
        std::span<const GlesShadedVarying> varyings, std::string& error);
};

} // namespace shade
