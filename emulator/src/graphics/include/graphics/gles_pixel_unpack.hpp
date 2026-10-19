// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe client-memory layout independently of texture dimensions.

#pragma once

#include "graphics/gles_abi.hpp"

#include <cstdint>

namespace shade {

struct GlesPixelUnpack {
    std::uint32_t alignment { gles_abi::default_pixel_alignment };
    std::uint32_t row_length { };
    std::uint32_t skip_rows { };
    std::uint32_t skip_pixels { };
    std::uint32_t row_bytes { };
};

}
