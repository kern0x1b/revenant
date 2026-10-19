// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Blend premultiplied pixels using truncating eight-bit fixed-point
// alpha arithmetic.

#pragma once

#include <cstdint>
#include <span>

namespace shade {

// Premultiplied pixel arithmetic with a 256-step, truncating alpha factor.
// This is the integer scanline convention; normalized GLES blending differs.
class Fixed8PixelBlender {
public:
    static void source_over(std::span<const std::uint32_t> source,
        std::span<const std::uint32_t> destination,
        std::span<std::uint32_t> result);
};

} // namespace shade
