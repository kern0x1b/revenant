// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode emulated image-device output through the host JPEG codec.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <vector>

namespace shade {

[[nodiscard]] std::optional<std::vector<std::byte>> encode_jpeg_argb(
    std::span<const std::uint32_t> pixels, std::uint32_t width,
    std::uint32_t height, int quality = 90);

}
