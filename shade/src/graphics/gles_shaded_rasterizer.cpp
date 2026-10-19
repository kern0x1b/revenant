// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Rasterize triangles whose pixels a guest GLSL ES fragment shader colours.

#include "graphics/gles_shaded_rasterizer.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>

#include "graphics/display.hpp"
#include "graphics/gles_abi.hpp"
#include "graphics/gles_resources.hpp"
#include "graphics/glsl_es.hpp"

namespace shade {
namespace {

    using Color = std::array<float, 4>;

    struct Vertex {
        float x { };
        float y { };
        float inverse_w { 1.0F };
        float depth { };
        std::span<const float> varyings;
    };

    float edge(const Vertex& a, const Vertex& b, float x, float y)
    {
        return (x - a.x) * (b.y - a.y) - (y - a.y) * (b.x - a.x);
    }

    // Top-left fill rule: a pixel centre exactly on an edge belongs to the
    // triangle only for an edge that runs up or leftwards.
    bool includes_boundary(const Vertex& a, const Vertex& b, float orientation)
    {
        const auto dx = orientation * (b.x - a.x);
        const auto dy = orientation * (b.y - a.y);
        return dy > 0.0F || (dy == 0.0F && dx < 0.0F);
    }

    Color unpack(std::uint32_t pixel)
    {
        return { static_cast<float>((pixel >> 16U) & 0xffU) / 255.0F,
            static_cast<float>((pixel >> 8U) & 0xffU) / 255.0F,
            static_cast<float>(pixel & 0xffU) / 255.0F,
            static_cast<float>((pixel >> 24U) & 0xffU) / 255.0F };
    }

    std::uint32_t pack(const Color& color)
    {
        const auto channel = [&](std::size_t component) {
            return static_cast<std::uint32_t>(
                std::lround(std::clamp(color[component], 0.0F, 1.0F) * 255.0F));
        };
        return (channel(3) << 24U) | (channel(0) << 16U) | (channel(1) << 8U) |
               channel(2);
    }

    float blend_factor(std::uint32_t factor, std::size_t component,
        const Color& source, const Color& destination, const Color& constant)
    {
        switch (factor) {
        case gles_abi::zero:
            return 0.0F;
        case gles_abi::one:
            return 1.0F;
        case gles_abi::source_color:
            return source[component];
        case gles_abi::one_minus_source_color:
            return 1.0F - source[component];
        case gles_abi::source_alpha:
            return source[3];
        case gles_abi::one_minus_source_alpha:
            return 1.0F - source[3];
        case gles_abi::destination_alpha:
            return destination[3];
        case gles_abi::one_minus_destination_alpha:
            return 1.0F - destination[3];
        case gles_abi::destination_color:
            return destination[component];
        case gles_abi::one_minus_destination_color:
            return 1.0F - destination[component];
        case gles_abi::source_alpha_saturate:
            return component == 3U
                       ? 1.0F
                       : std::min(source[3], 1.0F - destination[3]);
        case gles_abi::constant_color:
            return constant[component];
        case gles_abi::one_minus_constant_color:
            return 1.0F - constant[component];
        case gles_abi::constant_alpha:
            return constant[3];
        case gles_abi::one_minus_constant_alpha:
            return 1.0F - constant[3];
        default:
            return 1.0F;
        }
    }

    std::uint32_t apply_color_mask(std::uint32_t source,
        std::uint32_t destination, const std::array<bool, 4>& mask)
    {
        constexpr std::array<std::uint32_t, 4> channel_masks { 0x00ff0000U,
            0x0000ff00U, 0x000000ffU, 0xff000000U };
        auto result = destination;
        for (std::size_t component = 0; component < mask.size(); ++component) {
            if (!mask[component])
                continue;
            result = (result & ~channel_masks[component]) |
                     (source & channel_masks[component]);
        }
        return result;
    }

    // What texture2D reads. A texture that is missing or has no image reads
    // as opaque black, as GLSL ES defines. Without mipmaps the footprint is
    // taken as a magnification, so the magnification filter applies.
    class ShaderTextures final : public glsl::TextureAccess {
    public:
        explicit ShaderTextures(const GlesRasterState& state)
            : state_(state)
        {
        }

        [[nodiscard]] std::array<float, 4> sample(
            std::uint32_t unit, float s, float t) const override
        {
            constexpr Color black { 0.0F, 0.0F, 0.0F, 1.0F };
            if (unit >= state_.texture_units.size() ||
                state_.resources == nullptr)
                return black;
            auto texture_unit = state_.texture_units[unit];
            const auto* texture =
                state_.resources->texture(texture_unit.texture);
            if (texture == nullptr)
                return black;
            const auto level = texture->levels.find(0U);
            if (level == texture->levels.end() || level->second.width == 0U ||
                level->second.height == 0U ||
                level->second.argb.size() !=
                    static_cast<std::size_t>(level->second.width) *
                        level->second.height)
                return black;
            texture_unit.enabled = true;
            texture_unit.rectangle = false;
            return unpack(sample_raster_texture(
                state_, texture_unit, s, t, { 0.0F, 0.0F, 0.0F, 0.0F }));
        }

    private:
        const GlesRasterState& state_;
    };

    struct Outputs {
        const glsl::Variable* fragment_color { };
        const glsl::Variable* fragment_data { };
        const glsl::Variable* fragment_coordinate { };
        const glsl::Variable* front_facing { };
    };

    struct Pass {
        DisplayFrame& frame;
        const GlesRasterState& state;
        glsl::Instance& fragment;
        std::span<const GlesShadedVarying> varyings;
        const ShaderTextures& textures;
        Outputs outputs;
        std::string& error;
    };

    // False when the shader failed to run, which ends the draw.
    bool shade_pixel(Pass& pass, std::size_t offset, const Color& coordinate,
        bool front_facing, const std::array<float, 3>& weights,
        const std::array<Vertex, 3>& triangle,
        const std::array<float, 3>& perspective)
    {
        auto& fragment = pass.fragment;
        for (const auto& binding : pass.varyings) {
            auto values = fragment.values(*binding.variable);
            const auto count = glsl::component_count(binding.variable->type);
            const auto end = binding.offset + values.size() * count;
            if (count > values[0].v.size() ||
                end > triangle[0].varyings.size() ||
                end > triangle[1].varyings.size() ||
                end > triangle[2].varyings.size()) {
                pass.error = "varying '" + binding.variable->name +
                             "' reaches past the values of a vertex";
                return false;
            }
            for (std::size_t element = 0; element < values.size(); ++element) {
                for (std::size_t k = 0; k < count; ++k) {
                    const auto at = binding.offset + element * count + k;
                    values[element].v[k] =
                        triangle[0].varyings[at] * perspective[0] +
                        triangle[1].varyings[at] * perspective[1] +
                        triangle[2].varyings[at] * perspective[2];
                }
            }
        }
        if (pass.outputs.fragment_coordinate != nullptr) {
            auto& value = fragment.values(*pass.outputs.fragment_coordinate)[0];
            value.v[0] = coordinate[0];
            value.v[1] = coordinate[1];
            value.v[2] = triangle[0].depth * weights[0] +
                         triangle[1].depth * weights[1] +
                         triangle[2].depth * weights[2];
            value.v[3] = triangle[0].inverse_w * weights[0] +
                         triangle[1].inverse_w * weights[1] +
                         triangle[2].inverse_w * weights[2];
        }
        if (pass.outputs.front_facing != nullptr)
            fragment.values(*pass.outputs.front_facing)[0].v[0] =
                front_facing ? 1.0F : 0.0F;
        if (!fragment.run(&pass.textures)) {
            if (fragment.discarded())
                return true;
            pass.error = fragment.error();
            return false;
        }
        Color source { };
        if (pass.outputs.fragment_color != nullptr) {
            const auto& value =
                fragment.values(*pass.outputs.fragment_color)[0];
            std::copy_n(value.v.begin(), 4, source.begin());
        }
        // A shader writes gl_FragColor or gl_FragData[0], never both; the one
        // it did not write stays zero.
        if (pass.outputs.fragment_data != nullptr &&
            std::all_of(source.begin(), source.end(),
                [](float component) { return component == 0.0F; })) {
            const auto& value = fragment.values(*pass.outputs.fragment_data)[0];
            std::copy_n(value.v.begin(), 4, source.begin());
        }
        for (auto& component : source)
            component = std::clamp(component, 0.0F, 1.0F);
        auto& destination = pass.frame.pixels[offset];
        auto pixel = pack(source);
        if (pass.state.blend_enabled) {
            const auto before = unpack(destination);
            Color blended { };
            for (std::size_t component = 0; component < blended.size();
                ++component) {
                blended[component] =
                    source[component] * blend_factor(pass.state.blend_source,
                                            component, source, before,
                                            pass.state.blend_constant) +
                    before[component] *
                        blend_factor(pass.state.blend_destination, component,
                            source, before, pass.state.blend_constant);
            }
            pixel = pack(blended);
        }
        destination = apply_color_mask(pixel, destination, pass.state.color_mask);
        return true;
    }

    bool draw_triangle(Pass& pass, const std::array<Vertex, 3>& triangle,
        bool cull_enabled)
    {
        const auto& state = pass.state;
        const auto& frame = pass.frame;
        const auto area =
            edge(triangle[0], triangle[1], triangle[2].x, triangle[2].y);
        if (std::abs(area) < 1.0e-6F)
            return true;
        const auto facing_area =
            state.render_target_inverted_vertical ? -area : area;
        const auto front_facing = state.front_face == gles_abi::counter_clockwise
                                      ? facing_area > 0.0F
                                      : facing_area < 0.0F;
        if (cull_enabled &&
            (state.cull_mode == gles_abi::front_and_back ||
                (state.cull_mode == gles_abi::front && front_facing) ||
                (state.cull_mode == gles_abi::back && !front_facing)))
            return true;
        // The vertices are the guest's numbers: NaN, infinity and values far
        // beyond the frame must not reach a float to int conversion.
        for (const auto& vertex : triangle) {
            if (!std::isfinite(vertex.x) || !std::isfinite(vertex.y))
                return true;
        }
        const auto last_column = static_cast<float>(frame.width - 1U);
        const auto last_row = static_cast<float>(frame.height - 1U);
        const auto minimum_x = static_cast<int>(std::clamp(
            std::floor(std::min({ triangle[0].x, triangle[1].x, triangle[2].x })),
            0.0F, last_column));
        const auto maximum_x = static_cast<int>(std::clamp(
            std::ceil(std::max({ triangle[0].x, triangle[1].x, triangle[2].x })),
            0.0F, last_column));
        const auto minimum_y = static_cast<int>(std::clamp(
            std::floor(std::min({ triangle[0].y, triangle[1].y, triangle[2].y })),
            0.0F, last_row));
        const auto maximum_y = static_cast<int>(std::clamp(
            std::ceil(std::max({ triangle[0].y, triangle[1].y, triangle[2].y })),
            0.0F, last_row));
        const auto orientation = area > 0.0F ? 1.0F : -1.0F;
        const std::array boundaries { includes_boundary(triangle[1],
                                          triangle[2], orientation),
            includes_boundary(triangle[2], triangle[0], orientation),
            includes_boundary(triangle[0], triangle[1], orientation) };
        for (int y = minimum_y; y <= maximum_y; ++y) {
            for (int x = minimum_x; x <= maximum_x; ++x) {
                const auto sample_x = static_cast<float>(x) + 0.5F;
                const auto sample_y = static_cast<float>(y) + 0.5F;
                // The row a GL window coordinate counts up from.
                const auto guest_y =
                    state.render_target_inverted_vertical
                        ? sample_y
                        : static_cast<float>(frame.height) - sample_y;
                if (state.scissor_enabled) {
                    const auto scissor_right =
                        static_cast<float>(state.scissor_box[0]) +
                        static_cast<float>(state.scissor_box[2]);
                    const auto scissor_top =
                        static_cast<float>(state.scissor_box[1]) +
                        static_cast<float>(state.scissor_box[3]);
                    if (sample_x < static_cast<float>(state.scissor_box[0]) ||
                        sample_x >= scissor_right ||
                        guest_y < static_cast<float>(state.scissor_box[1]) ||
                        guest_y >= scissor_top)
                        continue;
                }
                const std::array edge_values { edge(triangle[1], triangle[2],
                                                   sample_x, sample_y),
                    edge(triangle[2], triangle[0], sample_x, sample_y),
                    edge(triangle[0], triangle[1], sample_x, sample_y) };
                bool covered = true;
                for (std::size_t index = 0; index < edge_values.size();
                    ++index) {
                    const auto value = orientation * edge_values[index];
                    if (value < 0.0F || (value == 0.0F && !boundaries[index])) {
                        covered = false;
                        break;
                    }
                }
                if (!covered)
                    continue;
                const std::array<float, 3> weights { edge_values[0] / area,
                    edge_values[1] / area, edge_values[2] / area };
                // Varyings are interpolated in homogeneous space, so a quad
                // split in two triangles does not bend at the diagonal.
                const auto inverse_w = triangle[0].inverse_w * weights[0] +
                                       triangle[1].inverse_w * weights[1] +
                                       triangle[2].inverse_w * weights[2];
                if (!std::isfinite(inverse_w) || std::abs(inverse_w) <= 1.0e-6F)
                    continue;
                const std::array<float, 3> perspective {
                    triangle[0].inverse_w * weights[0] / inverse_w,
                    triangle[1].inverse_w * weights[1] / inverse_w,
                    triangle[2].inverse_w * weights[2] / inverse_w
                };
                const auto offset = static_cast<std::size_t>(y) * frame.width +
                                    static_cast<std::size_t>(x);
                if (!shade_pixel(pass, offset, { sample_x, guest_y, 0.0F, 0.0F },
                        front_facing, weights, triangle, perspective))
                    return false;
            }
        }
        return true;
    }

} // namespace

bool layout_varyings(const glsl::Module& vertex, const glsl::Module& fragment,
    GlesVaryingLayout& layout, std::string& error)
{
    layout = { };
    for (const auto& variable : fragment.variables()) {
        if (variable.storage != glsl::Storage::Varying)
            continue;
        const auto* written = vertex.find(variable.name);
        if (written == nullptr || written->storage != glsl::Storage::Varying) {
            error = "the fragment shader reads varying '" + variable.name +
                    "', which the vertex shader does not declare";
            return false;
        }
        if (written->type != variable.type ||
            written->array_size != variable.array_size) {
            error = "varying '" + variable.name +
                    "' is declared with a different type or array size in "
                    "the two shaders";
            return false;
        }
        const auto size = static_cast<std::uint64_t>(
                              glsl::component_count(variable.type)) *
                          std::max(variable.array_size, 1U);
        if (layout.floats + size > maximum_shaded_varying_floats) {
            error = "the program passes more varyings than the device has "
                    "(at varying '" +
                    variable.name + "')";
            return false;
        }
        layout.fragment.push_back({ &variable, layout.floats });
        layout.vertex.push_back({ written, layout.floats });
        layout.floats += static_cast<std::uint32_t>(size);
    }
    return true;
}

bool collect_varyings(const glsl::Instance& vertex,
    const GlesVaryingLayout& layout, std::vector<float>& floats,
    std::string& error)
{
    floats.assign(layout.floats, 0.0F);
    for (const auto& source : layout.vertex) {
        const auto values = vertex.values(*source.written);
        const auto width = glsl::component_count(source.written->type);
        if (width > values[0].v.size() ||
            static_cast<std::uint64_t>(source.offset) +
                    static_cast<std::uint64_t>(values.size()) * width >
                floats.size()) {
            error = "varying '" + source.written->name +
                    "' does not fit the space laid out for it";
            return false;
        }
        for (std::size_t element = 0; element < values.size(); ++element) {
            for (std::size_t k = 0; k < width; ++k)
                floats[source.offset + element * width + k] =
                    values[element].v[k];
        }
    }
    return true;
}

bool GlesShadedRasterizer::draw(DisplayFrame& frame,
    std::span<const GlesShadedVertex> vertices, std::uint32_t mode,
    const GlesRasterState& state, glsl::Instance& fragment,
    std::span<const GlesShadedVarying> varyings, std::string& error)
{
    error.clear();
    if (mode != gles_abi::triangles && mode != gles_abi::triangle_strip &&
        mode != gles_abi::triangle_fan) {
        error = "only triangles, triangle strips and triangle fans are drawn "
                "with a shader";
        return false;
    }
    if (frame.width == 0 || frame.height == 0 ||
        frame.pixels.size() !=
            static_cast<std::size_t>(frame.width) * frame.height) {
        error = "the render target has no pixels";
        return false;
    }
    if (state.viewport_width == 0 || state.viewport_height == 0)
        return true;
    // A vertex carries every float the varyings read.
    std::uint64_t needed = 0;
    for (const auto& binding : varyings) {
        const auto size = static_cast<std::uint64_t>(binding.offset) +
                          static_cast<std::uint64_t>(
                              glsl::component_count(binding.variable->type)) *
                              std::max(binding.variable->array_size, 1U);
        needed = std::max(needed, size);
    }
    std::vector<Vertex> screen;
    screen.reserve(vertices.size());
    for (const auto& vertex : vertices) {
        if (vertex.varyings.size() < needed) {
            error = "a vertex carries fewer varyings than the fragment "
                    "shader reads";
            return false;
        }
        if (vertex.position[3] == 0.0F) {
            error = "a vertex has w = 0";
            return false;
        }
        const auto inverse_w = 1.0F / vertex.position[3];
        const auto window_x =
            static_cast<float>(state.viewport_x) +
            (vertex.position[0] * inverse_w * 0.5F + 0.5F) *
                static_cast<float>(state.viewport_width);
        const auto window_y =
            static_cast<float>(state.viewport_y) +
            (vertex.position[1] * inverse_w * 0.5F + 0.5F) *
                static_cast<float>(state.viewport_height);
        screen.push_back(Vertex { window_x,
            state.render_target_inverted_vertical
                ? window_y
                : static_cast<float>(frame.height) - window_y,
            inverse_w, vertex.position[2] * inverse_w * 0.5F + 0.5F,
            vertex.varyings });
    }
    const ShaderTextures textures { state };
    Outputs outputs;
    outputs.fragment_color = fragment.module().find("gl_FragColor");
    outputs.fragment_data = fragment.module().find("gl_FragData");
    outputs.fragment_coordinate = fragment.module().find("gl_FragCoord");
    outputs.front_facing = fragment.module().find("gl_FrontFacing");
    Pass pass { frame, state, fragment, varyings, textures, outputs, error };
    const auto emit = [&](std::size_t a, std::size_t b, std::size_t c) {
        return draw_triangle(
            pass, { screen[a], screen[b], screen[c] }, state.cull_enabled);
    };
    if (mode == gles_abi::triangles) {
        for (std::size_t index = 0; index + 2 < screen.size(); index += 3) {
            if (!emit(index, index + 1U, index + 2U))
                return false;
        }
    } else if (mode == gles_abi::triangle_strip) {
        for (std::size_t index = 0; index + 2 < screen.size(); ++index) {
            const auto drawn = (index & 1U) == 0
                                   ? emit(index, index + 1U, index + 2U)
                                   : emit(index + 1U, index, index + 2U);
            if (!drawn)
                return false;
        }
    } else {
        for (std::size_t index = 1; index + 1 < screen.size(); ++index) {
            if (!emit(0, index, index + 1U))
                return false;
        }
    }
    return true;
}

} // namespace shade
