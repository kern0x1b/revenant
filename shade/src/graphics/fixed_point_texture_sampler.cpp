// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Sample texture scanlines using signed fixed-point coordinates.

#include "graphics/fixed_point_texture_sampler.hpp"

#include <algorithm>
#include <bit>

namespace shade {
namespace {

    std::uint32_t interpolate(
        std::uint32_t first, std::uint32_t second, std::uint32_t weight)
    {
        constexpr std::uint32_t lanes = 0x00ff00ffU;
        const auto low = first & lanes;
        const auto high = (first >> 8U) & lanes;
        return ((low + ((((second & lanes) - low) * weight) >> 8U)) & lanes) |
               (((high + (((((second >> 8U) & lanes) - high) * weight) >> 8U))
                    << 8U) &
                   ~lanes);
    }

} // namespace

void FixedPointTextureSampler::sample(
    std::span<const std::uint32_t> first_row,
    std::span<const std::uint32_t> second_row, std::uint32_t coordinate,
    std::uint32_t increment, std::int32_t maximum_coordinate,
    std::uint32_t vertical_weight, bool linear, bool opaque,
    std::span<std::uint32_t> destination)
{
    const auto clamp = [maximum_coordinate](std::uint32_t value) {
        return static_cast<std::uint32_t>(std::clamp(
            std::bit_cast<std::int32_t>(value), 0, maximum_coordinate));
    };
    for (auto& pixel : destination) {
        const auto left = clamp(coordinate - (linear ? 0x8000U : 0U));
        pixel = first_row[left >> 16U];
        if (linear) {
            const auto right = clamp(coordinate + 0x8000U) >> 16U;
            const auto first = interpolate(
                pixel, second_row[left >> 16U], vertical_weight);
            const auto second = interpolate(
                first_row[right], second_row[right], vertical_weight);
            pixel = interpolate(first, second, (left >> 8U) & 0xffU);
        }
        if (opaque)
            pixel |= 0xff000000U;
        coordinate += increment;
    }
}

} // namespace shade
