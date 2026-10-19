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
    // Zero selects the upload width. Row length and skips are in pixels/rows,
    // not bytes, and apply to both image and subimage uploads.
    std::uint32_t row_length { };
    std::uint32_t skip_rows { };
    std::uint32_t skip_pixels { };
    // APPLE_row_bytes overrides row length and alignment when nonzero.
    std::uint32_t row_bytes { };
};

} // namespace shade
