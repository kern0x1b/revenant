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

struct GlesShadedVertex {
    std::array<float, 4> position { 0.0F, 0.0F, 0.0F, 1.0F };
    std::vector<float> varyings;
};

struct GlesShadedVarying {
    const glsl::Variable* variable { };
    std::uint32_t offset { };
};

inline constexpr std::uint32_t maximum_shaded_varying_floats = 32U;

struct GlesVaryingLayout {
    struct Source {
        const glsl::Variable* written { };
        std::uint32_t offset { };
    };

    std::vector<GlesShadedVarying> fragment;
    std::vector<Source> vertex;
    std::uint32_t floats { };
};

[[nodiscard]] bool layout_varyings(const glsl::Module& vertex,
    const glsl::Module& fragment, GlesVaryingLayout& layout, std::string& error);

[[nodiscard]] bool collect_varyings(const glsl::Instance& vertex,
    const GlesVaryingLayout& layout, std::vector<float>& floats,
    std::string& error);

class GlesShadedRasterizer {
public:
    [[nodiscard]] static bool draw(DisplayFrame& frame,
        std::span<const GlesShadedVertex> vertices, std::uint32_t mode,
        const GlesRasterState& state, glsl::Instance& fragment,
        std::span<const GlesShadedVarying> varyings, std::string& error);
};

}
