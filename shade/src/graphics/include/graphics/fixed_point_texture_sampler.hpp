// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Sample texture scanlines using signed fixed-point coordinates.

#pragma once

#include <cstdint>
#include <span>

namespace shade {

// Scanline sampling with signed 16.16 coordinates and truncating eight-bit
// interpolation weights. This preserves the integer software-renderer ABI.
class FixedPointTextureSampler {
public:
    static void sample(std::span<const std::uint32_t> first_row,
        std::span<const std::uint32_t> second_row, std::uint32_t coordinate,
        std::uint32_t increment, std::int32_t maximum_coordinate,
        std::uint32_t vertical_weight, bool linear, bool opaque,
        std::span<std::uint32_t> destination);
};

} // namespace shade
