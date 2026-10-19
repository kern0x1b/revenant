// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Retain background-layer provenance for local scene composition.

#include "graphics/local_scene_background.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>

#include "graphics/gles_abi.hpp"

namespace shade {
namespace {

    constexpr float quad_epsilon = 1.0e-4F;
    constexpr float bounds_tolerance = 0.05F;

    struct AxisAlignedQuad {
        // left, top, right, bottom in host pixel coordinates.
        std::array<float, 4> position_bounds { };
        std::array<float, 4> texture_bounds { };
        // texture x = [0] * position x + [1], texture y = [2] * position y +
        // [3]. Texture coordinates are expressed in source pixels.
        std::array<float, 4> texture_from_position { };
    };

    bool approximately_equal(float left, float right)
    {
        return std::abs(left - right) <=
               quad_epsilon *
                   std::max({ 1.0F, std::abs(left), std::abs(right) });
    }

    bool same_quad_vertex(const GlesRasterVertex& left,
        const GlesRasterVertex& right, std::size_t texture_unit)
    {
        for (std::size_t component = 0; component < left.position.size();
            ++component) {
            if (!approximately_equal(
                    left.position[component], right.position[component])) {
                return false;
            }
        }
        return approximately_equal(left.texture[texture_unit][0],
                   right.texture[texture_unit][0]) &&
               approximately_equal(left.texture[texture_unit][1],
                   right.texture[texture_unit][1]);
    }

    std::optional<std::array<std::size_t, 4>> quad_indices(
        std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
        std::size_t texture_unit)
    {
        if (mode == gles_abi::triangles && vertices.size() == 6U &&
            same_quad_vertex(vertices[0], vertices[5], texture_unit) &&
            same_quad_vertex(vertices[2], vertices[3], texture_unit)) {
            return std::array<std::size_t, 4> { 0U, 1U, 2U, 4U };
        }
        if (mode == gles_abi::triangle_strip && vertices.size() == 4U)
            return std::array<std::size_t, 4> { 0U, 1U, 3U, 2U };
        if (mode == gles_abi::triangle_fan && vertices.size() == 4U)
            return std::array<std::size_t, 4> { 0U, 1U, 2U, 3U };
        return std::nullopt;
    }

    std::optional<AxisAlignedQuad> axis_aligned_quad(std::uint32_t target_width,
        std::uint32_t target_height, const GlesRasterState& state,
        std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
        std::size_t texture_unit, std::uint32_t texture_width,
        std::uint32_t texture_height, bool rectangle_texture)
    {
        if (target_width == 0U || target_height == 0U || texture_width == 0U ||
            texture_height == 0U || state.viewport_width == 0U ||
            state.viewport_height == 0U) {
            return std::nullopt;
        }
        const auto indices = quad_indices(vertices, mode, texture_unit);
        if (!indices)
            return std::nullopt;

        struct Sample {
            float x;
            float y;
            float texture_x;
            float texture_y;
        };
        std::array<Sample, 4> samples { };
        const auto first_w = vertices[(*indices)[0]].position[3];
        if (!std::isfinite(first_w) || std::abs(first_w) <= 1.0e-6F)
            return std::nullopt;

        auto left = std::numeric_limits<float>::infinity();
        auto top = std::numeric_limits<float>::infinity();
        auto right = -std::numeric_limits<float>::infinity();
        auto bottom = -std::numeric_limits<float>::infinity();
        for (std::size_t index = 0; index < samples.size(); ++index) {
            const auto& vertex = vertices[(*indices)[index]];
            const auto w = vertex.position[3];
            if (!std::isfinite(w) || std::abs(w) <= 1.0e-6F ||
                !approximately_equal(w, first_w)) {
                return std::nullopt;
            }
            const auto inverse_w = 1.0F / w;
            const auto window_x =
                static_cast<float>(state.viewport_x) +
                (vertex.position[0] * inverse_w * 0.5F + 0.5F) *
                    static_cast<float>(state.viewport_width);
            const auto window_y =
                static_cast<float>(state.viewport_y) +
                (vertex.position[1] * inverse_w * 0.5F + 0.5F) *
                    static_cast<float>(state.viewport_height);
            const auto host_y =
                state.render_target_inverted_vertical
                    ? window_y
                    : static_cast<float>(target_height) - window_y;
            const auto texture_scale_x =
                rectangle_texture ? 1.0F : static_cast<float>(texture_width);
            const auto texture_scale_y =
                rectangle_texture ? 1.0F : static_cast<float>(texture_height);
            samples[index] = { window_x, host_y,
                vertex.texture[texture_unit][0] * texture_scale_x,
                vertex.texture[texture_unit][1] * texture_scale_y };
            if (!std::isfinite(samples[index].x) ||
                !std::isfinite(samples[index].y) ||
                !std::isfinite(samples[index].texture_x) ||
                !std::isfinite(samples[index].texture_y)) {
                return std::nullopt;
            }
            left = std::min(left, samples[index].x);
            top = std::min(top, samples[index].y);
            right = std::max(right, samples[index].x);
            bottom = std::max(bottom, samples[index].y);
        }
        if (right - left <= quad_epsilon || bottom - top <= quad_epsilon)
            return std::nullopt;

        const auto position_tolerance =
            quad_epsilon * std::max({ 1.0F, right - left, bottom - top });
        std::array<bool, 4> horizontal_edges { };
        for (std::size_t index = 0; index < samples.size(); ++index) {
            const auto& start = samples[index];
            const auto& end = samples[(index + 1U) % samples.size()];
            const auto horizontal =
                std::abs(start.y - end.y) <= position_tolerance &&
                std::abs(start.x - end.x) > position_tolerance;
            const auto vertical =
                std::abs(start.x - end.x) <= position_tolerance &&
                std::abs(start.y - end.y) > position_tolerance;
            if (!horizontal && !vertical)
                return std::nullopt;
            horizontal_edges[index] = horizontal;
        }
        if (horizontal_edges[0] == horizontal_edges[1] ||
            horizontal_edges[0] != horizontal_edges[2] ||
            horizontal_edges[1] != horizontal_edges[3]) {
            return std::nullopt;
        }

        const auto horizontal_neighbor = horizontal_edges[0] ? 1U : 3U;
        const auto vertical_neighbor = horizontal_edges[0] ? 3U : 1U;
        const auto scale_x =
            (samples[horizontal_neighbor].texture_x - samples[0].texture_x) /
            (samples[horizontal_neighbor].x - samples[0].x);
        const auto scale_y =
            (samples[vertical_neighbor].texture_y - samples[0].texture_y) /
            (samples[vertical_neighbor].y - samples[0].y);
        const auto offset_x = samples[0].texture_x - scale_x * samples[0].x;
        const auto offset_y = samples[0].texture_y - scale_y * samples[0].y;
        const auto texture_tolerance =
            quad_epsilon * std::max({ 1.0F, static_cast<float>(texture_width),
                               static_cast<float>(texture_height) });
        for (const auto& sample : samples) {
            if (std::abs(sample.texture_x - (scale_x * sample.x + offset_x)) >
                    texture_tolerance ||
                std::abs(sample.texture_y - (scale_y * sample.y + offset_y)) >
                    texture_tolerance) {
                return std::nullopt;
            }
        }

        const auto texture_at_left = scale_x * left + offset_x;
        const auto texture_at_right = scale_x * right + offset_x;
        const auto texture_at_top = scale_y * top + offset_y;
        const auto texture_at_bottom = scale_y * bottom + offset_y;
        return AxisAlignedQuad { { left, top, right, bottom },
            { std::min(texture_at_left, texture_at_right),
                std::min(texture_at_top, texture_at_bottom),
                std::max(texture_at_left, texture_at_right),
                std::max(texture_at_top, texture_at_bottom) },
            { scale_x, offset_x, scale_y, offset_y } };
    }

} // namespace

void LocalSceneBackground::reset() { states_.clear(); }

void LocalSceneBackground::invalidate(
    const std::shared_ptr<HostSurface>& target)
{
    if (target)
        states_.erase(target->key());
}

void LocalSceneBackground::observe(const std::shared_ptr<HostSurface>& target,
    const GlesRasterState& state, const GlesResourceStore& resources,
    std::span<const GlesRasterVertex> vertices, std::uint32_t mode)
{
    if (!target || !state.render_target_premultiplied || state.blend_enabled)
        return;

    // An unblended write starts a new local base. Keep no older provenance if
    // the replacement cannot be represented by the conservative direct-layer
    // model below.
    states_.erase(target->key());
    if (state.scissor_enabled || !std::ranges::all_of(state.color_mask,
                                     [](bool enabled) { return enabled; })) {
        return;
    }

    const GlesResourceStore::TextureLevel* source_level = nullptr;
    std::size_t source_unit_index = 0U;
    for (std::size_t unit_index = 0; unit_index < state.texture_units.size();
        ++unit_index) {
        const auto& unit = state.texture_units[unit_index];
        if (!unit.enabled)
            continue;
        if (source_level || unit.environment.mode != gles_abi::replace)
            return;
        const auto* texture = resources.texture(unit.texture);
        if (!texture)
            return;
        const auto level = texture->levels.find(0U);
        if (level == texture->levels.end() || !level->second.host_surface)
            return;
        source_level = &level->second;
        source_unit_index = unit_index;
    }
    if (!source_level || source_level->host_surface == target)
        return;

    const auto target_descriptor = target->descriptor();
    const auto source_descriptor = source_level->host_surface->descriptor();
    if (target_descriptor.width == 0U || target_descriptor.height == 0U ||
        source_descriptor.width != source_level->width ||
        source_descriptor.height != source_level->height) {
        return;
    }
    const auto mapping = axis_aligned_quad(target_descriptor.width,
        target_descriptor.height, state, vertices, mode, source_unit_index,
        source_descriptor.width, source_descriptor.height,
        state.texture_units[source_unit_index].rectangle);
    if (!mapping || mapping->position_bounds[0] < -bounds_tolerance ||
        mapping->position_bounds[1] < -bounds_tolerance ||
        mapping->position_bounds[2] >
            static_cast<float>(target_descriptor.width) + bounds_tolerance ||
        mapping->position_bounds[3] >
            static_cast<float>(target_descriptor.height) + bounds_tolerance ||
        mapping->texture_bounds[0] < -bounds_tolerance ||
        mapping->texture_bounds[1] < -bounds_tolerance ||
        mapping->texture_bounds[2] >
            static_cast<float>(source_descriptor.width) + bounds_tolerance ||
        mapping->texture_bounds[3] >
            static_cast<float>(source_descriptor.height) + bounds_tolerance) {
        return;
    }

    states_.insert_or_assign(target->key(),
        State { target, source_level->host_surface, mapping->position_bounds,
            mapping->texture_from_position,
            std::max(source_level->host_surface->cpu_generation(),
                source_level->host_surface->gpu_generation()) });
}

bool LocalSceneBackground::restore(const std::shared_ptr<HostSurface>& scene,
    const std::shared_ptr<HostSurface>& destination,
    std::size_t scene_unit_index, const GlesRasterState& state,
    std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
    HostRectangle scissor, CommandEncoder& encoder, bool& restored)
{
    restored = false;
    if (!scene || !destination ||
        scene_unit_index >= state.texture_units.size() ||
        state.texture_units[scene_unit_index].environment.mode !=
            gles_abi::replace ||
        std::ranges::count_if(state.texture_units,
            [](const auto& unit) { return unit.enabled; }) != 1) {
        return true;
    }

    const auto retained = states_.find(scene->key());
    if (retained == states_.end() || retained->second.target != scene ||
        !retained->second.source || retained->second.source == destination ||
        retained->second.source_generation !=
            std::max(retained->second.source->cpu_generation(),
                retained->second.source->gpu_generation())) {
        return true;
    }
    const auto scene_descriptor = scene->descriptor();
    const auto destination_descriptor = destination->descriptor();
    const auto source_descriptor = retained->second.source->descriptor();
    const auto& local_bounds = retained->second.target_bounds;
    // Scanout restoration only handles full-width scene slices. Requiring the
    // retained source layer to span the local target's full width prevents a
    // cropped primary scene from being mistaken for a complete background.
    if (local_bounds[0] > bounds_tolerance ||
        local_bounds[2] <
            static_cast<float>(scene_descriptor.width) - bounds_tolerance) {
        return true;
    }

    const auto& scene_unit = state.texture_units[scene_unit_index];
    const auto mapping = axis_aligned_quad(destination_descriptor.width,
        destination_descriptor.height, state, vertices, mode, scene_unit_index,
        scene_descriptor.width, scene_descriptor.height, scene_unit.rectangle);
    if (!mapping ||
        mapping->texture_bounds[0] < local_bounds[0] - bounds_tolerance ||
        mapping->texture_bounds[1] < local_bounds[1] - bounds_tolerance ||
        mapping->texture_bounds[2] > local_bounds[2] + bounds_tolerance ||
        mapping->texture_bounds[3] > local_bounds[3] + bounds_tolerance) {
        return true;
    }

    const auto& outer = mapping->texture_from_position;
    const auto& inner = retained->second.source_from_target;
    const auto source_x = [&](float destination_x) {
        return inner[0] * (outer[0] * destination_x + outer[1]) + inner[1];
    };
    const auto source_y = [&](float destination_y) {
        return inner[2] * (outer[2] * destination_y + outer[3]) + inner[3];
    };
    const auto left = mapping->position_bounds[0];
    const auto top = mapping->position_bounds[1];
    const auto right = mapping->position_bounds[2];
    const auto bottom = mapping->position_bounds[3];
    std::array<HostTexturedVertex, 4> quad { {
        { { left, top }, { source_x(left), source_y(top) }, 1.0F },
        { { right, top }, { source_x(right), source_y(top) }, 1.0F },
        { { right, bottom }, { source_x(right), source_y(bottom) }, 1.0F },
        { { left, bottom }, { source_x(left), source_y(bottom) }, 1.0F },
    } };
    const auto valid_source_coordinate = [&](const HostPoint& coordinate) {
        return coordinate.x >= -bounds_tolerance &&
               coordinate.y >= -bounds_tolerance &&
               coordinate.x <= static_cast<float>(source_descriptor.width) +
                                   bounds_tolerance &&
               coordinate.y <= static_cast<float>(source_descriptor.height) +
                                   bounds_tolerance;
    };
    if (!std::ranges::all_of(quad, [&](const auto& vertex) {
            return valid_source_coordinate(vertex.texture);
        })) {
        return true;
    }

    const auto whole_source = HostRectangle { 0, 0, source_descriptor.width,
        source_descriptor.height };
    if (!encoder.copy_quad(retained->second.source, destination, quad,
            whole_source, scissor, HostCompositeMode::Copy, 0xffU,
            HostFilter::Nearest)) {
        return true;
    }
    if (!encoder.submit(PerfSubmitReason::GlesSync))
        return false;
    restored = true;
    return true;
}

} // namespace shade
