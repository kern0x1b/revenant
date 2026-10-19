// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve application presentation size and orientation from bundle
// metadata.

#pragma once

#include <cstdint>
#include <filesystem>
#include <span>
#include <string_view>
#include <vector>

#include "foundation/display_geometry.hpp"

namespace emulator {

enum class ApplicationDisplayMode : std::uint8_t {
    Native,
    IPhoneCompatibility1x,
};

struct ApplicationDisplay {
    ApplicationDisplayMode kind {
        ApplicationDisplayMode::Native
    };
    DisplayGeometry logical_geometry;
};

[[nodiscard]] ApplicationDisplay detect_application_display(
    const std::filesystem::path& rootfs, std::string_view executable_path,
    DisplayGeometry user_interface_geometry);

[[nodiscard]] DisplayGeometry application_display_geometry(
    const ApplicationDisplay& profile, DisplayGeometry output);

[[nodiscard]] DisplayViewport application_display_viewport(
    const ApplicationDisplay& profile, DisplayGeometry output);

[[nodiscard]] std::vector<std::uint32_t>
compose_application_display_pixels(const ApplicationDisplay& profile,
    DisplayGeometry source, DisplayGeometry output,
    std::span<const std::uint32_t> pixels);

[[nodiscard]] DisplayOrientation detect_application_display_orientation(
    const std::filesystem::path& rootfs, std::string_view executable_path);

[[nodiscard]] const char* display_orientation_name(
    DisplayOrientation orientation);

[[nodiscard]] std::vector<std::uint32_t> orient_display_pixels(
    DisplayGeometry source_geometry, std::span<const std::uint32_t> pixels,
    DisplayOrientation orientation);

}
