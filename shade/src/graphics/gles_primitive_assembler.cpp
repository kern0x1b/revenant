// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expand guest GLES primitive topologies into renderer-independent
// batches.

#include "graphics/gles_primitive_assembler.hpp"

#include <cmath>
#include <cstddef>
#include <limits>
#include <new>
#include <optional>
#include <span>
#include <stdexcept>
#include <vector>

#include "graphics/gles_abi.hpp"

namespace shade {
namespace {

    bool is_triangle_mode(std::uint32_t mode)
    {
        return mode == gles_abi::triangles ||
               mode == gles_abi::triangle_strip ||
               mode == gles_abi::triangle_fan;
    }

    bool is_line_mode(std::uint32_t mode)
    {
        return mode == gles_abi::lines || mode == gles_abi::line_strip ||
               mode == gles_abi::line_loop;
    }

    std::size_t line_segment_count(std::uint32_t mode, std::size_t vertex_count)
    {
        if (vertex_count < 2U)
            return 0U;
        if (mode == gles_abi::lines)
            return vertex_count / 2U;
        if (mode == gles_abi::line_strip)
            return vertex_count - 1U;
        return vertex_count;
    }

    bool append_line_segment(std::vector<GlesRasterVertex>& destination,
        const GlesRasterVertex& start, const GlesRasterVertex& end,
        const GlesRasterState& state)
    {
        const auto start_w = start.position[3];
        const auto end_w = end.position[3];
        if (!std::isfinite(start_w) || !std::isfinite(end_w) ||
            start_w == 0.0F || end_w == 0.0F) {
            return false;
        }

        const auto start_x = start.position[0] / start_w;
        const auto start_y = start.position[1] / start_w;
        const auto end_x = end.position[0] / end_w;
        const auto end_y = end.position[1] / end_w;
        if (!std::isfinite(start_x) || !std::isfinite(start_y) ||
            !std::isfinite(end_x) || !std::isfinite(end_y)) {
            return false;
        }

        const auto viewport_width = static_cast<float>(state.viewport_width);
        const auto viewport_height = static_cast<float>(state.viewport_height);
        const auto delta_x = (end_x - start_x) * viewport_width * 0.5F;
        const auto delta_y = (end_y - start_y) * viewport_height * 0.5F;
        const auto length = std::hypot(delta_x, delta_y);
        if (!std::isfinite(length))
            return false;
        if (length <= std::numeric_limits<float>::epsilon())
            return true;

        const auto half_width = state.line_width * 0.5F;
        const auto perpendicular_x = -delta_y * half_width / length;
        const auto perpendicular_y = delta_x * half_width / length;
        const auto offset_x = 2.0F * perpendicular_x / viewport_width;
        const auto offset_y = 2.0F * perpendicular_y / viewport_height;

        auto start_positive = start;
        auto start_negative = start;
        auto end_positive = end;
        auto end_negative = end;
        start_positive.position[0] += offset_x * start_w;
        start_positive.position[1] += offset_y * start_w;
        start_negative.position[0] -= offset_x * start_w;
        start_negative.position[1] -= offset_y * start_w;
        end_positive.position[0] += offset_x * end_w;
        end_positive.position[1] += offset_y * end_w;
        end_negative.position[0] -= offset_x * end_w;
        end_negative.position[1] -= offset_y * end_w;

        destination.push_back(start_positive);
        destination.push_back(start_negative);
        destination.push_back(end_negative);
        destination.push_back(start_positive);
        destination.push_back(end_negative);
        destination.push_back(end_positive);
        return true;
    }

} // namespace

std::span<const GlesRasterVertex> GlesPrimitiveBatch::vertices() const
{
    if (expanded_)
        return *expanded_;
    return source_;
}

bool GlesPrimitiveAssembler::supports(std::uint32_t mode)
{
    return is_triangle_mode(mode) || is_line_mode(mode);
}

std::size_t GlesPrimitiveAssembler::minimum_vertex_count(std::uint32_t mode)
{
    if (is_line_mode(mode))
        return 2U;
    if (is_triangle_mode(mode))
        return 3U;
    return 0U;
}

std::optional<GlesPrimitiveBatch> GlesPrimitiveAssembler::assemble(
    std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
    const GlesRasterState& state)
{
    if (!supports(mode))
        return std::nullopt;

    GlesPrimitiveBatch batch;
    batch.source_ = vertices;
    batch.mode_ = mode;
    if (is_triangle_mode(mode))
        return batch;

    if (state.viewport_width == 0U || state.viewport_height == 0U ||
        !std::isfinite(state.line_width) || state.line_width <= 0.0F) {
        return std::nullopt;
    }

    batch.mode_ = gles_abi::triangles;
    batch.ignores_culling_ = true;
    batch.expanded_.emplace();
    auto& expanded = *batch.expanded_;
    const auto segment_count = line_segment_count(mode, vertices.size());
    if (segment_count > expanded.max_size() / 6U)
        return std::nullopt;
    try {
        expanded.reserve(segment_count * 6U);
    } catch (const std::bad_alloc&) {
        return std::nullopt;
    } catch (const std::length_error&) {
        return std::nullopt;
    }

    const auto append = [&](std::size_t start, std::size_t end) {
        return append_line_segment(
            expanded, vertices[start], vertices[end], state);
    };
    if (mode == gles_abi::lines) {
        for (std::size_t index = 0; index + 1U < vertices.size(); index += 2U) {
            if (!append(index, index + 1U))
                return std::nullopt;
        }
    } else {
        for (std::size_t index = 0; index + 1U < vertices.size(); ++index) {
            if (!append(index, index + 1U))
                return std::nullopt;
        }
        if (mode == gles_abi::line_loop && vertices.size() > 1U &&
            !append(vertices.size() - 1U, 0U)) {
            return std::nullopt;
        }
    }
    return batch;
}

} // namespace shade
