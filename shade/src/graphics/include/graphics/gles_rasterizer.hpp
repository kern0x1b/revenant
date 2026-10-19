// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Rasterize guest GLES primitives and texture blends in software.

#pragma once

#include <array>
#include <cstdint>
#include <span>

#include "graphics/gles_abi.hpp"

namespace shade {

class DisplayState;
class GlesResourceStore;
struct DisplayFrame;

struct GlesRasterVertex {
    std::array<float, 4> position { 0.0F, 0.0F, 0.0F, 1.0F };
    std::array<float, 4> color { 1.0F, 1.0F, 1.0F, 1.0F };
    std::array<std::array<float, 2>, gles_abi::texture_unit_count> texture { };
};

struct GlesTextureEnvironment {
    std::uint32_t mode { gles_abi::modulate };
    std::array<float, 4> color { };
    std::uint32_t combine_rgb { gles_abi::modulate };
    std::uint32_t combine_alpha { gles_abi::modulate };
    std::array<std::uint32_t, 3> rgb_sources { gles_abi::texture_source,
        gles_abi::previous, gles_abi::constant };
    std::array<std::uint32_t, 3> alpha_sources { gles_abi::texture_source,
        gles_abi::previous, gles_abi::constant };
    std::array<std::uint32_t, 3> rgb_operands { gles_abi::source_color,
        gles_abi::source_color, gles_abi::source_alpha };
    std::array<std::uint32_t, 3> alpha_operands { gles_abi::source_alpha,
        gles_abi::source_alpha, gles_abi::source_alpha };
    float rgb_scale { 1.0F };
    float alpha_scale { 1.0F };
};

struct GlesRasterTextureUnit {
    std::uint32_t texture { };
    GlesTextureEnvironment environment;
    bool enabled { };
    bool rectangle { };
};

struct GlesRasterState {
    // Separates per-context texture namespaces from a shared render target.
    std::uint64_t resource_owner { };
    std::int32_t viewport_x { };
    std::int32_t viewport_y { };
    std::uint32_t viewport_width { };
    std::uint32_t viewport_height { };
    const GlesResourceStore* resources { };
    std::array<GlesRasterTextureUnit, gles_abi::texture_unit_count>
        texture_units { };
    bool blend_enabled { };
    bool scissor_enabled { };
    std::array<std::int32_t, 4> scissor_box { };
    std::array<bool, 4> color_mask { true, true, true, true };
    std::uint32_t blend_source { };
    std::uint32_t blend_destination { };
    std::array<float, 4> blend_constant { };
    std::uint32_t cull_mode { gles_abi::back };
    std::uint32_t front_face { gles_abi::counter_clockwise };
    float line_width { 1.0F };
    bool cull_enabled { };
    bool render_target_inverted_vertical { };
    // Local GLES framebuffer textures are consumed by the firmware as
    // premultiplied source-over images. Keep this target-local so imported
    // CoreSurface scanout layers retain their existing alpha semantics.
    bool render_target_premultiplied { };
};

[[nodiscard]] std::uint32_t premultiply_argb(std::uint32_t pixel);

// Samples level 0 of the texture a unit names at (s, t) with the texture's
// own wrap and filter modes; gradient is the derivative of (s, t) per pixel
// in x then y, which picks the minification or magnification filter. Returns
// opaque white where the unit has no complete texture.
[[nodiscard]] std::uint32_t sample_raster_texture(const GlesRasterState& state,
    const GlesRasterTextureUnit& unit, float s, float t,
    const std::array<float, 4>& gradient);

class GlesSoftwareRasterizer {
public:
    static bool draw(DisplayFrame& frame,
        std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
        const GlesRasterState& state);
    static bool draw(DisplayState& display,
        std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
        const GlesRasterState& state);
};

} // namespace shade
