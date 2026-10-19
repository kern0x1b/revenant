// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Blend premultiplied pixels using truncating eight-bit fixed-point
// alpha arithmetic.

#include "graphics/fixed8_pixel_blender.hpp"

namespace shade {

void Fixed8PixelBlender::source_over(std::span<const std::uint32_t> source,
    std::span<const std::uint32_t> destination,
    std::span<std::uint32_t> result)
{
    constexpr auto lanes = 0x00ff00ffU;
    for (std::size_t index = 0; index < result.size(); ++index) {
        const auto factor = 256U - (source[index] >> 24U);
        const auto pixel = destination[index];
        const auto low = (((pixel & lanes) * factor) >> 8U) & lanes;
        const auto high = (((pixel >> 8U) & lanes) * factor) & ~lanes;
        result[index] = source[index] + (low | high);
    }
}

} // namespace shade
