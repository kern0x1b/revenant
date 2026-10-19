// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest MBX textured-quad operations to shared-surface
// rendering.

#include "kernel/mbx2d_hle.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <mutex>
#include <optional>
#include <vector>

#include "foundation/address_space.hpp"
#include "foundation/application_path.hpp"
#include "graphics/display.hpp"
#include "graphics/gles_renderer.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "graphics/mbx2d_abi.hpp"
#include "foundation/performance.hpp"
#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    struct Point {
        float x { };
        float y { };
    };

    constexpr float edge_tolerance = 0.01F;
    constexpr std::uint64_t maximum_quad_pixels = 16U * 1024U * 1024U;
    constexpr std::uint64_t scene_extent_numerator = 3;
    constexpr std::uint64_t scene_extent_denominator = 4;

    bool nearly_equal(float left, float right)
    {
        return std::abs(left - right) <= edge_tolerance;
    }

    bool triangles_share_only_diagonal(const std::array<Point, 4>& quad)
    {
        const auto side = [&](std::size_t vertex) {
            const auto diagonal_x = quad[2].x - quad[0].x;
            const auto diagonal_y = quad[2].y - quad[0].y;
            const auto point_x = quad[vertex].x - quad[0].x;
            const auto point_y = quad[vertex].y - quad[0].y;
            return diagonal_x * point_y - diagonal_y * point_x;
        };
        const auto first = side(1);
        const auto second = side(3);
        return (first > edge_tolerance && second < -edge_tolerance) ||
               (first < -edge_tolerance && second > edge_tolerance);
    }

    bool covers_scene_extent(std::int64_t width, std::int64_t height,
        std::uint32_t destination_width, std::uint32_t destination_height)
    {
        if (width <= 0 || height <= 0)
            return false;
        return static_cast<std::uint64_t>(width) * scene_extent_denominator >=
                   static_cast<std::uint64_t>(destination_width) *
                       scene_extent_numerator &&
               static_cast<std::uint64_t>(height) * scene_extent_denominator >=
                   static_cast<std::uint64_t>(destination_height) *
                       scene_extent_numerator;
    }

    std::optional<std::array<Point, 4>> read_quad(
        AddressSpace& memory, std::uint32_t address)
    {
        if (address == 0 ||
            address > std::numeric_limits<std::uint32_t>::max() -
                          7U * sizeof(std::uint32_t)) {
            return std::nullopt;
        }
        std::array<Point, 4> result { };
        for (std::size_t vertex = 0; vertex < result.size(); ++vertex) {
            const auto x = memory.read32(
                address + static_cast<std::uint32_t>(vertex * 8U));
            const auto y = memory.read32(
                address + static_cast<std::uint32_t>(vertex * 8U + 4U));
            if (!x || !y)
                return std::nullopt;
            result[vertex] = { std::bit_cast<float>(*x),
                std::bit_cast<float>(*y) };
            if (!std::isfinite(result[vertex].x) ||
                !std::isfinite(result[vertex].y)) {
                return std::nullopt;
            }
        }
        return result;
    }

    std::optional<std::array<float, 4>> read_perspective(
        AddressSpace& memory, std::uint32_t address)
    {
        if (address == 0 ||
            address > std::numeric_limits<std::uint32_t>::max() -
                          3U * sizeof(std::uint32_t)) {
            return std::nullopt;
        }
        std::array<float, 4> result { };
        for (std::size_t index = 0; index < result.size(); ++index) {
            const auto value =
                memory.read32(address + static_cast<std::uint32_t>(
                                            index * sizeof(std::uint32_t)));
            if (!value)
                return std::nullopt;
            result[index] = std::bit_cast<float>(*value);
            if (!std::isfinite(result[index]) ||
                std::abs(result[index]) <= 1.0e-6F)
                return std::nullopt;
        }
        return result;
    }

    struct TriangleSample {
        std::array<std::size_t, 3> vertices { };
        std::array<float, 3> weights { };
    };

    std::optional<TriangleSample> sample_triangle(
        const std::array<Point, 4>& quad, std::array<std::size_t, 3> vertices,
        Point point)
    {
        const auto& first = quad[vertices[0]];
        const auto& second = quad[vertices[1]];
        const auto& third = quad[vertices[2]];
        const auto denominator = (second.y - third.y) * (first.x - third.x) +
                                 (third.x - second.x) * (first.y - third.y);
        if (std::abs(denominator) <= edge_tolerance)
            return std::nullopt;
        const auto first_weight =
            ((second.y - third.y) * (point.x - third.x) +
                (third.x - second.x) * (point.y - third.y)) /
            denominator;
        const auto second_weight =
            ((third.y - first.y) * (point.x - third.x) +
                (first.x - third.x) * (point.y - third.y)) /
            denominator;
        const auto third_weight = 1.0F - first_weight - second_weight;
        if (first_weight < -edge_tolerance || second_weight < -edge_tolerance ||
            third_weight < -edge_tolerance)
            return std::nullopt;
        return TriangleSample { vertices,
            { first_weight, second_weight, third_weight } };
    }

    std::optional<TriangleSample> sample_quad(
        const std::array<Point, 4>& quad, Point point)
    {
        if (const auto first = sample_triangle(quad, { 0, 1, 2 }, point))
            return first;
        return sample_triangle(quad, { 0, 2, 3 }, point);
    }

    std::optional<Point> interpolate_perspective(
        const std::array<Point, 4>& values,
        const std::array<float, 4>& perspective, const TriangleSample& sample)
    {
        Point numerator { };
        float denominator = 0.0F;
        for (std::size_t index = 0; index < sample.vertices.size(); ++index) {
            const auto vertex = sample.vertices[index];
            const auto weight = perspective[vertex];
            if (!std::isfinite(weight) || std::abs(weight) <= 1.0e-6F)
                return std::nullopt;
            const auto reciprocal = 1.0F / weight;
            const auto coefficient = sample.weights[index] * reciprocal;
            numerator.x += coefficient * values[vertex].x;
            numerator.y += coefficient * values[vertex].y;
            denominator += coefficient;
        }
        if (!std::isfinite(denominator) || std::abs(denominator) <= 1.0e-6F)
            return std::nullopt;
        return Point { numerator.x / denominator, numerator.y / denominator };
    }

} // namespace

void Mbx2dHle::quad_color(UserlandHleCall& call)
{
    const auto destination = resolve(state_.destination);
    const auto positions = read_quad(call.memory(), call.argument(0));
    if (!destination || !positions) {
        call.set_return(mbx2d_abi::failure);
        return;
    }

    auto left_value = (*positions)[0].x;
    auto right_value = left_value;
    auto top_value = (*positions)[0].y;
    auto bottom_value = top_value;
    for (const auto& position : *positions) {
        left_value = std::min(left_value, position.x);
        right_value = std::max(right_value, position.x);
        top_value = std::min(top_value, position.y);
        bottom_value = std::max(bottom_value, position.y);
    }
    if (right_value - left_value <= edge_tolerance ||
        bottom_value - top_value <= edge_tolerance) {
        call.set_return(mbx2d_abi::success);
        return;
    }

    auto left = std::max<std::int64_t>(
        static_cast<std::int64_t>(std::floor(left_value)), 0);
    auto right = std::min<std::int64_t>(
        static_cast<std::int64_t>(std::ceil(right_value)), destination->width);
    auto top = std::max<std::int64_t>(
        static_cast<std::int64_t>(std::floor(top_value)), 0);
    auto bottom = std::min<std::int64_t>(
        static_cast<std::int64_t>(std::ceil(bottom_value)),
        destination->height);
    if (state_.scissor.enabled) {
        left = std::max<std::int64_t>(left, state_.scissor.left);
        top = std::max<std::int64_t>(top, state_.scissor.top);
        right = std::min<std::int64_t>(right, state_.scissor.right);
        bottom = std::min<std::int64_t>(bottom, state_.scissor.bottom);
    }
    if (right <= left || bottom <= top) {
        call.set_return(mbx2d_abi::success);
        return;
    }

    const auto width = right - left;
    const auto height = bottom - top;
    if (static_cast<std::uint64_t>(width) >
        maximum_quad_pixels / static_cast<std::uint64_t>(height)) {
        call.set_return(mbx2d_abi::failure);
        return;
    }
    const auto axis_aligned = nearly_equal((*positions)[0].x, left_value) &&
                              nearly_equal((*positions)[0].y, top_value) &&
                              nearly_equal((*positions)[1].x, right_value) &&
                              nearly_equal((*positions)[1].y, top_value) &&
                              nearly_equal((*positions)[2].x, right_value) &&
                              nearly_equal((*positions)[2].y, bottom_value) &&
                              nearly_equal((*positions)[3].x, left_value) &&
                              nearly_equal((*positions)[3].y, bottom_value);
    if (covers_scene_extent(
            width, height, destination->width, destination->height)) {
        prepare_destination_for_frame(
            call, state_, DamageRegion { left, top, right, bottom }, 0U);
    }
    const auto composite_mode = host_composite_mode(state_);
    if (axis_aligned && host_graphics_->accelerated() &&
        destination->host_surface && destination->backing &&
        destination->backing->pixel_format == surface_pixel_format_bgra &&
        composite_mode && left <= std::numeric_limits<std::int32_t>::max() &&
        top <= std::numeric_limits<std::int32_t>::max() &&
        static_cast<std::uint64_t>(width) <=
            std::numeric_limits<std::uint32_t>::max() &&
        static_cast<std::uint64_t>(height) <=
            std::numeric_limits<std::uint32_t>::max() &&
        command_encoder_->fill(destination->host_surface,
            { static_cast<std::int32_t>(left), static_cast<std::int32_t>(top),
                static_cast<std::uint32_t>(width),
                static_cast<std::uint32_t>(height) },
            call.argument(1), *composite_mode, state_.blend.global_alpha)) {
        call.set_return(mbx2d_abi::success);
        return;
    }
    if (!axis_aligned && triangles_share_only_diagonal(*positions) &&
        host_graphics_->accelerated() && destination->host_surface &&
        destination->backing &&
        destination->backing->pixel_format == surface_pixel_format_bgra &&
        composite_mode && left <= std::numeric_limits<std::int32_t>::max() &&
        top <= std::numeric_limits<std::int32_t>::max() &&
        static_cast<std::uint64_t>(width) <=
            std::numeric_limits<std::uint32_t>::max() &&
        static_cast<std::uint64_t>(height) <=
            std::numeric_limits<std::uint32_t>::max()) {
        std::array<HostPoint, 4> quad { };
        for (std::size_t index = 0; index < quad.size(); ++index) {
            quad[index] = { (*positions)[index].x, (*positions)[index].y };
        }
        if (command_encoder_->fill_quad(destination->host_surface, quad,
                { static_cast<std::int32_t>(left),
                    static_cast<std::int32_t>(top),
                    static_cast<std::uint32_t>(width),
                    static_cast<std::uint32_t>(height) },
                call.argument(1), *composite_mode, state_.blend.global_alpha)) {
            call.set_return(mbx2d_abi::success);
            return;
        }
    }
    const auto destination_pixels =
        read_region(*destination, left, top, width, height, call);
    if (!destination_pixels) {
        call.set_return(mbx2d_abi::failure);
        return;
    }

    std::vector<std::uint32_t> source_pixels(
        static_cast<std::size_t>(width * height), call.argument(1));
    std::vector<bool> covered;
    if (!axis_aligned) {
        covered.assign(source_pixels.size(), false);
        for (std::int64_t y = 0; y < height; ++y) {
            for (std::int64_t x = 0; x < width; ++x) {
                const auto index = static_cast<std::size_t>(y * width + x);
                covered[index] = sample_quad(
                    *positions, Point { static_cast<float>(left + x) + 0.5F,
                                    static_cast<float>(top + y) + 0.5F })
                                     .has_value();
            }
        }
    }

    auto pixels = composite(
        state_, *destination, left, top, width, height, source_pixels, call);
    if (!pixels) {
        call.set_return(mbx2d_abi::failure);
        return;
    }
    if (!axis_aligned) {
        for (std::size_t index = 0; index < covered.size(); ++index) {
            if (!covered[index])
                (*pixels)[index] = (*destination_pixels)[index];
        }
    }
    call.set_return(
        write_region(*destination, left, top, width, height, *pixels, call)
            ? mbx2d_abi::success
            : mbx2d_abi::failure);
}

void Mbx2dHle::quad_copy(
    UserlandHleCall& call, bool context_api, bool perspective_api)
{
    auto* selected_state = select_state(call, context_api);
    if (!selected_state) {
        call.set_return(mbx2d_abi::failure);
        return;
    }
    auto& state = *selected_state;
    const auto first_argument = context_api ? 1U : 0U;
    const auto source = resolve_source(call, state.source);
    const auto destination = resolve(state.destination);
    const auto positions =
        read_quad(call.memory(), call.argument(first_argument));
    auto texture = read_quad(call.memory(), call.argument(first_argument + 1U));
    std::array<float, 4> perspective { 1.0F, 1.0F, 1.0F, 1.0F };
    if (perspective_api) {
        const auto values =
            read_perspective(call.memory(), call.argument(first_argument + 2U));
        if (!values) {
            call.set_return(mbx2d_abi::failure);
            return;
        }
        perspective = *values;
    }
    if (!source || !destination || !positions || !texture) {
        call.set_return(mbx2d_abi::failure);
        return;
    }
    const auto viewport =
        display_ ? display_->geometry() : default_display_geometry;
    [&] {
        if (!shared_state_ || !source->backing || !destination->backing ||
            source->width != viewport.width ||
            source->height != viewport.height ||
            destination->width != viewport.width ||
            destination->height != viewport.height) {
            return false;
        }
        std::lock_guard lock { shared_state_->mach_mutex };
        const auto source_process = shared_state_->processes.find(
            source->backing->provenance.producer_process_id);
        const auto destination_process = shared_state_->processes.find(
            destination->backing->provenance.producer_process_id);
        if (source_process == shared_state_->processes.end() ||
            destination_process == shared_state_->processes.end() ||
            !is_application_executable_path(
                source_process->second.executable_path) ||
            is_application_executable_path(
                destination_process->second.executable_path)) {
            return false;
        }

        auto left = (*positions)[0].x;
        auto right = left;
        auto top = (*positions)[0].y;
        auto bottom = top;
        for (const auto& position : *positions) {
            left = std::min(left, position.x);
            right = std::max(right, position.x);
            top = std::min(top, position.y);
            bottom = std::max(bottom, position.y);
        }
        if (!nearly_equal(left, 0.0F) ||
            !nearly_equal(right, static_cast<float>(viewport.width)) ||
            top <= edge_tolerance ||
            !nearly_equal(bottom, static_cast<float>(viewport.height))) {
            return false;
        }

        auto minimum_u = (*texture)[0].x;
        auto maximum_u = minimum_u;
        auto minimum_v = (*texture)[0].y;
        auto maximum_v = minimum_v;
        for (const auto& coordinate : *texture) {
            minimum_u = std::min(minimum_u, coordinate.x);
            maximum_u = std::max(maximum_u, coordinate.x);
            minimum_v = std::min(minimum_v, coordinate.y);
            maximum_v = std::max(maximum_v, coordinate.y);
        }
        // Firmware texture coordinates address pixel centers, so a full source
        // may end at half a pixel inside its nominal extent.
        constexpr auto texture_edge_tolerance = 1.0F;
        if (minimum_u > texture_edge_tolerance ||
            maximum_u + texture_edge_tolerance <
                static_cast<float>(source->width) ||
            minimum_v > texture_edge_tolerance ||
            maximum_v + texture_edge_tolerance <
                static_cast<float>(source->height) ||
            maximum_v <= minimum_v + edge_tolerance) {
            return false;
        }

        // The firmware's first full-screen handoff quad reserves the
        // destination top band but still addresses the whole source surface,
        // squeezing the application's client snapshot into the remaining
        // extent. Keep the source at its native client height; the destination
        // position already accounts for the reserved band. Later quads are
        // fractional zoom bounds and intentionally retain firmware texture
        // coordinates.
        const auto source_content_height =
            std::min(static_cast<float>(source->height), bottom - top);
        const auto texture_height = maximum_v - minimum_v;
        for (auto& coordinate : *texture) {
            const auto normalized = (coordinate.y - minimum_v) / texture_height;
            coordinate.y = minimum_v + std::clamp(normalized, 0.0F, 1.0F) *
                                           source_content_height;
        }
        return true;
    }();
    if (!source_surface_allowed(*source)) {
        call.set_return(mbx2d_abi::success);
        return;
    }

    auto left_value = (*positions)[0].x;
    auto right_value = left_value;
    auto top_value = (*positions)[0].y;
    auto bottom_value = top_value;
    for (const auto& position : *positions) {
        left_value = std::min(left_value, position.x);
        right_value = std::max(right_value, position.x);
        top_value = std::min(top_value, position.y);
        bottom_value = std::max(bottom_value, position.y);
    }
    if (right_value - left_value <= edge_tolerance ||
        bottom_value - top_value <= edge_tolerance) {
        call.set_return(mbx2d_abi::success);
        return;
    }

    const auto unclipped_left =
        static_cast<std::int64_t>(std::floor(left_value));
    const auto unclipped_right =
        static_cast<std::int64_t>(std::ceil(right_value));
    const auto unclipped_top = static_cast<std::int64_t>(std::floor(top_value));
    const auto unclipped_bottom =
        static_cast<std::int64_t>(std::ceil(bottom_value));
    auto left = unclipped_left;
    auto right = unclipped_right;
    auto top = unclipped_top;
    auto bottom = unclipped_bottom;
    left = std::max<std::int64_t>(left, 0);
    top = std::max<std::int64_t>(top, 0);
    right = std::min<std::int64_t>(right, destination->width);
    bottom = std::min<std::int64_t>(bottom, destination->height);
    if (state.scissor.enabled) {
        left = std::max<std::int64_t>(left, state.scissor.left);
        top = std::max<std::int64_t>(top, state.scissor.top);
        right = std::min<std::int64_t>(right, state.scissor.right);
        bottom = std::min<std::int64_t>(bottom, state.scissor.bottom);
    }
    if (right <= left || bottom <= top) {
        call.set_return(mbx2d_abi::success);
        return;
    }

    float minimum_u = (*texture)[0].x;
    float maximum_u = minimum_u;
    float minimum_v = (*texture)[0].y;
    float maximum_v = minimum_v;
    for (const auto& coordinate : *texture) {
        minimum_u = std::min(minimum_u, coordinate.x);
        maximum_u = std::max(maximum_u, coordinate.x);
        minimum_v = std::min(minimum_v, coordinate.y);
        maximum_v = std::max(maximum_v, coordinate.y);
    }
    auto source_left = static_cast<std::int64_t>(std::floor(minimum_u));
    auto source_right = static_cast<std::int64_t>(std::ceil(maximum_u));
    auto source_top = static_cast<std::int64_t>(std::floor(minimum_v));
    auto source_bottom = static_cast<std::int64_t>(std::ceil(maximum_v));
    if (source_right <= source_left)
        ++source_right;
    if (source_bottom <= source_top)
        ++source_bottom;
    source_left = std::clamp<std::int64_t>(source_left, 0, source->width);
    source_right = std::clamp<std::int64_t>(source_right, 0, source->width);
    source_top = std::clamp<std::int64_t>(source_top, 0, source->height);
    source_bottom = std::clamp<std::int64_t>(source_bottom, 0, source->height);
    if (source_right <= source_left || source_bottom <= source_top) {
        call.set_return(mbx2d_abi::success);
        return;
    }

    const auto source_width = source_right - source_left;
    const auto source_height = source_bottom - source_top;
    const auto width = right - left;
    const auto height = bottom - top;
    if (static_cast<std::uint64_t>(width) >
        maximum_quad_pixels / static_cast<std::uint64_t>(height)) {
        call.set_return(mbx2d_abi::failure);
        return;
    }

    const auto perspective_affine =
        std::all_of(perspective.begin(), perspective.end(),
            [](float value) { return nearly_equal(value, 1.0F); });
    const auto axis_aligned_affine =
        perspective_affine && nearly_equal((*positions)[0].x, left_value) &&
        nearly_equal((*positions)[0].y, top_value) &&
        nearly_equal((*positions)[1].x, right_value) &&
        nearly_equal((*positions)[1].y, top_value) &&
        nearly_equal((*positions)[2].x, right_value) &&
        nearly_equal((*positions)[2].y, bottom_value) &&
        nearly_equal((*positions)[3].x, left_value) &&
        nearly_equal((*positions)[3].y, bottom_value) &&
        nearly_equal((*texture)[0].x + (*texture)[2].x,
            (*texture)[1].x + (*texture)[3].x) &&
        nearly_equal((*texture)[0].y + (*texture)[2].y,
            (*texture)[1].y + (*texture)[3].y);
    if (covers_scene_extent(
            width, height, destination->width, destination->height)) {
        prepare_destination_for_frame(call, state,
            DamageRegion { left, top, right, bottom },
            state.source ? state.source->surface : 0U);
    }
    const auto matches_texture = [&](std::array<Point, 4> expected) {
        for (std::size_t index = 0; index < expected.size(); ++index) {
            if (!nearly_equal((*texture)[index].x, expected[index].x) ||
                !nearly_equal((*texture)[index].y, expected[index].y)) {
                return false;
            }
        }
        return true;
    };
    const auto source_left_f = static_cast<float>(source_left);
    const auto source_right_f = static_cast<float>(source_right);
    const auto source_top_f = static_cast<float>(source_top);
    const auto source_bottom_f = static_cast<float>(source_bottom);
    std::optional<HostRotation> host_rotation;
    if (matches_texture({ { { source_left_f, source_top_f },
            { source_right_f, source_top_f },
            { source_right_f, source_bottom_f },
            { source_left_f, source_bottom_f } } })) {
        host_rotation = HostRotation::Identity;
    } else if (matches_texture({ { { source_left_f, source_bottom_f },
                   { source_left_f, source_top_f },
                   { source_right_f, source_top_f },
                   { source_right_f, source_bottom_f } } })) {
        host_rotation = HostRotation::Clockwise90;
    } else if (matches_texture({ { { source_right_f, source_bottom_f },
                   { source_left_f, source_bottom_f },
                   { source_left_f, source_top_f },
                   { source_right_f, source_top_f } } })) {
        host_rotation = HostRotation::Rotate180;
    } else if (matches_texture({ { { source_right_f, source_top_f },
                   { source_right_f, source_bottom_f },
                   { source_left_f, source_bottom_f },
                   { source_left_f, source_top_f } } })) {
        host_rotation = HostRotation::Clockwise270;
    }
    const auto destination_unclipped =
        left == unclipped_left && right == unclipped_right &&
        top == unclipped_top && bottom == unclipped_bottom;
    const auto destination_integral =
        nearly_equal(left_value, static_cast<float>(unclipped_left)) &&
        nearly_equal(right_value, static_cast<float>(unclipped_right)) &&
        nearly_equal(top_value, static_cast<float>(unclipped_top)) &&
        nearly_equal(bottom_value, static_cast<float>(unclipped_bottom));
    const auto composite_mode = host_composite_mode(state);
    const auto host_source_current = synchronize_host_source(call, *source);
    const auto encode_host_rectangle = [&] {
        const auto started = std::chrono::steady_clock::now();
        const auto encoded = command_encoder_->copy(source->host_surface,
            destination->host_surface,
            { static_cast<std::int32_t>(source_left),
                static_cast<std::int32_t>(source_top),
                static_cast<std::uint32_t>(source_width),
                static_cast<std::uint32_t>(source_height) },
            { static_cast<std::int32_t>(left), static_cast<std::int32_t>(top),
                static_cast<std::uint32_t>(width),
                static_cast<std::uint32_t>(height) },
            *composite_mode, state.blend.global_alpha, HostFilter::Nearest,
            *host_rotation);
        performance_counters().record_diagnostic_graphics_hle(
            PerfDiagnosticGraphicsHleKind::HostCopyEncode,
            static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now() - started)
                    .count()));
        return encoded;
    };
    if (axis_aligned_affine && host_rotation && destination_unclipped &&
        destination_integral && host_graphics_->accelerated() &&
        host_source_current && source->host_surface &&
        destination->host_surface && source->backing && destination->backing &&
        source->backing->pixel_format == surface_pixel_format_bgra &&
        destination->backing->pixel_format == surface_pixel_format_bgra &&
        composite_mode &&
        source_left <= std::numeric_limits<std::int32_t>::max() &&
        source_top <= std::numeric_limits<std::int32_t>::max() &&
        left <= std::numeric_limits<std::int32_t>::max() &&
        top <= std::numeric_limits<std::int32_t>::max() &&
        static_cast<std::uint64_t>(source_width) <=
            std::numeric_limits<std::uint32_t>::max() &&
        static_cast<std::uint64_t>(source_height) <=
            std::numeric_limits<std::uint32_t>::max() &&
        static_cast<std::uint64_t>(width) <=
            std::numeric_limits<std::uint32_t>::max() &&
        static_cast<std::uint64_t>(height) <=
            std::numeric_limits<std::uint32_t>::max() &&
        encode_host_rectangle()) {
        performance_counters().record_hle("QuadCopy.NativeRectangle", 0);
        call.set_return(mbx2d_abi::success);
        return;
    }
    const auto ordered_geometry = triangles_share_only_diagonal(*positions);
    const auto host_ready =
        host_graphics_->accelerated() && host_source_current &&
        source->host_surface && destination->host_surface && source->backing &&
        destination->backing &&
        source->backing->pixel_format == surface_pixel_format_bgra &&
        destination->backing->pixel_format == surface_pixel_format_bgra;
    bool native_quad_attempted = false;
    if (ordered_geometry && host_ready && composite_mode &&
        left <= std::numeric_limits<std::int32_t>::max() &&
        top <= std::numeric_limits<std::int32_t>::max() &&
        static_cast<std::uint64_t>(width) <=
            std::numeric_limits<std::uint32_t>::max() &&
        static_cast<std::uint64_t>(height) <=
            std::numeric_limits<std::uint32_t>::max()) {
        native_quad_attempted = true;
        std::array<HostTexturedVertex, 4> quad { };
        for (std::size_t index = 0; index < quad.size(); ++index) {
            quad[index] = { { (*positions)[index].x, (*positions)[index].y },
                { (*texture)[index].x, (*texture)[index].y },
                perspective[index] };
        }
        const auto started = std::chrono::steady_clock::now();
        const auto encoded = command_encoder_->copy_quad(source->host_surface,
            destination->host_surface, quad,
            { static_cast<std::int32_t>(source_left),
                static_cast<std::int32_t>(source_top),
                static_cast<std::uint32_t>(source_width),
                static_cast<std::uint32_t>(source_height) },
            { static_cast<std::int32_t>(left), static_cast<std::int32_t>(top),
                static_cast<std::uint32_t>(width),
                static_cast<std::uint32_t>(height) },
            *composite_mode, state.blend.global_alpha, HostFilter::Nearest);
        performance_counters().record_diagnostic_graphics_hle(
            PerfDiagnosticGraphicsHleKind::HostQuadEncode,
            static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now() - started)
                    .count()));
        if (encoded) {
            call.set_return(mbx2d_abi::success);
            return;
        }
    }
    performance_counters().record_hle(native_quad_attempted
                                          ? "QuadCopy.NativeQuadDeclined"
                                          : "QuadCopy.NativeQuadIneligible",
        0);
    performance_counters().record_hle("QuadCopy.Software", 0);
    const auto source_pixels = read_region(
        *source, source_left, source_top, source_width, source_height, call);
    if (!source_pixels) {
        call.set_return(mbx2d_abi::failure);
        return;
    }
    const auto destination_pixels =
        read_region(*destination, left, top, width, height, call);
    if (!destination_pixels) {
        call.set_return(mbx2d_abi::failure);
        return;
    }
    std::vector<std::uint32_t> sampled = *destination_pixels;
    std::vector<bool> covered;
    if (axis_aligned_affine) {
        const auto inverse_width = 1.0F / (right_value - left_value);
        const auto inverse_height = 1.0F / (bottom_value - top_value);
        for (std::int64_t y = 0; y < height; ++y) {
            const auto vertical =
                (static_cast<float>(top + y) + 0.5F - top_value) *
                inverse_height;
            const auto row_u = (*texture)[0].x +
                               vertical * ((*texture)[3].x - (*texture)[0].x);
            const auto row_v = (*texture)[0].y +
                               vertical * ((*texture)[3].y - (*texture)[0].y);
            for (std::int64_t x = 0; x < width; ++x) {
                const auto horizontal =
                    (static_cast<float>(left + x) + 0.5F - left_value) *
                    inverse_width;
                const auto u =
                    row_u + horizontal * ((*texture)[1].x - (*texture)[0].x);
                const auto v =
                    row_v + horizontal * ((*texture)[1].y - (*texture)[0].y);
                const auto source_x = std::clamp<std::int64_t>(
                    static_cast<std::int64_t>(std::floor(u)), source_left,
                    source_right - 1);
                const auto source_y = std::clamp<std::int64_t>(
                    static_cast<std::int64_t>(std::floor(v)), source_top,
                    source_bottom - 1);
                sampled[static_cast<std::size_t>(y * width + x)] =
                    (*source_pixels)[static_cast<std::size_t>(
                        (source_y - source_top) * source_width + source_x -
                        source_left)];
            }
        }
    } else {
        covered.assign(static_cast<std::size_t>(width * height), false);
        for (std::int64_t y = 0; y < height; ++y) {
            for (std::int64_t x = 0; x < width; ++x) {
                const Point point { static_cast<float>(left + x) + 0.5F,
                    static_cast<float>(top + y) + 0.5F };
                const auto triangle = sample_quad(*positions, point);
                if (!triangle)
                    continue;
                const auto texture_point =
                    interpolate_perspective(*texture, perspective, *triangle);
                if (!texture_point)
                    continue;
                const auto u = texture_point->x;
                const auto v = texture_point->y;
                const auto source_x = std::clamp<std::int64_t>(
                    static_cast<std::int64_t>(std::floor(u)), source_left,
                    source_right - 1);
                const auto source_y = std::clamp<std::int64_t>(
                    static_cast<std::int64_t>(std::floor(v)), source_top,
                    source_bottom - 1);
                const auto destination_index =
                    static_cast<std::size_t>(y * width + x);
                sampled[destination_index] =
                    (*source_pixels)[static_cast<std::size_t>(
                        (source_y - source_top) * source_width + source_x -
                        source_left)];
                covered[destination_index] = true;
            }
        }
    }

    auto pixels =
        composite(state, *destination, left, top, width, height, sampled, call);
    if (!pixels) {
        call.set_return(mbx2d_abi::failure);
        return;
    }
    if (!axis_aligned_affine) {
        for (std::size_t index = 0; index < covered.size(); ++index) {
            if (!covered[index])
                (*pixels)[index] = (*destination_pixels)[index];
        }
    }
    call.set_return(
        write_region(*destination, left, top, width, height, *pixels, call)
            ? mbx2d_abi::success
            : mbx2d_abi::failure);
}

} // namespace shade
