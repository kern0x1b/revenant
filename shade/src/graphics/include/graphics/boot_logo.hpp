// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>
#include <filesystem>
#include <vector>

#include "foundation/display_geometry.hpp"

namespace shade {

// A prepared firmware asset, independent of SDL and the guest compositor.
class BootLogo {
public:
    // Center native pixels on a black panel. Alpha is composited onto black;
    // oversized images are clipped rather than distorted or enlarged.
    [[nodiscard]] static std::vector<std::uint32_t> load(
        const std::filesystem::path& path, DisplayGeometry panel);
    [[nodiscard]] static std::vector<std::uint32_t> placeholder(
        DisplayGeometry panel);
};

} // namespace shade
